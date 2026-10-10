use std::fs::{self, File, OpenOptions};
use std::io::Write;
use std::path::Path;
use std::sync::{Arc, Mutex};

use fs2::FileExt;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};

pub type Progress = Arc<dyn Fn(ProgressUpdate) + Send + Sync>;
pub type UploadProgress = Arc<dyn Fn(u64, u64) + Send + Sync>;

#[derive(Serialize)]
pub struct ProgressUpdate {
    pub phase: &'static str,
    pub message: &'static str,
    pub progress: Option<f64>,
    pub sent: u64,
    pub total: u64,
}

struct UploadCounter {
    finished: u64,
    total: u64,
    current_total: u64,
    current_sent: u64,
}

#[derive(Deserialize)]
pub struct Input {
    pub account_id: String,
    pub token: String,
    pub session: crate::transport::SessionOptions,
    #[serde(default)]
    pub login: Value,
    pub request: ShareRequest,
}

#[derive(Deserialize, Serialize)]
pub struct ShareRequest {
    pub id: String,
    pub chat_id: String,
    #[serde(default)]
    pub files: Vec<SharedFile>,
    #[serde(default)]
    pub text: String,
    pub state_path: String,
}

#[derive(Clone, Deserialize, Serialize)]
pub struct SharedFile {
    pub path: String,
    pub name: String,
    pub mime: String,
    pub size: u64,
}

impl SharedFile {
    pub fn is_photo(&self) -> bool {
        self.mime.starts_with("image/") && self.mime != "image/gif" && self.mime != "image/svg+xml"
    }
}

impl Input {
    pub fn validate_files(&self) -> Result<(), String> {
        for file in &self.request.files {
            let metadata = fs::symlink_metadata(&file.path)
                .map_err(|_| "Файл больше недоступен. Выберите его заново".to_string())?;
            if !Path::new(&file.path).is_absolute()
                || !metadata.is_file()
                || metadata.len() != file.size
                || file.name.is_empty()
            {
                return Err("Файл изменён или недоступен. Выберите его заново".into());
            }
        }
        Ok(())
    }
}

#[derive(Serialize, Debug)]
pub struct Outcome {
    pub status: String,
    pub message: String,
    pub sent_count: usize,
    pub total_count: usize,
    pub message_ids: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub refreshed_token: Option<String>,
}

impl Outcome {
    pub fn failed(message: &str) -> Self {
        Self {
            status: "failed".into(),
            message: message.into(),
            sent_count: 0,
            total_count: 0,
            message_ids: vec![],
            refreshed_token: None,
        }
    }

    pub fn unknown(message: &str) -> Self {
        Self {
            status: "unknown".into(),
            ..Self::failed(message)
        }
    }
}

#[derive(Deserialize, Serialize)]
struct SavedState {
    version: u32,
    identity: String,
    entries: Vec<Entry>,
}

#[derive(Deserialize, Serialize)]
struct Entry {
    files: Vec<usize>,
    cid: i64,
    status: EntryStatus,
    payload: Option<Value>,
    message_id: Option<String>,
}

#[derive(Clone, Copy, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "snake_case")]
enum EntryStatus {
    Pending,
    Sending,
    Sent,
    Failed,
    Unknown,
}

pub struct Journal {
    path: String,
    state: SavedState,
    _lock: File,
}

