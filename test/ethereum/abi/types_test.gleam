import gleeth/ethereum/abi/types
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// ---------------------------------------------------------------------------
// is_dynamic
// ---------------------------------------------------------------------------

pub fn uint256_is_static_test() {
  types.is_dynamic(types.Uint(256))
  |> should.equal(False)
}

pub fn int128_is_static_test() {
  types.is_dynamic(types.Int(128))
  |> should.equal(False)
}

pub fn address_is_static_test() {
  types.is_dynamic(types.Address)
  |> should.equal(False)
}

pub fn bool_is_static_test() {
  types.is_dynamic(types.Bool)
  |> should.equal(False)
}

pub fn fixed_bytes_is_static_test() {
  types.is_dynamic(types.FixedBytes(32))
  |> should.equal(False)
}

pub fn bytes_is_dynamic_test() {
  types.is_dynamic(types.Bytes)
  |> should.equal(True)
}

pub fn string_is_dynamic_test() {
  types.is_dynamic(types.String)
  |> should.equal(True)
}

pub fn dynamic_array_is_dynamic_test() {
  types.is_dynamic(types.Array(types.Uint(256)))
  |> should.equal(True)
}

pub fn fixed_array_of_static_is_static_test() {
  types.is_dynamic(types.FixedArray(types.Uint(256), 3))
  |> should.equal(False)
}

pub fn fixed_array_of_dynamic_is_dynamic_test() {
  types.is_dynamic(types.FixedArray(types.String, 2))
  |> should.equal(True)
}

pub fn static_tuple_is_static_test() {
  types.is_dynamic(types.Tuple([types.Uint(256), types.Address]))
  |> should.equal(False)
}

pub fn dynamic_tuple_is_dynamic_test() {
  types.is_dynamic(types.Tuple([types.Uint(256), types.String]))
  |> should.equal(True)
}

pub fn empty_tuple_is_static_test() {
  types.is_dynamic(types.Tuple([]))
  |> should.equal(False)
}

// ---------------------------------------------------------------------------
// to_string
// ---------------------------------------------------------------------------

pub fn uint256_to_string_test() {
  types.to_string(types.Uint(256))
  |> should.equal("uint256")
}

pub fn int8_to_string_test() {
  types.to_string(types.Int(8))
  |> should.equal("int8")
}

pub fn address_to_string_test() {
  types.to_string(types.Address)
  |> should.equal("address")
}

pub fn bool_to_string_test() {
  types.to_string(types.Bool)
  |> should.equal("bool")
}

pub fn bytes32_to_string_test() {
  types.to_string(types.FixedBytes(32))
  |> should.equal("bytes32")
}

pub fn bytes_to_string_test() {
  types.to_string(types.Bytes)
  |> should.equal("bytes")
}

pub fn string_to_string_test() {
  types.to_string(types.String)
  |> should.equal("string")
}

pub fn dynamic_array_to_string_test() {
  types.to_string(types.Array(types.Uint(256)))
  |> should.equal("uint256[]")
}

pub fn fixed_array_to_string_test() {
  types.to_string(types.FixedArray(types.Address, 3))
  |> should.equal("address[3]")
}

pub fn tuple_to_string_test() {
  types.to_string(types.Tuple([types.Address, types.Uint(256)]))
  |> should.equal("(address,uint256)")
}

pub fn nested_array_to_string_test() {
  types.to_string(types.Array(types.Array(types.Uint(256))))
  |> should.equal("uint256[][]")
}

// ---------------------------------------------------------------------------
// head_size
// ---------------------------------------------------------------------------

pub fn scalar_head_size_test() {
  types.head_size(types.Uint(256))
  |> should.equal(32)
}

pub fn dynamic_head_size_test() {
  types.head_size(types.String)
  |> should.equal(32)
}

pub fn static_fixed_array_head_size_test() {
  types.head_size(types.FixedArray(types.Uint(256), 3))
  |> should.equal(96)
}

pub fn static_tuple_head_size_test() {
  types.head_size(types.Tuple([types.Uint(256), types.Address]))
  |> should.equal(64)
}
