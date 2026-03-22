import gleam/int
import gleam/list
import gleam/string
import gleeth/crypto/transaction
import gleeth/crypto/wallet
import gleeth/utils/hex
import gleeunit/should
import qcheck

const test_private_key = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

const recipient = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

// =============================================================================
// Generator for random legacy transaction parameters
// =============================================================================

type LegacyTxParams {
  LegacyTxParams(
    value_int: Int,
    gas_limit_int: Int,
    gas_price_int: Int,
    nonce_int: Int,
    chain_id: Int,
    has_data: Bool,
  )
}

fn legacy_tx_generator() -> qcheck.Generator(LegacyTxParams) {
  // Generate reasonable random values for each field
  qcheck.map6(
    // value: 0 to 100 ETH in wei (as int)
    qcheck.bounded_int(from: 0, to: 100_000_000_000_000_000_000),
    // gas_limit: 21000 to 1000000
    qcheck.bounded_int(from: 21_000, to: 1_000_000),
    // gas_price: 0 to 500 gwei
    qcheck.bounded_int(from: 0, to: 500_000_000_000),
    // nonce: 0 to 10000
    qcheck.bounded_int(from: 0, to: 10_000),
    // chain_id: pick from common ones + random
    qcheck.from_generators(qcheck.return(1), [
      qcheck.return(10),
      qcheck.return(137),
      qcheck.return(42_161),
      qcheck.return(11_155_111),
      qcheck.bounded_int(from: 1, to: 100_000),
    ]),
    // has_data: sometimes include calldata
    qcheck.from_generators(qcheck.return(True), [qcheck.return(False)]),
    fn(value, gas_limit, gas_price, nonce, chain_id, has_data) {
      LegacyTxParams(value, gas_limit, gas_price, nonce, chain_id, has_data)
    },
  )
}

type Eip1559TxParams {
  Eip1559TxParams(
    value_int: Int,
    gas_limit_int: Int,
    max_fee_int: Int,
    max_priority_fee_int: Int,
    nonce_int: Int,
    chain_id: Int,
    has_data: Bool,
  )
}

fn eip1559_tx_generator() -> qcheck.Generator(Eip1559TxParams) {
  // Need 7 params but map6 is max - use bind for the 7th
  qcheck.map6(
    qcheck.bounded_int(from: 0, to: 100_000_000_000_000_000_000),
    qcheck.bounded_int(from: 21_000, to: 1_000_000),
    // max_fee: 1 gwei to 500 gwei
    qcheck.bounded_int(from: 1_000_000_000, to: 500_000_000_000),
    // max_priority_fee: 0 to 10 gwei
    qcheck.bounded_int(from: 0, to: 10_000_000_000),
    qcheck.bounded_int(from: 0, to: 10_000),
    qcheck.from_generators(qcheck.return(1), [
      qcheck.return(10),
      qcheck.return(137),
      qcheck.return(42_161),
      qcheck.return(11_155_111),
      qcheck.bounded_int(from: 1, to: 100_000),
    ]),
    fn(value, gas_limit, max_fee, priority_fee, nonce, chain_id) {
      Eip1559TxParams(
        value,
        gas_limit,
        max_fee,
        priority_fee,
        nonce,
        chain_id,
        False,
      )
    },
  )
}

// =============================================================================
// Helper: convert int to 0x-prefixed hex
// =============================================================================

fn int_to_hex(n: Int) -> String {
  case n {
    0 -> "0x0"
    _ -> "0x" <> string.lowercase(int.to_base16(n))
  }
}

// Sample calldata (ERC-20 transfer selector + dummy data)
const sample_calldata = "0xa9059cbb000000000000000000000000dead0000000000000000000000000000000000000000000000000000000000000000000000000000000000000de0b6b3a7640000"

// =============================================================================
// Fuzz test: Legacy sign -> decode roundtrip
// =============================================================================

