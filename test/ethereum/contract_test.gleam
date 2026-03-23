import gleam/string
import gleeth/ethereum/abi/types as abi_types
import gleeth/ethereum/contract
import gleeth/rpc/types
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

/// Test parameter parsing
pub fn parse_parameter_test() {
  let result = contract.parse_parameter("uint256:123456")

  case result {
    Ok(#(abi_type, abi_value)) -> {
      should.equal(abi_type, abi_types.Uint(256))
      should.equal(abi_value, abi_types.UintValue(123_456))
    }
    Error(_) -> should.fail()
  }
}

/// Test parameter encoding
pub fn encode_parameters_test() {
  let param = #(abi_types.Uint(256), abi_types.UintValue(1000))
  let result = contract.encode_parameters([param])

  case result {
    Ok(encoded) -> {
      should.equal(string.length(encoded), 64)
    }
    Error(_) -> should.fail()
  }
}

/// Test function selector generation
pub fn generate_function_selector_test() {
  let result =
    contract.generate_function_selector("balanceOf", [abi_types.Address])

  case result {
    Ok(selector) -> should.equal(selector, "0x70a08231")
    Error(_) -> should.fail()
  }
}

/// Test call data building
pub fn build_call_data_test() {
  let result =
    contract.build_call_data("transfer", [
      #(
        abi_types.Address,
        abi_types.AddressValue("0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000"),
      ),
      #(abi_types.Uint(256), abi_types.UintValue(1_000_000_000_000_000_000)),
    ])

  case result {
    Ok(call_data) -> {
      should.be_true(string.starts_with(call_data, "0xa9059cbb"))
    }
    Error(_) -> should.fail()
  }
}

/// Test error handling
pub fn parse_parameter_error_test() {
  let result = contract.parse_parameter("malformed")

  case result {
    Error(types.ParseError(_)) -> Nil
    _ -> should.fail()
  }
}
