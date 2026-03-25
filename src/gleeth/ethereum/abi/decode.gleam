import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import gleeth/crypto/keccak
import gleeth/ethereum/abi/type_parser
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
import gleeth/ethereum/abi/json
import gleeth/utils/hex as hex_utils

// =============================================================================
// Calldata decoding
// =============================================================================

/// Result of decoding calldata against an ABI.
pub type DecodedCalldata {
  DecodedCalldata(function_name: String, arguments: List(AbiValue))
}

/// Decode calldata by matching the 4-byte selector against parsed ABI entries.
/// Returns the function name and decoded argument values.
pub fn decode_calldata(
  calldata_hex: String,
  entries: List(json.AbiEntry),
) -> Result(DecodedCalldata, AbiError) {
  use calldata_bytes <- result.try(
    hex_utils.decode(calldata_hex)
    |> result.map_error(fn(_) { types.DecodeError("Invalid calldata hex") }),
  )
  case calldata_bytes {
    <<selector:bits-size(32), params_data:bits>> -> {
      use #(name, param_types) <- result.try(match_selector(selector, entries))
      use values <- result.try(decode(param_types, params_data))
      Ok(DecodedCalldata(function_name: name, arguments: values))
    }
    _ -> Error(types.DecodeError("Calldata too short (need at least 4 bytes)"))
  }
}

/// Decode calldata given a function signature string like "transfer(address,uint256)".
/// Computes the selector from the signature and decodes the parameters.
pub fn decode_function_input(
  signature: String,
  calldata_hex: String,
) -> Result(List(AbiValue), AbiError) {
  use #(name, param_types) <- result.try(parse_function_signature(signature))
  use expected_selector <- result.try(compute_selector(name, param_types))
  use calldata_bytes <- result.try(
    hex_utils.decode(calldata_hex)
    |> result.map_error(fn(_) { types.DecodeError("Invalid calldata hex") }),
  )
  case calldata_bytes {
    <<actual_selector:bits-size(32), params_data:bits>> -> {
      case actual_selector == expected_selector {
        True -> decode(param_types, params_data)
        False ->
          Error(types.DecodeError(
            "Selector mismatch: expected "
            <> hex_utils.encode(expected_selector)
            <> ", got "
            <> hex_utils.encode(actual_selector),
          ))
      }
    }
    _ -> Error(types.DecodeError("Calldata too short (need at least 4 bytes)"))
  }
}

/// Decode the return value of a function given its output type signature.
/// For example: decode_function_output("(uint256)", result_hex)
pub fn decode_function_output(
  output_types_sig: String,
  result_hex: String,
) -> Result(List(AbiValue), AbiError) {
  use type_list <- result.try(parse_type_list(output_types_sig))
  use result_bytes <- result.try(
    hex_utils.decode(result_hex)
    |> result.map_error(fn(_) { types.DecodeError("Invalid result hex") }),
  )
  decode(type_list, result_bytes)
}

/// Decode the return value of a function using a parsed ABI entry.
/// Extracts output types from the FunctionEntry and decodes the hex data.
pub fn decode_outputs(
  function_entry: json.AbiEntry,
  result_hex: String,
) -> Result(List(AbiValue), AbiError) {
  let output_type_list = json.output_types(function_entry)
  use result_bytes <- result.try(
    hex_utils.decode(result_hex)
    |> result.map_error(fn(_) { types.DecodeError("Invalid result hex") }),
  )
  decode(output_type_list, result_bytes)
}

// =============================================================================
// Revert reason decoding
// =============================================================================

/// Result of decoding a revert reason.
pub type DecodedRevert {
  /// Standard Error(string) revert
  RevertString(String)
  /// Standard Panic(uint256) revert
  RevertPanic(Int)
  /// Custom error decoded against an ABI
  RevertCustomError(name: String, arguments: List(AbiValue))
  /// Unknown selector, raw data preserved
  RevertUnknown(BitArray)
}

/// Decode revert data. Handles standard Error(string) with selector 0x08c379a0,
/// Panic(uint256) with selector 0x4e487b71, and custom errors if an ABI is provided.
pub fn decode_revert(revert_hex: String) -> Result(DecodedRevert, AbiError) {
  decode_revert_with_abi(revert_hex, [])
}

