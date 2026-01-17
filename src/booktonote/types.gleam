/// Type definitions for OCR operations and error handling
/// Result type for OCR operations
pub type OcrResult {
  /// Successful OCR extraction
  OcrSuccess(text: String, paragraphs: List(String))
  /// OCR operation failed
  OcrError(error: OcrErrorType, message: String)
}

/// Specific error types for OCR operations
pub type OcrErrorType {
  /// Tesseract OCR is not installed or not accessible
  TesseractNotFound
  /// The uploaded file is not a supported image format
  InvalidImageFormat
  /// OCR processing encountered an error
  ProcessingFailed
  /// The uploaded file exceeds the maximum size limit
  FileTooLarge
  /// No text was detected in the image
  NoTextDetected
}