impl Journal {
    pub fn open(input: &Input) -> Result<Self, Outcome> {
        let request = &input.request;
        if input.account_id.parse::<i64>().is_err()
            || request.chat_id.parse::<i64>().is_err()
            || request.id.is_empty()
            || input.token.is_empty()
            || request.files.len() > 30
            || (request.files.is_empty() && request.text.trim().is_empty())
            || !Path::new(&request.state_path).is_absolute()
        {
            return Err(Outcome::failed("Недостаточно данных для отправки"));
        }
        let lock = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(format!("{}.lock", request.state_path))
            .map_err(|_| Outcome::failed("Не удалось сохранить состояние отправки"))?;
        lock.try_lock_exclusive()
            .map_err(|_| Outcome::failed("Эта отправка уже выполняется"))?;
        let identity = hex::encode(Sha256::digest(
            json!({
                "account_id": input.account_id,
                "request": request,
            })
            .to_string(),
        ));
        let state = match fs::read(&request.state_path) {
            Ok(bytes) => {
                let state: SavedState = serde_json::from_slice(&bytes).map_err(|_| {
                    Outcome::unknown("Состояние отправки повреждено. Проверьте чат")
                })?;
                if state.version != 1 || state.identity != identity {
                    return Err(Outcome::unknown(
                        "Данные отправки изменены. Проверьте чат перед повтором",
                    ));
                }
                state
            }
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                let photos: Vec<usize> = request
                    .files
                    .iter()
                    .enumerate()
                    .filter_map(|(index, file)| file.is_photo().then_some(index))
                    .collect();
                let mut groups = Vec::new();
                if !photos.is_empty() {
                    groups.push(photos);
                }
                groups.extend(
                    request
                        .files
                        .iter()
                        .enumerate()
                        .filter_map(|(index, file)| (!file.is_photo()).then_some(vec![index])),
                );
                if groups.is_empty() {
                    groups.push(vec![]);
                }
                let entries = groups
                    .into_iter()
                    .enumerate()
                    .map(|(index, files)| {
                        let digest = Sha256::digest(format!(
                            "{}:{}:{}",
                            input.account_id, request.id, index
                        ));
                        let raw = i64::from_be_bytes(digest[..8].try_into().unwrap());
                        Entry {
                            files,
                            cid: -(raw & i64::MAX).max(1),
                            status: EntryStatus::Pending,
                            payload: None,
                            message_id: None,
                        }
                    })
                    .collect();
                SavedState {
                    version: 1,
                    identity,
                    entries,
                }
            }
            Err(_) => {
                return Err(Outcome::unknown(
                    "Не удалось прочитать состояние отправки. Проверьте чат",
                ))
            }
        };
        let journal = Self {
            path: request.state_path.clone(),
            state,
            _lock: lock,
        };
        journal
            .persist()
            .map_err(|_| Outcome::failed("Не удалось сохранить состояние отправки"))?;
        Ok(journal)
    }

    fn persist(&self) -> Result<(), ()> {
        let parent = Path::new(&self.path).parent().ok_or(())?;
        let mut file = tempfile::NamedTempFile::new_in(parent).map_err(|_| ())?;
        serde_json::to_writer(&mut file, &self.state).map_err(|_| ())?;
        file.flush().map_err(|_| ())?;
        file.as_file().sync_all().map_err(|_| ())?;
        file.persist(&self.path).map_err(|_| ())?;
        Ok(())
    }

    pub fn terminal(&self) -> Option<Outcome> {
        if self
            .state
            .entries
            .iter()
            .all(|entry| entry.status == EntryStatus::Sent)
        {
            return Some(self.outcome("sent", "Отправлено"));
        }
        if self
            .state
            .entries
            .iter()
            .any(|entry| matches!(entry.status, EntryStatus::Sending | EntryStatus::Unknown))
        {
            return Some(self.outcome(
                "unknown",
                "Сервер мог получить сообщение. Проверьте чат; автоматический повтор остановлен",
            ));
        }
        None
    }

    pub fn outcome(&self, status: &str, message: &str) -> Outcome {
        Outcome {
            status: status.into(),
            message: message.into(),
            sent_count: self
                .state
                .entries
                .iter()
                .filter(|entry| entry.status == EntryStatus::Sent)
                .count(),
            total_count: self.state.entries.len(),
            message_ids: self
                .state
                .entries
                .iter()
                .filter_map(|entry| entry.message_id.clone())
                .collect(),
            refreshed_token: None,
        }
    }
}

pub enum SendError {
    Rejected(String),
    Unknown,
}

pub trait Transport {
    async fn upload(
        &mut self,
        file: &SharedFile,
        progress: UploadProgress,
    ) -> Result<Value, String>;
    async fn send(&mut self, payload: &Value) -> Result<String, SendError>;
}

