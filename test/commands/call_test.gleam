import gleam/string
import gleeth/ethereum/contract
import gleeth/rpc/types
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Test parameter parsing
pub fn parse_parameter_uint256_test() {
  let result = contract.parse_parameter("uint256:1000")

  case result {
    Ok(param) -> {
      should.equal(param.param_type, contract.UInt256)
      should.equal(param.value, "1000")
    }
    Error(_) -> should.be_true(False)
  }
}

pub fn parse_parameter_address_test() {
  let result =
    contract.parse_parameter(
      "address:0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
    )

  case result {
    Ok(param) -> {
      should.equal(param.param_type, contract.Address)
      should.equal(param.value, "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000")
    }
    Error(_) -> should.be_true(False)
  }
}

pub fn parse_parameter_bool_test() {
  let result = contract.parse_parameter("bool:true")

  case result {
    Ok(param) -> {
      should.equal(param.param_type, contract.Bool)
      should.equal(param.value, "true")
    }
    Error(_) -> should.be_true(False)
  }
}

// Test function selector generation
pub fn generate_function_selector_total_supply_test() {
  let result = contract.generate_function_selector("totalSupply", [])

  case result {
    Ok(selector) -> should.equal(selector, "0x18160ddd")
    Error(_) -> should.be_true(False)
  }
}

pub fn generate_function_selector_balance_of_test() {
  let result =
    contract.generate_function_selector("balanceOf", [contract.Address])

  case result {
    Ok(selector) -> should.equal(selector, "0x70a08231")
    Error(_) -> should.be_true(False)
  }
}

// Test parameter encoding with a more realistic function
pub fn encode_uint256_test() {
  let param = contract.Parameter(contract.UInt256, "1000")
  let contract_call =
    contract.ContractCall("approve", [
      contract.Parameter(
        contract.Address,
        "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
      ),
      param,
    ])

  let result = contract.build_call_data(contract_call)

  case result {
    Ok(call_data) -> {
      // Should start with approve selector
      should.be_true(string.starts_with(call_data, "0x095ea7b3"))
      // Should be 138 characters (0x + 8 selector + 64 address + 64 amount)
      should.equal(string.length(call_data), 138)
    }
    Error(_) -> should.be_true(False)
  }
}

pub fn encode_address_test() {
  let param =
    contract.Parameter(
      contract.Address,
      "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
    )
  let contract_call = contract.ContractCall("balanceOf", [param])

  let result = contract.build_call_data(contract_call)

  case result {
    Ok(call_data) -> {
      // Should start with balanceOf selector
      should.be_true(string.starts_with(call_data, "0x70a08231"))
      // Should be 74 characters (0x + 8 selector + 64 parameter)
      should.equal(string.length(call_data), 74)
    }
    Error(_) -> should.be_true(False)
  }
}

// Test no parameters call
pub fn build_call_data_no_params_test() {
  let contract_call = contract.ContractCall("totalSupply", [])

  let result = contract.build_call_data(contract_call)

  case result {
    Ok(call_data) -> {
      // Should be exactly the function selector
      should.equal(call_data, "0x18160ddd")
    }
    Error(_) -> should.be_true(False)
  }
}

// Test error cases
pub fn parse_parameter_invalid_format_test() {
  let result = contract.parse_parameter("invalid_format")

  case result {
    Error(types.ParseError(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

pub fn generate_function_selector_unsupported_test() {
  let result = contract.generate_function_selector("unknownFunction", [])

  case result {
    Error(types.ParseError(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}
