//// EIP-55 checksummed Ethereum addresses.
////
//// Ethereum addresses are 20-byte hex strings. EIP-55 defines a mixed-case
//// encoding that serves as a checksum: each hex character is uppercased if
//// the corresponding nibble of the keccak256 hash of the lowercase address
//// is >= 8.
////
//// ## Examples
////
//// ```gleam
//// address.checksum("0xd8da6bf26964af9d7eed9e03e53415d37aa96045")
//// // -> Ok("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
//// ```

import gleam/bit_array
import gleam/list
import gleam/string
import gleeth/crypto/keccak

/// Produce the EIP-55 checksummed form of an Ethereum address.
pub fn checksum(address: String) -> Result(String, String) {
  let cleaned = case string.starts_with(address, "0x") {
    True -> string.drop_start(address, 2)
    False -> address
  }
  case string.length(cleaned) {
    40 -> Ok("0x" <> apply_checksum(string.lowercase(cleaned)))
    _ -> Error("Address must be 40 hex characters")
  }
}

/// Check whether a mixed-case address has a valid EIP-55 checksum.
/// All-lowercase and all-uppercase addresses are considered valid
/// (no checksum applied).
pub fn is_valid_checksum(address: String) -> Bool {
  let cleaned = case string.starts_with(address, "0x") {
    True -> string.drop_start(address, 2)
    False -> address
  }
  case string.length(cleaned) {
    40 -> {
      let lower = string.lowercase(cleaned)
      let upper = string.uppercase(cleaned)
      // All-lowercase and all-uppercase are always valid
      case cleaned == lower || cleaned == upper {
        True -> True
        False -> apply_checksum(lower) == cleaned
      }
    }
    _ -> False
  }
}

/// Convert a potentially checksummed address to lowercase with 0x prefix.
pub fn to_lowercase(address: String) -> Result(String, String) {
  let cleaned = case string.starts_with(address, "0x") {
    True -> string.drop_start(address, 2)
    False -> address
  }
  case string.length(cleaned) {
    40 -> Ok("0x" <> string.lowercase(cleaned))
    _ -> Error("Address must be 40 hex characters")
  }
}

fn apply_checksum(lower_hex: String) -> String {
  let hash = keccak.keccak256_binary(bit_array.from_string(lower_hex))
  let hash_hex = string.lowercase(bit_array.base16_encode(hash))
  let addr_chars = string.to_graphemes(lower_hex)
  let hash_chars = string.to_graphemes(hash_hex)
  list.map2(addr_chars, hash_chars, fn(addr_char, hash_char) {
    case is_letter(addr_char) {
      False -> addr_char
      True -> {
        case nibble_value(hash_char) >= 8 {
          True -> string.uppercase(addr_char)
          False -> addr_char
        }
      }
    }
  })
  |> string.concat
}

fn is_letter(char: String) -> Bool {
  case char {
    "a" | "b" | "c" | "d" | "e" | "f" -> True
    _ -> False
  }
}

fn nibble_value(char: String) -> Int {
  case char {
    "0" -> 0
    "1" -> 1
    "2" -> 2
    "3" -> 3
    "4" -> 4
    "5" -> 5
    "6" -> 6
    "7" -> 7
    "8" -> 8
    "9" -> 9
    "a" -> 10
    "b" -> 11
    "c" -> 12
    "d" -> 13
    "e" -> 14
    "f" -> 15
    _ -> 0
  }
}
