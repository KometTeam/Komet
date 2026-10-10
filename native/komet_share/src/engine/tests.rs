use super::*;
use std::collections::VecDeque;

pub(crate) fn input(directory: &Path, files: Vec<SharedFile>) -> Input {
    serde_json::from_value(json!({
        "account_id": "123", "token": "synthetic-auth-token",
        "session": {
            "host": "example.test", "port": 443, "device_id": "synthetic-device",
            "instance_id": "synthetic-instance", "app_version": "1.0", "build_number": 1,
            "device_type": "IOS", "os_version": "18.0", "timezone": "UTC", "screen": "390x844",
            "push_device_type": "APNS", "arch": "arm64", "locale": "ru", "device_name": "Synthetic Phone",
            "device_locale": "ru_RU", "client_session_id": 321, "ping_interactive": true,
            "fingerprint_digests": {"signature": "010203", "dex": "040506", "so": "070809"}
        },
        "login": {"chatCacheFingerprint": "stale", "exp": {"chatsCountGroups": {"$bin": "CzI="}}},
        "request": {"id": "synthetic-request", "chat_id": "456", "files": files,
            "text": "Synthetic caption", "state_path": directory.join("state.json")}
    })).unwrap()
}

fn file(directory: &Path, name: &str, mime: &str, size: usize) -> SharedFile {
    let path = directory.join(name);
    fs::write(&path, vec![0_u8; size]).unwrap();
    SharedFile {
        path: path.to_str().unwrap().into(),
        name: name.into(),
        mime: mime.into(),
        size: size as u64,
    }
}

#[derive(Default)]
struct FakeTransport {
    uploaded: Vec<String>,
    sent: Vec<Value>,
    replies: VecDeque<Result<String, SendError>>,
    state_path: Option<String>,
    upload_failure: bool,
    out_of_order_progress: bool,
}

impl Transport for FakeTransport {
    async fn upload(
        &mut self,
        file: &SharedFile,
        progress: UploadProgress,
    ) -> Result<Value, String> {
        self.uploaded.push(file.name.clone());
        progress(file.size / 2, file.size);
        if self.upload_failure {
            return Err("Synthetic upload failure".into());
        }
        progress(file.size, file.size);
        if self.out_of_order_progress {
            progress(file.size / 4, file.size);
        }
        Ok(json!({"_type": if file.is_photo() { "PHOTO" } else { "FILE" }, "token": file.name}))
    }

    async fn send(&mut self, payload: &Value) -> Result<String, SendError> {
        if let Some(path) = &self.state_path {
            let state: Value = serde_json::from_slice(&fs::read(path).unwrap()).unwrap();
            assert!(state["entries"].as_array().unwrap().iter().any(|entry| {
                entry["cid"] == payload["message"]["cid"] && entry["status"] == "sending"
            }));
        }
        self.sent.push(payload.clone());
        self.replies
            .pop_front()
            .unwrap_or_else(|| Ok(format!("synthetic-message-{}", self.sent.len())))
    }
}

fn events() -> (Progress, Arc<Mutex<Vec<Value>>>) {
    let values = Arc::new(Mutex::new(Vec::new()));
    let storage = values.clone();
    (
        Arc::new(move |event| {
            storage
                .lock()
                .unwrap()
                .push(serde_json::to_value(event).unwrap())
        }),
        values,
    )
}

