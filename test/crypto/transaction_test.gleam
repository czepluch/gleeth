import gleam/string
import gleeth/crypto/transaction
import gleeth/crypto/wallet
import gleeth/provider
import gleeth/rpc/client
import gleeth/rpc/methods
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
// EIP-1559 transaction building
// =============================================================================

pub fn create_eip1559_transaction_test() {
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
  tx.max_fee_per_gas |> should.equal("0x4a817c800")
  tx.max_priority_fee_per_gas |> should.equal("0x3b9aca00")
  tx.access_list |> should.equal([])
}

pub fn reject_invalid_eip1559_chain_id_test() {
  transaction.create_eip1559_transaction(
    recipient,
    "0x0",
    "0x5208",
    "0x4a817c800",
    "0x3b9aca00",
    "0x0",
    "0x",
    0,
    [],
  )
  |> should.be_error
}

// =============================================================================
// EIP-1559 Vector 1: Simple ETH transfer, mainnet
// cast mktx --private-key 0xac09...ff80 --chain 1 --nonce 0
//   --priority-gas-price 1000000000 --gas-price 20000000000
//   --gas-limit 21000 --value 1ether <recipient>
// =============================================================================

pub fn sign_eip1559_eth_transfer_mainnet_test() {
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

  signed.raw_transaction
  |> should.equal(
    "0x02f8730180843b9aca008504a817c8008252089470997970c51812dc3a010c7d01b50e0d17dc79c8880de0b6b3a764000080c001a00a3a2646d4ad968bb56317fdb15e17fb4d9deec0d03e8b6cb05e7125bda3006da026618ad17cc63cf1979ca75f850c536a073ec88ab1ab7c8db8b8eb129499d9ae",
  )
}

pub fn sign_eip1559_eth_transfer_mainnet_vrs_test() {
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

  // v is just the recovery_id (0 or 1)
  signed.v |> should.equal("0x1")
}

pub fn sign_eip1559_eth_transfer_mainnet_hash_test() {
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

  transaction.get_eip1559_transaction_hash(signed)
  |> should.equal(
    "0x9bab8d3e7893fd77088c164d2834ddcb9fbfa73c93bdee90e396e3e27141f1ba",
  )
}

// =============================================================================
// EIP-1559 Vector 2: ETH transfer, Sepolia (chain ID 11155111), nonce 42
// cast mktx --private-key 0xac09...ff80 --chain 11155111 --nonce 42
//   --priority-gas-price 2000000000 --gas-price 50000000000
//   --gas-limit 21000 --value 0.5ether <recipient>
// =============================================================================

pub fn sign_eip1559_eth_transfer_sepolia_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let assert Ok(tx) =
    transaction.create_eip1559_transaction(
      recipient,
      "0x6f05b59d3b20000",
      "0x5208",
      "0xba43b7400",
      "0x77359400",
      "0x2a",
      "0x",
      11_155_111,
      [],
    )
  let assert Ok(signed) = transaction.sign_eip1559_transaction(tx, w)

  signed.raw_transaction
  |> should.equal(
    "0x02f87683aa36a72a8477359400850ba43b74008252089470997970c51812dc3a010c7d01b50e0d17dc79c88806f05b59d3b2000080c001a02277911a1d78c0b1e244762708aab7b8a1f9c780ce66bab4f9ef381e47fd3912a05f030193d4ee9bbbc53bd2a5721a957e8cedcbbe595fe33be512eaa5a0568c97",
  )
}

pub fn sign_eip1559_eth_transfer_sepolia_hash_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let assert Ok(tx) =
    transaction.create_eip1559_transaction(
      recipient,
      "0x6f05b59d3b20000",
      "0x5208",
      "0xba43b7400",
      "0x77359400",
      "0x2a",
      "0x",
      11_155_111,
      [],
    )
  let assert Ok(signed) = transaction.sign_eip1559_transaction(tx, w)

  transaction.get_eip1559_transaction_hash(signed)
  |> should.equal(
    "0x6a691a96007b0723e8cd9bb1f12755cc4f879a74b5763a3899b3996d2ec49825",
  )
}

