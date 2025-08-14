import gleam/string
import gleeth/ethereum/contract
import gleeth/rpc/types
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Test parameter type parsing
pub fn parse_param_type_uint256_test() {
  let result = contract.parse_parameter("uint256:123456")

  case result {
    Ok(param) -> {
      should.equal(param.param_type, contract.UInt256)
      should.equal(param.value, "123456")
    }
    Error(_) -> should.be_true(False)
  }
}

pub fn parse_param_type_uint_alias_test() {
  let result = contract.parse_parameter("uint:789")

  case result {
    Ok(param) -> should.equal(param.param_type, contract.UInt256)
    Error(_) -> should.be_true(False)
  }
}

pub fn parse_param_type_address_test() {
  let result =
    contract.parse_parameter(
      "address:0x1234567890123456789012345678901234567890",
    )

  case result {
    Ok(param) -> should.equal(param.param_type, contract.Address)
    Error(_) -> should.be_true(False)
  }
}

pub fn parse_param_type_bool_test() {
  let result = contract.parse_parameter("bool:false")

  case result {
    Ok(param) -> should.equal(param.param_type, contract.Bool)
    Error(_) -> should.be_true(False)
  }
}

pub fn parse_param_type_boolean_alias_test() {
  let result = contract.parse_parameter("boolean:true")

  case result {
    Ok(param) -> should.equal(param.param_type, contract.Bool)
    Error(_) -> should.be_true(False)
  }
}

pub fn parse_param_type_bytes32_test() {
  let result =
    contract.parse_parameter(
      "bytes32:0x1234567890123456789012345678901234567890123456789012345678901234",
    )

  case result {
    Ok(param) -> should.equal(param.param_type, contract.Bytes32)
    Error(_) -> should.be_true(False)
  }
}

// Test parameter encoding functions
pub fn encode_uint256_small_number_test() {
  let param = contract.Parameter(contract.UInt256, "1000")
  let result = contract.encode_parameters([param])

  case result {
    Ok(encoded) -> {
      // Should be 64 characters (32 bytes) padded with zeros
      should.equal(string.length(encoded), 64)
      should.be_true(string.ends_with(encoded, "3e8"))
      // 1000 in hex
    }
    Error(_) -> should.be_true(False)
  }
}

pub fn encode_uint256_hex_input_test() {
  let param = contract.Parameter(contract.UInt256, "0x3e8")
  let result = contract.encode_parameters([param])

  case result {
    Ok(encoded) -> {
      should.equal(string.length(encoded), 64)
      should.be_true(string.ends_with(encoded, "3e8"))
    }
    Error(_) -> should.be_true(False)
  }
}

pub fn encode_address_with_0x_test() {
  let param =
    contract.Parameter(
      contract.Address,
      "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
    )
  let result = contract.encode_parameters([param])

  case result {
    Ok(encoded) -> {
      should.equal(string.length(encoded), 64)
      // Should pad address to 32 bytes (24 zeros + 20 byte address)
      should.be_true(string.starts_with(encoded, "000000000000000000000000"))
      should.be_true(string.ends_with(
        encoded,
        "742dbf0b6d9baa31b82bb5bcb6e0e1c7a5b30000",
      ))
    }
    Error(_) -> should.be_true(False)
  }
}

pub fn encode_address_without_0x_test() {
  let param =
    contract.Parameter(
      contract.Address,
      "742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
    )
  let result = contract.encode_parameters([param])

  case result {
    Ok(encoded) -> {
      should.equal(string.length(encoded), 64)
      should.be_true(string.ends_with(
        encoded,
        "742dbf0b6d9baa31b82bb5bcb6e0e1c7a5b30000",
      ))
    }
    Error(_) -> should.be_true(False)
  }
}

pub fn encode_bool_true_test() {
  let param = contract.Parameter(contract.Bool, "true")
  let result = contract.encode_parameters([param])

  case result {
    Ok(encoded) -> {
      should.equal(string.length(encoded), 64)
      should.be_true(string.ends_with(encoded, "1"))
    }
    Error(_) -> should.be_true(False)
  }
}

pub fn encode_bool_false_test() {
  let param = contract.Parameter(contract.Bool, "false")
  let result = contract.encode_parameters([param])

  case result {
    Ok(encoded) -> {
      should.equal(string.length(encoded), 64)
      should.be_true(string.ends_with(encoded, "0"))
    }
    Error(_) -> should.be_true(False)
  }
}

pub fn encode_bool_numeric_true_test() {
  let param = contract.Parameter(contract.Bool, "1")
  let result = contract.encode_parameters([param])

  case result {
    Ok(encoded) -> {
      should.equal(string.length(encoded), 64)
      should.be_true(string.ends_with(encoded, "1"))
    }
    Error(_) -> should.be_true(False)
  }
}

