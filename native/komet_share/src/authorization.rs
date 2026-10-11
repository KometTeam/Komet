use std::fs::{self, OpenOptions};
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

use fs2::FileExt;
use serde::Deserialize;
use serde_json::Value;

#[derive(Clone, Deserialize)]
pub struct ShareAuthorization {
    pub snapshot_path: String,
    pub lock_path: String,
    pub epoch: String,
}

pub fn denied() -> String {
    "Разрешение на отправку изменилось или устарело. Откройте Komet и повторите".into()
}

impl ShareAuthorization {
    pub fn check(&self, account_id: &str, chat_id: &str) -> Result<(), String> {
        let snapshot = Path::new(&self.snapshot_path);
        let lock_path = Path::new(&self.lock_path);
        if !snapshot.is_absolute()
            || snapshot.file_name().and_then(|name| name.to_str()) != Some("accounts.json")
            || lock_path.file_name().and_then(|name| name.to_str()) != Some("accounts.lock")
            || snapshot.parent() != lock_path.parent()
            || self.epoch.is_empty()
        {
            return Err(denied());
        }
        let lock = OpenOptions::new()
            .read(true)
            .write(true)
            .open(lock_path)
            .map_err(|_| denied())?;
        FileExt::lock_shared(&lock).map_err(|_| denied())?;
        if fs::metadata(snapshot).map_err(|_| denied())?.len() > 16 * 1024 * 1024 {
            return Err(denied());
        }
        let bytes = fs::read(snapshot).map_err(|_| denied())?;
        let accounts: Value = serde_json::from_slice(&bytes).map_err(|_| denied())?;
        let account = accounts
            .as_array()
            .ok_or_else(denied)?
            .iter()
            .find(|account| account["id"].as_str() == Some(account_id))
            .ok_or_else(denied)?;
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|_| denied())?
            .as_millis();
        let updated = account["updatedAtMillis"].as_u64().ok_or_else(denied)? as u128;
        if account["policyEpoch"].as_str() != Some(self.epoch.as_str())
            || updated > now
            || now - updated > 300_000
        {
            return Err(denied());
        }
        let chat = account["chats"]
            .as_array()
            .ok_or_else(denied)?
            .iter()
            .find(|chat| chat["id"].as_str() == Some(chat_id))
            .ok_or_else(denied)?;
        if !chat["disabledReason"].is_null() {
            return Err(denied());
        }
        Ok(())
    }
}