// =============================================================================
// EIP-1559 Vector 3: Contract call with calldata
// cast mktx --private-key 0xac09...ff80 --chain 1 --nonce 1
//   --priority-gas-price 1500000000 --gas-price 30000000000
//   --gas-limit 100000 --value 0
//   <recipient> "transfer(address,uint256)" 0xdead...0000 1000000000000000000
// =============================================================================

pub fn sign_eip1559_contract_call_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let calldata =
    "0xa9059cbb000000000000000000000000dead0000000000000000000000000000000000000000000000000000000000000000000000000000000000000de0b6b3a7640000"
  let assert Ok(tx) =
    transaction.create_eip1559_transaction(
      recipient,
      "0x0",
      "0x186a0",
      "0x6fc23ac00",
      "0x59682f00",
      "0x1",
      calldata,
      1,
      [],
    )
  let assert Ok(signed) = transaction.sign_eip1559_transaction(tx, w)

  signed.raw_transaction
  |> should.equal(
    "0x02f8b101018459682f008506fc23ac00830186a09470997970c51812dc3a010c7d01b50e0d17dc79c880b844a9059cbb000000000000000000000000dead0000000000000000000000000000000000000000000000000000000000000000000000000000000000000de0b6b3a7640000c080a004acf85f9244f1bbee4d128df342f21047f82ee421b21f8a92be8d4881114acca055519cd3891534fd64913c8d9881b88f03a9b5b4a17d4173c32e35ac8078988c",
  )
}

pub fn sign_eip1559_contract_call_hash_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let calldata =
    "0xa9059cbb000000000000000000000000dead0000000000000000000000000000000000000000000000000000000000000000000000000000000000000de0b6b3a7640000"
  let assert Ok(tx) =
    transaction.create_eip1559_transaction(
      recipient,
      "0x0",
      "0x186a0",
      "0x6fc23ac00",
      "0x59682f00",
      "0x1",
      calldata,
      1,
      [],
    )
  let assert Ok(signed) = transaction.sign_eip1559_transaction(tx, w)

  // v = 0 for this signature
  signed.v |> should.equal("0x0")

  transaction.get_eip1559_transaction_hash(signed)
  |> should.equal(
    "0x42f60f0698c66d580d3d1c3d13e24f364ba48ffb5dd53fc532554005e892337e",
  )
}

// =============================================================================
// EIP-1559 Vector 4: Transaction with access list
// cast mktx --private-key 0xac09...ff80 --chain 1 --nonce 2
//   --priority-gas-price 1000000000 --gas-price 20000000000
//   --gas-limit 50000 --value 0
//   --access-list '[{"address":"<recipient>","storageKeys":["0x0...01"]}]'
//   <recipient>
// =============================================================================

pub fn sign_eip1559_with_access_list_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let assert Ok(tx) =
    transaction.create_eip1559_transaction(
      recipient,
      "0x0",
      "0xc350",
      "0x4a817c800",
      "0x3b9aca00",
      "0x2",
      "0x",
      1,
      [
        transaction.AccessListEntry(
          address: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
          storage_keys: [
            "0x0000000000000000000000000000000000000000000000000000000000000001",
          ],
        ),
      ],
    )
  let assert Ok(signed) = transaction.sign_eip1559_transaction(tx, w)

  signed.raw_transaction
  |> should.equal(
    "0x02f8a40102843b9aca008504a817c80082c3509470997970c51812dc3a010c7d01b50e0d17dc79c88080f838f79470997970c51812dc3a010c7d01b50e0d17dc79c8e1a0000000000000000000000000000000000000000000000000000000000000000180a083311d92388bb8bbe54d47b4ce1bb646836d59ae263bbb0bbac68a0db95db3a1a058af19624b22330ec6da7d516691d42388ac3ec7c0b57e151ff761ac1ab04ad5",
  )
}