pub fn encode_bool_numeric_false_test() {
  let param = contract.Parameter(contract.Bool, "0")
  let result = contract.encode_parameters([param])

  case result {
    Ok(encoded) -> {
      should.equal(string.length(encoded), 64)
      should.be_true(string.ends_with(encoded, "0"))
    }
    Error(_) -> should.be_true(False)
  }
}

pub fn encode_bytes32_exact_length_test() {
  let param =
    contract.Parameter(
      contract.Bytes32,
      "0x1234567890123456789012345678901234567890123456789012345678901234",
    )
  let result = contract.encode_parameters([param])

  case result {
    Ok(encoded) -> {
      should.equal(string.length(encoded), 64)
      should.equal(
        encoded,
        "1234567890123456789012345678901234567890123456789012345678901234",
      )
    }
    Error(_) -> should.be_true(False)
  }
}

pub fn encode_bytes32_short_padded_test() {
  let param = contract.Parameter(contract.Bytes32, "0x1234")
  let result = contract.encode_parameters([param])

  case result {
    Ok(encoded) -> {
      should.equal(string.length(encoded), 64)
      should.be_true(string.starts_with(encoded, "1234"))
      should.be_true(string.ends_with(encoded, "0000"))
    }
    Error(_) -> should.be_true(False)
  }
}

// Test multiple parameter encoding
pub fn encode_multiple_parameters_test() {
  let params = [
    contract.Parameter(
      contract.Address,
      "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
    ),
    contract.Parameter(contract.UInt256, "1000"),
  ]
  let result = contract.encode_parameters(params)

  case result {
    Ok(encoded) -> {
      // Should be 128 characters (2 * 32 bytes)
      should.equal(string.length(encoded), 128)
    }
    Error(_) -> should.be_true(False)
  }
}

// Test function signature generation
pub fn generate_function_signature_no_params_test() {
  let result = contract.generate_function_selector("name", [])

  case result {
    Ok(selector) -> should.equal(selector, "0x06fdde03")
    // name()
    Error(_) -> should.be_true(False)
  }
}

pub fn generate_function_signature_single_param_test() {
  let result =
    contract.generate_function_selector("balanceOf", [contract.Address])

  case result {
    Ok(selector) -> should.equal(selector, "0x70a08231")
    // balanceOf(address)
    Error(_) -> should.be_true(False)
  }
}

pub fn generate_function_signature_multiple_params_test() {
  let result =
    contract.generate_function_selector("transfer", [
      contract.Address,
      contract.UInt256,
    ])

  case result {
    Ok(selector) -> should.equal(selector, "0xa9059cbb")
    // transfer(address,uint256)
    Error(_) -> should.be_true(False)
  }
}

// Test call data building
pub fn build_call_data_complete_test() {
  let contract_call =
    contract.ContractCall(function_name: "transfer", parameters: [
      contract.Parameter(
        contract.Address,
        "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
      ),
      contract.Parameter(contract.UInt256, "1000000000000000000"),
      // 1 ETH in wei
    ])

  let result = contract.build_call_data(contract_call)

  case result {
    Ok(call_data) -> {
      // Should start with transfer selector
      should.be_true(string.starts_with(call_data, "0xa9059cbb"))
      // Should be 138 characters (0x + 8 selector + 64 address + 64 amount)
      should.equal(string.length(call_data), 138)
    }
    Error(_) -> should.be_true(False)
  }
}

// Test error cases
pub fn parse_parameter_malformed_test() {
  let result = contract.parse_parameter("malformed")

  case result {
    Error(types.ParseError(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

pub fn parse_parameter_unsupported_type_test() {
  let result = contract.parse_parameter("unsupported:value")

  case result {
    Error(types.ParseError(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

pub fn encode_bool_invalid_value_test() {
  let param = contract.Parameter(contract.Bool, "maybe")
  let result = contract.encode_parameters([param])

  case result {
    Error(types.ParseError(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

pub fn encode_address_invalid_length_test() {
  let param = contract.Parameter(contract.Address, "0x123")
  // Too short
  let result = contract.encode_parameters([param])

  case result {
    Error(types.InvalidAddress(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

pub fn encode_bytes32_too_long_test() {
  let param =
    contract.Parameter(
      contract.Bytes32,
      "0x12345678901234567890123456789012345678901234567890123456789012345678",
    )
  // Too long
  let result = contract.encode_parameters([param])

  case result {
    Error(types.ParseError(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

pub fn generate_function_selector_unsupported_function_test() {
  let result = contract.generate_function_selector("unknownFunction", [])

  case result {
    Error(types.ParseError(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}
