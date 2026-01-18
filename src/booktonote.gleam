/// Main server entry point

import booktonote/ocr_engine
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

  // Create OCR engine (dependency injection)
  let engine = ocr_engine.qwen_vl()

  // Preload model at startup
  io.println("Loading " <> engine.name <> " model...")
  case engine.ensure_running() {
    Ok(_) -> io.println(engine.name <> " model loaded successfully")
    Error(err) ->
      io.println("Warning: Failed to load " <> engine.name <> " model: " <> err)
  }

  // Generate a secret key base for Wisp
  let secret_key_base = wisp.random_string(64)

  // Create handler with engine injected
  let handler = fn(req) { router.handle_request(req, engine) }

  // Start the server with Wisp-Mist integration
  let assert Ok(_) =
    wisp_mist.handler(handler, secret_key_base)
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
