import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeth/crypto/keccak

import gleeth/rpc/types as rpc_types
import gleeth/utils/hex

// Supported parameter types for contract calls
pub type ParamType {
  UInt256
  Address
  String
  Bool
  Bytes32
}

// Parameter with type and value
pub type Parameter {
  Parameter(param_type: ParamType, value: String)
}

// Contract function call data
pub type ContractCall {
  ContractCall(function_name: String, parameters: List(Parameter))
}

// Generate function selector using dynamic keccak256 hashing
pub fn generate_function_selector(
  function_name: String,
  param_types: List(ParamType),
) -> Result(String, rpc_types.GleethError) {
  let signature = generate_function_signature(function_name, param_types)

  // Use our keccak implementation to generate the selector
  case keccak.function_selector(signature) {
    Ok(selector) -> Ok(selector)
    Error(msg) -> Error(rpc_types.ParseError(msg))
  }
}

// Generate function signature string
fn generate_function_signature(
  function_name: String,
  param_types: List(ParamType),
) -> String {
  let type_strings = list.map(param_types, param_type_to_string)
  let params_str = string.join(type_strings, ",")
  function_name <> "(" <> params_str <> ")"
}

// Convert parameter type to ABI string
fn param_type_to_string(param_type: ParamType) -> String {
  case param_type {
    UInt256 -> "uint256"
    Address -> "address"
    String -> "string"
    Bool -> "bool"
    Bytes32 -> "bytes32"
  }
}

// Encode parameters for contract call
pub fn encode_parameters(
  parameters: List(Parameter),
) -> Result(String, rpc_types.GleethError) {
  case parameters {
    [] -> Ok("")
    params -> {
      use encoded_params <- result.try(list.try_map(
        params,
        encode_single_parameter,
      ))
      Ok(string.concat(encoded_params))
    }
  }
}

// Encode a single parameter
fn encode_single_parameter(
  parameter: Parameter,
) -> Result(String, rpc_types.GleethError) {
  case parameter.param_type {
    UInt256 -> encode_uint256(parameter.value)
    Address -> encode_address(parameter.value)
    Bool -> encode_bool(parameter.value)
    Bytes32 -> encode_bytes32(parameter.value)
    String -> Error(rpc_types.ParseError("String encoding not yet implemented"))
  }
}

// Encode uint256 parameter (pad to 32 bytes)
fn encode_uint256(value: String) -> Result(String, rpc_types.GleethError) {
  // Handle hex values vs decimal
  let hex_value = case hex.strip_prefix(value) {
    clean_hex if clean_hex == value -> {
      // No 0x prefix, could be decimal
      case int.parse(value) {
        Ok(int_val) -> int_to_hex(int_val)
        Error(_) -> value
        // Assume it's already hex without 0x prefix
      }
    }
    clean_hex -> clean_hex
  }

  // Pad to 64 hex characters (32 bytes)
  let padded = string.pad_start(hex_value, 64, "0")
  Ok(padded)
}

// Encode address parameter (pad to 32 bytes)
fn encode_address(value: String) -> Result(String, rpc_types.GleethError) {
  let clean_address = hex.strip_prefix(value)

  // Validate address length
  case string.length(clean_address) {
    40 -> {
      // Pad address to 32 bytes (24 zeros + 20 bytes address)
      // Convert to lowercase for consistency
      let lowercase_address = string.lowercase(clean_address)
      let padded = string.pad_start(lowercase_address, 64, "0")
      Ok(padded)
    }
    _ -> Error(rpc_types.InvalidAddress("Address must be 40 hex characters"))
  }
}

// Encode boolean parameter
fn encode_bool(value: String) -> Result(String, rpc_types.GleethError) {
  case string.lowercase(value) {
    "true" | "1" -> Ok(string.pad_start("1", 64, "0"))
    "false" | "0" -> Ok(string.pad_start("0", 64, "0"))
    _ ->
      Error(rpc_types.ParseError("Boolean must be 'true', 'false', '1', or '0'"))
  }
}

// Encode bytes32 parameter
fn encode_bytes32(value: String) -> Result(String, rpc_types.GleethError) {
  let clean_value = hex.strip_prefix(value)

  case string.length(clean_value) {
    64 -> Ok(clean_value)
    len if len < 64 -> Ok(string.pad_end(clean_value, 64, "0"))
    _ -> Error(rpc_types.ParseError("bytes32 value too long"))
  }
}

// Build complete call data (function selector + encoded parameters)
pub fn build_call_data(
  contract_call: ContractCall,
) -> Result(String, rpc_types.GleethError) {
  let param_types = list.map(contract_call.parameters, fn(p) { p.param_type })

  use selector <- result.try(generate_function_selector(
    contract_call.function_name,
    param_types,
  ))

  use encoded_params <- result.try(encode_parameters(contract_call.parameters))

  // Remove 0x prefix from selector for concatenation
  let clean_selector = hex.strip_prefix(selector)

  Ok(hex.ensure_prefix(clean_selector <> encoded_params))
}

// Parse parameter string into Parameter type
// Format: "type:value" e.g., "address:0x1234..." or "uint256:1000"
pub fn parse_parameter(
  param_str: String,
) -> Result(Parameter, rpc_types.GleethError) {
  case string.split(param_str, ":") {
    [type_str, value] -> {
      use param_type <- result.try(parse_param_type(type_str))
      Ok(Parameter(param_type: param_type, value: value))
    }
    _ -> Error(rpc_types.ParseError("Parameter must be in format 'type:value'"))
  }
}

// Parse parameter type from string
fn parse_param_type(
  type_str: String,
) -> Result(ParamType, rpc_types.GleethError) {
  case string.lowercase(type_str) {
    "uint256" | "uint" -> Ok(UInt256)
    "address" -> Ok(Address)
    "string" -> Ok(String)
    "bool" | "boolean" -> Ok(Bool)
    "bytes32" -> Ok(Bytes32)
    _ -> Error(rpc_types.ParseError("Unsupported parameter type: " <> type_str))
  }
}

// Helper function to convert integer to hex string
fn int_to_hex(value: Int) -> String {
  int_to_hex_recursive(value, "")
}

// Recursive helper for int to hex conversion
fn int_to_hex_recursive(value: Int, acc: String) -> String {
  case value {
    0 ->
      case acc {
        "" -> "0"
        _ -> acc
      }
    _ -> {
      let remainder = value % 16
      let quotient = value / 16
      let hex_char = case remainder {
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
      int_to_hex_recursive(quotient, hex_char <> acc)
    }
  }
}
