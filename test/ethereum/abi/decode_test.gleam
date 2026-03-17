import gleam/string
import gleeth/ethereum/abi/decode
import gleeth/ethereum/abi/encode
import gleeth/ethereum/abi/types
import gleeth/utils/hex
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Helper: build data from hex string
fn from_hex(h: String) -> BitArray {
  let assert Ok(bytes) = hex.decode("0x" <> h)
  bytes
}

// ---------------------------------------------------------------------------
// Static scalar types
// ---------------------------------------------------------------------------

pub fn decode_uint256_zero_test() {
  let data = from_hex(string.repeat("0", 64))
  let assert Ok([types.UintValue(0)]) = decode.decode([types.Uint(256)], data)
}

pub fn decode_uint256_one_test() {
  let data = from_hex(string.repeat("0", 63) <> "1")
  let assert Ok([types.UintValue(1)]) = decode.decode([types.Uint(256)], data)
}

pub fn decode_uint8_test() {
  let data = from_hex(string.repeat("0", 62) <> "ff")
  let assert Ok([types.UintValue(255)]) = decode.decode([types.Uint(8)], data)
}

pub fn decode_bool_true_test() {
  let data = from_hex(string.repeat("0", 63) <> "1")
  let assert Ok([types.BoolValue(True)]) = decode.decode([types.Bool], data)
}

pub fn decode_bool_false_test() {
  let data = from_hex(string.repeat("0", 64))
  let assert Ok([types.BoolValue(False)]) = decode.decode([types.Bool], data)
}

pub fn decode_address_test() {
  let data =
    from_hex(
      "000000000000000000000000" <> "d8da6bf26964af9d7eed9e03e53415d37aa96045",
    )
  let assert Ok([types.AddressValue(addr)]) =
    decode.decode([types.Address], data)
  addr
  |> should.equal("0xd8da6bf26964af9d7eed9e03e53415d37aa96045")
}

pub fn decode_int256_negative_one_test() {
  let data = from_hex(string.repeat("f", 64))
  let assert Ok([types.IntValue(-1)]) = decode.decode([types.Int(256)], data)
}

pub fn decode_int8_negative_test() {
  let data = from_hex(string.repeat("f", 62) <> "80")
  let assert Ok([types.IntValue(-128)]) = decode.decode([types.Int(8)], data)
}

pub fn decode_bytes4_test() {
  let data = from_hex("deadbeef" <> string.repeat("0", 56))
  let assert Ok([types.FixedBytesValue(bytes)]) =
    decode.decode([types.FixedBytes(4)], data)
  bytes
  |> should.equal(<<0xde, 0xad, 0xbe, 0xef>>)
}

// ---------------------------------------------------------------------------
// Multiple static values
// ---------------------------------------------------------------------------

pub fn decode_two_uint256_test() {
  let data =
    from_hex(string.repeat("0", 63) <> "1" <> string.repeat("0", 63) <> "2")
  let assert Ok([types.UintValue(1), types.UintValue(2)]) =
    decode.decode([types.Uint(256), types.Uint(256)], data)
}

// ---------------------------------------------------------------------------
// Dynamic types
// ---------------------------------------------------------------------------

pub fn decode_string_test() {
  let data =
    from_hex(
      // offset = 32
      string.repeat("0", 62)
      <> "20"
      // length = 5
      <> string.repeat("0", 63)
      <> "5"
      // "hello" padded
      <> "68656c6c6f"
      <> string.repeat("0", 54),
    )
  let assert Ok([types.StringValue("hello")]) =
    decode.decode([types.String], data)
}

pub fn decode_bytes_dynamic_test() {
  let data =
    from_hex(
      string.repeat("0", 62)
      <> "20"
      <> string.repeat("0", 63)
      <> "2"
      <> "dead"
      <> string.repeat("0", 60),
    )
  let assert Ok([types.BytesValue(bytes)]) = decode.decode([types.Bytes], data)
  bytes
  |> should.equal(<<0xde, 0xad>>)
}