#[tokio::test]
async fn photos_form_album_and_caption_is_sent_once() {
    let directory = tempfile::tempdir().unwrap();
    let input = input(
        directory.path(),
        vec![
            file(directory.path(), "doc.pdf", "application/pdf", 100),
            file(directory.path(), "first.jpg", "image/jpeg", 200),
            file(directory.path(), "second.jpg", "image/jpeg", 300),
            file(directory.path(), "animated.gif", "image/gif", 400),
        ],
    );
    let mut journal = Journal::open(&input).unwrap();
    let mut transport = FakeTransport {
        state_path: Some(input.request.state_path.clone()),
        ..Default::default()
    };
    let (progress, values) = events();
    let outcome = deliver(&input, &mut journal, &mut transport, progress).await;
    assert_eq!(outcome.status, "sent");
    assert_eq!(outcome.sent_count, 3);
    assert_eq!(
        transport.sent[0]["message"]["attaches"]
            .as_array()
            .unwrap()
            .len(),
        2
    );
    assert_eq!(transport.sent[0]["message"]["text"], "Synthetic caption");
    assert!(transport.sent[1]["message"].get("text").is_none());
    assert_eq!(transport.sent[2]["message"]["attaches"][0]["_type"], "FILE");
    let values = values.lock().unwrap();
    let first_sending = values
        .iter()
        .position(|event| event["phase"] == "sending")
        .unwrap();
    assert!(values[first_sending..]
        .iter()
        .all(|event| event["phase"] != "uploading"));
    assert_eq!(values.last().unwrap()["phase"], "sent");
    assert!(!fs::read_to_string(&input.request.state_path)
        .unwrap()
        .contains(&input.token));
}

#[tokio::test]
async fn unknown_send_is_never_repeated_after_restart() {
    let directory = tempfile::tempdir().unwrap();
    let input = input(directory.path(), vec![]);
    let mut journal = Journal::open(&input).unwrap();
    let mut transport = FakeTransport {
        replies: VecDeque::from([Err(SendError::Unknown)]),
        state_path: Some(input.request.state_path.clone()),
        ..Default::default()
    };
    let (progress, values) = events();
    assert_eq!(
        deliver(&input, &mut journal, &mut transport, progress)
            .await
            .status,
        "unknown"
    );
    assert!(values
        .lock()
        .unwrap()
        .iter()
        .all(|event| event["phase"] != "sent"));
    drop(journal);
    let mut journal = Journal::open(&input).unwrap();
    let mut restarted = FakeTransport::default();
    assert_eq!(
        deliver(&input, &mut journal, &mut restarted, events().0)
            .await
            .status,
        "unknown"
    );
    assert!(restarted.sent.is_empty());
}

#[tokio::test]
async fn crash_with_sending_marker_blocks_duplicate_even_without_unknown_write() {
    let directory = tempfile::tempdir().unwrap();
    let input = input(directory.path(), vec![]);
    let mut journal = Journal::open(&input).unwrap();
    journal.state.entries[0].status = EntryStatus::Sending;
    journal.persist().unwrap();
    drop(journal);
    let mut restarted = Journal::open(&input).unwrap();
    let mut transport = FakeTransport::default();
    assert_eq!(
        deliver(&input, &mut restarted, &mut transport, events().0)
            .await
            .status,
        "unknown"
    );
    assert!(transport.sent.is_empty());
}

#[tokio::test]
async fn explicit_retry_skips_sent_messages_and_reuses_cid_and_upload() {
    let directory = tempfile::tempdir().unwrap();
    let input = input(
        directory.path(),
        vec![
            file(directory.path(), "one.pdf", "application/pdf", 100),
            file(directory.path(), "two.pdf", "application/pdf", 300),
        ],
    );
    let mut journal = Journal::open(&input).unwrap();
    let mut transport = FakeTransport {
        replies: VecDeque::from([
            Ok("synthetic-first".into()),
            Err(SendError::Rejected("Synthetic rejection".into())),
        ]),
        ..Default::default()
    };
    let outcome = deliver(&input, &mut journal, &mut transport, events().0).await;
    assert_eq!(outcome.status, "failed");
    assert_eq!(outcome.sent_count, 1);
    let failed_cid = transport.sent[1]["message"]["cid"].clone();
    drop(journal);
    let mut journal = Journal::open(&input).unwrap();
    let mut retry = FakeTransport::default();
    let outcome = deliver(&input, &mut journal, &mut retry, events().0).await;
    assert_eq!(outcome.status, "sent");
    assert_eq!(outcome.sent_count, 2);
    assert_eq!(retry.sent.len(), 1);
    assert_eq!(retry.sent[0]["message"]["cid"], failed_cid);
    assert!(retry.uploaded.is_empty());
    drop(journal);
    assert_eq!(
        Journal::open(&input).unwrap().terminal().unwrap().status,
        "sent"
    );
}

