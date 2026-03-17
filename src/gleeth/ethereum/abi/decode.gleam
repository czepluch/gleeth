import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import gleeth/ethereum/abi/types.{
  type AbiError, type AbiType, type AbiValue, Address, Array, Bool, Bytes,
  FixedArray, FixedBytes, Int, String, Tuple, Uint,
}

/// Decode ABI-encoded data given a list of expected types.
/// This is the top-level decoder for function return values or event data.
pub fn decode(
  type_list: List(AbiType),
  data: BitArray,
) -> Result(List(AbiValue), AbiError) {
  decode_tuple_at(type_list, data, 0)
}

/// Decode a single value of a known type from ABI-encoded data.
pub fn decode_single(
  type_: AbiType,
  data: BitArray,
) -> Result(AbiValue, AbiError) {
  use values <- result.try(decode([type_], data))
  case values {
    [value] -> Ok(value)
    _ -> Error(types.DecodeError("Expected exactly one value"))
  }
}

// ---------------------------------------------------------------------------
// Internal: tuple decoding
// ---------------------------------------------------------------------------

/// Decode a tuple from data starting at a given offset.
/// The tuple's head starts at `base_offset` within `data`.
fn decode_tuple_at(
  type_list: List(AbiType),
  data: BitArray,
  base_offset: Int,
) -> Result(List(AbiValue), AbiError) {
  // Walk through types, reading head slots and following offsets for dynamic types
  use #(values, _) <- result.try(
    list.try_fold(type_list, #([], base_offset), fn(acc, t) {
      let #(vals, head_pos) = acc
      let slot_size = types.head_size(t)
      case types.is_dynamic(t) {
        False -> {
          // Static: decode inline starting at head_pos
          use value <- result.try(decode_static_at(t, data, head_pos))
          Ok(#([value, ..vals], head_pos + slot_size))
        }
        True -> {
          // Dynamic: read 32-byte offset from head, decode at base_offset + offset
          use offset <- result.try(read_uint256_at(data, head_pos))
          let abs_offset = base_offset + offset
          use value <- result.try(decode_dynamic_at(t, data, abs_offset))
          Ok(#([value, ..vals], head_pos + 32))
        }
      }
    }),
  )
  Ok(list.reverse(values))
}

// ---------------------------------------------------------------------------
// Static type decoding
// ---------------------------------------------------------------------------

fn decode_static_at(
  t: AbiType,
  data: BitArray,
  offset: Int,
) -> Result(AbiValue, AbiError) {
  case t {
    Uint(size) -> decode_uint_at(data, offset, size)
    Int(size) -> decode_int_at(data, offset, size)
    Address -> decode_address_at(data, offset)
    Bool -> decode_bool_at(data, offset)
    FixedBytes(size) -> decode_fixed_bytes_at(data, offset, size)
    FixedArray(element_type, size) ->
      decode_static_fixed_array_at(element_type, size, data, offset)
    Tuple(element_types) -> {
      use values <- result.try(decode_tuple_at(element_types, data, offset))
      Ok(types.TupleValue(values))
    }
    // Dynamic types should not reach here
    _ -> Error(types.DecodeError("Expected static type, got dynamic"))
  }
}

fn decode_uint_at(
  data: BitArray,
  offset: Int,
  bit_size: Int,
) -> Result(AbiValue, AbiError) {
  use raw <- result.try(read_uint256_at(data, offset))
  // Mask to the declared bit width
  let mask = int.bitwise_shift_left(1, bit_size) - 1
  Ok(types.UintValue(int.bitwise_and(raw, mask)))
}

fn decode_int_at(
  data: BitArray,
  offset: Int,
  bit_size: Int,
) -> Result(AbiValue, AbiError) {
  use raw <- result.try(read_uint256_at(data, offset))
  // Mask to bit_size bits, then check sign bit
  let mask = int.bitwise_shift_left(1, bit_size) - 1
  let masked = int.bitwise_and(raw, mask)
  let sign_bit = int.bitwise_shift_left(1, bit_size - 1)
  let value = case int.bitwise_and(masked, sign_bit) != 0 {
    True -> masked - int.bitwise_shift_left(1, bit_size)
    False -> masked
  }
  Ok(types.IntValue(value))
}

fn decode_address_at(data: BitArray, offset: Int) -> Result(AbiValue, AbiError) {
  // Address is last 20 bytes of 32-byte slot
  use slot <- result.try(read_bytes_at(data, offset, 32))
  case bit_array.slice(slot, 12, 20) {
    Ok(addr_bytes) -> {
      let hex_str =
        "0x" <> string.lowercase(bit_array.base16_encode(addr_bytes))
      Ok(types.AddressValue(hex_str))
    }
    Error(_) -> Error(types.DecodeError("Failed to extract address bytes"))
  }
}