pub fn decode_uint256_array_test() {
  let data =
    from_hex(
      // offset = 32
      string.repeat("0", 62)
      <> "20"
      // count = 3
      <> string.repeat("0", 63)
      <> "3"
      // elements: 1, 2, 3
      <> string.repeat("0", 63)
      <> "1"
      <> string.repeat("0", 63)
      <> "2"
      <> string.repeat("0", 63)
      <> "3",
    )
  let assert Ok([
    types.ArrayValue([
      types.UintValue(1),
      types.UintValue(2),
      types.UintValue(3),
    ]),
  ]) = decode.decode([types.Array(types.Uint(256))], data)
}

// ---------------------------------------------------------------------------
// Mixed static + dynamic
// ---------------------------------------------------------------------------

pub fn decode_uint256_and_string_test() {
  let data =
    from_hex(
      // uint256(42)
      string.repeat("0", 62)
      <> "2a"
      // offset = 64
      <> string.repeat("0", 62)
      <> "40"
      // length = 5
      <> string.repeat("0", 63)
      <> "5"
      // "hello" padded
      <> "68656c6c6f"
      <> string.repeat("0", 54),
    )
  let assert Ok([types.UintValue(42), types.StringValue("hello")]) =
    decode.decode([types.Uint(256), types.String], data)
}

// ---------------------------------------------------------------------------
// Roundtrip tests: encode then decode
// ---------------------------------------------------------------------------

