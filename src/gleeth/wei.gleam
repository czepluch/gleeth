//// Convert between human-readable values (ETH, gwei, integers) and the
//// `0x`-prefixed hex strings used by the Ethereum JSON-RPC wire format.
////
//// All RPC methods in gleeth accept and return hex strings. This module
//// bridges the gap so users don't have to construct hex manually.
////
//// ## Examples
////
//// ```gleam
//// let assert Ok(hex) = wei.from_ether("1.0")
//// // hex = "0xde0b6b3a7640000"
////
//// let assert Ok(eth) = wei.to_ether("0xde0b6b3a7640000")
//// // eth = "1.0"
//// ```

import bigi.{type BigInt}
import gleam/int
import gleam/result
import gleam/string
import gleeth/utils/hex

/// Convert an ether amount string to a wei hex string.
/// Handles integers ("1", "100") and decimals ("1.5", "0.001").
///
/// ## Examples
///
/// ```gleam
/// wei.from_ether("1.0")   // -> Ok("0xde0b6b3a7640000")
/// wei.from_ether("0.5")   // -> Ok("0x6f05b59d3b20000")
/// wei.from_ether("0")     // -> Ok("0x0")
/// ```
pub fn from_ether(ether: String) -> Result(String, String) {
  decimal_to_wei(ether, 18)
}

/// Convert a gwei amount string to a wei hex string.
///
/// ## Examples
///
/// ```gleam
/// wei.from_gwei("1.0")    // -> Ok("0x3b9aca00")
/// wei.from_gwei("20")     // -> Ok("0x4a817c800")
/// ```
pub fn from_gwei(gwei: String) -> Result(String, String) {
  decimal_to_wei(gwei, 9)
}

/// Convert a wei hex string to an ether decimal string.
///
/// ## Examples
///
/// ```gleam
/// wei.to_ether("0xde0b6b3a7640000")  // -> Ok("1.0")
/// wei.to_ether("0x0")                 // -> Ok("0.0")
/// ```
pub fn to_ether(wei_hex: String) -> Result(String, String) {
  wei_to_decimal(wei_hex, 18)
}

/// Convert a wei hex string to a gwei decimal string.
///
/// ## Examples
///
/// ```gleam
/// wei.to_gwei("0x3b9aca00")  // -> Ok("1.0")
/// ```
pub fn to_gwei(wei_hex: String) -> Result(String, String) {
  wei_to_decimal(wei_hex, 9)
}

/// Convert a decimal integer to a hex string.
///
/// ## Examples
///
/// ```gleam
/// wei.from_int(21000)  // -> "0x5208"
/// wei.from_int(0)      // -> "0x0"
/// ```
pub fn from_int(value: Int) -> String {
  case value {
    0 -> "0x0"
    _ -> "0x" <> string.lowercase(int.to_base16(value))
  }
}

/// Convert a hex string to a decimal integer.
///
/// ## Examples
///
/// ```gleam
/// wei.to_int("0x5208")  // -> Ok(21000)
/// ```
pub fn to_int(hex_string: String) -> Result(Int, String) {
  let clean = strip_0x(hex_string)
  case clean {
    "" -> Ok(0)
    _ ->
      int.base_parse(clean, 16)
      |> result.map_error(fn(_) { "Invalid hex: " <> hex_string })
  }
}

// =============================================================================
// Internal
// =============================================================================

/// Parse a decimal string (possibly with fractional part) and multiply by
/// 10^decimals to get the wei value as a BigInt, then convert to hex.
fn decimal_to_wei(amount: String, decimals: Int) -> Result(String, String) {
  let trimmed = string.trim(amount)
  case trimmed {
    "" -> Error("Empty amount")
    _ -> {
      use wei <- result.try(parse_decimal_to_bigint(trimmed, decimals))
      let zero = bigi.from_int(0)
      case bigi.compare(wei, zero) {
        order.Lt -> Error("Negative amounts not supported")
        _ -> Ok(bigint_to_hex(wei))
      }
    }
  }
}

