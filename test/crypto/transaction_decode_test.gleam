import gleam/string
import gleeth/crypto/transaction
import gleeth/crypto/wallet
import gleeunit/should

// Anvil default account 0
const test_private_key = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

const recipient = "0x70997970c51812dc3a010c7d01b50e0d17dc79c8"

// =============================================================================
// Legacy transaction decoding
// =============================================================================

// Vector 1: Simple ETH transfer, mainnet (from sign_eth_transfer_mainnet_test)
const legacy_mainnet_raw = "0xf86b80843b9aca008252089470997970c51812dc3a010c7d01b50e0d17dc79c8880de0b6b3a76400008025a09f6bac293e14b81cfdd8042e0bc0e2bccf37356bdb23a29e2f4836b8ac944363a06fd102f341f968caf9630c15b385e24c6ffdb24d3b90825831dda4bff931f397"

pub fn decode_legacy_mainnet_fields_test() {
  let assert Ok(tx) = transaction.decode_legacy(legacy_mainnet_raw)
  tx.nonce |> should.equal("0x0")
  tx.gas_price |> should.equal("0x3b9aca00")
  tx.gas_limit |> should.equal("0x5208")
  tx.to |> should.equal(recipient)
  tx.value |> should.equal("0xde0b6b3a7640000")
  tx.data |> should.equal("0x")
  tx.chain_id |> should.equal(1)
}

pub fn decode_legacy_mainnet_signature_test() {
  let assert Ok(tx) = transaction.decode_legacy(legacy_mainnet_raw)
  tx.v |> should.equal("0x25")
  tx.r
  |> should.equal(
    "0x9f6bac293e14b81cfdd8042e0bc0e2bccf37356bdb23a29e2f4836b8ac944363",
  )
  tx.s
  |> should.equal(
    "0x6fd102f341f968caf9630c15b385e24c6ffdb24d3b90825831dda4bff931f397",
  )
}

pub fn decode_legacy_mainnet_roundtrip_test() {
  // Sign a transaction, decode the output, re-sign, verify identical
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let assert Ok(tx) =
    transaction.create_legacy_transaction(
      recipient,
      "0xde0b6b3a7640000",
      "0x5208",
      "0x3b9aca00",
      "0x0",
      "0x",
      1,
    )
  let assert Ok(signed) = transaction.sign_transaction(tx, w)
  let assert Ok(decoded) = transaction.decode_legacy(signed.raw_transaction)

  // All fields must match
  decoded.nonce |> should.equal(signed.nonce)
  decoded.gas_price |> should.equal(signed.gas_price)
  decoded.gas_limit |> should.equal(signed.gas_limit)
  decoded.to |> should.equal(signed.to)
  decoded.value |> should.equal(signed.value)
  decoded.data |> should.equal(signed.data)
  decoded.chain_id |> should.equal(signed.chain_id)
  decoded.v |> should.equal(signed.v)
}

// Vector 2: Sepolia (chain ID 11155111)
const legacy_sepolia_raw = "0xf8702a8504a817c8008252089470997970c51812dc3a010c7d01b50e0d17dc79c88806f05b59d3b20000808401546d72a050efac42b869ea293ad6f9e5975710e8a1375996db8fc2c93269a05d4b791ac1a00ffbe8224c74ec06c658b6f4ec31f42b52d95cda0008977c195050ae0bbbd73d"

pub fn decode_legacy_sepolia_chain_id_test() {
  let assert Ok(tx) = transaction.decode_legacy(legacy_sepolia_raw)
  tx.chain_id |> should.equal(11_155_111)
  tx.nonce |> should.equal("0x2a")
  tx.value |> should.equal("0x6f05b59d3b20000")
}

// Vector: Contract call with calldata
const legacy_contract_call_raw = "0xf8a9018477359400830186a09470997970c51812dc3a010c7d01b50e0d17dc79c880b844a9059cbb000000000000000000000000dead0000000000000000000000000000000000000000000000000000000000000000000000000000000000000de0b6b3a764000026a024778a783a74b943117765848f57241e5119e64f5ac2df5152a3d6d00e85d3fea00743094cc6f7190d4ef4e1a428a2c19112ebed5c1c85140b18dc648e52e2c86e"