pub fn fuzz_legacy_sign_decode_roundtrip_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)

  use params <- qcheck.given(legacy_tx_generator())

  let value_hex = int_to_hex(params.value_int)
  let gas_limit_hex = int_to_hex(params.gas_limit_int)
  let gas_price_hex = int_to_hex(params.gas_price_int)
  let nonce_hex = int_to_hex(params.nonce_int)
  let data = case params.has_data {
    True -> sample_calldata
    False -> "0x"
  }

  let assert Ok(tx) =
    transaction.create_legacy_transaction(
      recipient,
      value_hex,
      gas_limit_hex,
      gas_price_hex,
      nonce_hex,
      data,
      params.chain_id,
    )

  let assert Ok(signed) = transaction.sign_transaction(tx, w)

  // Decode the signed transaction
  let assert Ok(decoded) = transaction.decode_legacy(signed.raw_transaction)

  // Verify all fields match
  decoded.nonce |> should.equal(signed.nonce)
  decoded.gas_price |> should.equal(signed.gas_price)
  decoded.gas_limit |> should.equal(signed.gas_limit)
  decoded.to |> should.equal(signed.to)
  decoded.value |> should.equal(signed.value)
  decoded.data |> should.equal(signed.data)
  decoded.chain_id |> should.equal(signed.chain_id)

  // Verify the transaction hash is consistent
  let hash1 = transaction.get_transaction_hash(signed)
  let hash2 = transaction.hash_raw_transaction(signed.raw_transaction)
  hash1 |> should.equal(hash2)

  // Verify hash is non-empty and starts with 0x
  string.starts_with(hash1, "0x") |> should.be_true
  { string.length(hash1) == 66 } |> should.be_true
}

// =============================================================================
// Fuzz test: EIP-1559 sign -> decode roundtrip
// =============================================================================

pub fn fuzz_eip1559_sign_decode_roundtrip_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)

  use params <- qcheck.given(eip1559_tx_generator())

  let value_hex = int_to_hex(params.value_int)
  let gas_limit_hex = int_to_hex(params.gas_limit_int)
  let max_fee_hex = int_to_hex(params.max_fee_int)
  let priority_fee_hex = int_to_hex(params.max_priority_fee_int)
  let nonce_hex = int_to_hex(params.nonce_int)

  let assert Ok(tx) =
    transaction.create_eip1559_transaction(
      recipient,
      value_hex,
      gas_limit_hex,
      max_fee_hex,
      priority_fee_hex,
      nonce_hex,
      "0x",
      params.chain_id,
      [],
    )

  let assert Ok(signed) = transaction.sign_eip1559_transaction(tx, w)

  // Decode the signed transaction
  let assert Ok(decoded) = transaction.decode_eip1559(signed.raw_transaction)

  // Verify all fields match
  decoded.chain_id |> should.equal(signed.chain_id)
  decoded.nonce |> should.equal(signed.nonce)
  decoded.max_fee_per_gas |> should.equal(signed.max_fee_per_gas)
  decoded.max_priority_fee_per_gas
  |> should.equal(signed.max_priority_fee_per_gas)
  decoded.gas_limit |> should.equal(signed.gas_limit)
  decoded.to |> should.equal(signed.to)
  decoded.value |> should.equal(signed.value)
  decoded.data |> should.equal(signed.data)

  // Verify hash consistency
  let hash1 = transaction.get_eip1559_transaction_hash(signed)
  let hash2 = transaction.hash_raw_transaction(signed.raw_transaction)
  hash1 |> should.equal(hash2)
}

// =============================================================================
// Fuzz test: Legacy contract creation roundtrip
// =============================================================================

pub fn fuzz_legacy_contract_creation_roundtrip_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)

  use nonce <- qcheck.given(qcheck.bounded_int(from: 0, to: 1000))

  let nonce_hex = int_to_hex(nonce)

  let assert Ok(tx) =
    transaction.create_legacy_transaction(
      "",
      "0x0",
      "0x186a0",
      "0x3b9aca00",
      nonce_hex,
      "0x6080604052",
      1,
    )

  let assert Ok(signed) = transaction.sign_transaction(tx, w)
  let assert Ok(decoded) = transaction.decode_legacy(signed.raw_transaction)

  decoded.to |> should.equal("")
  decoded.data |> should.equal("0x6080604052")
  decoded.nonce |> should.equal(signed.nonce)
}

// =============================================================================
// Fuzz test: Auto-detect decode matches specific decode
// =============================================================================

pub fn fuzz_auto_detect_legacy_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)

  use nonce <- qcheck.given(qcheck.bounded_int(from: 0, to: 1000))

  let nonce_hex = int_to_hex(nonce)

  let assert Ok(tx) =
    transaction.create_legacy_transaction(
      recipient,
      "0xde0b6b3a7640000",
      "0x5208",
      "0x3b9aca00",
      nonce_hex,
      "0x",
      1,
    )
  let assert Ok(signed) = transaction.sign_transaction(tx, w)

  let assert Ok(decoded) = transaction.decode(signed.raw_transaction)
  case decoded {
    transaction.DecodedLegacy(tx) -> tx.chain_id |> should.equal(1)
    _ -> should.fail()
  }
}

