import gleam/bit_array
import gleam/string
import gleeth/crypto/keccak
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

/// Test keccak256 with known test vectors
pub fn keccak256_basic_test() {
  // Empty string
  keccak.keccak256_hex("")
  |> should.equal(
    "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
  )

  // Simple string
  keccak.keccak256_hex("hello")
  |> should.equal(
    "0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8",
  )
}

/// Test function selector generation
pub fn function_selector_test() {
  case keccak.function_selector("balanceOf(address)") {
    Ok(selector) -> selector |> should.equal("0x70a08231")
    Error(_) -> should.fail()
  }
}

/// Test binary input
pub fn keccak256_binary_test() {
  let input = bit_array.from_string("test")
  let result = keccak.keccak256_binary(input)
  let hex_result = "0x" <> string.lowercase(bit_array.base16_encode(result))

  hex_result
  |> should.equal(
    "0x9c22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb658",
  )
}