pub fn sign_eip1559_with_access_list_hash_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let assert Ok(tx) =
    transaction.create_eip1559_transaction(
      recipient,
      "0x0",
      "0xc350",
      "0x4a817c800",
      "0x3b9aca00",
      "0x2",
      "0x",
      1,
      [
        transaction.AccessListEntry(
          address: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
          storage_keys: [
            "0x0000000000000000000000000000000000000000000000000000000000000001",
          ],
        ),
      ],
    )
  let assert Ok(signed) = transaction.sign_eip1559_transaction(tx, w)

  transaction.get_eip1559_transaction_hash(signed)
  |> should.equal(
    "0xf34037a1d45d4dfab8bd0f31f8957fc6a97b1a7d9f7250460dcee97a92f33800",
  )
}

// =============================================================================
// Anvil integration tests
// Skips gracefully if anvil is not running on localhost:8545
// Start anvil with: anvil
// =============================================================================

const anvil_url = "http://localhost:8545"

const anvil_chain_id = 31_337

fn anvil_available() -> Bool {
  case client.make_request(anvil_url, "eth_chainId", []) {
    Ok(_) -> True
    Error(_) -> False
  }
}

pub fn anvil_legacy_broadcast_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) = wallet.from_private_key_hex(test_private_key)

      // Query nonce from anvil
      let assert Ok(nonce) =
        methods.get_transaction_count(p, test_address, "pending")

      // Query gas price from anvil
      let assert Ok(gas_price) = methods.get_gas_price(p)

      // Build, sign, broadcast
      let assert Ok(tx) =
        transaction.create_legacy_transaction(
          recipient,
          "0xde0b6b3a7640000",
          "0x5208",
          gas_price,
          nonce,
          "0x",
          anvil_chain_id,
        )
      let assert Ok(signed) = transaction.sign_transaction(tx, w)

      let assert Ok(tx_hash) =
        methods.send_raw_transaction(p, signed.raw_transaction)

      // The returned hash should match what we compute locally
      let expected_hash = transaction.get_transaction_hash(signed)
      tx_hash |> should.equal(expected_hash)

      // Poll for receipt
      let assert Ok(receipt) = methods.get_transaction_receipt(p, tx_hash)
      receipt.transaction_hash
      |> string.lowercase
      |> should.equal(string.lowercase(tx_hash))
    }
  }
}

pub fn anvil_eip1559_broadcast_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) = wallet.from_private_key_hex(test_private_key)

      // Query nonce
      let assert Ok(nonce) =
        methods.get_transaction_count(p, test_address, "pending")

      // Query fee parameters
      let assert Ok(gas_price) = methods.get_gas_price(p)
      let assert Ok(priority_fee) = methods.get_max_priority_fee(p)

      // Build EIP-1559 transaction
      let assert Ok(tx) =
        transaction.create_eip1559_transaction(
          recipient,
          "0xde0b6b3a7640000",
          "0x5208",
          gas_price,
          priority_fee,
          nonce,
          "0x",
          anvil_chain_id,
          [],
        )
      let assert Ok(signed) = transaction.sign_eip1559_transaction(tx, w)

      // Broadcast
      let assert Ok(tx_hash) =
        methods.send_raw_transaction(p, signed.raw_transaction)

      let expected_hash = transaction.get_eip1559_transaction_hash(signed)
      tx_hash |> should.equal(expected_hash)

      // Poll for receipt and verify success
      let assert Ok(receipt) = methods.get_transaction_receipt(p, tx_hash)
      receipt.transaction_hash
      |> string.lowercase
      |> should.equal(string.lowercase(tx_hash))
    }
  }
}

pub fn anvil_fee_history_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(fh) = methods.get_fee_history(p, 4, "latest", [25.0, 75.0])

      // Should return fee data for the requested blocks
      // oldest_block should be a hex string
      string.starts_with(fh.oldest_block, "0x")
      |> should.be_true
    }
  }
}
