use sha2::{Digest, Sha256};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use kolibri_net::{
    media, opcodes, ClientConfig, HandshakeConfig, ProxyConfig, Session, SessionConfig, UserAgent,
};
use serde::Deserialize;
use serde_json::{json, Value};

use crate::engine::{Input, SendError, SharedFile, Transport, UploadProgress};

#[derive(Deserialize)]
pub struct SessionOptions {
    pub host: String,
    pub port: u16,
    pub device_id: String,
    pub instance_id: String,
    pub app_version: String,
    pub build_number: i64,
    pub device_type: String,
    pub os_version: String,
    pub timezone: String,
    pub screen: String,
    pub push_device_type: String,
    pub arch: String,
    pub locale: String,
    pub device_name: String,
    pub device_locale: String,
    pub client_session_id: i64,
    #[serde(default)]
    pub ping_interactive: bool,
    #[serde(default)]
    pub insecure_tls: bool,
    #[serde(default)]
    pub trust_mincifry_ca: bool,
    pub proxy: Option<String>,
    pub is_pwa: Option<bool>,
    pub header_user_agent: Option<String>,
    pub fingerprint_digests: Option<FingerprintDigests>,
}

#[derive(Deserialize)]
pub struct FingerprintDigests {
    signature: String,
    dex: String,
    so: String,
}

impl FingerprintDigests {
    fn decode(&self) -> Result<[Vec<u8>; 3], String> {
        let decode = |value: &str| {
            hex::decode(value)
                .ok()
                .filter(|bytes| !bytes.is_empty() && bytes.len() <= 64)
                .ok_or_else(|| "Обновите данные аккаунта в приложении Komet".to_string())
        };
        Ok([
            decode(&self.signature)?,
            decode(&self.dex)?,
            decode(&self.so)?,
        ])
    }
}

pub struct Connection {
    session: Session,
    proxy: Option<ProxyConfig>,
    insecure_tls: bool,
    pub refreshed_token: Option<String>,
}

struct Response {
    ok: bool,
    body: Value,
}

impl Connection {
    pub async fn connect(input: &Input) -> Result<Self, String> {
        let options = &input.session;
        kolibri_net::set_trust_mincifry_ca(options.trust_mincifry_ca);
        let proxy = options
            .proxy
            .as_deref()
            .map(ProxyConfig::parse)
            .transpose()
            .map_err(|_| "Проверьте настройки прокси в Komet".to_string())?;
        let mut client = ClientConfig::new(&options.host, options.port);
        client.proxy = proxy.clone();
        client.insecure_tls = options.insecure_tls;
        let handshake = HandshakeConfig {
            instance_id: options.instance_id.clone(),
            device_id: options.device_id.clone(),
            client_session_id: fresh_session_id(input),
            user_agent: UserAgent {
                device_type: options.device_type.clone(),
                app_version: options.app_version.clone(),
                os_version: options.os_version.clone(),
                timezone: options.timezone.clone(),
                screen: options.screen.clone(),
                push_device_type: options.push_device_type.clone(),
                arch: options.arch.clone(),
                locale: options.locale.clone(),
                build_number: options.build_number,
                device_name: options.device_name.clone(),
                device_locale: options.device_locale.clone(),
                is_pwa: options.is_pwa,
                header_user_agent: options.header_user_agent.clone(),
            },
        };
        let mut config = SessionConfig::new(client, handshake);
        config.auto_reconnect = false;
        config.ping_interactive = options.ping_interactive;
        let mut connection = Self {
            session: Session::new(config),
            proxy,
            insecure_tls: options.insecure_tls,
            refreshed_token: None,
        };
        let info = connection
            .session
            .connect()
            .await
            .map_err(|_| "Не удалось подключиться к Komet. Проверьте интернет".to_string())?;
        let payload = login_payload(input, info.calls_seed)?;
        let response = connection
            .request(opcodes::LOGIN, &payload)
            .await
            .map_err(|_| "Не удалось войти в Komet. Откройте приложение и повторите".to_string())?;
        if !response.ok {
            return Err(server_message(
                &response.body,
                "Войдите в аккаунт в приложении Komet",
            ));
        }
        connection.refreshed_token = response
            .body
            .get("token")
            .and_then(Value::as_str)
            .filter(|token| !token.is_empty())
            .map(str::to_owned);
        Ok(connection)
    }

