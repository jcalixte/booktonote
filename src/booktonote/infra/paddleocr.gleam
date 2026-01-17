/// PaddleOCR implementation for text extraction
/// Uses a persistent Python worker process to avoid reloading models on each request
import gleam/dynamic/decode
import gleam/json
import gleam/result

/// External FFI calls
@external(erlang, "booktonote_ffi", "getenv")
fn getenv(name: String) -> Result(String, Nil)

@external(erlang, "booktonote_ffi", "start_ocr_worker")
fn start_ocr_worker(script_path: String) -> Result(String, String)

@external(erlang, "booktonote_ffi", "send_ocr_request")
fn send_ocr_request(request_json: String) -> Result(String, String)

@external(erlang, "booktonote_ffi", "is_ocr_worker_running")
fn is_ocr_worker_running() -> Bool

/// Default path to the OCR worker script (Docker)
const default_ocr_worker_path = "/app/scripts/ocr_worker.py"

/// Get the OCR worker script path from environment or use default
fn get_ocr_worker_path() -> String {
  getenv("OCR_WORKER_PATH")
  |> result.unwrap(default_ocr_worker_path)
}

/// Ensure the OCR worker is running, start it if not
pub fn ensure_worker_running() -> Result(String, String) {
  case is_ocr_worker_running() {
    True -> Ok("Worker already running")
    False -> {
      let script_path = get_ocr_worker_path()
      start_ocr_worker(script_path)
    }
  }
}

/// Check if PaddleOCR is installed by checking if worker can start
/// This is now cached - we just check if the worker is running
pub fn check_engine_installed() -> Result(String, Nil) {
  case ensure_worker_running() {
    Ok(_) -> Ok("PaddleOCR")
    Error(_) -> Error(Nil)
  }
}

/// Extract text from an image using the persistent PaddleOCR worker
pub fn extract_text(image_path: String) -> Result(String, String) {
  // Ensure worker is running
  case ensure_worker_running() {
    Error(err) -> Error("Failed to start OCR worker: " <> err)
    Ok(_) -> {
      // Build the request JSON
      let request =
        json.object([#("image_path", json.string(image_path))])
        |> json.to_string

      // Send request to worker
      case send_ocr_request(request) {
        Error(err) -> Error(err)
        Ok(response_json) -> parse_worker_response(response_json)
      }
    }
  }
}

/// Response type from the worker
type WorkerResponse {
  SuccessResponse(text: String)
  ErrorResponse(error: String)
}

/// Parse the JSON response from the worker
fn parse_worker_response(response_json: String) -> Result(String, String) {
  // Decoder for success response: {"success": true, "text": "..."}
  let success_decoder =
    decode.at(["success"], decode.bool)
    |> decode.then(fn(success) {
      case success {
        True ->
          decode.at(["text"], decode.string)
          |> decode.map(SuccessResponse)
        False ->
          decode.at(["error"], decode.string)
          |> decode.map(ErrorResponse)
      }
    })

  case json.parse(response_json, success_decoder) {
    Ok(SuccessResponse(text)) -> Ok(text)
    Ok(ErrorResponse(error)) -> Error(error)
    Error(_) -> Error("Failed to parse OCR worker response: " <> response_json)
  }
}
