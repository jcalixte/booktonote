/// Main server entry point

import booktonote/infra/paddleocr
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

  // Preload OCR model at startup
  io.println("Loading OCR model...")
  case paddleocr.ensure_worker_running() {
    Ok(_) -> io.println("OCR model loaded successfully")
    Error(err) -> io.println("Warning: Failed to load OCR model: " <> err)
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
