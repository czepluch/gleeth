import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeth/crypto/keccak
import gleeth/ethereum/abi/types.{
  type AbiError, type AbiType, type AbiValue, Address, Array, Bool, Bytes,
  FixedArray, FixedBytes, Int, String, Tuple, Uint,
}
import gleeth/utils/hex

/// Encode a list of typed values according to the Solidity ABI spec.
/// This is the top-level encoding for function parameters.
pub fn encode(values: List(#(AbiType, AbiValue))) -> Result(BitArray, AbiError) {
  encode_tuple_values(values)
}

/// Encode a single typed value.
pub fn encode_single(
  type_: AbiType,
  value: AbiValue,
) -> Result(BitArray, AbiError) {
  encode_value(type_, value)
}

/// Compute the 4-byte function selector: keccak256(name(type1,type2,...))[:4]
pub fn function_selector(
  name: String,
  param_types: List(AbiType),
) -> Result(BitArray, AbiError) {
  let sig =
    name
    <> "("
    <> string.join(list.map(param_types, types.to_string), ",")
    <> ")"
  let hash = keccak.keccak256_binary(bit_array.from_string(sig))
  case bit_array.slice(hash, 0, 4) {
    Ok(selector) -> Ok(selector)
    Error(_) -> Error(types.EncodeError("Failed to compute function selector"))
  }
}

/// Build complete call data: 4-byte selector + ABI-encoded parameters.
pub fn encode_call(
  name: String,
  params: List(#(AbiType, AbiValue)),
) -> Result(BitArray, AbiError) {
  let param_types = list.map(params, fn(p) { p.0 })
  use selector <- result.try(function_selector(name, param_types))
  use encoded <- result.try(encode(params))
  Ok(bit_array.concat([selector, encoded]))
}

// ---------------------------------------------------------------------------
// Internal: tuple (head/tail) encoding
// ---------------------------------------------------------------------------

/// Encode values using ABI tuple encoding (head/tail layout).
fn encode_tuple_values(
  pairs: List(#(AbiType, AbiValue)),
) -> Result(BitArray, AbiError) {
  let total_head_size =
    list.fold(pairs, 0, fn(acc, pair) { acc + types.head_size(pair.0) })

  // Build head and tail in one pass
  use #(head, tail) <- result.try(
    list.try_fold(pairs, #(<<>>, <<>>), fn(acc, pair) {
      let #(head_acc, tail_acc) = acc
      let #(t, v) = pair
      case types.is_dynamic(t) {
        False -> {
          use encoded <- result.try(encode_value(t, v))
          Ok(#(bit_array.concat([head_acc, encoded]), tail_acc))
        }
        True -> {
          use encoded <- result.try(encode_value(t, v))
          let offset = total_head_size + bit_array.byte_size(tail_acc)
          let offset_bytes = encode_uint256(offset)
          Ok(#(
            bit_array.concat([head_acc, offset_bytes]),
            bit_array.concat([tail_acc, encoded]),
          ))
        }
      }
    }),
  )
  Ok(bit_array.concat([head, tail]))
}

// ---------------------------------------------------------------------------
// Internal: per-type encoding
// ---------------------------------------------------------------------------

fn encode_value(t: AbiType, v: AbiValue) -> Result(BitArray, AbiError) {
  case t, v {
    Uint(size), types.UintValue(n) -> encode_uint(n, size)
    Int(size), types.IntValue(n) -> encode_int(n, size)
    Address, types.AddressValue(addr) -> encode_address(addr)
    Bool, types.BoolValue(b) -> Ok(encode_uint256(bool_to_int(b)))
    FixedBytes(size), types.FixedBytesValue(data) ->
      encode_fixed_bytes(data, size)
    Bytes, types.BytesValue(data) -> Ok(encode_dynamic_bytes(data))
    String, types.StringValue(s) ->
      Ok(encode_dynamic_bytes(bit_array.from_string(s)))
    Array(element_type), types.ArrayValue(elements) ->
      encode_dynamic_array(element_type, elements)
    FixedArray(element_type, _size), types.ArrayValue(elements) ->
      encode_fixed_array(element_type, elements)
    Tuple(element_types), types.TupleValue(values) ->
      encode_tuple_type(element_types, values)
    _, _ ->
      Error(types.EncodeError("Type/value mismatch: " <> types.to_string(t)))
  }
}

fn encode_uint(value: Int, bit_size: Int) -> Result(BitArray, AbiError) {
  let max = int.bitwise_shift_left(1, bit_size)
  case value >= 0 && value < max {
    True -> Ok(encode_uint256(value))
    False ->
      Error(types.EncodeError(
        "Value out of range for uint"
        <> int.to_string(bit_size)
        <> ": "
        <> int.to_string(value),
      ))
  }
}

fn encode_int(value: Int, bit_size: Int) -> Result(BitArray, AbiError) {
  let half = int.bitwise_shift_left(1, bit_size - 1)
  case value >= -half && value < half {
    True -> {
      // Two's complement: negative values become (2^256 + value)
      let unsigned = case value >= 0 {
        True -> value
        False -> int.bitwise_shift_left(1, 256) + value
      }
      Ok(encode_uint256(unsigned))
    }
    False ->
      Error(types.EncodeError(
        "Value out of range for int"
        <> int.to_string(bit_size)
        <> ": "
        <> int.to_string(value),
      ))
  }
}

fn encode_address(addr: String) -> Result(BitArray, AbiError) {
  let clean = hex.strip_prefix(addr)
  case string.length(clean) {
    40 -> {
      case hex.decode("0x" <> clean) {
        Ok(bytes) -> Ok(left_pad32(bytes))
        Error(_) -> Error(types.EncodeError("Invalid hex in address: " <> addr))
      }
    }
    _ -> Error(types.EncodeError("Address must be 20 bytes (40 hex chars)"))
  }
}

fn encode_fixed_bytes(data: BitArray, size: Int) -> Result(BitArray, AbiError) {
  case bit_array.byte_size(data) == size {
    True -> Ok(right_pad32(data))
    False ->
      Error(types.EncodeError(
        "Expected "
        <> int.to_string(size)
        <> " bytes, got "
        <> int.to_string(bit_array.byte_size(data)),
      ))
  }
}

fn encode_dynamic_bytes(data: BitArray) -> BitArray {
  let length = bit_array.byte_size(data)
  let length_slot = encode_uint256(length)
  let padded_data = right_pad_to_32(data)
  bit_array.concat([length_slot, padded_data])
}

fn encode_dynamic_array(
  element_type: AbiType,
  elements: List(AbiValue),
) -> Result(BitArray, AbiError) {
  let count = list.length(elements)
  let count_slot = encode_uint256(count)
  let pairs = list.map(elements, fn(v) { #(element_type, v) })
  use encoded <- result.try(encode_tuple_values(pairs))
  Ok(bit_array.concat([count_slot, encoded]))
}

fn encode_fixed_array(
  element_type: AbiType,
  elements: List(AbiValue),
) -> Result(BitArray, AbiError) {
  let pairs = list.map(elements, fn(v) { #(element_type, v) })
  encode_tuple_values(pairs)
}

fn encode_tuple_type(
  element_types: List(AbiType),
  values: List(AbiValue),
) -> Result(BitArray, AbiError) {
  case list.length(element_types) == list.length(values) {
    False -> Error(types.EncodeError("Tuple element count mismatch"))
    True -> {
      let pairs = list.zip(element_types, values)
      encode_tuple_values(pairs)
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn encode_uint256(value: Int) -> BitArray {
  // Encode as 32-byte big-endian unsigned integer
  int_to_bytes32(value)
}

/// Convert an integer to a 32-byte big-endian representation.
/// For values that fit, we use direct byte construction.
fn int_to_bytes32(value: Int) -> BitArray {
  // Build 32 bytes from the integer, big-endian
  build_bytes(value, 32, <<>>)
}

fn build_bytes(value: Int, remaining: Int, acc: BitArray) -> BitArray {
  case remaining {
    0 -> acc
    _ -> {
      // Extract byte at position (remaining - 1) from LSB
      let shift = { remaining - 1 } * 8
      let byte = int.bitwise_and(int.bitwise_shift_right(value, shift), 0xff)
      build_bytes(value, remaining - 1, <<acc:bits, byte:8>>)
    }
  }
}

fn bool_to_int(b: Bool) -> Int {
  case b {
    True -> 1
    False -> 0
  }
}

/// Left-pad data with zeros to 32 bytes.
fn left_pad32(data: BitArray) -> BitArray {
  let size = bit_array.byte_size(data)
  case size >= 32 {
    True -> data
    False -> {
      let padding = make_zero_bytes(32 - size)
      bit_array.concat([padding, data])
    }
  }
}

/// Right-pad data with zeros to 32 bytes.
fn right_pad32(data: BitArray) -> BitArray {
  let size = bit_array.byte_size(data)
  case size >= 32 {
    True -> data
    False -> {
      let padding = make_zero_bytes(32 - size)
      bit_array.concat([data, padding])
    }
  }
}

/// Right-pad data to next 32-byte boundary.
fn right_pad_to_32(data: BitArray) -> BitArray {
  let size = bit_array.byte_size(data)
  case size {
    0 -> <<>>
    _ -> {
      let remainder = size % 32
      case remainder {
        0 -> data
        _ -> {
          let padding = make_zero_bytes(32 - remainder)
          bit_array.concat([data, padding])
        }
      }
    }
  }
}

fn make_zero_bytes(n: Int) -> BitArray {
  make_zero_bytes_acc(n, <<>>)
}

fn make_zero_bytes_acc(n: Int, acc: BitArray) -> BitArray {
  case n <= 0 {
    True -> acc
    False -> make_zero_bytes_acc(n - 1, <<acc:bits, 0:8>>)
  }
}
