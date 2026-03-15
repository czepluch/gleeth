import gleam/json
import gleam/string
import gleeth/crypto/transaction
import gleeth/crypto/wallet
import gleeth/rpc/client
import gleeunit/should

// Anvil default account 0
const test_private_key = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

const test_address = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

// Anvil default account 1 (recipient)
const recipient = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

// =============================================================================
// Wallet address derivation
// =============================================================================

pub fn wallet_derives_correct_address_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  wallet.get_address(w)
  |> string.lowercase
  |> should.equal(test_address)
}

// =============================================================================
// Transaction building
// =============================================================================

pub fn create_legacy_transaction_test() {
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
  tx.nonce |> should.equal("0x0")
  tx.gas_price |> should.equal("0x3b9aca00")
  tx.gas_limit |> should.equal("0x5208")
  tx.to |> should.equal("0x70997970c51812dc3a010c7d01b50e0d17dc79c8")
  tx.value |> should.equal("0xde0b6b3a7640000")
  tx.data |> should.equal("0x")
  tx.chain_id |> should.equal(1)
}

pub fn create_eth_transfer_test() {
  let assert Ok(tx) =
    transaction.create_eth_transfer(
      recipient,
      "0xde0b6b3a7640000",
      "0x5208",
      "0x3b9aca00",
      "0x0",
      1,
    )
  tx.data |> should.equal("0x")
}

pub fn reject_invalid_address_test() {
  transaction.create_legacy_transaction(
    "0xinvalid",
    "0x0",
    "0x5208",
    "0x3b9aca00",
    "0x0",
    "0x",
    1,
  )
  |> should.be_error
}

pub fn reject_invalid_chain_id_test() {
  transaction.create_legacy_transaction(
    recipient,
    "0x0",
    "0x5208",
    "0x3b9aca00",
    "0x0",
    "0x",
    0,
  )
  |> should.be_error
}

// =============================================================================
// Vector 1: Simple ETH transfer, mainnet
// cast mktx --legacy --private-key 0xac09...ff80 --chain 1 --nonce 0
//   --gas-price 1000000000 --gas-limit 21000 --value 1ether <recipient>
// =============================================================================

pub fn sign_eth_transfer_mainnet_test() {
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

  signed.raw_transaction
  |> should.equal(
    "0xf86b80843b9aca008252089470997970c51812dc3a010c7d01b50e0d17dc79c8880de0b6b3a76400008025a09f6bac293e14b81cfdd8042e0bc0e2bccf37356bdb23a29e2f4836b8ac944363a06fd102f341f968caf9630c15b385e24c6ffdb24d3b90825831dda4bff931f397",
  )
}

pub fn sign_eth_transfer_mainnet_vrs_test() {
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

  // v = recovery_id(0) + 2*1 + 35 = 37 = 0x25
  signed.v |> should.equal("0x25")
  signed.r
  |> should.equal(
    "0x9f6bac293e14b81cfdd8042e0bc0e2bccf37356bdb23a29e2f4836b8ac944363",
  )
  signed.s
  |> should.equal(
    "0x6fd102f341f968caf9630c15b385e24c6ffdb24d3b90825831dda4bff931f397",
  )
}

pub fn sign_eth_transfer_mainnet_hash_test() {
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

  transaction.get_transaction_hash(signed)
  |> should.equal(
    "0x22d76a11db763d4b5cc16135b4d8ee08acdce86bb84fb87f4a9fd353176bba26",
  )
}

// =============================================================================
// Vector 2: ETH transfer, Sepolia (chain ID 11155111), nonce 42
// cast mktx --legacy --private-key 0xac09...ff80 --chain 11155111 --nonce 42
//   --gas-price 20000000000 --gas-limit 21000 --value 0.5ether <recipient>
// =============================================================================

pub fn sign_eth_transfer_sepolia_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let assert Ok(tx) =
    transaction.create_legacy_transaction(
      recipient,
      "0x6f05b59d3b20000",
      "0x5208",
      "0x4a817c800",
      "0x2a",
      "0x",
      11_155_111,
    )
  let assert Ok(signed) = transaction.sign_transaction(tx, w)

  signed.raw_transaction
  |> should.equal(
    "0xf8702a8504a817c8008252089470997970c51812dc3a010c7d01b50e0d17dc79c88806f05b59d3b20000808401546d72a050efac42b869ea293ad6f9e5975710e8a1375996db8fc2c93269a05d4b791ac1a00ffbe8224c74ec06c658b6f4ec31f42b52d95cda0008977c195050ae0bbbd73d",
  )
}