#[tokio::test]
async fn progress_uses_aggregate_bytes_and_text_remains_indeterminate() {
    let directory = tempfile::tempdir().unwrap();
    let input = input(
        directory.path(),
        vec![
            file(directory.path(), "one.pdf", "application/pdf", 100),
            file(directory.path(), "two.pdf", "application/pdf", 300),
        ],
    );
    let mut journal = Journal::open(&input).unwrap();
    let (progress, values) = events();
    deliver(
        &input,
        &mut journal,
        &mut FakeTransport::default(),
        progress,
    )
    .await;
    let values = values.lock().unwrap();
    let uploading: Vec<_> = values
        .iter()
        .filter(|event| event["phase"] == "uploading")
        .collect();
    assert_eq!(
        uploading
            .iter()
            .map(|value| value["sent"].as_u64().unwrap())
            .collect::<Vec<_>>(),
        vec![50, 100, 250, 400]
    );
    assert_eq!(
        uploading
            .iter()
            .map(|value| value["progress"].as_f64().unwrap())
            .collect::<Vec<_>>(),
        vec![0.125, 0.25, 0.625, 1.0]
    );
    assert!(uploading.iter().all(|event| event["total"] == 400));
    drop(values);
    let text_directory = tempfile::tempdir().unwrap();
    let text = self::input(text_directory.path(), vec![]);
    let mut journal = Journal::open(&text).unwrap();
    let (progress, values) = events();
    deliver(&text, &mut journal, &mut FakeTransport::default(), progress).await;
    assert!(values
        .lock()
        .unwrap()
        .iter()
        .all(|event| event["progress"].is_null()));
}

#[tokio::test]
async fn failed_upload_does_not_attempt_message_send() {
    let directory = tempfile::tempdir().unwrap();
    let input = input(
        directory.path(),
        vec![file(directory.path(), "test.pdf", "application/pdf", 100)],
    );
    let mut journal = Journal::open(&input).unwrap();
    let mut transport = FakeTransport {
        upload_failure: true,
        ..Default::default()
    };
    let outcome = deliver(&input, &mut journal, &mut transport, events().0).await;
    assert_eq!(outcome.status, "failed");
    assert!(transport.sent.is_empty());
}

#[test]
fn exclusive_journal_and_identity_prevent_parallel_or_modified_replay() {
    let directory = tempfile::tempdir().unwrap();
    let mut input = input(directory.path(), vec![]);
    let journal = Journal::open(&input).unwrap();
    assert_eq!(Journal::open(&input).err().unwrap().status, "failed");
    drop(journal);
    input.request.text = "Changed caption".into();
    assert_eq!(Journal::open(&input).err().unwrap().status, "unknown");
}

#[test]
fn missing_or_changed_file_is_rejected_before_network() {
    let directory = tempfile::tempdir().unwrap();
    let input = input(
        directory.path(),
        vec![file(
            directory.path(),
            "name\"with quote.txt",
            "text/plain",
            100,
        )],
    );
    assert!(input.validate_files().is_ok());
    fs::write(&input.request.files[0].path, b"changed").unwrap();
    assert!(input.validate_files().is_err());
}

#[tokio::test]
async fn concurrent_video_callback_order_cannot_reduce_sent_bytes() {
    let directory = tempfile::tempdir().unwrap();
    let input = input(
        directory.path(),
        vec![file(directory.path(), "clip.mp4", "video/mp4", 400)],
    );
    let mut journal = Journal::open(&input).unwrap();
    let mut transport = FakeTransport {
        out_of_order_progress: true,
        ..Default::default()
    };
    let (progress, values) = events();
    deliver(&input, &mut journal, &mut transport, progress).await;
    let values = values.lock().unwrap();
    let sent: Vec<_> = values
        .iter()
        .filter(|event| event["phase"] == "uploading")
        .map(|event| event["sent"].as_u64().unwrap())
        .collect();
    assert_eq!(sent, vec![200, 400, 400]);
}