/// Decode revert data, matching custom errors against provided ABI entries.
pub fn decode_revert_with_abi(
  revert_hex: String,
  entries: List(json.AbiEntry),
) -> Result(DecodedRevert, AbiError) {
  use revert_bytes <- result.try(
    hex_utils.decode(revert_hex)
    |> result.map_error(fn(_) { types.DecodeError("Invalid revert hex") }),
  )
  case revert_bytes {
    <<>> -> Ok(RevertUnknown(<<>>))
    <<0x08, 0xc3, 0x79, 0xa0, params:bits>> -> {
      // Error(string)
      use values <- result.try(decode([String], params))
      case values {
        [types.StringValue(msg)] -> Ok(RevertString(msg))
        _ -> Ok(RevertUnknown(revert_bytes))
      }
    }
    <<0x4e, 0x48, 0x7b, 0x71, params:bits>> -> {
      // Panic(uint256)
      use values <- result.try(decode([Uint(256)], params))
      case values {
        [types.UintValue(code)] -> Ok(RevertPanic(code))
        _ -> Ok(RevertUnknown(revert_bytes))
      }
    }
    <<_selector:bits-size(32), _rest:bits>> -> {
      // Try matching against custom error entries in ABI
      case entries {
        [] -> Ok(RevertUnknown(revert_bytes))
        _ -> decode_custom_revert(revert_bytes, entries)
      }
    }
    _ -> Ok(RevertUnknown(revert_bytes))
  }
}

fn decode_custom_revert(
  revert_bytes: BitArray,
  entries: List(json.AbiEntry),
) -> Result(DecodedRevert, AbiError) {
  let assert Ok(selector) = bit_array.slice(revert_bytes, 0, 4)
  let params_start = 4
  let data_len = bit_array.byte_size(revert_bytes) - params_start
  let assert Ok(params_data) =
    bit_array.slice(revert_bytes, params_start, data_len)

  // Try to match against error entries (reusing function matching logic)
  case match_selector(selector, entries) {
    Ok(#(name, param_types)) -> {
      use values <- result.try(decode(param_types, params_data))
      Ok(RevertCustomError(name: name, arguments: values))
    }
    Error(_) -> Ok(RevertUnknown(revert_bytes))
  }
}

// =============================================================================
// Internal helpers
// =============================================================================

/// Match a 4-byte selector against ABI entries.
fn match_selector(
  selector: BitArray,
  entries: List(json.AbiEntry),
) -> Result(#(String, List(AbiType)), AbiError) {
  case entries {
    [] ->
      Error(types.DecodeError(
        "No matching function for selector " <> hex_utils.encode(selector),
      ))
    [entry, ..rest] -> {
      case entry {
        json.FunctionEntry(name: name, inputs: inputs, ..) -> {
          let param_types = list.map(inputs, fn(p) { p.type_ })
          case compute_selector(name, param_types) {
            Ok(computed) if computed == selector -> Ok(#(name, param_types))
            _ -> match_selector(selector, rest)
          }
        }
        _ -> match_selector(selector, rest)
      }
    }
  }
}

/// Compute 4-byte selector from function name and parameter types.
fn compute_selector(
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
    Ok(sel) -> Ok(sel)
    Error(_) -> Error(types.DecodeError("Failed to compute selector"))
  }
}

/// Parse a function signature like "transfer(address,uint256)" into name + types.
fn parse_function_signature(
  signature: String,
) -> Result(#(String, List(AbiType)), AbiError) {
  case string.split_once(signature, "(") {
    Ok(#(name, rest)) -> {
      // rest is "address,uint256)" - need to strip trailing ")"
      let types_str = case string.ends_with(rest, ")") {
        True -> string.drop_end(rest, 1)
        False -> rest
      }
      case types_str {
        "" -> Ok(#(name, []))
        _ -> {
          use type_list <- result.try(parse_type_list(types_str))
          Ok(#(name, type_list))
        }
      }
    }
    Error(_) ->
      Error(types.DecodeError("Invalid function signature: " <> signature))
  }
}

/// Parse a comma-separated list of type strings.
fn parse_type_list(types_str: String) -> Result(List(AbiType), AbiError) {
  let type_strings = string.split(types_str, ",")
  list.try_map(type_strings, fn(s) { type_parser.parse(string.trim(s)) })
}
