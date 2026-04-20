import bigi.{type BigInt}
import gleam/bit_array
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string

// Convert hex string to BigInt
pub fn hex_to_bigint(hex_string: String) -> Result(BigInt, Nil) {
  let clean_hex = case string.starts_with(hex_string, "0x") {
    True -> string.drop_start(hex_string, 2)
    False -> hex_string
  }

  case clean_hex {
    "" -> Ok(bigi.from_int(0))
    _ -> hex_chars_to_bigint(clean_hex)
  }
}

// Convert hex characters to BigInt using undigits
fn hex_chars_to_bigint(hex: String) -> Result(BigInt, Nil) {
  let chars = string.to_graphemes(hex)
  use digits <- result.try(list.try_map(chars, char_to_hex_value))
  bigi.undigits(digits, 16)
}

// Convert single hex character to its numeric value
fn char_to_hex_value(char: String) -> Result(Int, Nil) {
  case char {
    "0" -> Ok(0)
    "1" -> Ok(1)
    "2" -> Ok(2)
    "3" -> Ok(3)
    "4" -> Ok(4)
    "5" -> Ok(5)
    "6" -> Ok(6)
    "7" -> Ok(7)
    "8" -> Ok(8)
    "9" -> Ok(9)
    "a" | "A" -> Ok(10)
    "b" | "B" -> Ok(11)
    "c" | "C" -> Ok(12)
    "d" | "D" -> Ok(13)
    "e" | "E" -> Ok(14)
    "f" | "F" -> Ok(15)
    _ -> Error(Nil)
  }
}

// Convert hex string to regular int for smaller values
pub fn hex_to_int(hex_string: String) -> Result(Int, Nil) {
  use bigint <- result.try(hex_to_bigint(hex_string))
  bigi.to_int(bigint)
}

// Convert Wei (as hex string) to Ether (as float) using BigInt
pub fn wei_to_ether(wei_hex: String) -> Result(Float, Nil) {
  use wei_bigint <- result.try(hex_to_bigint(wei_hex))

  // Convert to string and then parse as float for division
  let wei_str = bigi.to_string(wei_bigint)
  case int.parse(wei_str) {
    Ok(wei_int) -> {
      let wei_float = int.to_float(wei_int)
      let ether = wei_float /. 1_000_000_000_000_000_000.0
      Ok(ether)
    }
    Error(_) -> {
      // For very large numbers, use string division approximation
      wei_to_ether_string_division(wei_str)
    }
  }
}

// Convert Wei (as hex string) to Gwei (as float) using BigInt
pub fn wei_to_gwei(wei_hex: String) -> Result(Float, Nil) {
  use wei_bigint <- result.try(hex_to_bigint(wei_hex))

  // Convert to string and then parse as float for division
  let wei_str = bigi.to_string(wei_bigint)
  case int.parse(wei_str) {
    Ok(wei_int) -> {
      let wei_float = int.to_float(wei_int)
      let gwei = wei_float /. 1_000_000_000.0
      // 1 gwei = 10^9 wei
      Ok(gwei)
    }
    Error(_) -> {
      // For very large numbers, use string division approximation
      wei_to_gwei_string_division(wei_str)
    }
  }
}

// Handle very large values using string manipulation with a configurable
// decimal digit count (18 for ether, 9 for gwei).
fn string_division(
  wei_str: String,
  decimals: Int,
  divisor: Float,
) -> Result(Float, Nil) {
  let wei_len = string.length(wei_str)
  case wei_len {
    len if len <= decimals -> {
      case int.parse(wei_str) {
        Ok(wei_int) -> Ok(int.to_float(wei_int) /. divisor)
        Error(_) -> Error(Nil)
      }
    }
    len -> {
      let whole_part = string.drop_end(wei_str, decimals)
      let frac_part = string.drop_start(wei_str, len - decimals)

      case int.parse(whole_part) {
        Ok(whole_int) -> {
          let whole_float = int.to_float(whole_int)
          case int.parse(frac_part) {
            Ok(frac_int) -> Ok(whole_float +. int.to_float(frac_int) /. divisor)
            Error(_) -> Ok(whole_float)
          }
        }
        Error(_) -> Error(Nil)
      }
    }
  }
}