pub fn sign_eth_transfer_sepolia_vrs_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let assert Ok(tx) =
    transaction.create_legacy_transaction(
      recipient,
      "0x6f05b59d3b20000",
      "0x5208",
      "0x4a817c800",
      "0x2a",
      "0x",
      11_155_111,
    )
  let assert Ok(signed) = transaction.sign_transaction(tx, w)

  // v = recovery_id(1) + 2*11155111 + 35 = 22310258 = 0x1546d72
  signed.v |> should.equal("0x1546d72")
}

pub fn sign_eth_transfer_sepolia_hash_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let assert Ok(tx) =
    transaction.create_legacy_transaction(
      recipient,
      "0x6f05b59d3b20000",
      "0x5208",
      "0x4a817c800",
      "0x2a",
      "0x",
      11_155_111,
    )
  let assert Ok(signed) = transaction.sign_transaction(tx, w)

  transaction.get_transaction_hash(signed)
  |> should.equal(
    "0xb10e8afffd93f670ef5eb01f4bed8879ced2e274d49390a4b24d85ab2a382b79",
  )
}

// =============================================================================
// Vector 3: Contract call with calldata, mainnet
// cast mktx --legacy --private-key 0xac09...ff80 --chain 1 --nonce 1
//   --gas-price 2000000000 --gas-limit 100000 --value 0
//   <recipient> "transfer(address,uint256)" 0xdead...0000 1000000000000000000
// =============================================================================

pub fn sign_contract_call_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let calldata =
    "0xa9059cbb000000000000000000000000dead0000000000000000000000000000000000000000000000000000000000000000000000000000000000000de0b6b3a7640000"
  let assert Ok(tx) =
    transaction.create_legacy_transaction(
      recipient,
      "0x0",
      "0x186a0",
      "0x77359400",
      "0x1",
      calldata,
      1,
    )
  let assert Ok(signed) = transaction.sign_transaction(tx, w)

  signed.raw_transaction
  |> should.equal(
    "0xf8a9018477359400830186a09470997970c51812dc3a010c7d01b50e0d17dc79c880b844a9059cbb000000000000000000000000dead0000000000000000000000000000000000000000000000000000000000000000000000000000000000000de0b6b3a764000026a024778a783a74b943117765848f57241e5119e64f5ac2df5152a3d6d00e85d3fea00743094cc6f7190d4ef4e1a428a2c19112ebed5c1c85140b18dc648e52e2c86e",
  )
}

pub fn sign_contract_call_hash_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let calldata =
    "0xa9059cbb000000000000000000000000dead0000000000000000000000000000000000000000000000000000000000000000000000000000000000000de0b6b3a7640000"
  let assert Ok(tx) =
    transaction.create_legacy_transaction(
      recipient,
      "0x0",
      "0x186a0",
      "0x77359400",
      "0x1",
      calldata,
      1,
    )
  let assert Ok(signed) = transaction.sign_transaction(tx, w)

  transaction.get_transaction_hash(signed)
  |> should.equal(
    "0x7223ff91072f019118f308edeb4226da290f2b307d795bd299146dd7b3afb5bd",
  )
}

// =============================================================================
// Anvil integration: sign and broadcast a transaction
// Skips gracefully if anvil is not running on localhost:8545
// Start anvil with: anvil
// =============================================================================

pub fn anvil_accept_signed_transaction_test() {
  case client.make_request("http://localhost:8545", "eth_chainId", []) {
    Ok(_) -> {
      let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
      let assert Ok(tx) =
        transaction.create_legacy_transaction(
          recipient,
          "0xde0b6b3a7640000",
          "0x5208",
          "0x3b9aca00",
          "0x0",
          "0x",
          31_337,
        )
      let assert Ok(signed) = transaction.sign_transaction(tx, w)

      // Broadcast the signed transaction
      let assert Ok(response_body) =
        client.make_request("http://localhost:8545", "eth_sendRawTransaction", [
          json.string(signed.raw_transaction),
        ])

      // Anvil should return the transaction hash, not an error
      let expected_hash = transaction.get_transaction_hash(signed)
      string.contains(response_body, expected_hash)
      |> should.be_true
    }
    Error(_) -> {
      // Anvil not running - skip gracefully
      Nil
    }
  }
}
