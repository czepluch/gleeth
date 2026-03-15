import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleeth/ethereum/contract

import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex
import gleeth/utils/validation

// Execute a contract function call
pub fn execute(
  rpc_url: String,
  contract_address: String,
  function_call: String,
  parameters: List(String),
) -> Result(Nil, rpc_types.GleethError) {
  // Validate contract address
  use validated_address <- result.try(validation.validate_address(
    contract_address,
  ))

  // Parse parameters
  use parsed_params <- result.try(parse_parameters(parameters))

  // Build contract call
  let contract_call =
    contract.ContractCall(
      function_name: function_call,
      parameters: parsed_params,
    )

  // Generate call data
  use call_data <- result.try(contract.build_call_data(contract_call))

  // Make the contract call
  use response <- result.try(methods.call_contract(
    rpc_url,
    validated_address,
    call_data,
  ))

  // Display results
  print_contract_response(contract_address, function_call, parameters, response)
  Ok(Nil)
}

// Parse parameter strings into Parameter types
fn parse_parameters(
  param_strings: List(String),
) -> Result(List(contract.Parameter), rpc_types.GleethError) {
  list.try_map(param_strings, contract.parse_parameter)
}

// Print contract call response
fn print_contract_response(
  contract_address: String,
  function_name: String,
  parameters: List(String),
  response: String,
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

  // Try to decode common response types
  case decode_response(function_name, response) {
    Ok(decoded) -> io.println("  Decoded: " <> decoded)
    Error(_) -> Nil
  }
}

// Decode contract response based on function type
fn decode_response(
  function_name: String,
  response: String,
) -> Result(String, rpc_types.GleethError) {
  // Remove 0x prefix for processing
  let clean_response = case string.starts_with(response, "0x") {
    True -> string.drop_start(response, 2)
    False -> response
  }

  case function_name {
    // Functions that return uint256
    "balanceOf" | "totalSupply" | "allowance" | "decimals" -> {
      decode_uint256(clean_response)
    }

    // Functions that return addresses  
    "owner" | "token0" | "token1" -> {
      decode_address(clean_response)
    }

    // Functions that return strings (more complex, simplified for now)
    "name" | "symbol" -> {
      decode_string_simple(clean_response)
    }

    // Functions that return boolean
    "approve" | "transfer" -> {
      decode_bool(clean_response)
    }

    // Special cases
    "getReserves" -> {
      decode_reserves(clean_response)
    }

    _ ->
      Error(rpc_types.ParseError(
        "Unknown return type for function: " <> function_name,
      ))
  }
}

// Decode uint256 from response
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

// Decode address from response
fn decode_address(hex_data: String) -> Result(String, rpc_types.GleethError) {
  case string.length(hex_data) >= 64 {
    True -> {
      // Address is in the last 40 characters (20 bytes)
      let address_hex = string.slice(hex_data, 24, 40)
      Ok("0x" <> address_hex)
    }
    False -> Error(rpc_types.ParseError("Response too short for address"))
  }
}

// Decode boolean from response
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

// Simple string decoding (assumes ASCII, no dynamic length handling)
fn decode_string_simple(
  hex_data: String,
) -> Result(String, rpc_types.GleethError) {
  case string.length(hex_data) >= 64 {
    True -> {
      // For simplicity, just show hex for now
      // Proper string decoding requires handling dynamic length and UTF-8
      Ok(
        "0x" <> string.slice(hex_data, 0, 64) <> " (string decoding simplified)",
      )
    }
    False -> Error(rpc_types.ParseError("Response too short for string"))
  }
}

// Decode Uniswap-style getReserves() response
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
