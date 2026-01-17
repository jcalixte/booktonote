/// Tesseract OCR service for text extraction from images
import booktonote/types.{
  type OcrResult, InvalidImageFormat, NoTextDetected, OcrError, OcrSuccess,
  ProcessingFailed, TesseractNotFound,
}
import gleam/int
import gleam/list
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
  let output =
    erlang_cmd(
      "tesseract --version 2>&1 && echo __SUCCESS__ || echo __FAILURE__",
    )

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
  // OEM 1 = LSTM neural network only (latest/most accurate)
  // PSM 6 = Single uniform block of text (optimized for book pages with paragraphs)
  let command =
    "tesseract "
    <> shell_escape(image_path)
    <> " "
    <> shell_escape(output_base)
    <> " --oem 1 --psm 6 -l eng 2>&1"

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
      OcrError(
        ProcessingFailed,
        "Failed to read OCR output or Tesseract failed",
      )
    }
  }
}

/// Parse Tesseract output and determine if text was found
pub fn parse_tesseract_output(output: String) -> OcrResult {
  let trimmed = string.trim(output)

  case trimmed {
    "" -> OcrError(NoTextDetected, "No text was detected in the image")
    text -> {
      // Normalize characters to ASCII equivalents
      let normalized_text = normalize_text(text)

      // Split into paragraphs (by double newline) and clean up
      let paragraphs =
        normalized_text
        |> string.split("\n\n")
        |> filter_empty_strings
        |> list.map(remove_new_line)

      // Join paragraphs back with double newlines for the text field
      let clean_text = string.join(paragraphs, "\n\n")

      OcrSuccess(text: clean_text, paragraphs: paragraphs)
    }
  }
}

/// Normalize special Unicode characters to ASCII equivalents
fn normalize_text(text: String) -> String {
  let double_quote = "\""

  text
  // Normalize left and right double quotes to straight double quote
  |> string.replace("\u{201C}", double_quote)
  |> string.replace("\u{201D}", double_quote)
  |> string.replace("\u{201E}", double_quote)
  // Normalize left and right single quotes to straight single quote
  |> string.replace("\u{2018}", "'")
  |> string.replace("\u{2019}", "'")
  |> string.replace("\u{201A}", "'")
  |> string.replace("\u{201B}", "'")
  |> string.replace("\u{00B4}", "'")
  |> string.replace("\u{0060}", "'")
  // Normalize dashes to regular hyphen
  |> string.replace("\u{2014}", "-")
  |> string.replace("\u{2013}", "-")
  |> string.replace("\u{2015}", "-")
  |> string.replace("\u{2010}", "-")
  |> string.replace("\u{2011}", "-")
  // Normalize ellipsis
  |> string.replace("\u{2026}", "...")
  // Normalize various spaces to regular space
  |> string.replace("\u{00A0}", " ")
  |> string.replace("\u{2000}", " ")
  |> string.replace("\u{2001}", " ")
  |> string.replace("\u{2002}", " ")
  |> string.replace("\u{2003}", " ")
  |> string.replace("\u{2004}", " ")
  |> string.replace("\u{2005}", " ")
  |> string.replace("\u{2006}", " ")
  |> string.replace("\u{2007}", " ")
  |> string.replace("\u{2008}", " ")
  |> string.replace("\u{2009}", " ")
  |> string.replace("\u{200A}", " ")
  // Normalize bullet points
  |> string.replace("\u{2022}", "- ")
  |> string.replace("\u{25E6}", "- ")
  |> string.replace("\u{25AA}", "- ")
  |> string.replace("\u{25AB}", "- ")
  // Remove zero-width characters
  |> string.replace("\u{200B}", "")
  |> string.replace("\u{200C}", "")
  |> string.replace("\u{200D}", "")
  |> string.replace("\u{FEFF}", "")
}

fn remove_new_line(arg: String) -> String {
  arg
  |> string.replace("\n", " ")
  |> string.replace("  ", " ")
}

/// Filter out empty strings from a list
fn filter_empty_strings(list: List(String)) -> List(String) {
  case list {
    [] -> []
    [head, ..tail] -> {
      let trimmed = string.trim(head)
      case trimmed {
        "" -> filter_empty_strings(tail)
        _ -> [trimmed, ..filter_empty_strings(tail)]
      }
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
