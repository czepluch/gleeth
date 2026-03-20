import gleam/bit_array
import gleam/string
import gleeth/ethereum/abi/decode
import gleeth/ethereum/abi/encode
import gleeth/ethereum/abi/types
import gleeunit/should

// =============================================================================
// Standard Error(string) revert decoding
// =============================================================================

pub fn decode_revert_error_string_test() {
  // Error(string) selector: 0x08c379a0
  // Encode the string "Insufficient balance"
  let assert Ok(encoded_string) =
    encode.encode([#(types.String, types.StringValue("Insufficient balance"))])
  let revert_data =
    "0x08c379a0" <> string.lowercase(bit_array.base16_encode(encoded_string))

  let assert Ok(result) = decode.decode_revert(revert_data)
  case result {
    decode.RevertString(msg) -> msg |> should.equal("Insufficient balance")
    _ -> should.fail()
  }
}

pub fn decode_revert_error_empty_string_test() {
  let assert Ok(encoded_string) =
    encode.encode([#(types.String, types.StringValue(""))])
  let revert_data =
    "0x08c379a0" <> string.lowercase(bit_array.base16_encode(encoded_string))

  let assert Ok(result) = decode.decode_revert(revert_data)
  case result {
    decode.RevertString(msg) -> msg |> should.equal("")
    _ -> should.fail()
  }
}

// =============================================================================
// Panic(uint256) revert decoding
// =============================================================================

pub fn decode_revert_panic_test() {
  // Panic(uint256) selector: 0x4e487b71
  // Panic code 0x01 = assert failure
  let assert Ok(encoded_code) =
    encode.encode([#(types.Uint(256), types.UintValue(1))])
  let revert_data =
    "0x4e487b71" <> string.lowercase(bit_array.base16_encode(encoded_code))

  let assert Ok(result) = decode.decode_revert(revert_data)
  case result {
    decode.RevertPanic(code) -> code |> should.equal(1)
    _ -> should.fail()
  }
}

pub fn decode_revert_panic_overflow_test() {
  // Panic code 0x11 = arithmetic overflow
  let assert Ok(encoded_code) =
    encode.encode([#(types.Uint(256), types.UintValue(0x11))])
  let revert_data =
    "0x4e487b71" <> string.lowercase(bit_array.base16_encode(encoded_code))

  let assert Ok(result) = decode.decode_revert(revert_data)
  case result {
    decode.RevertPanic(code) -> code |> should.equal(0x11)
    _ -> should.fail()
  }
}

// =============================================================================
// Unknown revert
// =============================================================================

pub fn decode_revert_unknown_selector_test() {
  // Some random 4-byte selector that doesn't match Error or Panic
  let revert_data =
    "0xdeadbeef0000000000000000000000000000000000000000000000000000000000000001"

  let assert Ok(result) = decode.decode_revert(revert_data)
  case result {
    decode.RevertUnknown(_) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn decode_revert_empty_data_test() {
  let assert Ok(result) = decode.decode_revert("0x")
  case result {
    decode.RevertUnknown(data) -> bit_array.byte_size(data) |> should.equal(0)
    _ -> should.fail()
  }
}

pub fn decode_revert_invalid_hex_test() {
  decode.decode_revert("not hex")
  |> should.be_error
}