pub fn decode_legacy_contract_call_test() {
  let assert Ok(tx) = transaction.decode_legacy(legacy_contract_call_raw)
  tx.nonce |> should.equal("0x1")
  tx.gas_price |> should.equal("0x77359400")
  tx.gas_limit |> should.equal("0x186a0")
  tx.value |> should.equal("0x0")
  tx.chain_id |> should.equal(1)
  // Calldata should be preserved
  string.starts_with(tx.data, "0xa9059cbb")
  |> should.be_true
}

// Edge case: Zero value transfer
const legacy_zero_value_raw = "0xf86380843b9aca008252089470997970c51812dc3a010c7d01b50e0d17dc79c8808026a02d7fa468cc7bf47232c9780678569bcb4fe80d94a4a5c7601d28a905f1a53439a077b160a89ca5b63a9e34bd0054ce573f84caebf11e44f679744e58f28a8f7e17"

pub fn decode_legacy_zero_value_test() {
  let assert Ok(tx) = transaction.decode_legacy(legacy_zero_value_raw)
  tx.value |> should.equal("0x0")
  tx.nonce |> should.equal("0x0")
  tx.data |> should.equal("0x")
}

// Edge case: Contract creation (empty to)
const legacy_contract_creation_raw = "0xf85580843b9aca00830186a0808085608060405226a0c7a6b0091101e7dc5fa8f23076a5eda2910c9ac04cf0e2704179ec1657650443a06597e0671e1c81fa9c6e387bc3bba6fe170e8c8bea3590475f1bc01e155c34e8"

pub fn decode_legacy_contract_creation_test() {
  let assert Ok(tx) = transaction.decode_legacy(legacy_contract_creation_raw)
  tx.to |> should.equal("")
  tx.data |> should.equal("0x6080604052")
  tx.chain_id |> should.equal(1)
}

// Edge case: Large chain ID (Arbitrum 42161)
const legacy_arbitrum_raw = "0xf86e808405f5e1008252089470997970c51812dc3a010c7d01b50e0d17dc79c8880de0b6b3a76400008083014985a07d73c7af71f4d31071b634059ba617fe83da0cc70ed1560538e1794f1d2c5f5ea052491db8308f06708b609487c9083a01535cdcdf03b07d82eb7c45dbf67be7aa"

pub fn decode_legacy_arbitrum_chain_id_test() {
  let assert Ok(tx) = transaction.decode_legacy(legacy_arbitrum_raw)
  tx.chain_id |> should.equal(42_161)
}

// Edge case: Very large chain ID (2^32-1)
const legacy_max_uint32_chain_raw = "0xf86880843b9aca008252089470997970c51812dc3a010c7d01b50e0d17dc79c88080850200000022a0010f05ea32701898b544ab0cadc905792a24dc484932de0a9693bde34a33f022a07744fd9d9ded592890dfa807d844d15ce7082c6ca8f72859224c41acdee24df0"

pub fn decode_legacy_max_uint32_chain_id_test() {
  let assert Ok(tx) = transaction.decode_legacy(legacy_max_uint32_chain_raw)
  tx.chain_id |> should.equal(4_294_967_295)
}

// =============================================================================
// EIP-1559 transaction decoding
// =============================================================================

// Vector 1: Simple ETH transfer, mainnet
const eip1559_mainnet_raw = "0x02f8730180843b9aca008504a817c8008252089470997970c51812dc3a010c7d01b50e0d17dc79c8880de0b6b3a764000080c001a00a3a2646d4ad968bb56317fdb15e17fb4d9deec0d03e8b6cb05e7125bda3006da026618ad17cc63cf1979ca75f850c536a073ec88ab1ab7c8db8b8eb129499d9ae"