/// Convert wei BigInt back to a decimal string with the given number of
/// decimal places.
fn wei_to_decimal(hex_string: String, decimals: Int) -> Result(String, String) {
  use wei <- result.try(
    hex.hex_to_bigint(hex_string)
    |> result.map_error(fn(_) { "Invalid hex: " <> hex_string }),
  )
  let divisor_str = power_of_10_string(decimals)
  let assert Ok(divisor) = bigi.from_string(divisor_str)
  let whole = bigi.divide(wei, divisor)
  let remainder = bigi.remainder(wei, divisor)
  let whole_str = bigi.to_string(whole)
  let remainder_str = bigi.to_string(remainder)
  // Pad remainder with leading zeros to fill decimal places
  let padded =
    string.repeat("0", decimals - string.length(remainder_str)) <> remainder_str
  // Trim trailing zeros but keep at least one decimal place
  let trimmed = trim_trailing_zeros(padded)
  Ok(whole_str <> "." <> trimmed)
}

/// Parse a decimal string like "1.5" or "100" into a BigInt representing
/// wei (multiplied by 10^decimals).
fn parse_decimal_to_bigint(
  amount: String,
  decimals: Int,
) -> Result(BigInt, String) {
  case string.split(amount, ".") {
    [whole] -> {
      // Integer amount: multiply by 10^decimals
      use whole_big <- result.try(
        bigi.from_string(whole)
        |> result.map_error(fn(_) { "Invalid number: " <> amount }),
      )
      let assert Ok(multiplier) = bigi.from_string(power_of_10_string(decimals))
      Ok(bigi.multiply(whole_big, multiplier))
    }
    [whole, frac] -> {
      let frac_len = string.length(frac)
      case frac_len > decimals {
        True ->
          Error(
            "Too many decimal places (max " <> int.to_string(decimals) <> ")",
          )
        False -> {
          // Pad fractional part to exactly `decimals` digits
          let padded_frac = frac <> string.repeat("0", decimals - frac_len)
          let combined = whole <> padded_frac
          bigi.from_string(combined)
          |> result.map_error(fn(_) { "Invalid number: " <> amount })
        }
      }
    }
    _ -> Error("Invalid decimal format: " <> amount)
  }
}

fn bigint_to_hex(value: BigInt) -> String {
  let zero = bigi.from_int(0)
  case bigi.compare(value, zero) {
    order.Eq -> "0x0"
    _ -> {
      let hex_str = bigint_to_hex_loop(value, "")
      "0x" <> string.lowercase(hex_str)
    }
  }
}

fn bigint_to_hex_loop(value: BigInt, acc: String) -> String {
  let zero = bigi.from_int(0)
  let sixteen = bigi.from_int(16)
  case bigi.compare(value, zero) {
    order.Eq -> acc
    _ -> {
      let remainder = bigi.remainder(value, sixteen)
      let quotient = bigi.divide(value, sixteen)
      let assert Ok(nibble) = bigi.to_int(remainder)
      let hex_char = nibble_to_char(nibble)
      bigint_to_hex_loop(quotient, hex_char <> acc)
    }
  }
}

fn nibble_to_char(n: Int) -> String {
  case n {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    9 -> "9"
    10 -> "a"
    11 -> "b"
    12 -> "c"
    13 -> "d"
    14 -> "e"
    15 -> "f"
    _ -> "0"
  }
}

fn power_of_10_string(n: Int) -> String {
  "1" <> string.repeat("0", n)
}

fn strip_0x(s: String) -> String {
  case string.starts_with(s, "0x") {
    True -> string.drop_start(s, 2)
    False -> s
  }
}

fn trim_trailing_zeros(s: String) -> String {
  case string.ends_with(s, "0") {
    True -> {
      let trimmed = string.drop_end(s, 1)
      case trimmed {
        "" -> "0"
        _ -> trim_trailing_zeros(trimmed)
      }
    }
    False -> {
      case s {
        "" -> "0"
        _ -> s
      }
    }
  }
}

import gleam/order
