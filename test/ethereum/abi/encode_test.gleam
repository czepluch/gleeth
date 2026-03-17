import gleam/bit_array
import gleam/string
import gleeth/ethereum/abi/encode
import gleeth/ethereum/abi/types
import gleeth/utils/hex
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Helper: encode and return lowercase hex without 0x prefix
fn encode_hex(values: List(#(types.AbiType, types.AbiValue))) -> String {
  let assert Ok(encoded) = encode.encode(values)
  string.lowercase(bit_array.base16_encode(encoded))
}

// ---------------------------------------------------------------------------
// Static scalar types
// ---------------------------------------------------------------------------

pub fn encode_uint256_zero_test() {
  let result = encode_hex([#(types.Uint(256), types.UintValue(0))])
  result
  |> should.equal(string.repeat("0", 64))
}

pub fn encode_uint256_one_test() {
  let result = encode_hex([#(types.Uint(256), types.UintValue(1))])
  result
  |> should.equal(string.repeat("0", 63) <> "1")
}

pub fn encode_uint256_large_test() {
  // 0x45 = 69
  let result = encode_hex([#(types.Uint(256), types.UintValue(69))])
  result
  |> should.equal(string.repeat("0", 62) <> "45")
}

pub fn encode_uint8_test() {
  let result = encode_hex([#(types.Uint(8), types.UintValue(255))])
  result
  |> should.equal(string.repeat("0", 62) <> "ff")
}

pub fn encode_bool_true_test() {
  let result = encode_hex([#(types.Bool, types.BoolValue(True))])
  result
  |> should.equal(string.repeat("0", 63) <> "1")
}

pub fn encode_bool_false_test() {
  let result = encode_hex([#(types.Bool, types.BoolValue(False))])
  result
  |> should.equal(string.repeat("0", 64))
}

pub fn encode_address_test() {
  let addr = "0x0000000000000000000000000000000000000001"
  let result = encode_hex([#(types.Address, types.AddressValue(addr))])
  // Address is left-padded: 12 zero bytes + 20 address bytes
  result
  |> should.equal(string.repeat("0", 63) <> "1")
}

pub fn encode_bytes32_test() {
  let data = <<0xab, 0xcd:8, 0:240>>
  // 32 bytes: abcd followed by 30 zero bytes
  let result =
    encode_hex([#(types.FixedBytes(32), types.FixedBytesValue(data))])
  result
  |> should.equal("abcd" <> string.repeat("0", 60))
}

pub fn encode_bytes4_test() {
  let data = <<0xde, 0xad, 0xbe, 0xef>>
  let result = encode_hex([#(types.FixedBytes(4), types.FixedBytesValue(data))])
  // Right-padded to 32 bytes
  result
  |> should.equal("deadbeef" <> string.repeat("0", 56))
}

pub fn encode_int256_negative_one_test() {
  let result = encode_hex([#(types.Int(256), types.IntValue(-1))])
  // -1 in two's complement is all ff's
  result
  |> should.equal(string.repeat("f", 64))
}

pub fn encode_int256_positive_test() {
  let result = encode_hex([#(types.Int(256), types.IntValue(42))])
  result
  |> should.equal(string.repeat("0", 62) <> "2a")
}

pub fn encode_int8_negative_test() {
  let result = encode_hex([#(types.Int(8), types.IntValue(-128))])
  // -128 in two's complement 256-bit: ff...ff80
  result
  |> should.equal(string.repeat("f", 62) <> "80")
}

// ---------------------------------------------------------------------------
// Multiple static values
// ---------------------------------------------------------------------------

pub fn encode_two_uint256_test() {
  let result =
    encode_hex([
      #(types.Uint(256), types.UintValue(1)),
      #(types.Uint(256), types.UintValue(2)),
    ])
  let expected = string.repeat("0", 63) <> "1" <> string.repeat("0", 63) <> "2"
  result
  |> should.equal(expected)
}

// ---------------------------------------------------------------------------
// Dynamic types
// ---------------------------------------------------------------------------

pub fn encode_string_test() {
  // encode("hello") should produce:
  // offset (0x20=32) | length (5) | "hello" right-padded
  let result = encode_hex([#(types.String, types.StringValue("hello"))])
  // Offset to tail: 32 (one head slot)
  let offset = string.repeat("0", 62) <> "20"
  // Length: 5
  let length = string.repeat("0", 63) <> "5"
  // Data: "hello" = 68656c6c6f, right-padded to 32 bytes
  let data = "68656c6c6f" <> string.repeat("0", 54)
  result
  |> should.equal(offset <> length <> data)
}

pub fn encode_bytes_dynamic_test() {
  let data = <<0xde, 0xad>>
  let result = encode_hex([#(types.Bytes, types.BytesValue(data))])
  let offset = string.repeat("0", 62) <> "20"
  let length = string.repeat("0", 63) <> "2"
  let content = "dead" <> string.repeat("0", 60)
  result
  |> should.equal(offset <> length <> content)
}

pub fn encode_uint256_and_string_test() {
  // function foo(uint256, string) with (42, "hello")
  // Head: uint256(42) | offset(64)
  // Tail: length(5) | "hello" padded
  let result =
    encode_hex([
      #(types.Uint(256), types.UintValue(42)),
      #(types.String, types.StringValue("hello")),
    ])
  // Slot 0: 42 = 0x2a
  let slot0 = string.repeat("0", 62) <> "2a"
  // Slot 1: offset = 64 = 0x40
  let slot1 = string.repeat("0", 62) <> "40"
  // Tail: length 5
  let len = string.repeat("0", 63) <> "5"
  // Tail: "hello" padded
  let data = "68656c6c6f" <> string.repeat("0", 54)
  result
  |> should.equal(slot0 <> slot1 <> len <> data)
}

// ---------------------------------------------------------------------------
// Dynamic array
// ---------------------------------------------------------------------------

pub fn encode_uint256_array_test() {
  let result =
    encode_hex([
      #(
        types.Array(types.Uint(256)),
        types.ArrayValue([
          types.UintValue(1),
          types.UintValue(2),
          types.UintValue(3),
        ]),
      ),
    ])
  // Head: offset = 32
  let offset = string.repeat("0", 62) <> "20"
  // Tail: count = 3
  let count = string.repeat("0", 63) <> "3"
  // Elements: 1, 2, 3
  let e1 = string.repeat("0", 63) <> "1"
  let e2 = string.repeat("0", 63) <> "2"
  let e3 = string.repeat("0", 63) <> "3"
  result
  |> should.equal(offset <> count <> e1 <> e2 <> e3)
}

// ---------------------------------------------------------------------------
// Function selector
// ---------------------------------------------------------------------------

pub fn function_selector_transfer_test() {
  let assert Ok(selector) =
    encode.function_selector("transfer", [types.Address, types.Uint(256)])
  // transfer(address,uint256) = 0xa9059cbb
  hex.encode(selector)
  |> should.equal("0xa9059cbb")
}

pub fn function_selector_balanceof_test() {
  let assert Ok(selector) =
    encode.function_selector("balanceOf", [types.Address])
  hex.encode(selector)
  |> should.equal("0x70a08231")
}

pub fn function_selector_approve_test() {
  let assert Ok(selector) =
    encode.function_selector("approve", [types.Address, types.Uint(256)])
  hex.encode(selector)
  |> should.equal("0x095ea7b3")
}

// ---------------------------------------------------------------------------
// encode_call
// ---------------------------------------------------------------------------

pub fn encode_call_transfer_test() {
  let addr = "0x0000000000000000000000000000000000000001"
  let assert Ok(call_data) =
    encode.encode_call("transfer", [
      #(types.Address, types.AddressValue(addr)),
      #(types.Uint(256), types.UintValue(1000)),
    ])
  let hex_str = string.lowercase(bit_array.base16_encode(call_data))
  // Should start with transfer selector
  should.be_true(string.starts_with(hex_str, "a9059cbb"))
}

// ---------------------------------------------------------------------------
// Error cases
// ---------------------------------------------------------------------------

pub fn encode_uint8_overflow_test() {
  encode.encode([#(types.Uint(8), types.UintValue(256))])
  |> should.be_error()
}

pub fn encode_type_mismatch_test() {
  encode.encode([#(types.Uint(256), types.BoolValue(True))])
  |> should.be_error()
}
