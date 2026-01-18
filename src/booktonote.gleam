/// Main server entry point

import booktonote/infra/qwen_vl
import booktonote/router
import gleam/erlang/process
import gleam/io
import mist
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  // Configure Wisp logger
  wisp.configure_logger()

  io.println("Starting BookToNote OCR server...")

  // Preload Qwen2-VL model at startup
  io.println("Loading Qwen2-VL model...")
  case qwen_vl.ensure_worker_running() {
    Ok(_) -> io.println("Qwen2-VL model loaded successfully")
    Error(err) -> io.println("Warning: Failed to load Qwen2-VL model: " <> err)
  }

  // Generate a secret key base for Wisp
  let secret_key_base = wisp.random_string(64)

  // Start the server with Wisp-Mist integration
  let assert Ok(_) =
    wisp_mist.handler(router.handle_request, secret_key_base)
    |> mist.new
    |> mist.port(8080)
    |> mist.start

  io.println("Server started on http://localhost:8080")
  io.println("Endpoints:")
  io.println("  POST /ocr    - Upload image for OCR")
  io.println("  GET  /health - Health check")
  io.println("  GET  /       - API documentation")

  // Keep the process alive
  process.sleep_forever()
}
