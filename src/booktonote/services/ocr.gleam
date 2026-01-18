/// Abstract OCR service for text extraction from images
/// Implementation details are injected via OcrEngine
import booktonote/ocr_engine.{type OcrEngine}
import booktonote/types.{
  type OcrResult, InvalidImageFormat, NoTextDetected, OcrError, OcrSuccess,
  OcrEngineNotFound,
}
import gleam/list
import gleam/string
import simplifile

/// Run OCR on an image file and extract text
pub fn run_ocr(engine: OcrEngine, image_path: String) -> OcrResult {
  // Check if OCR engine is available
  case engine.check_installed() {
    Error(_) ->
      OcrError(
        OcrEngineNotFound,
        "OCR engine is not installed or not accessible",
      )
    Ok(_) -> {
      // Verify the image file exists
      case simplifile.is_file(image_path) {
        Ok(False) | Error(_) ->
          OcrError(InvalidImageFormat, "Image file not found or not accessible")
        Ok(True) -> {
          // Delegate to implementation
          case engine.extract_text(image_path) {
            Ok(text) -> parse_ocr_output(text)
            Error(message) -> OcrError(types.ProcessingFailed, message)
          }
        }
      }
    }
  }
}

/// Parse OCR output and determine if text was found
pub fn parse_ocr_output(output: String) -> OcrResult {
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
