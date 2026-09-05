use std::io::{self, Read};
use std::process;

use komet_crypto::cipher;

fn digits(value: &str) -> String {
    value.chars().filter(|c| c.is_ascii_digit()).collect()
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.len() != 2 {
        eprintln!("usage: review_blob <phone> <code> < payload.json");
        process::exit(2);
    }

    let password = format!("{}:{}", digits(&args[0]), args[1]);

    let mut payload = String::new();
    if io::stdin().read_to_string(&mut payload).is_err() {
        eprintln!("review_blob: cannot read payload from stdin");
        process::exit(1);
    }
    let payload = payload.trim();
    if payload.is_empty() {
        eprintln!("review_blob: empty payload");
        process::exit(1);
    }

    let key = match cipher::derive_key(&password) {
        Ok(key) => key,
        Err(e) => {
            eprintln!("review_blob: derive_key: {e}");
            process::exit(1);
        }
    };

    let blob = match cipher::encrypt(payload, &key) {
        Ok(blob) => blob.replace(' ', ""),
        Err(e) => {
            eprintln!("review_blob: encrypt: {e}");
            process::exit(1);
        }
    };

    match cipher::decrypt(&blob, &key) {
        Ok(back) if back == payload => println!("{blob}"),
        Ok(_) => {
            eprintln!("review_blob: roundtrip mismatch");
            process::exit(1);
        }
        Err(e) => {
            eprintln!("review_blob: roundtrip failed: {e}");
            process::exit(1);
        }
    }
}
