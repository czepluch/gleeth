import gleeth/utils/validation
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

/// Test address validation
pub fn validate_address_test() {
  case
    validation.validate_address("0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000")
  {
    Ok(result) ->
      result |> should.equal("0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000")
    Error(_) -> should.fail()
  }

  case validation.validate_address("invalid") {
    Ok(_) -> should.fail()
    Error(_) -> Nil
  }
}

/// Test hash validation
pub fn validate_hash_test() {
  case
    validation.validate_hash(
      "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
    )
  {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }

  case validation.validate_hash("0x123") {
    Ok(_) -> should.fail()
    Error(_) -> Nil
  }
}

/// Test private key validation
pub fn validate_private_key_test() {
  case
    validation.validate_private_key(
      "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    )
  {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }

  case validation.validate_private_key("0xinvalidkey") {
    Ok(_) -> should.fail()
    Error(_) -> Nil
  }
}

/// Test chain ID validation
pub fn validate_chain_id_test() {
  case validation.validate_chain_id(1) {
    Ok(result) -> result |> should.equal(1)
    Error(_) -> should.fail()
  }

  case validation.validate_chain_id(0) {
    Ok(_) -> should.fail()
    Error(_) -> Nil
  }
}
