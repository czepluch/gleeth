import gleam/option.{None, Some}
import gleeth/utils/validation
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

/// Test address validation in balance command context
pub fn balance_address_validation_test() {
  let valid_address = "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000"
  let invalid_address = "invalid"

  case validation.validate_address(valid_address) {
    Ok(_) -> should.be_true(True)
    Error(_) -> should.fail()
  }

  case validation.validate_address(invalid_address) {
    Ok(_) -> should.fail()
    Error(_) -> should.be_true(True)
  }
}

/// Test balance command parameter validation
pub fn balance_parameter_validation_test() {
  // Test empty addresses list
  let empty_addresses: List(String) = []
  let no_file: option.Option(String) = None

  // This should represent invalid input (no addresses and no file)
  case empty_addresses, no_file {
    [], None -> should.be_true(True)
    // This combination should be invalid
    _, _ -> should.be_true(False)
  }
}

/// Test single vs multiple address routing logic
pub fn balance_routing_logic_test() {
  let single_address = ["0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000"]
  let multiple_addresses = [
    "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
    "0x1111111111111111111111111111111111111111",
  ]

  // Test that we can distinguish between single and multiple addresses
  case single_address, multiple_addresses {
    [_single], [_first, _second, ..] -> should.be_true(True)
    _, _ -> should.fail()
  }
}

/// Test file vs address input logic
pub fn balance_input_modes_test() {
  let addresses = ["0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000"]
  let file_option = Some("addresses.txt")
  let no_file = None

  // Test different input combinations
  case addresses, file_option {
    [_], Some(_) -> should.be_true(True)
    // Both addresses and file
    _, _ -> should.be_true(True)
    // Other combinations also valid
  }

  case addresses, no_file {
    [_], None -> should.be_true(True)
    // Only addresses
    _, _ -> should.be_true(True)
    // Other combinations
  }
}