    async fn request(&self, opcode: u16, payload: &Value) -> Result<Response, ()> {
        let mut bytes = Vec::new();
        rmpv::encode::write_value(&mut bytes, &kolibri_net::protocol::json_to_value(payload))
            .map_err(|_| ())?;
        let packet = self
            .session
            .request_raw(opcode, &bytes)
            .await
            .map_err(|_| ())?;
        Ok(Response {
            ok: packet.is_ok(),
            body: packet.json_tagged().map_err(|_| ())?,
        })
    }

    async fn upload_info(&self, opcode: u16, payload: Value) -> Result<Value, String> {
        let response = self
            .request(opcode, &payload)
            .await
            .map_err(|_| "Не удалось подготовить загрузку. Проверьте интернет".to_string())?;
        if !response.ok {
            return Err(server_message(
                &response.body,
                "Сервер не разрешил загрузку",
            ));
        }
        Ok(response.body)
    }
}

fn fresh_session_id(input: &Input) -> i64 {
    if input.session.client_session_id == 0 {
        return 0;
    }
    static NEXT: AtomicU64 = AtomicU64::new(0);
    let nonce = NEXT.fetch_add(1, Ordering::Relaxed);
    let time = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos();
    let digest = Sha256::digest(format!("{}:{time}:{nonce}", input.request.id));
    let mut id = (u32::from_be_bytes(digest[..4].try_into().unwrap()) & 0x7fff_ffff).max(1) as i64;
    if id == input.session.client_session_id {
        id = id % 0x7fff_ffff + 1;
    }
    id
}

fn upload_filename(name: &str) -> String {
    name.chars()
        .map(|character| match character {
            '\r' | '\n' | '"' | '\\' | ';' => '_',
            value if value.is_control() => '_',
            value => value,
        })
        .collect()
}

fn login_payload(input: &Input, seed: Option<i64>) -> Result<Value, String> {
    let mut payload = input.login.as_object().cloned().unwrap_or_default();
    payload.insert("token".into(), json!(input.token));
    payload.remove("chatCacheFingerprint");
    if let (Some(seed), Some(digests)) = (seed, &input.session.fingerprint_digests) {
        let [signature, dex, so] = digests.decode()?;
        let fingerprint = kolibri_net::auth::chat_cache_fingerprint(
            &signature,
            &dex,
            &so,
            seed,
            &input.session.device_id,
        );
        payload.insert(
            "chatCacheFingerprint".into(),
            kolibri_net::protocol::value_to_json_tagged(&rmpv::Value::Binary(fingerprint)),
        );
    }
    payload
        .entry("interactive")
        .or_insert(json!(input.session.ping_interactive));
    Ok(Value::Object(payload))
}

fn server_message(body: &Value, fallback: &str) -> String {
    ["localizedMessage", "message", "title"]
        .iter()
        .find_map(|key| body.get(key).and_then(Value::as_str))
        .unwrap_or(fallback)
        .chars()
        .take(300)
        .collect()
}

fn required_string<'a>(value: &'a Value, key: &str) -> Result<&'a str, String> {
    value
        .get(key)
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| "Сервер вернул неполные данные загрузки".into())
}

fn photo_token(body: &[u8]) -> Option<String> {
    let value: Value = serde_json::from_slice(body).ok()?;
    value
        .get("photos")
        .and_then(Value::as_object)
        .and_then(|photos| {
            photos
                .values()
                .find_map(|photo| photo.get("token").and_then(Value::as_str))
        })
        .or_else(|| value.get("photoToken").and_then(Value::as_str))
        .filter(|value| !value.is_empty())
        .map(str::to_owned)
}

fn send_attempts(payload: &Value) -> usize {
    let has_video = payload
        .get("message")
        .and_then(|message| message.get("attaches"))
        .and_then(Value::as_array)
        .is_some_and(|attachments| {
            attachments
                .iter()
                .any(|attachment| attachment.get("_type").and_then(Value::as_str) == Some("VIDEO"))
        });
    if has_video {
        30
    } else {
        20
    }
}

