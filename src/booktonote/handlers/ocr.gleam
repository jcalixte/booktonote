/// OCR upload and processing handler

import booktonote/services/tesseract
import booktonote/types.{
  type OcrErrorType, FileTooLarge, InvalidImageFormat, NoTextDetected,
  OcrError, OcrSuccess, ProcessingFailed, TesseractNotFound,
}
import gleam/json
import gleam/list
import gleam/string
import simplifile
import wisp.{type Request, type Response}

/// Maximum file size in bytes (10MB)
const max_file_size = 10_485_760

/// Handle OCR upload requests
pub fn handle_upload(req: Request) -> Response {
  // Use wisp's form parsing to handle multipart data
  use formdata <- wisp.require_form(req)

  // Extract the uploaded file from form data
  // formdata.files is a list of #(field_name, UploadedFile) tuples
  case list.find(formdata.files, fn(file_tuple) {
    let #(field_name, _uploaded_file) = file_tuple
    field_name == "image"
  }) {
    Error(_) ->
      error_response(InvalidImageFormat, "Missing required field: image", 400)

    Ok(#(_field_name, uploaded_file)) -> {
      // Validate file size
      case simplifile.file_info(uploaded_file.path) {
        Ok(file_info) ->
          case file_info.size > max_file_size {
            True ->
              error_response(
                FileTooLarge,
                "File exceeds maximum size (10MB)",
                413,
              )
            False -> process_validated_file(uploaded_file)
          }
        Error(_) ->
          error_response(
            InvalidImageFormat,
            "Could not read file information",
            400,
          )
      }
    }
  }
}

/// Process a validated uploaded file
fn process_validated_file(uploaded_file: wisp.UploadedFile) -> Response {
  // Validate file extension
  case is_valid_image_format(uploaded_file.file_name) {
    False ->
      error_response(
        InvalidImageFormat,
        "Supported formats: jpg, jpeg, png, tiff, pdf",
        400,
      )
    True -> {
      // Process the image with Tesseract
      case tesseract.run_ocr(uploaded_file.path) {
        OcrSuccess(text, confidence, page_count) ->
          success_response(text, confidence, page_count)
        OcrError(error_type, message) ->
          error_response(error_type, message, error_status_code(error_type))
      }
    }
  }
}

/// Check if file has a valid image format extension
fn is_valid_image_format(filename: String) -> Bool {
  let lowercase = string.lowercase(filename)
  string.ends_with(lowercase, ".jpg")
  || string.ends_with(lowercase, ".jpeg")
  || string.ends_with(lowercase, ".png")
  || string.ends_with(lowercase, ".tiff")
  || string.ends_with(lowercase, ".tif")
  || string.ends_with(lowercase, ".pdf")
}

/// Map OcrErrorType to HTTP status code
fn error_status_code(error_type: OcrErrorType) -> Int {
  case error_type {
    TesseractNotFound -> 503
    InvalidImageFormat -> 400
    ProcessingFailed -> 500
    FileTooLarge -> 413
    NoTextDetected -> 200
  }
}

/// Build a successful JSON response
fn success_response(text: String, confidence: Float, page_count: Int) -> Response {
  let response_json =
    json.object([
      #("success", json.bool(True)),
      #(
        "data",
        json.object([
          #("text", json.string(text)),
          #("confidence", json.float(confidence)),
          #("page_count", json.int(page_count)),
        ]),
      ),
    ])

  wisp.json_response(json.to_string(response_json), 200)
}

/// Build an error JSON response
fn error_response(
  error_type: OcrErrorType,
  message: String,
  status_code: Int,
) -> Response {
  let error_type_string = case error_type {
    TesseractNotFound -> "tesseract_not_found"
    InvalidImageFormat -> "invalid_image_format"
    ProcessingFailed -> "processing_failed"
    FileTooLarge -> "file_too_large"
    NoTextDetected -> "no_text_detected"
  }

  let response_json =
    json.object([
      #("success", json.bool(False)),
      #(
        "error",
        json.object([
          #("type", json.string(error_type_string)),
          #("message", json.string(message)),
        ]),
      ),
    ])

  wisp.json_response(json.to_string(response_json), status_code)
}
