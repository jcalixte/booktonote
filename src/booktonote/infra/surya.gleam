/// Surya OCR implementation for text extraction
/// This module contains the infrastructure details for running Surya OCR
import gleam/int
import gleam/result
import gleam/string
import simplifile

/// External FFI call to Erlang's os:cmd/1
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

/// Get current timestamp using Erlang's system time
@external(erlang, "erlang", "system_time")
fn get_timestamp() -> Int

/// Get environment variable - returns the value or empty string if not set
@external(erlang, "booktonote_ffi", "getenv")
fn getenv(name: String) -> Result(String, Nil)

/// Default path to the Surya OCR script (Docker)
const default_surya_script_path = "/app/scripts/surya_engine.py"

/// Get the Surya script path from environment or use default
fn get_surya_script_path() -> String {
  getenv("SURYA_SCRIPT_PATH")
  |> result.unwrap(default_surya_script_path)
}

/// Check if Surya is installed and accessible
pub fn check_engine_installed() -> Result(String, Nil) {
  let output =
    erlang_cmd(
      "python3.11 -c \"from surya.recognition import RecognitionPredictor; from surya.detection import DetectionPredictor; print('Surya ready')\" 2>&1 && echo __SUCCESS__ || echo __FAILURE__",
    )

  case string.contains(output, "__SUCCESS__") {
    True -> Ok("Surya")
    False -> Error(Nil)
  }
}

/// Extract text from an image using Surya OCR
pub fn extract_text(image_path: String) -> Result(String, String) {
  // Generate a unique output path using current timestamp
  let timestamp = get_timestamp()
  let output_file = "/tmp/surya_output_" <> int.to_string(timestamp) <> ".txt"

  // Build the Surya command with proper shell escaping
  let command =
    "python3.11 "
    <> shell_escape(get_surya_script_path())
    <> " "
    <> shell_escape(image_path)
    <> " "
    <> shell_escape(output_file)
    <> " 2>&1"

  // Execute Surya OCR
  let _ = erlang_cmd(command)

  // Try to read the output file
  case simplifile.read(output_file) {
    Ok(text) -> {
      // Clean up the output file
      let _ = simplifile.delete(output_file)
      Ok(text)
    }
    Error(_) -> {
      // Clean up attempt
      let _ = simplifile.delete(output_file)
      Error("Failed to read OCR output or Surya failed")
    }
  }
}

/// Escape shell arguments to prevent command injection
fn shell_escape(arg: String) -> String {
  "'" <> string.replace(arg, "'", "'\\''") <> "'"
}
