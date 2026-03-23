import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeth/ethereum/abi/encode as abi_encode
import gleeth/ethereum/abi/types as abi_types
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex

// Generate function selector using the ABI encoder
pub fn generate_function_selector(
  function_name: String,
  param_types: List(abi_types.AbiType),
) -> Result(String, rpc_types.GleethError) {
  case abi_encode.function_selector(function_name, param_types) {
    Ok(selector) -> Ok(hex.encode(selector))
    Error(err) -> Error(abi_error_to_gleeth_error(err))
  }
}

// Encode parameters for contract call using the ABI encoder
pub fn encode_parameters(
  parameters: List(#(abi_types.AbiType, abi_types.AbiValue)),
) -> Result(String, rpc_types.GleethError) {
  case parameters {
    [] -> Ok("")
    params -> {
      case abi_encode.encode(params) {
        Ok(encoded) -> Ok(string.lowercase(bit_array.base16_encode(encoded)))
        Error(err) -> Error(abi_error_to_gleeth_error(err))
      }
    }
  }
}

// Build complete call data (function selector + encoded parameters)
pub fn build_call_data(
  function_name: String,
  parameters: List(#(abi_types.AbiType, abi_types.AbiValue)),
) -> Result(String, rpc_types.GleethError) {
  let abi_type_list = list.map(parameters, fn(p) { p.0 })

  case abi_encode.function_selector(function_name, abi_type_list) {
    Ok(selector) -> {
      case parameters {
        [] -> Ok(hex.encode(selector))
        _ -> {
          case abi_encode.encode(parameters) {
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

// Parse parameter string into an ABI type/value pair
// Format: "type:value" e.g., "address:0x1234..." or "uint256:1000"
pub fn parse_parameter(
  param_str: String,
) -> Result(#(abi_types.AbiType, abi_types.AbiValue), rpc_types.GleethError) {
  case string.split(param_str, ":") {
    [type_str, value] -> {
      use abi_type <- result.try(parse_abi_type(type_str))
      use abi_value <- result.try(
        string_to_abi_value(abi_type, value)
        |> result.map_error(fn(e) { abi_error_to_gleeth_error(e) }),
      )
      Ok(#(abi_type, abi_value))
    }
    _ -> Error(rpc_types.ParseError("Parameter must be in format 'type:value'"))
  }
}

// ---------------------------------------------------------------------------
// Internal: parsing and conversion helpers
// ---------------------------------------------------------------------------

fn parse_abi_type(
  type_str: String,
) -> Result(abi_types.AbiType, rpc_types.GleethError) {
  case string.lowercase(type_str) {
    "uint256" | "uint" -> Ok(abi_types.Uint(256))
    "address" -> Ok(abi_types.Address)
    "string" -> Ok(abi_types.String)
    "bool" | "boolean" -> Ok(abi_types.Bool)
    "bytes32" -> Ok(abi_types.FixedBytes(32))
    _ -> Error(rpc_types.ParseError("Unsupported parameter type: " <> type_str))
  }
}

fn string_to_abi_value(
  abi_type: abi_types.AbiType,
  value: String,
) -> Result(abi_types.AbiValue, abi_types.AbiError) {
  case abi_type {
    abi_types.Uint(_) -> parse_uint_value(value)
    abi_types.Address -> Ok(abi_types.AddressValue(value))
    abi_types.String -> Ok(abi_types.StringValue(value))
    abi_types.Bool -> parse_bool_value(value)
    abi_types.FixedBytes(_) -> parse_bytes32_value(value)
    _ ->
      Error(abi_types.EncodeError(
        "Unsupported ABI type for CLI parsing: "
        <> abi_types.to_string(abi_type),
      ))
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

fn abi_error_to_gleeth_error(err: abi_types.AbiError) -> rpc_types.GleethError {
  rpc_types.AbiErr(err)
}
