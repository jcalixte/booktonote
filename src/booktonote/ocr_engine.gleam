/// OCR Engine interface for dependency injection
/// Allows swapping OCR implementations without changing consuming code

import booktonote/infra/qwen_vl

/// OCR Engine interface - record with function fields
pub type OcrEngine {
  OcrEngine(
    name: String,
    check_installed: fn() -> Result(String, Nil),
    extract_text: fn(String) -> Result(String, String),
    ensure_running: fn() -> Result(String, String),
  )
}

/// Create a Qwen2-VL OCR engine
pub fn qwen_vl() -> OcrEngine {
  OcrEngine(
    name: "Qwen2-VL",
    check_installed: qwen_vl.check_engine_installed,
    extract_text: qwen_vl.extract_text,
    ensure_running: qwen_vl.ensure_worker_running,
  )
}
