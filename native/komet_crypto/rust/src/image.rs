use chacha20poly1305::aead::{Aead, AeadCore, OsRng, Payload};
use chacha20poly1305::{ChaCha20Poly1305, Nonce};
use rand_core::RngCore;

use crate::cipher::{cipher_from, MAGIC, NONCE_LEN, TAG_LEN};
use crate::error::CryptoError;

const VERSION_IMAGE: u8 = 0x02;
const HEADER_LEN: usize = 6;
const CHANNELS: usize = 3;
const MAX_DIMENSION: u32 = 16384;

fn header(payload_len: u32) -> [u8; HEADER_LEN] {
    let n = payload_len.to_be_bytes();
    [MAGIC, VERSION_IMAGE, n[0], n[1], n[2], n[3]]
}

pub fn encrypt(plain_png: &[u8], key: &[u8]) -> Result<Vec<u8>, CryptoError> {
    let cipher = cipher_from(key)?;
    let nonce = ChaCha20Poly1305::generate_nonce(&mut OsRng);
    let payload_len = NONCE_LEN + plain_png.len() + TAG_LEN;
    if u32::try_from(payload_len).is_err() {
        return Err(CryptoError::Malformed);
    }
    let head = header(payload_len as u32);

    let sealed = cipher
        .encrypt(
            &nonce,
            Payload {
                msg: plain_png,
                aad: &head,
            },
        )
        .map_err(|_| CryptoError::Internal)?;

    let mut blob = Vec::with_capacity(HEADER_LEN + payload_len);
    blob.extend_from_slice(&head);
    blob.extend_from_slice(&nonce);
    blob.extend_from_slice(&sealed);

    to_noise_png(&blob)
}

pub fn decrypt(noise_png: &[u8], key: &[u8]) -> Result<Vec<u8>, CryptoError> {
    let blob = from_noise_png(noise_png)?;
    let payload_len = envelope_len(&blob).ok_or(CryptoError::NotEncrypted)?;
    let end = HEADER_LEN + payload_len;
    if blob.len() < end {
        return Err(CryptoError::Malformed);
    }

    let cipher = cipher_from(key)?;
    let nonce = Nonce::from_slice(&blob[HEADER_LEN..HEADER_LEN + NONCE_LEN]);
    cipher
        .decrypt(
            nonce,
            Payload {
                msg: &blob[HEADER_LEN + NONCE_LEN..end],
                aad: &blob[..HEADER_LEN],
            },
        )
        .map_err(|_| CryptoError::WrongKey)
}

pub fn looks_encrypted(noise_png: &[u8]) -> bool {
    from_noise_png(noise_png)
        .ok()
        .and_then(|blob| envelope_len(&blob))
        .is_some()
}

fn envelope_len(blob: &[u8]) -> Option<usize> {
    if blob.len() < HEADER_LEN || blob[0] != MAGIC || blob[1] != VERSION_IMAGE {
        return None;
    }
    let len = u32::from_be_bytes([blob[2], blob[3], blob[4], blob[5]]) as usize;
    if len < NONCE_LEN + TAG_LEN || HEADER_LEN + len > blob.len() {
        return None;
    }
    Some(len)
}

fn to_noise_png(blob: &[u8]) -> Result<Vec<u8>, CryptoError> {
    let pixels = blob.len().div_ceil(CHANNELS);
    let width = (pixels as f64).sqrt().ceil().max(1.0) as u32;
    if width > MAX_DIMENSION {
        return Err(CryptoError::Malformed);
    }
    let height = (pixels as u32).div_ceil(width).max(1);

    let mut raw = vec![0u8; width as usize * height as usize * CHANNELS];
    raw[..blob.len()].copy_from_slice(blob);
    OsRng.fill_bytes(&mut raw[blob.len()..]);

    let mut out = Vec::new();
    {
        let mut encoder = png::Encoder::new(&mut out, width, height);
        encoder.set_color(png::ColorType::Rgb);
        encoder.set_depth(png::BitDepth::Eight);
        encoder.set_compression(png::Compression::Fast);
        let mut writer = encoder
            .write_header()
            .map_err(|_| CryptoError::Internal)?;
        writer
            .write_image_data(&raw)
            .map_err(|_| CryptoError::Internal)?;
    }
    Ok(out)
}

