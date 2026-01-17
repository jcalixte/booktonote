import booktonote/services/ocr
import booktonote/types.{NoTextDetected, OcrError, OcrSuccess}

pub fn parse_ocr_output_empty_string_test() {
  let result = ocr.parse_ocr_output("")

  assert result == OcrError(NoTextDetected, "No text was detected in the image")
}

pub fn parse_ocr_output_whitespace_only_test() {
  let result = ocr.parse_ocr_output("   \n\n   ")

  assert result == OcrError(NoTextDetected, "No text was detected in the image")
}

pub fn parse_ocr_output_single_paragraph_test() {
  let result = ocr.parse_ocr_output("Hello world")

  assert result == OcrSuccess(text: "Hello world", paragraphs: ["Hello world"])
}

pub fn parse_ocr_output_multiple_paragraphs_test() {
  let input = "First paragraph here.\n\nSecond paragraph here."
  let result = ocr.parse_ocr_output(input)

  assert result
    == OcrSuccess(
      text: "First paragraph here.\n\nSecond paragraph here.",
      paragraphs: ["First paragraph here.", "Second paragraph here."],
    )
}

pub fn parse_ocr_output_trims_whitespace_test() {
  let result = ocr.parse_ocr_output("  Hello world  \n")

  assert result == OcrSuccess(text: "Hello world", paragraphs: ["Hello world"])
}

pub fn parse_ocr_output_normalizes_smart_quotes_test() {
  let input = "\u{201C}Hello\u{201D} world"
  let result = ocr.parse_ocr_output(input)

  assert result
    == OcrSuccess(text: "\"Hello\" world", paragraphs: ["\"Hello\" world"])
}

pub fn parse_ocr_output_normalizes_em_dash_test() {
  let input = "Hello\u{2014}world"
  let result = ocr.parse_ocr_output(input)

  assert result == OcrSuccess(text: "Hello-world", paragraphs: ["Hello-world"])
}

pub fn parse_ocr_output_filters_empty_paragraphs_test() {
  let input = "First paragraph.\n\n\n\nSecond paragraph."
  let result = ocr.parse_ocr_output(input)

  assert result
    == OcrSuccess(text: "First paragraph.\n\nSecond paragraph.", paragraphs: [
      "First paragraph.",
      "Second paragraph.",
    ])
}

pub fn parse_ocr_output_normalizes_ellipsis_test() {
  let input = "Hello\u{2026}world"
  let result = ocr.parse_ocr_output(input)

  assert result
    == OcrSuccess(text: "Hello...world", paragraphs: ["Hello...world"])
}

pub fn parse_ocr_output_normalizes_single_quotes_test() {
  let input = "\u{2018}Hello\u{2019}"
  let result = ocr.parse_ocr_output(input)

  assert result == OcrSuccess(text: "'Hello'", paragraphs: ["'Hello'"])
}

pub fn parse_ocr_output_preserves_single_newlines_test() {
  let input = "First \nparagraph.\n\n\n\nSecond \nparagraph."
  let result = ocr.parse_ocr_output(input)

  assert result
    == OcrSuccess(text: "First paragraph.\n\nSecond paragraph.", paragraphs: [
      "First paragraph.",
      "Second paragraph.",
    ])
}
