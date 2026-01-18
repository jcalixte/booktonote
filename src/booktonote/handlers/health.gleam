/// Health check endpoint handler

import booktonote/ocr_engine.{type OcrEngine}
import gleam/json
import wisp.{type Response}

/// Handle health check requests
pub fn check(engine: OcrEngine) -> Response {
  let status = case engine.check_installed() {
    Ok(_version) -> "available"
    Error(_) -> "unavailable"
  }

  let response_json =
    json.object([
      #("status", json.string("healthy")),
      #(
        "services",
        json.object([#("ocr_engine", json.string(status))]),
      ),
    ])

  wisp.json_response(json.to_string(response_json), 200)
}
