import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeth/utils/hex

/// Represents an RLP-encodable item.
/// RLP encodes two types: raw byte strings and lists of RLP items.
pub type RlpItem {
  RlpBytes(BitArray)
  RlpList(List(RlpItem))
}

/// Errors that can occur during RLP decoding
pub type RlpError {
  InvalidPrefix(Int)
  UnexpectedEnd
  ExtraData
  InvalidLength
}

// =============================================================================
// Encoding
// =============================================================================

/// Encode an RLP item to bytes
pub fn encode(item: RlpItem) -> BitArray {
  case item {
    RlpBytes(data) -> encode_bytes(data)
    RlpList(items) -> encode_list(items)
  }
}

fn encode_bytes(data: BitArray) -> BitArray {
  case data {
    <<byte:8>> -> {
      case byte < 0x80 {
        // Single byte in 0x00-0x7f range encodes as itself
        True -> data
        // Single byte >= 0x80 needs a length prefix
        False -> {
          let prefix = encode_length(1, 0x80)
          <<prefix:bits, data:bits>>
        }
      }
    }
    _ -> {
      let len = bit_array.byte_size(data)
      let prefix = encode_length(len, 0x80)
      <<prefix:bits, data:bits>>
    }
  }
}

fn encode_list(items: List(RlpItem)) -> BitArray {
  let payload =
    list.fold(items, <<>>, fn(acc, item) {
      let encoded = encode(item)
      <<acc:bits, encoded:bits>>
    })
  let len = bit_array.byte_size(payload)
  let prefix = encode_length(len, 0xc0)
  <<prefix:bits, payload:bits>>
}

fn encode_length(len: Int, offset: Int) -> BitArray {
  case len <= 55 {
    True -> {
      let prefix_byte = offset + len
      <<prefix_byte:8>>
    }
    False -> {
      let len_bytes = to_binary_be(len)
      let len_of_len = bit_array.byte_size(len_bytes)
      let prefix_byte = offset + 55 + len_of_len
      <<prefix_byte:8, len_bytes:bits>>
    }
  }
}

// =============================================================================
// Decoding
// =============================================================================

/// Decode bytes into an RLP item
pub fn decode(data: BitArray) -> Result(RlpItem, RlpError) {
  use #(item, rest) <- result.try(decode_item(data))
  case bit_array.byte_size(rest) {
    0 -> Ok(item)
    _ -> Error(ExtraData)
  }
}

fn decode_item(data: BitArray) -> Result(#(RlpItem, BitArray), RlpError) {
  case data {
    <<>> -> Error(UnexpectedEnd)
    <<prefix:8, rest:bits>> -> decode_with_prefix(prefix, rest)
    _ -> Error(UnexpectedEnd)
  }
}

fn decode_with_prefix(
  prefix: Int,
  rest: BitArray,
) -> Result(#(RlpItem, BitArray), RlpError) {
  // 0x00-0x7f: single byte value
  case prefix < 0x80 {
    True -> Ok(#(RlpBytes(<<prefix:8>>), rest))
    False ->
      // 0x80-0xb7: short string (0-55 bytes)
      case prefix < 0xb8 {
        True -> {
          let len = prefix - 0x80
          use #(bytes, remaining) <- result.try(take_bytes(rest, len))
          Ok(#(RlpBytes(bytes), remaining))
        }
        False ->
          // 0xb8-0xbf: long string (>55 bytes)
          case prefix < 0xc0 {
            True -> {
              let len_of_len = prefix - 0xb7
              use #(len_bytes, after_len) <- result.try(take_bytes(
                rest,
                len_of_len,
              ))
              let len = bytes_to_int(len_bytes)
              use #(bytes, remaining) <- result.try(take_bytes(after_len, len))
              Ok(#(RlpBytes(bytes), remaining))
            }
            False ->
              // 0xc0-0xf7: short list (0-55 bytes payload)
              case prefix < 0xf8 {
                True -> {
                  let len = prefix - 0xc0
                  use #(payload, remaining) <- result.try(take_bytes(rest, len))
                  use items <- result.try(decode_list_payload(payload))
                  Ok(#(RlpList(items), remaining))
                }
                // 0xf8-0xff: long list (>55 bytes payload)
                False -> {
                  let len_of_len = prefix - 0xf7
                  use #(len_bytes, after_len) <- result.try(take_bytes(
                    rest,
                    len_of_len,
                  ))
                  let len = bytes_to_int(len_bytes)
                  use #(payload, remaining) <- result.try(take_bytes(
                    after_len,
                    len,
                  ))
                  use items <- result.try(decode_list_payload(payload))
                  Ok(#(RlpList(items), remaining))
                }
              }
          }
      }
  }
}

