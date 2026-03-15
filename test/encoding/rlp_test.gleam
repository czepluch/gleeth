import gleam/bit_array
import gleam/string
import gleeth/encoding/rlp.{ExtraData, RlpBytes, RlpList, UnexpectedEnd}
import gleeunit/should

// =============================================================================
// Encoding: byte strings
// =============================================================================

pub fn encode_empty_bytes_test() {
  rlp.encode(RlpBytes(<<>>))
  |> should.equal(<<0x80>>)
}

pub fn encode_single_byte_zero_test() {
  rlp.encode(RlpBytes(<<0x00>>))
  |> should.equal(<<0x00>>)
}

pub fn encode_single_byte_max_direct_test() {
  rlp.encode(RlpBytes(<<0x7f>>))
  |> should.equal(<<0x7f>>)
}

pub fn encode_single_byte_needs_prefix_test() {
  rlp.encode(RlpBytes(<<0x80>>))
  |> should.equal(<<0x81, 0x80>>)
}

pub fn encode_single_byte_ff_test() {
  rlp.encode(RlpBytes(<<0xff>>))
  |> should.equal(<<0x81, 0xff>>)
}

pub fn encode_short_string_dog_test() {
  rlp.encode(rlp.encode_string("dog"))
  |> should.equal(<<0x83, 0x64, 0x6f, 0x67>>)
}

pub fn encode_short_string_cat_test() {
  rlp.encode(rlp.encode_string("cat"))
  |> should.equal(<<0x83, 0x63, 0x61, 0x74>>)
}

pub fn encode_55_byte_string_test() {
  let data = bit_array.from_string(string.repeat("a", 55))
  let encoded = rlp.encode(RlpBytes(data))
  // 0xb7 = 0x80 + 55, the maximum short string prefix
  let assert <<0xb7:8, payload:bits>> = encoded
  bit_array.byte_size(payload)
  |> should.equal(55)
}

pub fn encode_56_byte_string_test() {
  let data = bit_array.from_string(string.repeat("a", 56))
  let encoded = rlp.encode(RlpBytes(data))
  // 0xb8 = 0xb7 + 1 (1-byte length), 0x38 = 56
  let assert <<0xb8:8, 0x38:8, payload:bits>> = encoded
  bit_array.byte_size(payload)
  |> should.equal(56)
}

pub fn encode_256_byte_string_test() {
  let data = bit_array.from_string(string.repeat("b", 256))
  let encoded = rlp.encode(RlpBytes(data))
  // 0xb9 = 0xb7 + 2 (2-byte length), 0x01 0x00 = 256
  let assert <<0xb9:8, 0x01:8, 0x00:8, payload:bits>> = encoded
  bit_array.byte_size(payload)
  |> should.equal(256)
}

// =============================================================================
// Encoding: lists
// =============================================================================

pub fn encode_empty_list_test() {
  rlp.encode(RlpList([]))
  |> should.equal(<<0xc0>>)
}

pub fn encode_cat_dog_list_test() {
  let item = RlpList([rlp.encode_string("cat"), rlp.encode_string("dog")])
  rlp.encode(item)
  |> should.equal(<<0xc8, 0x83, 0x63, 0x61, 0x74, 0x83, 0x64, 0x6f, 0x67>>)
}

pub fn encode_nested_list_test() {
  // [[], [[]], [[], [[]]]]
  let item =
    RlpList([
      RlpList([]),
      RlpList([RlpList([])]),
      RlpList([RlpList([]), RlpList([RlpList([])])]),
    ])
  rlp.encode(item)
  |> should.equal(<<0xc7, 0xc0, 0xc1, 0xc0, 0xc3, 0xc0, 0xc1, 0xc0>>)
}

pub fn encode_single_item_list_test() {
  let item = RlpList([RlpBytes(<<0x01>>)])
  rlp.encode(item)
  |> should.equal(<<0xc1, 0x01>>)
}

