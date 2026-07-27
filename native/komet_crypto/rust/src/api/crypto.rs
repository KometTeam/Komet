use std::fs;

use crate::cipher;
use crate::error::CryptoError;
use crate::image;

pub fn derive_key(password: String) -> Result<Vec<u8>, String> {
    cipher::derive_key(&password).map_err(|e| e.code().to_string())
}

pub fn encrypt_message(plaintext: String, key: Vec<u8>) -> Result<String, String> {
    cipher::encrypt(&plaintext, &key).map_err(|e| e.code().to_string())
}

pub fn decrypt_message(text: String, key: Vec<u8>) -> Result<String, String> {
    cipher::decrypt(&text, &key).map_err(|e| e.code().to_string())
}

pub fn looks_encrypted(text: String) -> bool {
    cipher::looks_encrypted(&text)
}

pub fn encrypt_image_file(
    source_path: String,
    dest_path: String,
    key: Vec<u8>,
) -> Result<(), String> {
    transform_file(&source_path, &dest_path, |bytes| {
        image::encrypt(bytes, &key)
    })
}

pub fn decrypt_image_file(
    source_path: String,
    dest_path: String,
    key: Vec<u8>,
) -> Result<(), String> {
    transform_file(&source_path, &dest_path, |bytes| {
        image::decrypt(bytes, &key)
    })
}

pub fn looks_encrypted_image_file(path: String) -> bool {
    fs::read(&path)
        .map(|bytes| image::looks_encrypted(&bytes))
        .unwrap_or(false)
}

fn transform_file(
    source_path: &str,
    dest_path: &str,
    transform: impl FnOnce(&[u8]) -> Result<Vec<u8>, CryptoError>,
) -> Result<(), String> {
    let bytes = fs::read(source_path).map_err(|e| format!("read: {e}"))?;
    let out = transform(&bytes).map_err(|e| e.code().to_string())?;
    fs::write(dest_path, out).map_err(|e| format!("write: {e}"))
}
