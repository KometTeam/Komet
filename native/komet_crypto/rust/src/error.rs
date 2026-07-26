use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CryptoError {
    EmptyPassword,
    BadKeyLength,
    NotEncrypted,
    Malformed,
    WrongKey,
    Internal,
}

impl CryptoError {
    pub fn code(self) -> &'static str {
        match self {
            CryptoError::EmptyPassword => "empty_password",
            CryptoError::BadKeyLength => "bad_key_length",
            CryptoError::NotEncrypted => "not_encrypted",
            CryptoError::Malformed => "malformed",
            CryptoError::WrongKey => "wrong_key",
            CryptoError::Internal => "internal",
        }
    }
}

impl fmt::Display for CryptoError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.code())
    }
}

impl std::error::Error for CryptoError {}
