import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeth/ethereum/abi/encode as abi_encode
import gleeth/ethereum/abi/types as abi_types
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex

// Supported parameter types for contract calls (legacy API)
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

// Generate function selector using the ABI encoder
pub fn generate_function_selector(
  function_name: String,
  param_types: List(ParamType),
) -> Result(String, rpc_types.GleethError) {
  let abi_types = list.map(param_types, param_type_to_abi_type)
  case abi_encode.function_selector(function_name, abi_types) {
    Ok(selector) -> Ok(hex.encode(selector))
    Error(err) -> Error(abi_error_to_gleeth_error(err))
  }
}

// Encode parameters for contract call using the ABI encoder
pub fn encode_parameters(
  parameters: List(Parameter),
) -> Result(String, rpc_types.GleethError) {
  case parameters {
    [] -> Ok("")
    params -> {
      use abi_pairs <- result.try(
        list.try_map(params, param_to_abi_pair)
        |> result.map_error(fn(e) { abi_error_to_gleeth_error(e) }),
      )
      case abi_encode.encode(abi_pairs) {
        Ok(encoded) -> Ok(string.lowercase(bit_array.base16_encode(encoded)))
        Error(err) -> Error(abi_error_to_gleeth_error(err))
      }
    }
  }
}

// Build complete call data (function selector + encoded parameters)
pub fn build_call_data(
  contract_call: ContractCall,
) -> Result(String, rpc_types.GleethError) {
  let abi_type_list =
    list.map(contract_call.parameters, fn(p) {
      param_type_to_abi_type(p.param_type)
    })

  use abi_pairs <- result.try(
    list.try_map(contract_call.parameters, param_to_abi_pair)
    |> result.map_error(fn(e) { abi_error_to_gleeth_error(e) }),
  )

  case
    abi_encode.function_selector(contract_call.function_name, abi_type_list)
  {
    Ok(selector) -> {
      case abi_pairs {
        [] -> Ok(hex.encode(selector))
        _ -> {
          case abi_encode.encode(abi_pairs) {
            Ok(encoded) -> {
              let selector_hex =
                string.lowercase(bit_array.base16_encode(selector))
              let params_hex =
                string.lowercase(bit_array.base16_encode(encoded))
              Ok("0x" <> selector_hex <> params_hex)
            }
            Error(err) -> Error(abi_error_to_gleeth_error(err))
          }
        }
      }
    }
    Error(err) -> Error(abi_error_to_gleeth_error(err))
  }
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

// ---------------------------------------------------------------------------
// Internal: conversion between legacy ParamType and new ABI types
// ---------------------------------------------------------------------------

fn param_type_to_abi_type(param_type: ParamType) -> abi_types.AbiType {
  case param_type {
    UInt256 -> abi_types.Uint(256)
    Address -> abi_types.Address
    String -> abi_types.String
    Bool -> abi_types.Bool
    Bytes32 -> abi_types.FixedBytes(32)
  }
}

fn param_to_abi_pair(
  param: Parameter,
) -> Result(#(abi_types.AbiType, abi_types.AbiValue), abi_types.AbiError) {
  let abi_type = param_type_to_abi_type(param.param_type)
  use abi_value <- result.try(string_to_abi_value(param.param_type, param.value))
  Ok(#(abi_type, abi_value))
}

fn string_to_abi_value(
  param_type: ParamType,
  value: String,
) -> Result(abi_types.AbiValue, abi_types.AbiError) {
  case param_type {
    UInt256 -> parse_uint_value(value)
    Address -> Ok(abi_types.AddressValue(value))
    String -> Ok(abi_types.StringValue(value))
    Bool -> parse_bool_value(value)
    Bytes32 -> parse_bytes32_value(value)
  }
}

fn parse_uint_value(
  value: String,
) -> Result(abi_types.AbiValue, abi_types.AbiError) {
  // Try decimal first, then hex
  case int.parse(value) {
    Ok(n) -> Ok(abi_types.UintValue(n))
    Error(_) -> {
      case hex.to_int(value) {
        Ok(n) -> Ok(abi_types.UintValue(n))
        Error(_) ->
          Error(abi_types.EncodeError("Cannot parse uint value: " <> value))
      }
    }
  }
}

fn parse_bool_value(
  value: String,
) -> Result(abi_types.AbiValue, abi_types.AbiError) {
  case string.lowercase(value) {
    "true" | "1" -> Ok(abi_types.BoolValue(True))
    "false" | "0" -> Ok(abi_types.BoolValue(False))
    _ ->
      Error(abi_types.EncodeError(
        "Boolean must be 'true', 'false', '1', or '0'",
      ))
  }
}

fn parse_bytes32_value(
  value: String,
) -> Result(abi_types.AbiValue, abi_types.AbiError) {
  case hex.decode(value) {
    Ok(bytes) -> {
      let size = bit_array.byte_size(bytes)
      case size <= 32 {
        True -> {
          // Right-pad to exactly 32 bytes
          let padding = make_zero_bytes(32 - size)
          Ok(abi_types.FixedBytesValue(bit_array.concat([bytes, padding])))
        }
        False -> Error(abi_types.EncodeError("bytes32 value too long"))
      }
    }
    Error(_) ->
      Error(abi_types.EncodeError("Invalid hex for bytes32: " <> value))
  }
}

fn make_zero_bytes(n: Int) -> BitArray {
  case n <= 0 {
    True -> <<>>
    False -> make_zero_bytes_acc(n, <<>>)
  }
}

fn make_zero_bytes_acc(n: Int, acc: BitArray) -> BitArray {
  case n <= 0 {
    True -> acc
    False -> make_zero_bytes_acc(n - 1, <<acc:bits, 0:8>>)
  }
}

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

fn abi_error_to_gleeth_error(err: abi_types.AbiError) -> rpc_types.GleethError {
  rpc_types.AbiErr(err)
}