// =============================================================================
// Encoding: integers
// =============================================================================

pub fn encode_int_zero_test() {
  rlp.encode(rlp.encode_int(0))
  |> should.equal(<<0x80>>)
}

pub fn encode_int_one_test() {
  rlp.encode(rlp.encode_int(1))
  |> should.equal(<<0x01>>)
}

pub fn encode_int_127_test() {
  rlp.encode(rlp.encode_int(127))
  |> should.equal(<<0x7f>>)
}

pub fn encode_int_128_test() {
  rlp.encode(rlp.encode_int(128))
  |> should.equal(<<0x81, 0x80>>)
}

pub fn encode_int_255_test() {
  rlp.encode(rlp.encode_int(255))
  |> should.equal(<<0x81, 0xff>>)
}

pub fn encode_int_256_test() {
  rlp.encode(rlp.encode_int(256))
  |> should.equal(<<0x82, 0x01, 0x00>>)
}

pub fn encode_int_1024_test() {
  rlp.encode(rlp.encode_int(1024))
  |> should.equal(<<0x82, 0x04, 0x00>>)
}

pub fn encode_int_65535_test() {
  rlp.encode(rlp.encode_int(65_535))
  |> should.equal(<<0x82, 0xff, 0xff>>)
}

pub fn encode_int_65536_test() {
  rlp.encode(rlp.encode_int(65_536))
  |> should.equal(<<0x83, 0x01, 0x00, 0x00>>)
}

// =============================================================================
// Decoding: byte strings
// =============================================================================

pub fn decode_empty_bytes_test() {
  rlp.decode(<<0x80>>)
  |> should.equal(Ok(RlpBytes(<<>>)))
}

pub fn decode_single_byte_zero_test() {
  rlp.decode(<<0x00>>)
  |> should.equal(Ok(RlpBytes(<<0x00>>)))
}

pub fn decode_single_byte_max_direct_test() {
  rlp.decode(<<0x7f>>)
  |> should.equal(Ok(RlpBytes(<<0x7f>>)))
}

pub fn decode_single_byte_needs_prefix_test() {
  rlp.decode(<<0x81, 0x80>>)
  |> should.equal(Ok(RlpBytes(<<0x80>>)))
}

pub fn decode_short_string_dog_test() {
  rlp.decode(<<0x83, 0x64, 0x6f, 0x67>>)
  |> should.equal(Ok(RlpBytes(<<0x64, 0x6f, 0x67>>)))
}

pub fn decode_56_byte_string_test() {
  let data = bit_array.from_string(string.repeat("a", 56))
  let encoded = rlp.encode(RlpBytes(data))
  rlp.decode(encoded)
  |> should.equal(Ok(RlpBytes(data)))
}

// =============================================================================
// Decoding: lists
// =============================================================================

pub fn decode_empty_list_test() {
  rlp.decode(<<0xc0>>)
  |> should.equal(Ok(RlpList([])))
}

pub fn decode_cat_dog_list_test() {
  rlp.decode(<<0xc8, 0x83, 0x63, 0x61, 0x74, 0x83, 0x64, 0x6f, 0x67>>)
  |> should.equal(
    Ok(
      RlpList([
        RlpBytes(<<0x63, 0x61, 0x74>>),
        RlpBytes(<<0x64, 0x6f, 0x67>>),
      ]),
    ),
  )
}

pub fn decode_nested_list_test() {
  rlp.decode(<<0xc7, 0xc0, 0xc1, 0xc0, 0xc3, 0xc0, 0xc1, 0xc0>>)
  |> should.equal(
    Ok(
      RlpList([
        RlpList([]),
        RlpList([RlpList([])]),
        RlpList([RlpList([]), RlpList([RlpList([])])]),
      ]),
    ),
  )
}

// =============================================================================
// Roundtrip tests
// =============================================================================

pub fn roundtrip_empty_bytes_test() {
  let item = RlpBytes(<<>>)
  rlp.encode(item) |> rlp.decode |> should.equal(Ok(item))
}