impl Transport for Connection {
    async fn upload(
        &mut self,
        file: &SharedFile,
        progress: UploadProgress,
    ) -> Result<Value, String> {
        progress(0, file.size);
        let on_progress: media::ProgressFn = Arc::new(move |sent, total| {
            progress(sent, total);
        });
        let ua = self.session.http_user_agent();
        let filename = upload_filename(&file.name);
        if file.is_photo() {
            let info = self
                .upload_info(opcodes::PHOTO_UPLOAD, json!({"count": 1}))
                .await?;
            let url = required_string(&info, "url")?;
            let response = media::upload_photo_path(
                url,
                &file.path,
                &filename,
                self.insecure_tls,
                self.proxy.as_ref(),
                Some(on_progress),
                &ua,
            )
            .await
            .map_err(|_| "Не удалось загрузить фотографию".to_string())?;
            if response.status != 200 {
                return Err("Сервер не принял фотографию".into());
            }
            let token = photo_token(&response.body)
                .ok_or_else(|| "Сервер не подтвердил загрузку фотографии".to_string())?;
            return Ok(json!({"_type": "PHOTO", "photoToken": token}));
        }
        let video = file.mime.starts_with("video/");
        let data = self
            .upload_info(
                if video {
                    opcodes::VIDEO_UPLOAD
                } else {
                    opcodes::FILE_UPLOAD
                },
                if video {
                    json!({"count": 1, "uploaderType": 0, "type": 0})
                } else {
                    json!({"count": 1})
                },
            )
            .await?;
        let info = data
            .get("info")
            .and_then(Value::as_array)
            .and_then(|list| list.first())
            .ok_or_else(|| "Сервер вернул неполные данные загрузки".to_string())?;
        let url = required_string(info, "url")?;
        let token = required_string(info, "token")?;
        if video {
            let uploaded = media::upload_video_path(
                url,
                &file.path,
                2 * 1024 * 1024,
                2,
                self.insecure_tls,
                self.proxy.clone(),
                Some(on_progress),
            )
            .await
            .map_err(|_| "Не удалось загрузить видео".to_string())?;
            if !uploaded {
                return Err("Сервер не принял видео".into());
            }
            Ok(json!({"_type": "VIDEO", "videoType": 0, "token": token}))
        } else {
            let response = media::upload_file_path(
                url,
                &file.path,
                &filename,
                None,
                Some("close"),
                self.insecure_tls,
                self.proxy.as_ref(),
                Some(on_progress),
                &ua,
            )
            .await
            .map_err(|_| "Не удалось загрузить файл".to_string())?;
            if response.status != 200 {
                return Err("Сервер не принял файл".into());
            }
            Ok(json!({"_type": "FILE", "token": token}))
        }
    }

