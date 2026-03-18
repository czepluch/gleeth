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