fn decode_list_payload(data: BitArray) -> Result(List(RlpItem), RlpError) {
  case bit_array.byte_size(data) {
    0 -> Ok([])
    _ -> {
      use #(item, rest) <- result.try(decode_item(data))
      use items <- result.try(decode_list_payload(rest))
      Ok([item, ..items])
    }
  }
}

// =============================================================================
// Convenience functions
// =============================================================================

/// Convert an integer to an RLP item.
/// Uses big-endian minimal encoding: 0 becomes empty bytes.
pub fn encode_int(value: Int) -> RlpItem {
  case value {
    0 -> RlpBytes(<<>>)
    _ -> RlpBytes(to_binary_be(value))
  }
}

/// Convert a UTF-8 string to an RLP item
pub fn encode_string(value: String) -> RlpItem {
  RlpBytes(bit_array.from_string(value))
}

/// Convert a "0x..." hex string to an RLP item with minimal encoding.
/// Strips the 0x prefix, decodes hex to bytes, and removes leading zero bytes.
pub fn encode_hex_field(hex_string: String) -> RlpItem {
  let stripped = hex.strip_prefix(hex_string)
  case stripped {
    "" -> RlpBytes(<<>>)
    _ -> {
      let padded = case string.length(stripped) % 2 {
        0 -> stripped
        _ -> "0" <> stripped
      }
      case hex.decode(padded) {
        Ok(bytes) -> RlpBytes(strip_leading_zeros(bytes))
        Error(_) -> RlpBytes(<<>>)
      }
    }
  }
}

// =============================================================================
// Internal helpers
// =============================================================================

/// Convert a non-negative integer to minimal big-endian bytes
fn to_binary_be(value: Int) -> BitArray {
  case value {
    0 -> <<>>
    _ -> do_to_binary_be(value, <<>>)
  }
}

fn do_to_binary_be(value: Int, acc: BitArray) -> BitArray {
  case value {
    0 -> acc
    _ -> {
      let byte = int.bitwise_and(value, 0xff)
      let rest = int.bitwise_shift_right(value, 8)
      do_to_binary_be(rest, <<byte:8, acc:bits>>)
    }
  }
}

/// Convert big-endian bytes to an integer
fn bytes_to_int(data: BitArray) -> Int {
  do_bytes_to_int(data, 0)
}

fn do_bytes_to_int(data: BitArray, acc: Int) -> Int {
  case data {
    <<byte:8, rest:bits>> -> do_bytes_to_int(rest, acc * 256 + byte)
    _ -> acc
  }
}

/// Take n bytes from the front of a BitArray
fn take_bytes(data: BitArray, n: Int) -> Result(#(BitArray, BitArray), RlpError) {
  case n == 0 {
    True -> Ok(#(<<>>, data))
    False -> {
      let available = bit_array.byte_size(data)
      case available >= n {
        True -> {
          case
            bit_array.slice(data, 0, n),
            bit_array.slice(data, n, available - n)
          {
            Ok(taken), Ok(rest) -> Ok(#(taken, rest))
            _, _ -> Error(UnexpectedEnd)
          }
        }
        False -> Error(UnexpectedEnd)
      }
    }
  }
}

/// Strip leading zero bytes from a BitArray
fn strip_leading_zeros(data: BitArray) -> BitArray {
  case data {
    <<0:8, rest:bits>> -> strip_leading_zeros(rest)
    _ -> data
  }
}