fn decode_bool_at(data: BitArray, offset: Int) -> Result(AbiValue, AbiError) {
  use raw <- result.try(read_uint256_at(data, offset))
  Ok(types.BoolValue(raw != 0))
}

fn decode_fixed_bytes_at(
  data: BitArray,
  offset: Int,
  size: Int,
) -> Result(AbiValue, AbiError) {
  // First `size` bytes of the 32-byte slot
  use slot <- result.try(read_bytes_at(data, offset, 32))
  case bit_array.slice(slot, 0, size) {
    Ok(bytes) -> Ok(types.FixedBytesValue(bytes))
    Error(_) -> Error(types.DecodeError("Failed to extract fixed bytes"))
  }
}

fn decode_static_fixed_array_at(
  element_type: AbiType,
  count: Int,
  data: BitArray,
  offset: Int,
) -> Result(AbiValue, AbiError) {
  // Create a list of the element type repeated `count` times
  let element_types = list.repeat(element_type, count)
  use values <- result.try(decode_tuple_at(element_types, data, offset))
  Ok(types.ArrayValue(values))
}

// ---------------------------------------------------------------------------
// Dynamic type decoding
// ---------------------------------------------------------------------------

fn decode_dynamic_at(
  t: AbiType,
  data: BitArray,
  offset: Int,
) -> Result(AbiValue, AbiError) {
  case t {
    Bytes -> decode_bytes_at(data, offset)
    String -> decode_string_at(data, offset)
    Array(element_type) -> decode_dynamic_array_at(element_type, data, offset)
    FixedArray(element_type, size) ->
      decode_dynamic_fixed_array_at(element_type, size, data, offset)
    Tuple(element_types) -> {
      use values <- result.try(decode_tuple_at(element_types, data, offset))
      Ok(types.TupleValue(values))
    }
    // Static types should not reach here
    _ -> Error(types.DecodeError("Expected dynamic type"))
  }
}

fn decode_bytes_at(data: BitArray, offset: Int) -> Result(AbiValue, AbiError) {
  use length <- result.try(read_uint256_at(data, offset))
  use bytes <- result.try(read_bytes_at(data, offset + 32, length))
  Ok(types.BytesValue(bytes))
}

fn decode_string_at(data: BitArray, offset: Int) -> Result(AbiValue, AbiError) {
  use length <- result.try(read_uint256_at(data, offset))
  use bytes <- result.try(read_bytes_at(data, offset + 32, length))
  case bit_array.to_string(bytes) {
    Ok(s) -> Ok(types.StringValue(s))
    Error(_) -> Error(types.DecodeError("Invalid UTF-8 in string"))
  }
}

fn decode_dynamic_array_at(
  element_type: AbiType,
  data: BitArray,
  offset: Int,
) -> Result(AbiValue, AbiError) {
  use count <- result.try(read_uint256_at(data, offset))
  let element_types = list.repeat(element_type, count)
  use values <- result.try(decode_tuple_at(element_types, data, offset + 32))
  Ok(types.ArrayValue(values))
}

fn decode_dynamic_fixed_array_at(
  element_type: AbiType,
  count: Int,
  data: BitArray,
  offset: Int,
) -> Result(AbiValue, AbiError) {
  let element_types = list.repeat(element_type, count)
  use values <- result.try(decode_tuple_at(element_types, data, offset))
  Ok(types.ArrayValue(values))
}

// ---------------------------------------------------------------------------
// Data reading helpers
// ---------------------------------------------------------------------------

/// Read 32 bytes at the given offset and interpret as a big-endian unsigned int.
fn read_uint256_at(data: BitArray, offset: Int) -> Result(Int, AbiError) {
  use slot <- result.try(read_bytes_at(data, offset, 32))
  Ok(bytes_to_uint(slot, 0, 0))
}

/// Read `length` bytes from data starting at offset.
fn read_bytes_at(
  data: BitArray,
  offset: Int,
  length: Int,
) -> Result(BitArray, AbiError) {
  case bit_array.slice(data, offset, length) {
    Ok(bytes) -> Ok(bytes)
    Error(_) ->
      Error(types.DecodeError(
        "Data too short: need "
        <> int.to_string(length)
        <> " bytes at offset "
        <> int.to_string(offset)
        <> ", have "
        <> int.to_string(bit_array.byte_size(data)),
      ))
  }
}

/// Convert a BitArray to an unsigned integer (big-endian).
fn bytes_to_uint(data: BitArray, index: Int, acc: Int) -> Int {
  case bit_array.slice(data, index, 1) {
    Ok(<<byte:8>>) ->
      bytes_to_uint(data, index + 1, int.bitwise_shift_left(acc, 8) + byte)
    _ -> acc
  }
}

// Need this import for address hex encoding
import gleam/string
