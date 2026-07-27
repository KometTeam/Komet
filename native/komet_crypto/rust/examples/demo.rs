use std::time::Instant;

use komet_crypto::cipher;

fn main() {
    let password = "мой ключ 2026";
    let started = Instant::now();
    let key = cipher::derive_key(password).expect("derive");
    println!("derive_key: {:?}", started.elapsed());

    for text in [
        "привет",
        "встречаемся в 19:00 у метро",
        "Hello! Это смешанный текст с эмодзи 🔐",
    ] {
        let encrypted = cipher::encrypt(text, &key).expect("encrypt");
        let decrypted = cipher::decrypt(&encrypted, &key).expect("decrypt");
        println!(
            "\n{} символов -> {} символов",
            text.chars().count(),
            encrypted.chars().count()
        );
        println!("  {text}");
        println!("  {encrypted}");
        assert_eq!(decrypted, text);
    }

    let wrong = cipher::derive_key("не тот ключ").expect("derive");
    let sample = cipher::encrypt("секрет", &key).expect("encrypt");
    println!("\nчужой ключ: {:?}", cipher::decrypt(&sample, &wrong));
    println!(
        "обычный текст: {:?}",
        cipher::decrypt("привет как дела", &key)
    );
}