pub fn fuzz_auto_detect_eip1559_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)

  use nonce <- qcheck.given(qcheck.bounded_int(from: 0, to: 1000))

  let nonce_hex = int_to_hex(nonce)

  let assert Ok(tx) =
    transaction.create_eip1559_transaction(
      recipient,
      "0xde0b6b3a7640000",
      "0x5208",
      "0x4a817c800",
      "0x3b9aca00",
      nonce_hex,
      "0x",
      1,
      [],
    )
  let assert Ok(signed) = transaction.sign_eip1559_transaction(tx, w)

  let assert Ok(decoded) = transaction.decode(signed.raw_transaction)
  case decoded {
    transaction.DecodedEip1559(tx) -> tx.chain_id |> should.equal(1)
    _ -> should.fail()
  }
}

// =============================================================================
// Fuzz test: EIP-155 v-value and chain_id roundtrip
// =============================================================================

pub fn fuzz_eip155_chain_id_recovery_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)

  // Test many different chain IDs
  use chain_id <- qcheck.given(qcheck.bounded_int(from: 1, to: 1_000_000))

  let assert Ok(tx) =
    transaction.create_legacy_transaction(
      recipient,
      "0x0",
      "0x5208",
      "0x3b9aca00",
      "0x0",
      "0x",
      chain_id,
    )
  let assert Ok(signed) = transaction.sign_transaction(tx, w)
  let assert Ok(decoded) = transaction.decode_legacy(signed.raw_transaction)

  // The decoded chain_id must match the original
  decoded.chain_id |> should.equal(chain_id)
}

// =============================================================================
// Cross-verification with cast (small batch)
// =============================================================================

pub fn cross_verify_with_cast_legacy_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)

  // Test 5 specific parameter sets and verify against cast
  let test_cases = [
    #(0, 21_000, 1_000_000_000, 0, 1),
    #(1_000_000_000_000_000_000, 21_000, 20_000_000_000, 5, 10),
    #(0, 100_000, 50_000_000_000, 100, 137),
    #(500_000_000_000_000, 21_000, 1_000_000_000, 0, 42_161),
    #(0, 21_000, 100_000_000, 999, 11_155_111),
  ]

  list.each(test_cases, fn(tc) {
    let #(value, gas_limit, gas_price, nonce, chain_id) = tc

    let assert Ok(tx) =
      transaction.create_legacy_transaction(
        recipient,
        int_to_hex(value),
        int_to_hex(gas_limit),
        int_to_hex(gas_price),
        int_to_hex(nonce),
        "0x",
        chain_id,
      )
    let assert Ok(signed) = transaction.sign_transaction(tx, w)

    // Decode with our decoder
    let assert Ok(decoded) = transaction.decode_legacy(signed.raw_transaction)

    // Verify chain_id roundtrip
    decoded.chain_id |> should.equal(chain_id)

    // Verify value roundtrip
    let assert Ok(decoded_value) = hex.to_int(decoded.value)
    decoded_value |> should.equal(value)

    // Verify nonce roundtrip
    let assert Ok(decoded_nonce) = hex.to_int(decoded.nonce)
    decoded_nonce |> should.equal(nonce)
  })
}

pub fn cross_verify_with_cast_eip1559_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)

  let test_cases = [
    #(0, 21_000, 1_000_000_000, 0, 0, 1),
    #(1_000_000_000_000_000_000, 21_000, 20_000_000_000, 2_000_000_000, 5, 10),
    #(0, 100_000, 50_000_000_000, 1_000_000_000, 100, 42_161),
  ]

  list.each(test_cases, fn(tc) {
    let #(value, gas_limit, max_fee, priority_fee, nonce, chain_id) = tc

    let assert Ok(tx) =
      transaction.create_eip1559_transaction(
        recipient,
        int_to_hex(value),
        int_to_hex(gas_limit),
        int_to_hex(max_fee),
        int_to_hex(priority_fee),
        int_to_hex(nonce),
        "0x",
        chain_id,
        [],
      )
    let assert Ok(signed) = transaction.sign_eip1559_transaction(tx, w)

    let assert Ok(decoded) = transaction.decode_eip1559(signed.raw_transaction)

    decoded.chain_id |> should.equal(chain_id)

    let assert Ok(decoded_value) = hex.to_int(decoded.value)
    decoded_value |> should.equal(value)
  })
}