fn wei_to_ether_string_division(wei_str: String) -> Result(Float, Nil) {
  string_division(wei_str, 18, 1_000_000_000_000_000_000.0)
}

fn wei_to_gwei_string_division(wei_str: String) -> Result(Float, Nil) {
  string_division(wei_str, 9, 1_000_000_000.0)
}

// Format Wei to a nice Ether string with proper decimal places
pub fn format_wei_to_ether(wei_hex: String) -> String {
  case wei_to_ether(wei_hex) {
    Ok(ether) -> {
      let ether_str = float.to_string(ether)
      case ether >. 0.001 {
        True -> ether_str <> " ETH"
        False -> {
          // For very small amounts, also show the Wei value
          ether_str <> " ETH (" <> wei_hex <> " Wei)"
        }
      }
    }
    Error(_) -> wei_hex <> " Wei (conversion failed)"
  }
}

// Format Wei to a nice Gwei string with proper decimal places
pub fn format_wei_to_gwei(wei_hex: String) -> String {
  case wei_to_gwei(wei_hex) {
    Ok(gwei) -> {
      let gwei_str = float.to_string(gwei)
      gwei_str <> " gwei"
    }
    Error(_) -> wei_hex <> " wei (gwei conversion failed)"
  }
}

// Convert hex block number to decimal string using BigInt
pub fn format_block_number(block_hex: String) -> String {
  case hex_to_bigint(block_hex) {
    Ok(block_bigint) -> bigi.to_string(block_bigint)
    Error(_) -> block_hex
  }
}

// Validate hex string format using bigi
pub fn is_valid_hex(hex_string: String) -> Bool {
  case hex_to_bigint(hex_string) {
    Ok(_) -> True
    Error(_) -> False
  }
}

// Decode hex string to BitArray
pub fn decode(hex_string: String) -> Result(BitArray, String) {
  let clean_hex = case string.starts_with(hex_string, "0x") {
    True -> string.drop_start(hex_string, 2)
    False -> hex_string
  }

  case string.length(clean_hex) % 2 {
    0 -> decode_hex_pairs(clean_hex)
    _ -> Error("Hex string must have an even number of characters")
  }
}

// Helper function to decode hex pairs to bytes
fn decode_hex_pairs(hex: String) -> Result(BitArray, String) {
  let chars = string.to_graphemes(hex)
  use bytes <- result.try(decode_hex_chars_to_bytes(chars, []))
  // Convert list of bytes to BitArray using bit syntax
  let bit_pattern =
    list.fold(bytes, <<>>, fn(acc, byte) { <<acc:bits, byte:8>> })
  Ok(bit_pattern)
}

// Convert hex character pairs to bytes
fn decode_hex_chars_to_bytes(
  chars: List(String),
  acc: List(Int),
) -> Result(List(Int), String) {
  case chars {
    [] -> Ok(list.reverse(acc))
    [high, low, ..rest] -> {
      use high_val <- result.try(
        char_to_hex_value(high)
        |> result.map_error(fn(_) { "Invalid hex character: " <> high }),
      )
      use low_val <- result.try(
        char_to_hex_value(low)
        |> result.map_error(fn(_) { "Invalid hex character: " <> low }),
      )
      let byte_val = high_val * 16 + low_val
      decode_hex_chars_to_bytes(rest, [byte_val, ..acc])
    }
    [_] -> Error("Hex string must have an even number of characters")
  }
}

// Encode BitArray to hex string with 0x prefix
pub fn encode(data: BitArray) -> String {
  "0x" <> bit_array.base16_encode(data) |> string.lowercase
}