pub async fn deliver(
    input: &Input,
    journal: &mut Journal,
    transport: &mut impl Transport,
    progress: Progress,
) -> Outcome {
    if let Some(outcome) = journal.terminal() {
        return outcome;
    }
    let count = journal.state.entries.len();
    let counter = Arc::new(Mutex::new(UploadCounter {
        total: input.request.files.iter().map(|file| file.size).sum(),
        finished: journal
            .state
            .entries
            .iter()
            .filter(|entry| entry.payload.is_some())
            .flat_map(|entry| &entry.files)
            .map(|index| input.request.files[*index].size)
            .sum(),
        current_total: 0,
        current_sent: 0,
    }));
    for index in 0..count {
        if journal.state.entries[index].status == EntryStatus::Sent {
            continue;
        }
        if journal.state.entries[index].payload.is_none() {
            let mut attachments = Vec::new();
            let files = journal.state.entries[index].files.clone();
            for file_index in &files {
                let callback = progress.clone();
                {
                    let mut bytes = counter.lock().unwrap();
                    bytes.current_total = input.request.files[*file_index].size;
                    bytes.current_sent = 0;
                }
                let bytes = counter.clone();
                let file_progress: UploadProgress = Arc::new(move |sent, total| {
                    let mut bytes = bytes.lock().unwrap();
                    if total > 0 {
                        bytes.total = bytes
                            .total
                            .saturating_sub(bytes.current_total)
                            .saturating_add(total);
                        bytes.current_total = total;
                    }
                    bytes.current_sent = bytes.current_sent.max(sent.min(bytes.current_total));
                    let sent = bytes.finished.saturating_add(bytes.current_sent);
                    let total = bytes.total;
                    callback(ProgressUpdate {
                        phase: "uploading",
                        message: "Загрузка вложений…",
                        progress: (total > 0).then(|| (sent as f64 / total as f64).clamp(0.0, 1.0)),
                        sent,
                        total,
                    });
                });
                match transport
                    .upload(&input.request.files[*file_index], file_progress)
                    .await
                {
                    Ok(attachment) => {
                        attachments.push(attachment);
                        let mut bytes = counter.lock().unwrap();
                        bytes.finished = bytes.finished.saturating_add(bytes.current_total);
                    }
                    Err(message) => return journal.outcome("failed", &message),
                }
            }
            let mut message = json!({
                "cid": journal.state.entries[index].cid,
                "attaches": attachments,
                "isLive": false,
                "detectShare": false,
                "elements": [],
            });
            if index == 0 && !input.request.text.trim().is_empty() {
                message["text"] = json!(input.request.text);
            }
            journal.state.entries[index].payload = Some(json!({
                "chatId": input.request.chat_id.parse::<i64>().unwrap(),
                "message": message,
                "notify": true,
            }));
            if journal.persist().is_err() {
                return journal.outcome(
                    "failed",
                    "Не удалось сохранить загрузку. Сообщение не отправлено",
                );
            }
        }
    }
    for index in 0..count {
        if journal.state.entries[index].status == EntryStatus::Sent {
            continue;
        }
        journal.state.entries[index].status = EntryStatus::Sending;
        if journal.persist().is_err() {
            journal.state.entries[index].status = EntryStatus::Failed;
            return journal.outcome(
                "failed",
                "Не удалось сохранить отправку. Сообщение не отправлено",
            );
        }
        let total = counter.lock().unwrap().total;
        progress(ProgressUpdate {
            phase: "sending",
            message: "Подтверждение отправки…",
            progress: (total > 0).then_some(1.0),
            sent: total,
            total,
        });
        let payload = journal.state.entries[index].payload.as_ref().unwrap();
        match transport.send(payload).await {
            Ok(message_id) => {
                journal.state.entries[index].status = EntryStatus::Sent;
                journal.state.entries[index].message_id = Some(message_id);
                if journal.persist().is_err() {
                    return journal.outcome(
                        "unknown",
                        "Сообщение отправлено, но подтверждение не сохранено. Проверьте чат",
                    );
                }
            }
            Err(SendError::Rejected(message)) => {
                journal.state.entries[index].status = EntryStatus::Failed;
                if journal.persist().is_err() {
                    return journal
                        .outcome("unknown", "Не удалось сохранить результат. Проверьте чат");
                }
                return journal.outcome("failed", &message);
            }
            Err(SendError::Unknown) => {
                journal.state.entries[index].status = EntryStatus::Unknown;
                let _ = journal.persist();
                return journal.outcome(
                    "unknown",
                    "Соединение прервано после отправки. Проверьте чат; повтор остановлен",
                );
            }
        }
    }
    let total = counter.lock().unwrap().total;
    progress(ProgressUpdate {
        phase: "sent",
        message: "Отправлено",
        progress: (total > 0).then_some(1.0),
        sent: total,
        total,
    });
    journal.outcome("sent", "Отправлено")
}

#[cfg(test)]
pub(crate) mod tests;
