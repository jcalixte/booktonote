/// Request router and middleware configuration

import booktonote/handlers/health
import booktonote/handlers/ocr
import gleam/http
import gleam/int
import gleam/json
import gleam/string
import wisp.{type Request, type Response}

/// Get current time in milliseconds
@external(erlang, "erlang", "monotonic_time")
fn monotonic_time_native() -> Int

@external(erlang, "erlang", "convert_time_unit")
fn convert_time_unit(time: Int, from: a, to: b) -> Int

fn now_ms() -> Int {
  convert_time_unit(monotonic_time_native(), Native, Millisecond)
}

/// Custom time unit atoms for Erlang FFI
type TimeUnit {
  Native
  Millisecond
}

/// Log request with timing
fn log_request_with_timing(
  req: Request,
  handler: fn() -> Response,
) -> Response {
  let start = now_ms()
  let response = handler()
  let duration = now_ms() - start

  let method = string.uppercase(http.method_to_string(req.method))
  let path = "/" <> string.join(wisp.path_segments(req), "/")
  let status = int.to_string(response.status)
  let duration_str = int.to_string(duration) <> "ms"

  wisp.log_info(status <> " " <> method <> " " <> path <> " " <> duration_str)

  response
}

/// Main request handler with middleware
pub fn handle_request(req: Request) -> Response {
  // Apply logging middleware with timing
  use <- log_request_with_timing(req)

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