// =============================================================================
// Common Hex String Processing Functions
// =============================================================================

/// Remove 0x prefix from hex string if present
pub fn strip_prefix(hex_string: String) -> String {
  case string.starts_with(hex_string, "0x") {
    True -> string.drop_start(hex_string, 2)
    False -> hex_string
  }
}

/// Add 0x prefix to hex string if not present
pub fn ensure_prefix(hex_string: String) -> String {
  case string.starts_with(hex_string, "0x") {
    True -> hex_string
    False -> "0x" <> hex_string
  }
}

/// Normalize hex string to lowercase with 0x prefix
pub fn normalize(hex_string: String) -> String {
  let clean = strip_prefix(hex_string)
  "0x" <> string.lowercase(clean)
}

/// Convert integer to hex string with 0x prefix
pub fn from_int(value: Int) -> String {
  "0x" <> int.to_base16(value) |> string.lowercase
}

/// Parse hex string to integer (with or without 0x prefix)
pub fn to_int(hex_string: String) -> Result(Int, Nil) {
  use bigint <- result.try(hex_to_bigint(hex_string))
  bigi.to_int(bigint)
}

/// Validate that a string contains only valid hex characters (after stripping 0x)
pub fn is_valid_hex_chars(hex_string: String) -> Bool {
  let clean = strip_prefix(hex_string)
  string.to_graphemes(clean) |> list.all(is_hex_char)
}

/// Check if a single character is a valid hex digit
fn is_hex_char(char: String) -> Bool {
  case char {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    "a" | "b" | "c" | "d" | "e" | "f" -> True
    "A" | "B" | "C" | "D" | "E" | "F" -> True
    _ -> False
  }
}

/// Format a hex value with decimal equivalent for display
pub fn format_with_decimal(hex_string: String) -> String {
  case to_int(hex_string) {
    Ok(decimal_value) ->
      int.to_string(decimal_value) <> " (" <> normalize(hex_string) <> ")"
    Error(_) -> normalize(hex_string)
  }
}

/// Pad hex string to specified length (without 0x prefix)
pub fn pad_left(hex_string: String, target_length: Int) -> String {
  let clean = strip_prefix(hex_string)
  let current_length = string.length(clean)
  case current_length >= target_length {
    True -> clean
    False -> {
      let padding_needed = target_length - current_length
      let padding = string.repeat("0", padding_needed)
      padding <> clean
    }
  }
}

/// Validate hex string has correct length for specific data types
pub fn validate_length(
  hex_string: String,
  expected_bytes: Int,
) -> Result(String, String) {
  let clean = strip_prefix(hex_string)
  let expected_chars = expected_bytes * 2
  case string.length(clean) {
    actual_chars if actual_chars == expected_chars -> Ok(clean)
    actual_chars ->
      Error(
        "Expected "
        <> int.to_string(expected_chars)
        <> " hex characters, got "
        <> int.to_string(actual_chars),
      )
  }
}

// =============================================================================
// Shared byte utilities
// =============================================================================

/// Convert a big-endian BitArray to an integer.
/// Used by ENS, permit, and RLP modules for ABI offset/length parsing.
pub fn bytes_to_int(data: BitArray) -> Int {
  do_bytes_to_int(data, 0)
}

fn do_bytes_to_int(data: BitArray, acc: Int) -> Int {
  case data {
    <<byte:8, rest:bits>> -> do_bytes_to_int(rest, acc * 256 + byte)
    _ -> acc
  }
}

/// Create a BitArray of n zero bytes.
/// Shared by eip712 and contract modules for padding.
pub fn make_zeros(n: Int) -> BitArray {
  case n <= 0 {
    True -> <<>>
    False -> make_zeros_acc(n, <<>>)
  }
}

fn make_zeros_acc(n: Int, acc: BitArray) -> BitArray {
  case n <= 0 {
    True -> acc
    False -> make_zeros_acc(n - 1, <<acc:bits, 0:8>>)
  }
}
