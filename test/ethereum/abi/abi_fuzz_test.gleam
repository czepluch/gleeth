/// Property-based fuzz tests for ABI encoding/decoding roundtrips.
/// Generates random values for each ABI type, encodes, decodes, and
/// verifies the original values are recovered.
import gleam/bit_array
import gleam/string
import gleeth/ethereum/abi/decode
import gleeth/ethereum/abi/encode
import gleeth/ethereum/abi/types
import gleeunit/should
import qcheck

// =============================================================================
// uint256 roundtrip
// =============================================================================

pub fn fuzz_abi_uint256_roundtrip_test() {
  use value <- qcheck.given(qcheck.bounded_int(
    from: 0,
    to: 1_000_000_000_000_000_000,
  ))
  let type_ = types.Uint(256)
  let abi_value = types.UintValue(value)

  let assert Ok(encoded) = encode.encode([#(type_, abi_value)])
  let assert Ok([decoded]) = decode.decode([type_], encoded)

  case decoded {
    types.UintValue(n) -> n |> should.equal(value)
    _ -> should.fail()
  }
}

// =============================================================================
// int256 roundtrip (positive and negative)
// =============================================================================

pub fn fuzz_abi_int256_roundtrip_test() {
  use value <- qcheck.given(qcheck.bounded_int(
    from: -1_000_000_000_000_000,
    to: 1_000_000_000_000_000,
  ))
  let type_ = types.Int(256)
  let abi_value = types.IntValue(value)

  let assert Ok(encoded) = encode.encode([#(type_, abi_value)])
  let assert Ok([decoded]) = decode.decode([type_], encoded)

  case decoded {
    types.IntValue(n) -> n |> should.equal(value)
    _ -> should.fail()
  }
}

// =============================================================================
// bool roundtrip
// =============================================================================

pub fn fuzz_abi_bool_roundtrip_test() {
  use value <- qcheck.given(
    qcheck.from_generators(qcheck.return(True), [
      qcheck.return(False),
    ]),
  )
  let type_ = types.Bool
  let abi_value = types.BoolValue(value)

  let assert Ok(encoded) = encode.encode([#(type_, abi_value)])
  let assert Ok([decoded]) = decode.decode([type_], encoded)

  case decoded {
    types.BoolValue(b) -> b |> should.equal(value)
    _ -> should.fail()
  }
}

// =============================================================================
// address roundtrip
// =============================================================================

pub fn fuzz_abi_address_roundtrip_test() {
  use address <- qcheck.given(
    qcheck.from_generators(
      qcheck.return("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"),
      [
        qcheck.return("0x70997970c51812dc3a010c7d01b50e0d17dc79c8"),
        qcheck.return("0xdead000000000000000000000000000000000000"),
        qcheck.return("0x0000000000000000000000000000000000000001"),
        qcheck.return("0x0000000000000000000000000000000000000000"),
      ],
    ),
  )

  let type_ = types.Address
  let abi_value = types.AddressValue(address)

  let assert Ok(encoded) = encode.encode([#(type_, abi_value)])
  let assert Ok([decoded]) = decode.decode([type_], encoded)

  case decoded {
    types.AddressValue(addr) ->
      string.lowercase(addr) |> should.equal(string.lowercase(address))
    _ -> should.fail()
  }
}

// =============================================================================
// string roundtrip
// =============================================================================

pub fn fuzz_abi_string_roundtrip_test() {
  use value <- qcheck.given(qcheck.string())
  let type_ = types.String
  let abi_value = types.StringValue(value)

  let assert Ok(encoded) = encode.encode([#(type_, abi_value)])
  let assert Ok([decoded]) = decode.decode([type_], encoded)

  case decoded {
    types.StringValue(s) -> s |> should.equal(value)
    _ -> should.fail()
  }
}

// =============================================================================
// bytes roundtrip
// =============================================================================

pub fn fuzz_abi_bytes_roundtrip_test() {
  // Generate byte-aligned bit arrays (ABI requires whole bytes)
  use length <- qcheck.given(qcheck.bounded_int(from: 0, to: 100))
  let value = build_byte_array(length, <<>>)
  let type_ = types.Bytes
  let abi_value = types.BytesValue(value)

  let assert Ok(encoded) = encode.encode([#(type_, abi_value)])
  let assert Ok([decoded]) = decode.decode([type_], encoded)

  case decoded {
    types.BytesValue(b) -> b |> should.equal(value)
    _ -> should.fail()
  }
}

// =============================================================================
// bytes32 roundtrip
// =============================================================================

pub fn fuzz_abi_bytes32_roundtrip_test() {
  use seed <- qcheck.given(qcheck.bounded_int(from: 0, to: 999_999_999))
  // Create a deterministic 32-byte value from the seed
  let padding = <<0:200>>
  let seed_bytes = <<seed:56>>
  let value = bit_array.concat([padding, seed_bytes])
  let assert Ok(value32) = bit_array.slice(value, 0, 32)

  let type_ = types.FixedBytes(32)
  let abi_value = types.FixedBytesValue(value32)

  let assert Ok(encoded) = encode.encode([#(type_, abi_value)])
  let assert Ok([decoded]) = decode.decode([type_], encoded)

  case decoded {
    types.FixedBytesValue(b) -> b |> should.equal(value32)
    _ -> should.fail()
  }
}

// =============================================================================
// Multi-value tuple roundtrip (uint256, bool, address)
// =============================================================================

pub fn fuzz_abi_tuple_roundtrip_test() {
  use value <- qcheck.given(qcheck.bounded_int(from: 0, to: 1_000_000_000))
  let type_list = [types.Uint(256), types.Bool, types.Address]
  let values = [
    #(types.Uint(256), types.UintValue(value)),
    #(types.Bool, types.BoolValue(value > 500_000_000)),
    #(
      types.Address,
      types.AddressValue("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"),
    ),
  ]

  let assert Ok(encoded) = encode.encode(values)
  let assert Ok(decoded) = decode.decode(type_list, encoded)

  case decoded {
    [types.UintValue(n), types.BoolValue(_), types.AddressValue(_)] ->
      n |> should.equal(value)
    _ -> should.fail()
  }
}

// =============================================================================
// Dynamic array roundtrip
// =============================================================================

pub fn fuzz_abi_uint_array_roundtrip_test() {
  use length <- qcheck.given(qcheck.bounded_int(from: 0, to: 10))
  let type_ = types.Array(types.Uint(256))
  let items = build_uint_list(length, [])
  let abi_value = types.ArrayValue(items)

  let assert Ok(encoded) = encode.encode([#(type_, abi_value)])
  let assert Ok([decoded]) = decode.decode([type_], encoded)

  case decoded {
    types.ArrayValue(decoded_items) -> {
      list_length(decoded_items) |> should.equal(length)
    }
    _ -> should.fail()
  }
}

fn build_byte_array(remaining: Int, acc: BitArray) -> BitArray {
  case remaining {
    0 -> acc
    _ -> build_byte_array(remaining - 1, <<acc:bits, remaining:8>>)
  }
}

fn build_uint_list(
  remaining: Int,
  acc: List(types.AbiValue),
) -> List(types.AbiValue) {
  case remaining {
    0 -> acc
    _ ->
      build_uint_list(remaining - 1, [types.UintValue(remaining * 100), ..acc])
  }
}

fn list_length(list: List(a)) -> Int {
  case list {
    [] -> 0
    [_, ..rest] -> 1 + list_length(rest)
  }
}
