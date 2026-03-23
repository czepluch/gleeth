import gleeth/wei
import gleeunit/should

// =============================================================================
// from_ether
// =============================================================================

pub fn from_ether_one_test() {
  let assert Ok(hex) = wei.from_ether("1")
  hex |> should.equal("0xde0b6b3a7640000")
}

pub fn from_ether_one_decimal_test() {
  let assert Ok(hex) = wei.from_ether("1.0")
  hex |> should.equal("0xde0b6b3a7640000")
}

pub fn from_ether_half_test() {
  let assert Ok(hex) = wei.from_ether("0.5")
  hex |> should.equal("0x6f05b59d3b20000")
}

pub fn from_ether_one_point_five_test() {
  let assert Ok(hex) = wei.from_ether("1.5")
  hex |> should.equal("0x14d1120d7b160000")
}

pub fn from_ether_zero_test() {
  let assert Ok(hex) = wei.from_ether("0")
  hex |> should.equal("0x0")
}

pub fn from_ether_small_test() {
  // 0.001 ETH = 1e15 wei = 0x38D7EA4C68000
  let assert Ok(hex) = wei.from_ether("0.001")
  hex |> should.equal("0x38d7ea4c68000")
}

pub fn from_ether_large_test() {
  // 100 ETH
  let assert Ok(hex) = wei.from_ether("100")
  hex |> should.equal("0x56bc75e2d63100000")
}

pub fn from_ether_empty_test() {
  wei.from_ether("") |> should.be_error
}

pub fn from_ether_invalid_test() {
  wei.from_ether("abc") |> should.be_error
}

// =============================================================================
// to_ether
// =============================================================================

pub fn to_ether_one_test() {
  let assert Ok(eth) = wei.to_ether("0xde0b6b3a7640000")
  eth |> should.equal("1.0")
}

pub fn to_ether_half_test() {
  let assert Ok(eth) = wei.to_ether("0x6f05b59d3b20000")
  eth |> should.equal("0.5")
}

pub fn to_ether_zero_test() {
  let assert Ok(eth) = wei.to_ether("0x0")
  eth |> should.equal("0.0")
}

pub fn to_ether_large_test() {
  let assert Ok(eth) = wei.to_ether("0x56bc75e2d63100000")
  eth |> should.equal("100.0")
}

// =============================================================================
// from_ether -> to_ether roundtrip
// =============================================================================

pub fn roundtrip_ether_one_test() {
  let assert Ok(hex) = wei.from_ether("1.0")
  let assert Ok(eth) = wei.to_ether(hex)
  eth |> should.equal("1.0")
}

pub fn roundtrip_ether_half_test() {
  let assert Ok(hex) = wei.from_ether("0.5")
  let assert Ok(eth) = wei.to_ether(hex)
  eth |> should.equal("0.5")
}

pub fn roundtrip_ether_small_test() {
  let assert Ok(hex) = wei.from_ether("0.001")
  let assert Ok(eth) = wei.to_ether(hex)
  eth |> should.equal("0.001")
}

// =============================================================================
// from_gwei / to_gwei
// =============================================================================

pub fn from_gwei_one_test() {
  let assert Ok(hex) = wei.from_gwei("1")
  hex |> should.equal("0x3b9aca00")
}

pub fn from_gwei_twenty_test() {
  let assert Ok(hex) = wei.from_gwei("20")
  hex |> should.equal("0x4a817c800")
}

pub fn to_gwei_one_test() {
  let assert Ok(gwei) = wei.to_gwei("0x3b9aca00")
  gwei |> should.equal("1.0")
}

pub fn roundtrip_gwei_test() {
  let assert Ok(hex) = wei.from_gwei("20.0")
  let assert Ok(gwei) = wei.to_gwei(hex)
  gwei |> should.equal("20.0")
}

// =============================================================================
// from_int / to_int
// =============================================================================

pub fn from_int_21000_test() {
  wei.from_int(21_000) |> should.equal("0x5208")
}

pub fn from_int_zero_test() {
  wei.from_int(0) |> should.equal("0x0")
}

pub fn to_int_21000_test() {
  let assert Ok(n) = wei.to_int("0x5208")
  n |> should.equal(21_000)
}

pub fn to_int_zero_test() {
  let assert Ok(n) = wei.to_int("0x0")
  n |> should.equal(0)
}

pub fn roundtrip_int_test() {
  let hex = wei.from_int(100_000)
  let assert Ok(n) = wei.to_int(hex)
  n |> should.equal(100_000)
}

pub fn to_int_invalid_test() {
  wei.to_int("not hex") |> should.be_error
}