    async fn send(&mut self, payload: &Value) -> Result<String, SendError> {
        let max_attempts = send_attempts(payload);
        for attempt in 0..max_attempts {
            let response = self
                .request(opcodes::MSG_SEND, payload)
                .await
                .map_err(|_| SendError::Unknown)?;
            if response.ok {
                let id = response
                    .body
                    .get("message")
                    .and_then(|message| message.get("id"))
                    .and_then(|id| match id {
                        Value::String(value) => Some(value.clone()),
                        Value::Number(value) => Some(value.to_string()),
                        _ => None,
                    })
                    .filter(|id| !id.is_empty())
                    .ok_or(SendError::Unknown)?;
                return Ok(id);
            }
            let not_ready = response
                .body
                .get("error")
                .and_then(Value::as_str)
                .is_some_and(|error| error.contains("not.ready"));
            if not_ready && attempt + 1 < max_attempts {
                tokio::time::sleep(Duration::from_secs(1)).await;
                continue;
            }
            return Err(SendError::Rejected(server_message(
                &response.body,
                "Сервер отклонил отправку",
            )));
        }
        Err(SendError::Unknown)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unsafe_header_characters_do_not_reject_otherwise_valid_names() {
        assert_eq!(upload_filename("Фото \"июнь\".jpg"), "Фото _июнь_.jpg");
        assert_eq!(
            upload_filename("name\r\nX-Fake: value;.txt"),
            "name__X-Fake: value_.txt"
        );
    }

    #[test]
    fn extension_session_is_distinct_from_host_connection() {
        let directory = tempfile::tempdir().unwrap();
        let input = crate::engine::tests::input(directory.path(), vec![]);
        let first = fresh_session_id(&input);
        let second = fresh_session_id(&input);
        assert_ne!(first, input.session.client_session_id);
        assert_ne!(first, second);
        assert!((1..=0x7fff_ffff).contains(&first));
    }

    #[test]
    fn parses_both_photo_upload_response_shapes() {
        assert_eq!(
            photo_token(br#"{"photos":{"one":{"token":"synthetic-token"}}}"#),
            Some("synthetic-token".into())
        );
        assert_eq!(
            photo_token(br#"{"photoToken":"synthetic-token"}"#),
            Some("synthetic-token".into())
        );
        assert_eq!(photo_token(br#"{"photoToken":""}"#), None);
        assert_eq!(photo_token(b"invalid"), None);
    }

    #[test]
    fn login_replaces_stale_fingerprint_using_fresh_handshake_seed() {
        let directory = tempfile::tempdir().unwrap();
        let input = crate::engine::tests::input(directory.path(), vec![]);
        let first = login_payload(&input, Some(101)).unwrap();
        let second = login_payload(&input, Some(202)).unwrap();
        assert_ne!(
            first["chatCacheFingerprint"],
            second["chatCacheFingerprint"]
        );
        let wire = kolibri_net::protocol::json_to_value(&first);
        let fields = wire.as_map().unwrap();
        let fingerprint = fields
            .iter()
            .find(|(key, _)| key.as_str() == Some("chatCacheFingerprint"))
            .unwrap();
        assert!(matches!(&fingerprint.1, rmpv::Value::Binary(bytes) if bytes.len() == 96));
        let exp = fields
            .iter()
            .find(|(key, _)| key.as_str() == Some("exp"))
            .unwrap();
        assert!(
            matches!(&exp.1.as_map().unwrap()[0].1, rmpv::Value::Binary(bytes) if bytes == &[0x0b, 0x32])
        );
    }

    #[test]
    fn login_without_seed_omits_stale_fingerprint_and_keeps_options() {
        let directory = tempfile::tempdir().unwrap();
        let input = crate::engine::tests::input(directory.path(), vec![]);
        let payload = login_payload(&input, None).unwrap();
        assert!(payload.get("chatCacheFingerprint").is_none());
        assert_eq!(payload["token"], input.token);
        assert_eq!(payload["exp"], input.login["exp"]);
        assert_eq!(payload["interactive"], input.session.ping_interactive);
    }

    #[test]
    fn exported_host_digests_match_all_architecture_and_prelogin_vectors() {
        let vectors: Vec<Value> = serde_json::from_str(include_str!(
            "../../../test/fixtures/share_fingerprint_vectors.json"
        ))
        .unwrap();
        let directory = tempfile::tempdir().unwrap();
        let mut input = crate::engine::tests::input(directory.path(), vec![]);
        for vector in vectors {
            input.session.fingerprint_digests =
                Some(serde_json::from_value(vector["digests"].clone()).unwrap());
            input.session.device_id = vector["device_id"].as_str().unwrap().into();
            let payload = login_payload(&input, vector["seed"].as_i64()).unwrap();
            let wire = kolibri_net::protocol::json_to_value(&payload["chatCacheFingerprint"]);
            let rmpv::Value::Binary(bytes) = wire else {
                panic!("fingerprint must remain binary");
            };
            assert_eq!(hex::encode(bytes), vector["fingerprint"].as_str().unwrap());
        }
    }

    #[test]
    fn web_options_omit_native_fingerprint_and_session_id() {
        let directory = tempfile::tempdir().unwrap();
        let mut input = crate::engine::tests::input(directory.path(), vec![]);
        input.session.fingerprint_digests = None;
        input.session.client_session_id = 0;
        assert!(login_payload(&input, Some(101))
            .unwrap()
            .get("chatCacheFingerprint")
            .is_none());
        assert_eq!(fresh_session_id(&input), 0);
    }

    #[test]
    fn invalid_exported_digest_prevents_invalid_login_payload() {
        let directory = tempfile::tempdir().unwrap();
        let mut input = crate::engine::tests::input(directory.path(), vec![]);
        input.session.fingerprint_digests.as_mut().unwrap().dex = "invalid-hex".into();
        assert!(login_payload(&input, Some(101)).is_err());
    }

    #[test]
    fn video_processing_retry_budget_matches_host() {
        for (kind, expected) in [("VIDEO", 30), ("PHOTO", 20), ("FILE", 20)] {
            let payload = json!({
                "chatId": 202,
                "message": {
                    "cid": -1001,
                    "attaches": [{"_type": kind, "token": "synthetic-token"}],
                },
            });
            assert_eq!(send_attempts(&payload), expected);
        }
        assert_eq!(
            send_attempts(&json!({"message": {"text": "synthetic"}})),
            20
        );
    }
}
