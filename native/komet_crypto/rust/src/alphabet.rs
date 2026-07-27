use data_encoding::BASE32_NOPAD;

use crate::error::CryptoError;

pub const RU_LOWERCASE_WITHOUT_YO: [char; 32] = [
    'а', 'б', 'в', 'г', 'д', 'е', 'ж', 'з', 'и', 'й', 'к', 'л', 'м', 'н', 'о', 'п', 'р', 'с', 'т',
    'у', 'ф', 'х', 'ц', 'ч', 'ш', 'щ', 'ъ', 'ы', 'ь', 'э', 'ю', 'я',
];

const MIN_WORD_LEN: usize = 4;
const WORD_LEN_SPREAD: usize = 5;

fn base32_symbol(index: usize) -> u8 {
    if index < 26 {
        b'A' + index as u8
    } else {
        b'2' + (index - 26) as u8
    }
}

fn base32_index(symbol: u8) -> Option<usize> {
    match symbol {
        b'A'..=b'Z' => Some((symbol - b'A') as usize),
        b'2'..=b'7' => Some((symbol - b'2') as usize + 26),
        _ => None,
    }
}

fn letter_index(letter: char) -> Option<usize> {
    RU_LOWERCASE_WITHOUT_YO.iter().position(|&l| l == letter)
}

pub fn encode(bytes: &[u8]) -> String {
    let base32 = BASE32_NOPAD.encode(bytes);
    let mut out = String::with_capacity(base32.len() * 3);
    let mut run = 0usize;
    let mut word_len = MIN_WORD_LEN;
    for symbol in base32.bytes() {
        let Some(index) = base32_index(symbol) else {
            continue;
        };
        if run == word_len {
            out.push(' ');
            run = 0;
            word_len = MIN_WORD_LEN + index % WORD_LEN_SPREAD;
        }
        out.push(RU_LOWERCASE_WITHOUT_YO[index]);
        run += 1;
    }
    out
}

pub fn decode(text: &str) -> Result<Vec<u8>, CryptoError> {
    let mut symbols = Vec::with_capacity(text.len());
    for raw in text.chars() {
        if raw.is_whitespace() {
            continue;
        }
        let letter = raw.to_lowercase().next().unwrap_or(raw);
        let index = letter_index(letter).ok_or(CryptoError::NotEncrypted)?;
        symbols.push(base32_symbol(index));
    }
    if symbols.is_empty() {
        return Err(CryptoError::NotEncrypted);
    }
    BASE32_NOPAD
        .decode(&symbols)
        .map_err(|_| CryptoError::Malformed)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn alphabet_has_no_duplicates_and_no_yo() {
        let mut sorted = RU_LOWERCASE_WITHOUT_YO.to_vec();
        sorted.sort_unstable();
        sorted.dedup();
        assert_eq!(sorted.len(), 32);
        assert!(!RU_LOWERCASE_WITHOUT_YO.contains(&'ё'));
    }

    #[test]
    fn roundtrip_preserves_bytes() {
        for len in 1..64usize {
            let bytes: Vec<u8> = (0..len).map(|i| (i * 37 + 11) as u8).collect();
            let encoded = encode(&bytes);
            assert_eq!(decode(&encoded).unwrap(), bytes, "len {len}");
        }
    }

    #[test]
    fn empty_input_encodes_to_empty_string() {
        assert_eq!(encode(&[]), "");
        assert_eq!(decode(""), Err(CryptoError::NotEncrypted));
    }

    #[test]
    fn output_is_lowercase_cyrillic_and_spaces() {
        let encoded = encode(&[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
        for ch in encoded.chars() {
            assert!(ch == ' ' || RU_LOWERCASE_WITHOUT_YO.contains(&ch), "{ch}");
        }
        assert!(encoded.contains(' '));
        assert!(!encoded.contains("  "));
    }

    #[test]
    fn spaces_are_decorative_only() {
        let bytes = b"komet encryption core";
        let encoded = encode(bytes);
        let stripped: String = encoded.chars().filter(|c| *c != ' ').collect();
        let padded = format!("  {}  ", encoded.replace(' ', "   "));
        let newlined = encoded.replace(' ', "\n");
        assert_eq!(decode(&stripped).unwrap(), bytes);
        assert_eq!(decode(&padded).unwrap(), bytes);
        assert_eq!(decode(&newlined).unwrap(), bytes);
    }

    #[test]
    fn decode_is_case_insensitive() {
        let bytes = b"autocapitalized";
        let encoded = encode(bytes);
        assert_eq!(decode(&encoded.to_uppercase()).unwrap(), bytes);
    }

    #[test]
    fn foreign_characters_are_rejected() {
        assert_eq!(decode("привет!"), Err(CryptoError::NotEncrypted));
        assert_eq!(decode("hello"), Err(CryptoError::NotEncrypted));
        assert_eq!(decode("ёжик"), Err(CryptoError::NotEncrypted));
        assert_eq!(decode("   "), Err(CryptoError::NotEncrypted));
    }
}
