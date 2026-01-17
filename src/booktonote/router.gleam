/// Request router and middleware configuration

import booktonote/handlers/health
import booktonote/handlers/ocr
import gleam/http
import gleam/json
import wisp.{type Request, type Response}

/// Main request handler with middleware
pub fn handle_request(req: Request) -> Response {
  // Apply logging middleware
  use <- wisp.log_request(req)

  // Apply crash rescue middleware
  use <- wisp.rescue_crashes

  // Route the request
  case wisp.path_segments(req) {
    // POST /ocr - OCR upload endpoint
    ["ocr"] ->
      case req.method {
        http.Post -> ocr.handle_upload(req)
        _ -> wisp.method_not_allowed([http.Post])
      }

    // GET /health - Health check endpoint
    ["health"] ->
      case req.method {
        http.Get -> health.check()
        _ -> wisp.method_not_allowed([http.Get])
      }

    // GET / - Welcome message
    [] ->
      case req.method {
        http.Get -> serve_welcome()
        _ -> wisp.method_not_allowed([http.Get])
      }

    // All other routes - 404
    _ -> wisp.not_found()
  }
}

/// Serve welcome message with API documentation
fn serve_welcome() -> Response {
  let response_json =
    json.object([
      #("service", json.string("BookToNote OCR API")),
      #("version", json.string("1.0.0")),
      #(
        "endpoints",
        json.object([
          #(
            "POST /ocr",
            json.string(
              "Upload an image (jpg, png, tiff, pdf) for text extraction",
            ),
          ),
          #("GET /health", json.string("Check service health status")),
        ]),
      ),
    ])

  wisp.json_response(json.to_string(response_json), 200)
}