pub fn roundtrip_short_string_test() {
  let item = rlp.encode_string("hello world")
  rlp.encode(item) |> rlp.decode |> should.equal(Ok(item))
}

pub fn roundtrip_single_byte_test() {
  let item = RlpBytes(<<42>>)
  rlp.encode(item) |> rlp.decode |> should.equal(Ok(item))
}

pub fn roundtrip_integer_test() {
  let item = rlp.encode_int(12_345)
  rlp.encode(item) |> rlp.decode |> should.equal(Ok(item))
}

pub fn roundtrip_nested_list_test() {
  let item =
    RlpList([
      RlpBytes(<<1, 2, 3>>),
      RlpList([RlpBytes(<<4, 5>>), RlpList([])]),
      RlpBytes(<<>>),
    ])
  rlp.encode(item) |> rlp.decode |> should.equal(Ok(item))
}

pub fn roundtrip_long_string_test() {
  let item = RlpBytes(bit_array.from_string(string.repeat("x", 100)))
  rlp.encode(item) |> rlp.decode |> should.equal(Ok(item))
}

pub fn roundtrip_256_byte_string_test() {
  let item = RlpBytes(bit_array.from_string(string.repeat("z", 256)))
  rlp.encode(item) |> rlp.decode |> should.equal(Ok(item))
}

// =============================================================================
// Error cases
// =============================================================================

pub fn decode_empty_input_test() {
  rlp.decode(<<>>)
  |> should.equal(Error(UnexpectedEnd))
}

pub fn decode_truncated_string_test() {
  // Header says 3 bytes but only 2 follow
  rlp.decode(<<0x83, 0x64, 0x6f>>)
  |> should.equal(Error(UnexpectedEnd))
}

pub fn decode_extra_trailing_data_test() {
  // Valid single byte followed by unexpected extra data
  rlp.decode(<<0x01, 0x02>>)
  |> should.equal(Error(ExtraData))
}

pub fn decode_truncated_list_test() {
  // Header says 2-byte list payload but only 1 byte follows
  rlp.decode(<<0xc2, 0x01>>)
  |> should.equal(Error(UnexpectedEnd))
}

pub fn decode_truncated_long_string_length_test() {
  // Long string header says 1-byte length follows, but nothing there
  rlp.decode(<<0xb8>>)
  |> should.equal(Error(UnexpectedEnd))
}

// =============================================================================
// Hex field encoding
// =============================================================================

pub fn encode_hex_field_empty_test() {
  rlp.encode_hex_field("0x")
  |> should.equal(RlpBytes(<<>>))
}

pub fn encode_hex_field_zero_test() {
  rlp.encode_hex_field("0x0")
  |> should.equal(RlpBytes(<<>>))
}

pub fn encode_hex_field_zero_padded_test() {
  rlp.encode_hex_field("0x00")
  |> should.equal(RlpBytes(<<>>))
}

pub fn encode_hex_field_one_test() {
  rlp.encode_hex_field("0x1")
  |> should.equal(RlpBytes(<<0x01>>))
}

pub fn encode_hex_field_value_test() {
  rlp.encode_hex_field("0x0400")
  |> should.equal(RlpBytes(<<0x04, 0x00>>))
}

pub fn encode_hex_field_with_leading_zeros_test() {
  rlp.encode_hex_field("0x000100")
  |> should.equal(RlpBytes(<<0x01, 0x00>>))
}

pub fn encode_hex_field_no_prefix_test() {
  rlp.encode_hex_field("ff")
  |> should.equal(RlpBytes(<<0xff>>))
}

pub fn encode_hex_field_address_test() {
  // 20-byte address should pass through without stripping
  rlp.encode_hex_field("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
  |> fn(item) {
    case item {
      RlpBytes(bytes) -> bit_array.byte_size(bytes) |> should.equal(20)
      _ -> should.fail()
    }
  }
}
