import gleeth/ethereum/abi/type_parser
import gleeth/ethereum/abi/types
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// ---------------------------------------------------------------------------
// Basic types
// ---------------------------------------------------------------------------

pub fn parse_uint256_test() {
  type_parser.parse("uint256")
  |> should.equal(Ok(types.Uint(256)))
}

pub fn parse_uint8_test() {
  type_parser.parse("uint8")
  |> should.equal(Ok(types.Uint(8)))
}

pub fn parse_bare_uint_test() {
  type_parser.parse("uint")
  |> should.equal(Ok(types.Uint(256)))
}

pub fn parse_int256_test() {
  type_parser.parse("int256")
  |> should.equal(Ok(types.Int(256)))
}

pub fn parse_int8_test() {
  type_parser.parse("int8")
  |> should.equal(Ok(types.Int(8)))
}

pub fn parse_bare_int_test() {
  type_parser.parse("int")
  |> should.equal(Ok(types.Int(256)))
}

pub fn parse_address_test() {
  type_parser.parse("address")
  |> should.equal(Ok(types.Address))
}

pub fn parse_bool_test() {
  type_parser.parse("bool")
  |> should.equal(Ok(types.Bool))
}

pub fn parse_bytes32_test() {
  type_parser.parse("bytes32")
  |> should.equal(Ok(types.FixedBytes(32)))
}

pub fn parse_bytes1_test() {
  type_parser.parse("bytes1")
  |> should.equal(Ok(types.FixedBytes(1)))
}

pub fn parse_bytes_dynamic_test() {
  type_parser.parse("bytes")
  |> should.equal(Ok(types.Bytes))
}

pub fn parse_string_test() {
  type_parser.parse("string")
  |> should.equal(Ok(types.String))
}

// ---------------------------------------------------------------------------
// Array types
// ---------------------------------------------------------------------------

pub fn parse_dynamic_array_test() {
  type_parser.parse("uint256[]")
  |> should.equal(Ok(types.Array(types.Uint(256))))
}

pub fn parse_fixed_array_test() {
  type_parser.parse("uint256[3]")
  |> should.equal(Ok(types.FixedArray(types.Uint(256), 3)))
}

pub fn parse_nested_array_test() {
  type_parser.parse("uint256[][]")
  |> should.equal(Ok(types.Array(types.Array(types.Uint(256)))))
}

pub fn parse_address_array_test() {
  type_parser.parse("address[]")
  |> should.equal(Ok(types.Array(types.Address)))
}

pub fn parse_fixed_then_dynamic_array_test() {
  type_parser.parse("uint256[2][]")
  |> should.equal(Ok(types.Array(types.FixedArray(types.Uint(256), 2))))
}

// ---------------------------------------------------------------------------
// Tuple types
// ---------------------------------------------------------------------------

pub fn parse_simple_tuple_test() {
  type_parser.parse("(address,uint256)")
  |> should.equal(Ok(types.Tuple([types.Address, types.Uint(256)])))
}

pub fn parse_nested_tuple_test() {
  type_parser.parse("(address,(uint256,bool))")
  |> should.equal(
    Ok(
      types.Tuple([
        types.Address,
        types.Tuple([types.Uint(256), types.Bool]),
      ]),
    ),
  )
}

pub fn parse_tuple_array_test() {
  type_parser.parse("(address,uint256)[]")
  |> should.equal(
    Ok(types.Array(types.Tuple([types.Address, types.Uint(256)]))),
  )
}

// ---------------------------------------------------------------------------
// Error cases
// ---------------------------------------------------------------------------

pub fn parse_empty_string_test() {
  type_parser.parse("")
  |> should.be_error()
}

pub fn parse_unknown_type_test() {
  type_parser.parse("foobar")
  |> should.be_error()
}

pub fn parse_invalid_uint_size_test() {
  type_parser.parse("uint7")
  |> should.be_error()
}

pub fn parse_invalid_bytes_size_test() {
  type_parser.parse("bytes33")
  |> should.be_error()
}

// ---------------------------------------------------------------------------
// Roundtrip: parse -> to_string -> parse
// ---------------------------------------------------------------------------

pub fn roundtrip_complex_type_test() {
  let type_str = "(address,uint256[],string)"
  let assert Ok(parsed) = type_parser.parse(type_str)
  let canonical = types.to_string(parsed)
  let assert Ok(reparsed) = type_parser.parse(canonical)
  should.equal(parsed, reparsed)
}
