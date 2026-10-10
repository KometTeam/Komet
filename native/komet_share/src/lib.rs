mod engine;
mod transport;

use std::ffi::{c_char, c_void, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use engine::{Input, Journal, Outcome, Progress, ProgressUpdate};

static SEND_LOCK: Mutex<()> = Mutex::new(());

type ProgressCallback = unsafe extern "C" fn(*const c_char, *mut c_void);

#[no_mangle]
pub unsafe extern "C" fn komet_share_send(
    input: *const c_char,
    callback: Option<ProgressCallback>,
    context: *mut c_void,
) -> *mut c_char {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if input.is_null() {
            return Outcome::failed("Нет данных для отправки");
        }
        let input =
            match serde_json::from_slice::<Input>(unsafe { CStr::from_ptr(input) }.to_bytes()) {
                Ok(input) => input,
                Err(_) => return Outcome::failed("Не удалось прочитать данные отправки"),
            };
        let context = context as usize;
        let last = Mutex::new((Instant::now() - Duration::from_secs(1), ""));
        let progress: Progress = Arc::new(move |event| {
            let mut last = last.lock().unwrap();
            if event.phase == last.1
                && last.0.elapsed() < Duration::from_millis(80)
                && event.progress != Some(1.0)
            {
                return;
            }
            *last = (Instant::now(), event.phase);
            drop(last);
            if let Some(callback) = callback {
                let json = serde_json::to_string(&event).unwrap();
                if let Ok(text) = CString::new(json) {
                    unsafe { callback(text.as_ptr(), context as *mut c_void) };
                }
            }
        });
        send(input, progress)
    }))
    .unwrap_or_else(|_| Outcome::unknown("Отправка прервана. Проверьте чат перед повтором"));
    CString::new(serde_json::to_string(&result).unwrap_or_else(|_| {
        "{\"status\":\"unknown\",\"message\":\"Не удалось подтвердить отправку\"}".into()
    }))
    .unwrap()
    .into_raw()
}

#[no_mangle]
pub unsafe extern "C" fn komet_share_free(value: *mut c_char) {
    if !value.is_null() {
        drop(unsafe { CString::from_raw(value) });
    }
}

fn send(input: Input, progress: Progress) -> Outcome {
    let Ok(_guard) = SEND_LOCK.try_lock() else {
        return Outcome::failed("Дождитесь завершения текущей отправки");
    };
    let mut journal = match Journal::open(&input) {
        Ok(value) => value,
        Err(outcome) => return outcome,
    };
    if let Some(outcome) = journal.terminal() {
        return outcome;
    }
    if let Err(message) = input.validate_files() {
        return journal.outcome("failed", &message);
    }
    let runtime = match tokio::runtime::Builder::new_multi_thread()
        .worker_threads(2)
        .enable_all()
        .build()
    {
        Ok(runtime) => runtime,
        Err(_) => return journal.outcome("failed", "Не удалось запустить отправку"),
    };
    runtime.block_on(async {
        progress(ProgressUpdate {
            phase: "connecting",
            message: "Подключение к Komet…",
            progress: None,
            sent: 0,
            total: 0,
        });
        let mut transport = match transport::Connection::connect(&input).await {
            Ok(transport) => transport,
            Err(message) => return journal.outcome("failed", &message),
        };
        let mut outcome = engine::deliver(&input, &mut journal, &mut transport, progress).await;
        outcome.refreshed_token = transport.refreshed_token.clone();
        outcome
    })
}