pub fn decode_eip1559_mainnet_fields_test() {
  let assert Ok(tx) = transaction.decode_eip1559(eip1559_mainnet_raw)
  tx.chain_id |> should.equal(1)
  tx.nonce |> should.equal("0x0")
  tx.max_priority_fee_per_gas |> should.equal("0x3b9aca00")
  tx.max_fee_per_gas |> should.equal("0x4a817c800")
  tx.gas_limit |> should.equal("0x5208")
  tx.to |> should.equal(recipient)
  tx.value |> should.equal("0xde0b6b3a7640000")
  tx.data |> should.equal("0x")
  tx.access_list |> should.equal([])
}

pub fn decode_eip1559_mainnet_signature_test() {
  let assert Ok(tx) = transaction.decode_eip1559(eip1559_mainnet_raw)
  tx.v |> should.equal("0x1")
}

pub fn decode_eip1559_mainnet_roundtrip_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let assert Ok(tx) =
    transaction.create_eip1559_transaction(
      recipient,
      "0xde0b6b3a7640000",
      "0x5208",
      "0x4a817c800",
      "0x3b9aca00",
      "0x0",
      "0x",
      1,
      [],
    )
  let assert Ok(signed) = transaction.sign_eip1559_transaction(tx, w)
  let assert Ok(decoded) = transaction.decode_eip1559(signed.raw_transaction)

  decoded.chain_id |> should.equal(signed.chain_id)
  decoded.nonce |> should.equal(signed.nonce)
  decoded.max_priority_fee_per_gas
  |> should.equal(signed.max_priority_fee_per_gas)
  decoded.max_fee_per_gas |> should.equal(signed.max_fee_per_gas)
  decoded.gas_limit |> should.equal(signed.gas_limit)
  decoded.to |> should.equal(signed.to)
  decoded.value |> should.equal(signed.value)
  decoded.data |> should.equal(signed.data)
  decoded.v |> should.equal(signed.v)
}

// Vector 2: Sepolia
const eip1559_sepolia_raw = "0x02f87683aa36a72a8477359400850ba43b74008252089470997970c51812dc3a010c7d01b50e0d17dc79c88806f05b59d3b2000080c001a02277911a1d78c0b1e244762708aab7b8a1f9c780ce66bab4f9ef381e47fd3912a05f030193d4ee9bbbc53bd2a5721a957e8cedcbbe595fe33be512eaa5a0568c97"

pub fn decode_eip1559_sepolia_test() {
  let assert Ok(tx) = transaction.decode_eip1559(eip1559_sepolia_raw)
  tx.chain_id |> should.equal(11_155_111)
  tx.nonce |> should.equal("0x2a")
  tx.value |> should.equal("0x6f05b59d3b20000")
}

// Edge case: Zero value, zero priority fee
const eip1559_zero_value_raw = "0x02f866018080843b9aca008252089470997970c51812dc3a010c7d01b50e0d17dc79c88080c080a051899494986b9594e3c8290a7aa6ededf275a287bb8616f4f85dc24302770463a07e2d6cef7abe45fc6c1c031dc18ec2e480ce3a65f4420174a8cb2a909d76dfea"

pub fn decode_eip1559_zero_value_test() {
  let assert Ok(tx) = transaction.decode_eip1559(eip1559_zero_value_raw)
  tx.value |> should.equal("0x0")
  tx.max_priority_fee_per_gas |> should.equal("0x0")
  tx.nonce |> should.equal("0x0")
}

// Edge case: Contract creation
const eip1559_contract_creation_raw = "0x02f85d0180843b9aca008504a817c800830186a08080856080604052c080a0dfae576153fbfc3548eda2be6fb5a1b5a18623e73a3314941295627ff4fa566ca00b66e34436bf643793e2b1b4dbec02493b18e451a921ee0fe099cc62409cefa5"

pub fn decode_eip1559_contract_creation_test() {
  let assert Ok(tx) = transaction.decode_eip1559(eip1559_contract_creation_raw)
  tx.to |> should.equal("")
  tx.data |> should.equal("0x6080604052")
  tx.chain_id |> should.equal(1)
}