pub fn roundtrip_uint256_test() {
  let types_list = [types.Uint(256)]
  let values = [types.UintValue(12_345)]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_string_test() {
  let types_list = [types.String]
  let values = [types.StringValue("hello world")]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_mixed_test() {
  let types_list = [types.Uint(256), types.String, types.Bool]
  let values = [
    types.UintValue(42),
    types.StringValue("test"),
    types.BoolValue(True),
  ]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_address_test() {
  let types_list = [types.Address]
  let values = [
    types.AddressValue("0xd8da6bf26964af9d7eed9e03e53415d37aa96045"),
  ]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_dynamic_array_test() {
  let types_list = [types.Array(types.Uint(256))]
  let values = [
    types.ArrayValue([
      types.UintValue(10),
      types.UintValue(20),
      types.UintValue(30),
    ]),
  ]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_int256_negative_test() {
  let types_list = [types.Int(256)]
  let values = [types.IntValue(-42)]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_bytes_test() {
  let types_list = [types.Bytes]
  let values = [types.BytesValue(<<1, 2, 3, 4, 5>>)]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_complex_test() {
  // (uint256, string, address, bool, bytes)
  let types_list = [
    types.Uint(256),
    types.String,
    types.Address,
    types.Bool,
    types.Bytes,
  ]
  let values = [
    types.UintValue(999),
    types.StringValue("complex test"),
    types.AddressValue("0x0000000000000000000000000000000000000001"),
    types.BoolValue(False),
    types.BytesValue(<<0xca, 0xfe>>),
  ]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

// ---------------------------------------------------------------------------
// Roundtrip tests: compound and nested types
// ---------------------------------------------------------------------------

pub fn roundtrip_static_fixed_array_test() {
  // uint256[3]
  let types_list = [types.FixedArray(types.Uint(256), 3)]
  let values = [
    types.ArrayValue([
      types.UintValue(10),
      types.UintValue(20),
      types.UintValue(30),
    ]),
  ]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_static_fixed_array_with_other_params_test() {
  // (uint256, uint256[3], bool)
  let types_list = [
    types.Uint(256),
    types.FixedArray(types.Uint(256), 3),
    types.Bool,
  ]
  let values = [
    types.UintValue(42),
    types.ArrayValue([
      types.UintValue(1),
      types.UintValue(2),
      types.UintValue(3),
    ]),
    types.BoolValue(True),
  ]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_static_fixed_array_mixed_with_dynamic_test() {
  // (uint256[2], string, bool)
  let types_list = [
    types.FixedArray(types.Uint(256), 2),
    types.String,
    types.Bool,
  ]
  let values = [
    types.ArrayValue([types.UintValue(100), types.UintValue(200)]),
    types.StringValue("after fixed array"),
    types.BoolValue(False),
  ]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_dynamic_fixed_array_test() {
  // string[2] - fixed array of dynamic elements
  let types_list = [types.FixedArray(types.String, 2)]
  let values = [
    types.ArrayValue([
      types.StringValue("hello"),
      types.StringValue("world"),
    ]),
  ]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_string_array_test() {
  // string[] - dynamic array of dynamic elements
  let types_list = [types.Array(types.String)]
  let values = [
    types.ArrayValue([
      types.StringValue("one"),
      types.StringValue("two"),
      types.StringValue("three"),
    ]),
  ]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_nested_array_test() {
  // uint256[][] - array of arrays
  let types_list = [types.Array(types.Array(types.Uint(256)))]
  let values = [
    types.ArrayValue([
      types.ArrayValue([types.UintValue(1), types.UintValue(2)]),
      types.ArrayValue([types.UintValue(3)]),
    ]),
  ]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_static_tuple_test() {
  // (uint256, bool) as a single tuple parameter
  let types_list = [types.Tuple([types.Uint(256), types.Bool])]
  let values = [types.TupleValue([types.UintValue(42), types.BoolValue(True)])]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_dynamic_tuple_test() {
  // (uint256, string) as a single tuple parameter - dynamic because of string
  let types_list = [types.Tuple([types.Uint(256), types.String])]
  let values = [
    types.TupleValue([types.UintValue(7), types.StringValue("hi")]),
  ]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_tuple_with_other_params_test() {
  // (uint256, (address, bool), string)
  let types_list = [
    types.Uint(256),
    types.Tuple([types.Address, types.Bool]),
    types.String,
  ]
  let values = [
    types.UintValue(99),
    types.TupleValue([
      types.AddressValue("0x0000000000000000000000000000000000000abc"),
      types.BoolValue(False),
    ]),
    types.StringValue("end"),
  ]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_nested_dynamic_tuple_test() {
  // ((uint256, string), bool) - outer tuple is dynamic because inner tuple is
  let types_list = [
    types.Tuple([types.Uint(256), types.String]),
    types.Bool,
  ]
  let values = [
    types.TupleValue([types.UintValue(42), types.StringValue("nested")]),
    types.BoolValue(True),
  ]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_array_of_tuples_test() {
  // (uint256, bool)[] - dynamic array of static tuples
  let tuple_type = types.Tuple([types.Uint(256), types.Bool])
  let types_list = [types.Array(tuple_type)]
  let values = [
    types.ArrayValue([
      types.TupleValue([types.UintValue(1), types.BoolValue(True)]),
      types.TupleValue([types.UintValue(2), types.BoolValue(False)]),
    ]),
  ]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_empty_dynamic_array_test() {
  let types_list = [types.Array(types.Uint(256))]
  let values = [types.ArrayValue([])]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_empty_string_test() {
  let types_list = [types.String]
  let values = [types.StringValue("")]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

pub fn roundtrip_kitchen_sink_test() {
  // (uint256, string[], address, (bool, bytes32), uint8)
  let types_list = [
    types.Uint(256),
    types.Array(types.String),
    types.Address,
    types.Tuple([types.Bool, types.FixedBytes(4)]),
    types.Uint(8),
  ]
  let values = [
    types.UintValue(1_000_000),
    types.ArrayValue([
      types.StringValue("alpha"),
      types.StringValue("beta"),
    ]),
    types.AddressValue("0x000000000000000000000000000000000000dead"),
    types.TupleValue([
      types.BoolValue(True),
      types.FixedBytesValue(<<0xca, 0xfe, 0xba, 0xbe>>),
    ]),
    types.UintValue(255),
  ]
  let assert Ok(encoded) = encode.encode(list.zip(types_list, values))
  let assert Ok(decoded) = decode.decode(types_list, encoded)
  decoded
  |> should.equal(values)
}

// Need list for zip
import gleam/list
