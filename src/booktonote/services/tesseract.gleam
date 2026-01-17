/// Tesseract OCR service for text extraction from images

import booktonote/types.{
  type OcrResult, InvalidImageFormat, NoTextDetected, OcrError, OcrSuccess,
  ProcessingFailed, TesseractNotFound,
}
import gleam/int
import gleam/string
import simplifile

/// External FFI call to Erlang's os:cmd/1
/// Note: os:cmd expects a charlist, so we need to convert
@external(erlang, "unicode", "characters_to_list")
fn string_to_charlist(string: String) -> List(Int)

@external(erlang, "unicode", "characters_to_binary")
fn charlist_to_string(charlist: List(Int)) -> String

/// Run an OS command and return output as String
fn erlang_cmd(command: String) -> String {
  let charlist = string_to_charlist(command)
  let result = do_erlang_cmd(charlist)
  charlist_to_string(result)
}

@external(erlang, "os", "cmd")
fn do_erlang_cmd(command: List(Int)) -> List(Int)

/// Check if Tesseract is installed and accessible
pub fn check_tesseract_installed() -> Result(String, Nil) {
  let output = erlang_cmd("tesseract --version 2>&1 && echo __SUCCESS__ || echo __FAILURE__")

  case string.contains(output, "__SUCCESS__") {
    True -> {
      let version = string.trim(output)
      Ok(version)
    }
    False -> Error(Nil)
  }
}

/// Run OCR on an image file and extract text
pub fn run_ocr(image_path: String) -> OcrResult {
  // First check if Tesseract is installed
  case check_tesseract_installed() {
    Error(_) ->
      OcrError(
        TesseractNotFound,
        "Tesseract OCR is not installed or not accessible",
      )
    Ok(_) -> {
      // Verify the image file exists
      case simplifile.is_file(image_path) {
        Ok(False) | Error(_) ->
          OcrError(InvalidImageFormat, "Image file not found or not accessible")
        Ok(True) -> process_image(image_path)
      }
    }
  }
}

/// Process the image with Tesseract and return the result
fn process_image(image_path: String) -> OcrResult {
  // Generate a unique output path using current timestamp
  let timestamp = get_timestamp()
  let output_base = "/tmp/ocr_output_" <> int.to_string(timestamp)
  let output_file = output_base <> ".txt"

  // Build the tesseract command with proper shell escaping
  let command =
    "tesseract "
    <> shell_escape(image_path)
    <> " "
    <> shell_escape(output_base)
    <> " --psm 3 -l eng 2>&1"

  // Execute Tesseract
  let _ = erlang_cmd(command)

  // Try to read the output file
  case simplifile.read(output_file) {
    Ok(text) -> {
      // Clean up the output file
      let _ = simplifile.delete(output_file)
      parse_tesseract_output(text)
    }
    Error(_) -> {
      // Clean up attempt
      let _ = simplifile.delete(output_file)
      OcrError(ProcessingFailed, "Failed to read OCR output or Tesseract failed")
    }
  }
}

/// Parse Tesseract output and determine if text was found
fn parse_tesseract_output(output: String) -> OcrResult {
  let trimmed = string.trim(output)

  case trimmed {
    "" -> OcrError(NoTextDetected, "No text was detected in the image")
    text -> {
      // Count approximate pages (for now, always 1)
      let page_count = 1

      // For now, we don't extract confidence from basic output
      // Confidence would require using TSV output format
      let confidence = 0.0

      OcrSuccess(text: text, confidence: confidence, page_count: page_count)
    }
  }
}

/// Escape shell arguments to prevent command injection
fn shell_escape(arg: String) -> String {
  "'" <> string.replace(arg, "'", "'\\''") <> "'"
}

/// Get current timestamp using Erlang's system time
@external(erlang, "erlang", "system_time")
fn get_timestamp() -> Int