// Edge case: With access list (single entry, single key)
const eip1559_access_list_raw = "0x02f8a40102843b9aca008504a817c80082c3509470997970c51812dc3a010c7d01b50e0d17dc79c88080f838f79470997970c51812dc3a010c7d01b50e0d17dc79c8e1a0000000000000000000000000000000000000000000000000000000000000000180a083311d92388bb8bbe54d47b4ce1bb646836d59ae263bbb0bbac68a0db95db3a1a058af19624b22330ec6da7d516691d42388ac3ec7c0b57e151ff761ac1ab04ad5"

pub fn decode_eip1559_access_list_test() {
  let assert Ok(tx) = transaction.decode_eip1559(eip1559_access_list_raw)
  case tx.access_list {
    [entry] -> {
      entry.address
      |> string.lowercase
      |> should.equal(recipient)
      case entry.storage_keys {
        [key] ->
          key
          |> should.equal(
            "0x0000000000000000000000000000000000000000000000000000000000000001",
          )
        _ -> should.fail()
      }
    }
    _ -> should.fail()
  }
}

// Edge case: Multi-entry access list (2 addresses, 3 keys total)
const eip1559_multi_access_list_raw = "0x02f8ff0105843b9aca008504a817c80082c3509470997970c51812dc3a010c7d01b50e0d17dc79c88080f893f8599470997970c51812dc3a010c7d01b50e0d17dc79c8f842a00000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000002f794f39fd6e51aad88f6f4ce6ab8827279cfffb92266e1a0000000000000000000000000000000000000000000000000000000000000000080a056f559eb35d8ed096c8cb2b58a02c88c989fbe36030137bd26862576248a1a94a031e1d0ba64a0097d188bde6af8c29f3ca51f6d71cb9c69540d52a69ef17829fe"

pub fn decode_eip1559_multi_access_list_test() {
  let assert Ok(tx) = transaction.decode_eip1559(eip1559_multi_access_list_raw)
  case tx.access_list {
    [entry1, entry2] -> {
      // First entry: recipient with 2 storage keys
      entry1.address
      |> string.lowercase
      |> should.equal(recipient)
      entry1.storage_keys
      |> list.length
      |> should.equal(2)

      // Second entry: sender with 1 storage key
      entry2.address
      |> string.lowercase
      |> should.equal("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
      entry2.storage_keys
      |> list.length
      |> should.equal(1)
    }
    _ -> should.fail()
  }
}

// Edge case: Large chain ID (Arbitrum)
const eip1559_arbitrum_raw = "0x02f87482a4b1808405f5e100843b9aca008252089470997970c51812dc3a010c7d01b50e0d17dc79c8880de0b6b3a764000080c080a05f1b03639264cf1a6855788d193dda26c5427a4e2e9a4b9c2034bdee6b26977ca01087b43c4020c4bf58c09bcd0303281eca6315efddb5d001d1d1ccb63bfc7db2"

pub fn decode_eip1559_arbitrum_chain_id_test() {
  let assert Ok(tx) = transaction.decode_eip1559(eip1559_arbitrum_raw)
  tx.chain_id |> should.equal(42_161)
}

// =============================================================================
// Auto-detect decoding
// =============================================================================

pub fn decode_auto_detect_legacy_test() {
  let assert Ok(decoded) = transaction.decode(legacy_mainnet_raw)
  case decoded {
    transaction.DecodedLegacy(tx) -> tx.chain_id |> should.equal(1)
    _ -> should.fail()
  }
}

pub fn decode_auto_detect_eip1559_test() {
  let assert Ok(decoded) = transaction.decode(eip1559_mainnet_raw)
  case decoded {
    transaction.DecodedEip1559(tx) -> tx.chain_id |> should.equal(1)
    _ -> should.fail()
  }
}

// =============================================================================
// Error cases
// =============================================================================

pub fn decode_legacy_invalid_hex_test() {
  transaction.decode_legacy("not hex at all")
  |> should.be_error
}

pub fn decode_eip1559_missing_prefix_test() {
  // A legacy tx passed to decode_eip1559 should fail
  transaction.decode_eip1559(legacy_mainnet_raw)
  |> should.be_error
}

// =============================================================================
// Helpers
// =============================================================================

import gleam/list
