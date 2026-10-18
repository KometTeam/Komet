use super::*;
use std::collections::VecDeque;

pub(crate) fn input(directory: &Path, files: Vec<SharedFile>) -> Input {
    fs::write(directory.join("accounts.lock"), b"").unwrap();
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as u64;
    fs::write(
        directory.join("accounts.json"),
        serde_json::to_vec(&json!([{
            "id": "123", "policyEpoch": "synthetic-policy", "updatedAtMillis": now,
            "chats": [{"id": "456"}]
        }]))
        .unwrap(),
    )
    .unwrap();
    serde_json::from_value(json!({
        "account_id": "123", "token": "synthetic-auth-token",
        "authorization": {"snapshot_path": directory.join("accounts.json"),
            "lock_path": directory.join("accounts.lock"), "epoch": "synthetic-policy"},
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

fn story_input(directory: &Path, files: Vec<SharedFile>) -> Input {
    let mut input = input(directory, files);
    input.request.target = ShareTarget::Story;
    input.request.chat_id = "-1".into();
    let snapshot = Path::new(&input.authorization.as_ref().unwrap().snapshot_path);
    let mut accounts: Value = serde_json::from_slice(&fs::read(snapshot).unwrap()).unwrap();
    accounts[0]["chats"] = json!([{"id": "456"}, {"id": "-1"}]);
    fs::write(snapshot, serde_json::to_vec(&accounts).unwrap()).unwrap();
    input
}

#[derive(Default)]
struct FakeTransport {
    uploaded: Vec<String>,
    sent: Vec<Value>,
    opcodes: Vec<u16>,
    replies: VecDeque<Result<String, SendError>>,
    state_path: Option<String>,
    upload_failure: bool,
    out_of_order_progress: bool,
    revoke_during_upload: Option<String>,
    completed_upload: bool,
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
        if let Some(path) = &self.revoke_during_upload {
            fs::write(path, b"[]").unwrap();
            tokio::time::sleep(std::time::Duration::from_millis(250)).await;
        }
        self.completed_upload = true;
        progress(file.size, file.size);
        if self.out_of_order_progress {
            progress(file.size / 4, file.size);
        }
        Ok(json!({"_type": if file.is_photo() { "PHOTO" } else { "FILE" }, "token": file.name}))
    }

    async fn send(&mut self, opcode: u16, payload: &Value) -> Result<String, SendError> {
        if let Some(path) = &self.state_path {
            let state: Value = serde_json::from_slice(&fs::read(path).unwrap()).unwrap();
            let cid = payload
                .get("message")
                .and_then(|message| message.get("cid"))
                .unwrap_or_else(|| payload.pointer("/stories/0/cid").unwrap());
            assert!(state["entries"]
                .as_array()
                .unwrap()
                .iter()
                .any(|entry| { entry["cid"] == *cid && entry["status"] == "sending" }));
        }
        self.opcodes.push(opcode);
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

#[tokio::test]
async fn policy_revocation_between_upload_and_send_blocks_plaintext() {
    let directory = tempfile::tempdir().unwrap();
    let input = input(
        directory.path(),
        vec![file(directory.path(), "synthetic.jpg", "image/jpeg", 4)],
    );
    let mut journal = Journal::open(&input).unwrap();
    let policy_path = directory.path().join("accounts.json");
    let progress: Progress = Arc::new(move |event| {
        if event.phase == "sending" {
            fs::write(&policy_path, b"[]").unwrap();
        }
    });
    let mut transport = FakeTransport::default();
    let outcome = deliver(&input, &mut journal, &mut transport, progress).await;
    assert_eq!(outcome.status, "failed");
    assert_eq!(transport.uploaded.len(), 1);
    assert!(transport.sent.is_empty());
}

#[test]
fn policy_rejects_stale_snapshots_and_changed_epochs() {
    let directory = tempfile::tempdir().unwrap();
    let input = input(directory.path(), vec![]);
    assert!(input.authorize().is_ok());
    let path = directory.path().join("accounts.json");
    let mut accounts: Value = serde_json::from_slice(&fs::read(&path).unwrap()).unwrap();
    accounts[0]["updatedAtMillis"] = json!(0);
    fs::write(&path, serde_json::to_vec(&accounts).unwrap()).unwrap();
    assert!(input.authorize().is_err());
    let input = self::input(directory.path(), vec![]);
    let mut accounts: Value = serde_json::from_slice(&fs::read(&path).unwrap()).unwrap();
    accounts[0]["policyEpoch"] = json!("new-policy");
    fs::write(&path, serde_json::to_vec(&accounts).unwrap()).unwrap();
    assert!(input.authorize().is_err());
}

#[tokio::test]
async fn policy_missing_authorization_sends_nothing() {
    let directory = tempfile::tempdir().unwrap();
    let mut input = input(directory.path(), vec![]);
    input.authorization = None;
    let mut journal = Journal::open(&input).unwrap();
    let mut transport = FakeTransport::default();
    let outcome = deliver(&input, &mut journal, &mut transport, events().0).await;
    assert_eq!(outcome.status, "failed");
    assert!(transport.sent.is_empty());
}

#[tokio::test]
async fn policy_revocation_cancels_an_active_upload() {
    let directory = tempfile::tempdir().unwrap();
    let input = input(
        directory.path(),
        vec![file(directory.path(), "synthetic.jpg", "image/jpeg", 4)],
    );
    let mut journal = Journal::open(&input).unwrap();
    let mut transport = FakeTransport {
        revoke_during_upload: Some(
            directory
                .path()
                .join("accounts.json")
                .to_str()
                .unwrap()
                .into(),
        ),
        ..Default::default()
    };
    let outcome = deliver(&input, &mut journal, &mut transport, events().0).await;
    assert_eq!(outcome.status, "failed");
    assert!(!transport.completed_upload);
    assert!(transport.sent.is_empty());
}

#[test]
fn story_journal_keeps_all_photos_in_one_entry_with_stable_positive_cid() {
    let directory = tempfile::tempdir().unwrap();
    let input = story_input(
        directory.path(),
        vec![
            file(directory.path(), "first.jpg", "image/jpeg", 100),
            file(directory.path(), "second.jpg", "image/jpeg", 200),
        ],
    );
    assert!(input.authorize().is_ok());
    let journal = Journal::open(&input).unwrap();
    assert_eq!(journal.state.entries.len(), 1);
    assert_eq!(journal.state.entries[0].files, vec![0, 1]);
    assert!(journal.state.entries[0].cid > 0);
    let cid = journal.state.entries[0].cid;
    drop(journal);
    let reopened = Journal::open(&input).unwrap();
    assert_eq!(reopened.state.entries[0].cid, cid);
    let persisted: Value =
        serde_json::from_slice(&fs::read(&input.request.state_path).unwrap()).unwrap();
    assert_eq!(persisted["entries"][0]["cid"], cid);
}

#[tokio::test]
async fn story_deliver_builds_stories_payload_for_stories_send() {
    let directory = tempfile::tempdir().unwrap();
    let input = story_input(
        directory.path(),
        vec![
            file(directory.path(), "first.jpg", "image/jpeg", 100),
            file(directory.path(), "second.jpg", "image/jpeg", 200),
        ],
    );
    let mut journal = Journal::open(&input).unwrap();
    let mut transport = FakeTransport {
        state_path: Some(input.request.state_path.clone()),
        ..Default::default()
    };
    let outcome = deliver(&input, &mut journal, &mut transport, events().0).await;
    assert_eq!(outcome.status, "sent");
    assert_eq!(outcome.sent_count, 1);
    assert_eq!(outcome.total_count, 1);
    assert_eq!(outcome.message_ids, vec!["synthetic-message-1"]);
    assert_eq!(transport.uploaded, vec!["first.jpg", "second.jpg"]);
    assert_eq!(transport.opcodes, vec![kolibri_net::opcodes::STORIES_SEND]);
    assert!(transport.sent[0].get("message").is_none());
    assert!(transport.sent[0].get("chatId").is_none());
    let stories = transport.sent[0]["stories"].as_array().unwrap();
    assert_eq!(stories.len(), 2);
    for (index, story) in stories.iter().enumerate() {
        assert_eq!(story["cid"], journal.state.entries[0].cid);
        assert_eq!(story["settings"], 1);
        assert_eq!(story["expiration"], 86400000);
        assert_eq!(story["media"]["_type"], "PHOTO");
        assert_eq!(story["media"]["token"], transport.uploaded[index].as_str());
    }
    assert!(journal.state.entries[0].status == EntryStatus::Sent);
    let persisted: Value =
        serde_json::from_slice(&fs::read(&input.request.state_path).unwrap()).unwrap();
    assert_eq!(persisted["entries"].as_array().unwrap().len(), 1);
}

#[test]
fn story_target_rejects_non_photos_empty_files_and_wrong_chat() {
    let directory = tempfile::tempdir().unwrap();
    let input = story_input(
        directory.path(),
        vec![file(directory.path(), "clip.mp4", "video/mp4", 100)],
    );
    let outcome = Journal::open(&input).err().unwrap();
    assert_eq!(outcome.status, "failed");
    assert_eq!(
        outcome.message,
        "В сторис можно отправить только фотографии"
    );
    let input = story_input(directory.path(), vec![]);
    let outcome = Journal::open(&input).err().unwrap();
    assert_eq!(outcome.status, "failed");
    assert_eq!(outcome.message, "Недостаточно данных для отправки");
    let mut input = story_input(
        directory.path(),
        vec![file(directory.path(), "shot.jpg", "image/jpeg", 100)],
    );
    input.request.chat_id = "456".into();
    let outcome = Journal::open(&input).err().unwrap();
    assert_eq!(outcome.status, "failed");
    assert_eq!(outcome.message, "Недостаточно данных для отправки");
}