fn from_noise_png(noise_png: &[u8]) -> Result<Vec<u8>, CryptoError> {
    let decoder = png::Decoder::new(noise_png);
    let mut reader = decoder.read_info().map_err(|_| CryptoError::NotEncrypted)?;
    let info = reader.info();
    if info.color_type != png::ColorType::Rgb || info.bit_depth != png::BitDepth::Eight {
        return Err(CryptoError::NotEncrypted);
    }
    let mut raw = vec![0u8; reader.output_buffer_size()];
    let frame = reader
        .next_frame(&mut raw)
        .map_err(|_| CryptoError::Malformed)?;
    raw.truncate(frame.buffer_size());
    Ok(raw)
}

#[cfg(test)]
mod tests {
    use super::*;

    const KEY: [u8; 32] = [7u8; 32];
    const OTHER_KEY: [u8; 32] = [8u8; 32];

    fn sample_png(width: u32, height: u32) -> Vec<u8> {
        let mut out = Vec::new();
        {
            let mut encoder = png::Encoder::new(&mut out, width, height);
            encoder.set_color(png::ColorType::Rgb);
            encoder.set_depth(png::BitDepth::Eight);
            let mut writer = encoder.write_header().unwrap();
            let raw: Vec<u8> = (0..width as usize * height as usize * 3)
                .map(|i| (i * 7 % 251) as u8)
                .collect();
            writer.write_image_data(&raw).unwrap();
        }
        out
    }

    #[test]
    fn roundtrip_returns_original_bytes() {
        for (w, h) in [(1, 1), (16, 9), (64, 64), (200, 137)] {
            let original = sample_png(w, h);
            let encrypted = encrypt(&original, &KEY).unwrap();
            assert_eq!(decrypt(&encrypted, &KEY).unwrap(), original, "{w}x{h}");
        }
    }

    #[test]
    fn output_is_a_valid_rgb_png() {
        let encrypted = encrypt(&sample_png(32, 32), &KEY).unwrap();
        assert_eq!(&encrypted[1..4], b"PNG");
        let decoder = png::Decoder::new(encrypted.as_slice());
        let reader = decoder.read_info().unwrap();
        let info = reader.info();
        assert_eq!(info.color_type, png::ColorType::Rgb);
        assert_eq!(info.bit_depth, png::BitDepth::Eight);
        assert!(info.width >= 1 && info.height >= 1);
    }

    #[test]
    fn same_input_produces_different_output() {
        let original = sample_png(16, 16);
        let a = encrypt(&original, &KEY).unwrap();
        let b = encrypt(&original, &KEY).unwrap();
        assert_ne!(a, b);
    }

    #[test]
    fn wrong_key_is_rejected() {
        let encrypted = encrypt(&sample_png(16, 16), &KEY).unwrap();
        assert_eq!(decrypt(&encrypted, &OTHER_KEY), Err(CryptoError::WrongKey));
    }

    #[test]
    fn tampered_pixels_are_rejected() {
        let mut encrypted = encrypt(&sample_png(16, 16), &KEY).unwrap();
        let raw = from_noise_png(&encrypted).unwrap();
        let mut tampered = raw.clone();
        tampered[HEADER_LEN + NONCE_LEN + 4] ^= 0x01;
        encrypted = to_noise_png(&tampered).unwrap();
        assert_eq!(decrypt(&encrypted, &KEY), Err(CryptoError::WrongKey));
    }

    #[test]
    fn plain_png_is_not_mistaken_for_ciphertext() {
        let plain = sample_png(24, 24);
        assert!(!looks_encrypted(&plain));
        assert_eq!(decrypt(&plain, &KEY), Err(CryptoError::NotEncrypted));
        assert!(looks_encrypted(&encrypt(&plain, &KEY).unwrap()));
    }

    #[test]
    fn garbage_input_is_rejected() {
        assert!(!looks_encrypted(b"not a png at all"));
        assert_eq!(
            decrypt(b"not a png at all", &KEY),
            Err(CryptoError::NotEncrypted)
        );
    }

    #[test]
    fn bad_key_length_is_reported() {
        assert_eq!(
            encrypt(&sample_png(8, 8), &[0u8; 8]),
            Err(CryptoError::BadKeyLength)
        );
    }
}
