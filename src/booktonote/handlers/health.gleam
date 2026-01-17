/// Health check endpoint handler

import booktonote/services/tesseract
import gleam/json
import wisp.{type Response}

/// Handle health check requests
pub fn check() -> Response {
  let status = case tesseract.check_tesseract_installed() {
    Ok(_version) -> "available"
    Error(_) -> "unavailable"
  }

  let response_json =
    json.object([
      #("status", json.string("healthy")),
      #(
        "services",
        json.object([#("tesseract", json.string(status))]),
      ),
    ])

  wisp.json_response(json.to_string(response_json), 200)
}
