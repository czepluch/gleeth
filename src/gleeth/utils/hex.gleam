import bigi.{type BigInt}
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

// Handle very large Wei values using string manipulation
fn wei_to_ether_string_division(wei_str: String) -> Result(Float, Nil) {
  let wei_len = string.length(wei_str)
  case wei_len {
    len if len <= 18 -> {
      // Less than 1 ETH
      case int.parse(wei_str) {
        Ok(wei_int) -> Ok(int.to_float(wei_int) /. 1_000_000_000_000_000_000.0)
        Error(_) -> Error(Nil)
      }
    }
    len -> {
      // More than 1 ETH - split the string
      let ether_part = string.drop_end(wei_str, 18)
      let wei_part = string.drop_start(wei_str, len - 18)

      case int.parse(ether_part) {
        Ok(ether_int) -> {
          let ether_float = int.to_float(ether_int)
          case int.parse(wei_part) {
            Ok(fraction_int) -> {
              let fraction =
                int.to_float(fraction_int) /. 1_000_000_000_000_000_000.0
              Ok(ether_float +. fraction)
            }
            Error(_) -> Ok(ether_float)
          }
        }
        Error(_) -> Error(Nil)
      }
    }
  }
}

// Handle very large Wei values using string manipulation for gwei conversion
fn wei_to_gwei_string_division(wei_str: String) -> Result(Float, Nil) {
  let wei_len = string.length(wei_str)
  case wei_len {
    len if len <= 9 -> {
      // Less than 1 gwei
      case int.parse(wei_str) {
        Ok(wei_int) -> Ok(int.to_float(wei_int) /. 1_000_000_000.0)
        Error(_) -> Error(Nil)
      }
    }
    len -> {
      // More than 1 gwei - split the string
      let gwei_part = string.drop_end(wei_str, 9)
      let wei_part = string.drop_start(wei_str, len - 9)

      case int.parse(gwei_part) {
        Ok(gwei_int) -> {
          let gwei_float = int.to_float(gwei_int)
          case int.parse(wei_part) {
            Ok(fraction_int) -> {
              let fraction = int.to_float(fraction_int) /. 1_000_000_000.0
              Ok(gwei_float +. fraction)
            }
            Error(_) -> Ok(gwei_float)
          }
        }
        Error(_) -> Error(Nil)
      }
    }
  }
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
