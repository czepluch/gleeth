import gleam/bit_array
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleeth/ethereum/abi/decode as abi_decode
import gleeth/ethereum/abi/json as abi_json
import gleeth/ethereum/abi/types as abi_types
import gleeth/ethereum/contract
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex
import gleeth/utils/validation
import simplifile

// Execute a contract function call
pub fn execute(
  provider: Provider,
  contract_address: String,
  function_call: String,
  parameters: List(String),
  abi_file: Option(String),
) -> Result(Nil, rpc_types.GleethError) {
  // Validate contract address
  use validated_address <- result.try(validation.validate_address(
    contract_address,
  ))

  // Parse parameters
  use parsed_params <- result.try(parse_parameters(parameters))

  // Generate call data
  use call_data <- result.try(contract.build_call_data(
    function_call,
    parsed_params,
  ))

  // Make the contract call
  use response <- result.try(methods.call_contract(
    provider,
    validated_address,
    call_data,
  ))

  // Display results
  print_contract_response(
    contract_address,
    function_call,
    parameters,
    response,
    abi_file,
  )
  Ok(Nil)
}

// Parse parameter strings into ABI type/value pairs
fn parse_parameters(
  param_strings: List(String),
) -> Result(
  List(#(abi_types.AbiType, abi_types.AbiValue)),
  rpc_types.GleethError,
) {
  list.try_map(param_strings, contract.parse_parameter)
}

// Print contract call response
fn print_contract_response(
  contract_address: String,
  function_name: String,
  parameters: List(String),
  response: String,
  abi_file: Option(String),
) -> Nil {
  io.println("Contract Call Results:")
  io.println("  Contract: " <> contract_address)
  io.println("  Function: " <> function_name <> "()")

  case parameters {
    [] -> Nil
    params -> {
      io.println("  Parameters:")
      list.each(params, fn(param) { io.println("    " <> param) })
    }
  }

  io.println("  Raw Response: " <> response)

  // Try ABI-based decoding first, then fall back to heuristic
  case abi_file {
    Some(file) -> {
      case decode_with_abi(file, function_name, response) {
        Ok(decoded) -> io.println("  Decoded: " <> decoded)
        Error(err) -> {
          io.println("  ABI decode failed: " <> abi_error_message(err))
          // Fall back to heuristic
          case decode_response(function_name, response) {
            Ok(decoded) -> io.println("  Decoded (heuristic): " <> decoded)
            Error(_) -> Nil
          }
        }
      }
    }
    None -> {
      case decode_response(function_name, response) {
        Ok(decoded) -> io.println("  Decoded: " <> decoded)
        Error(_) -> Nil
      }
    }
  }
}

// ---------------------------------------------------------------------------
// ABI-based decoding
// ---------------------------------------------------------------------------

fn decode_with_abi(
  abi_file: String,
  function_name: String,
  response: String,
) -> Result(String, abi_types.AbiError) {
  // Read ABI file
  use abi_json_str <- result.try(
    simplifile.read(abi_file)
    |> result.map_error(fn(_) {
      abi_types.InvalidAbiJson("Cannot read ABI file: " <> abi_file)
    }),
  )

  // Parse ABI
  use entries <- result.try(abi_json.parse_abi(abi_json_str))

  // Find the function
  use entry <- result.try(abi_json.find_function(entries, function_name))

  let output_types = abi_json.output_types(entry)

  case output_types {
    [] -> Ok("(void)")
    _ -> {
      // Decode the response hex
      use data <- result.try(
        hex.decode(response)
        |> result.map_error(fn(_) {
          abi_types.DecodeError("Invalid hex in response")
        }),
      )
      use values <- result.try(abi_decode.decode(output_types, data))
      Ok(format_abi_values(output_types, values))
    }
  }
}

fn format_abi_values(
  types: List(abi_types.AbiType),
  values: List(abi_types.AbiValue),
) -> String {
  let pairs = list.zip(types, values)
  let formatted =
    list.map(pairs, fn(pair) {
      let #(t, v) = pair
      format_single_value(t, v)
    })
  case formatted {
    [single] -> single
    multiple -> "(" <> string.join(multiple, ", ") <> ")"
  }
}

fn format_single_value(t: abi_types.AbiType, v: abi_types.AbiValue) -> String {
  case t, v {
    abi_types.Uint(_), abi_types.UintValue(n) -> int.to_string(n)
    abi_types.Int(_), abi_types.IntValue(n) -> int.to_string(n)
    abi_types.Address, abi_types.AddressValue(addr) -> addr
    abi_types.Bool, abi_types.BoolValue(b) ->
      case b {
        True -> "true"
        False -> "false"
      }
    abi_types.FixedBytes(size), abi_types.FixedBytesValue(data) ->
      "0x"
      <> string.lowercase(bit_array.base16_encode(data))
      |> string.slice(0, 2 + size * 2)
    abi_types.Bytes, abi_types.BytesValue(data) ->
      "0x" <> string.lowercase(bit_array.base16_encode(data))
    abi_types.String, abi_types.StringValue(s) -> "\"" <> s <> "\""
    abi_types.Array(element_type), abi_types.ArrayValue(elements) -> {
      let inner =
        list.map(elements, fn(el) { format_single_value(element_type, el) })
      "[" <> string.join(inner, ", ") <> "]"
    }
    abi_types.Tuple(element_types), abi_types.TupleValue(vals) ->
      format_abi_values(element_types, vals)
    _, _ -> "<unknown>"
  }
}

fn abi_error_message(err: abi_types.AbiError) -> String {
  case err {
    abi_types.EncodeError(msg) -> msg
    abi_types.DecodeError(msg) -> msg
    abi_types.TypeParseError(msg) -> msg
    abi_types.InvalidAbiJson(msg) -> msg
  }
}

// ---------------------------------------------------------------------------
// Heuristic decoding (fallback when no ABI is provided)
// ---------------------------------------------------------------------------

fn decode_response(
  function_name: String,
  response: String,
) -> Result(String, rpc_types.GleethError) {
  let clean_response = hex.strip_prefix(response)

  case function_name {
    "balanceOf" | "totalSupply" | "allowance" | "decimals" ->
      decode_uint256(clean_response)
    "owner" | "token0" | "token1" -> decode_address(clean_response)
    "name" | "symbol" -> decode_string_abi(clean_response)
    "approve" | "transfer" -> decode_bool(clean_response)
    "getReserves" -> decode_reserves(clean_response)
    _ ->
      Error(rpc_types.ParseError(
        "Unknown return type for function: " <> function_name,
      ))
  }
}

fn decode_uint256(hex_data: String) -> Result(String, rpc_types.GleethError) {
  case string.length(hex_data) >= 64 {
    True -> {
      let value_hex = string.slice(hex_data, 0, 64)
      case hex.hex_to_int(value_hex) {
        Ok(int_value) ->
          Ok(string.concat([int.to_string(int_value), " (0x", value_hex, ")"]))
        Error(_) -> Ok("0x" <> value_hex)
      }
    }
    False -> Error(rpc_types.ParseError("Response too short for uint256"))
  }
}

fn decode_address(hex_data: String) -> Result(String, rpc_types.GleethError) {
  case string.length(hex_data) >= 64 {
    True -> {
      let address_hex = string.slice(hex_data, 24, 40)
      Ok("0x" <> address_hex)
    }
    False -> Error(rpc_types.ParseError("Response too short for address"))
  }
}

fn decode_bool(hex_data: String) -> Result(String, rpc_types.GleethError) {
  case string.length(hex_data) >= 64 {
    True -> {
      let value_hex = string.slice(hex_data, 63, 1)
      case value_hex {
        "0" -> Ok("false")
        "1" -> Ok("true")
        _ -> Ok("0x" <> string.slice(hex_data, 0, 64))
      }
    }
    False -> Error(rpc_types.ParseError("Response too short for boolean"))
  }
}

fn decode_string_abi(hex_data: String) -> Result(String, rpc_types.GleethError) {
  // Try proper ABI string decoding: offset + length + data
  case string.length(hex_data) >= 192 {
    True -> {
      // Read length from second slot
      let length_hex = string.slice(hex_data, 64, 64)
      case hex.hex_to_int(length_hex) {
        Ok(length) -> {
          // Read string data starting at third slot
          let data_hex = string.slice(hex_data, 128, length * 2)
          case hex.decode("0x" <> data_hex) {
            Ok(bytes) -> {
              case bit_array.to_string(bytes) {
                Ok(s) -> Ok("\"" <> s <> "\"")
                Error(_) -> Ok("0x" <> data_hex <> " (non-UTF-8)")
              }
            }
            Error(_) -> Ok("0x" <> string.slice(hex_data, 0, 64))
          }
        }
        Error(_) -> Ok("0x" <> string.slice(hex_data, 0, 64))
      }
    }
    False -> {
      case string.length(hex_data) >= 64 {
        True -> Ok("0x" <> string.slice(hex_data, 0, 64))
        False -> Error(rpc_types.ParseError("Response too short for string"))
      }
    }
  }
}

fn decode_reserves(hex_data: String) -> Result(String, rpc_types.GleethError) {
  case string.length(hex_data) >= 192 {
    True -> {
      let reserve0_hex = string.slice(hex_data, 0, 64)
      let reserve1_hex = string.slice(hex_data, 64, 64)
      let timestamp_hex = string.slice(hex_data, 128, 64)

      case
        hex.hex_to_int(reserve0_hex),
        hex.hex_to_int(reserve1_hex),
        hex.hex_to_int(timestamp_hex)
      {
        Ok(r0), Ok(r1), Ok(ts) -> {
          Ok(
            "Reserve0: "
            <> int.to_string(r0)
            <> ", Reserve1: "
            <> int.to_string(r1)
            <> ", Timestamp: "
            <> int.to_string(ts),
          )
        }
        _, _, _ -> Ok("0x" <> hex_data)
      }
    }
    False -> Error(rpc_types.ParseError("Response too short for reserves"))
  }
}
