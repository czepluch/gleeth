import gleeth/utils/hex
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

/// Test basic hex operations
pub fn hex_operations_test() {
  // Test prefix operations
  hex.strip_prefix("0x1234") |> should.equal("1234")
  hex.ensure_prefix("1234") |> should.equal("0x1234")
  hex.normalize("ABCD") |> should.equal("0xabcd")
}

/// Test hex validation
pub fn hex_validation_test() {
  hex.is_valid_hex_chars("1234abcd") |> should.be_true()
  hex.is_valid_hex_chars("xyz") |> should.be_false()
}

/// Test hex conversion
pub fn hex_conversion_test() {
  hex.from_int(255) |> should.equal("0xff")

  case hex.to_int("0xff") {
    Ok(result) -> result |> should.equal(255)
    Error(_) -> should.fail()
  }
}

/// Test wei conversion
pub fn wei_conversion_test() {
  case hex.wei_to_ether("0xde0b6b3a7640000") {
    Ok(ether) -> ether |> should.equal(1.0)
    Error(_) -> should.fail()
  }
}
