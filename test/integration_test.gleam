/// Integration tests against anvil.
/// These tests require anvil running on localhost:8545.
/// They skip gracefully if anvil is not available.
///
/// Start anvil with: anvil
import gleam/int
import gleam/string
import gleeth/crypto/transaction
import gleeth/crypto/wallet
import gleeth/provider
import gleeth/rpc/client
import gleeth/rpc/methods
import gleeunit/should

// Anvil default accounts
const private_key_0 = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

const address_0 = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

const private_key_1 = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"

const address_1 = "0x70997970c51812dc3a010c7d01b50e0d17dc79c8"

const anvil_url = "http://localhost:8545"

const anvil_chain_id = 31_337

// Counter contract bytecode (no constructor args)
// Solidity: count storage, increment(), getCount(), failAlways()
const counter_bytecode = "0x6080604052348015600e575f5ffd5b5061023f8061001c5f395ff3fe608060405234801561000f575f5ffd5b506004361061004a575f3560e01c806306661abd1461004e5780634940e5e21461006c578063a87d942c14610076578063d09de08a14610094575b5f5ffd5b61005661009e565b6040516100639190610118565b60405180910390f35b6100746100a3565b005b61007e6100de565b60405161008b9190610118565b60405180910390f35b61009c6100e6565b005b5f5481565b6040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016100d59061018b565b60405180910390fd5b5f5f54905090565b60015f5f8282546100f791906101d6565b92505081905550565b5f819050919050565b61011281610100565b82525050565b5f60208201905061012b5f830184610109565b92915050565b5f82825260208201905092915050565b7f616c77617973206661696c7300000000000000000000000000000000000000005f82015250565b5f610175600c83610131565b915061018082610141565b602082019050919050565b5f6020820190508181035f8301526101a281610169565b9050919050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b5f6101e082610100565b91506101eb83610100565b9250828201905080821115610203576102026101a9565b5b9291505056fea2646970667358221220e18be73e90078f4886a349bc2dd104c24c9e81430ac0dd3dd4268a44346d436464736f6c63430008210033"

fn anvil_available() -> Bool {
  case client.make_request(anvil_url, "eth_chainId", []) {
    Ok(_) -> True
    Error(_) -> False
  }
}

fn get_nonce(p: provider.Provider, address: String) -> String {
  let assert Ok(nonce) = methods.get_transaction_count(p, address, "pending")
  nonce
}

fn get_gas_price(p: provider.Provider) -> String {
  let assert Ok(gas_price) = methods.get_gas_price(p)
  gas_price
}

fn int_to_hex(n: Int) -> String {
  case n {
    0 -> "0x0"
    _ -> "0x" <> string.lowercase(int.to_base16(n))
  }
}

// =============================================================================
// Contract deployment
// =============================================================================

pub fn anvil_deploy_contract_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) = wallet.from_private_key_hex(private_key_0)

      let nonce = get_nonce(p, address_0)
      let gas_price = get_gas_price(p)

      // Deploy counter contract (empty to, bytecode as data)
      let assert Ok(tx) =
        transaction.create_legacy_transaction(
          "",
          "0x0",
          "0x200000",
          gas_price,
          nonce,
          counter_bytecode,
          anvil_chain_id,
        )
      let assert Ok(signed) = transaction.sign_transaction(tx, w)

      let assert Ok(tx_hash) =
        methods.send_raw_transaction(p, signed.raw_transaction)

      // Verify receipt has contract address
      let assert Ok(receipt) = methods.wait_for_receipt(p, tx_hash)
      receipt.contract_address
      |> string.length
      |> should.equal(42)

      // The deployed contract address should start with 0x
      string.starts_with(receipt.contract_address, "0x")
      |> should.be_true
    }
  }
}

pub fn anvil_deploy_and_call_contract_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) = wallet.from_private_key_hex(private_key_0)

      let nonce = get_nonce(p, address_0)
      let gas_price = get_gas_price(p)

      // Deploy
      let assert Ok(tx) =
        transaction.create_legacy_transaction(
          "",
          "0x0",
          "0x200000",
          gas_price,
          nonce,
          counter_bytecode,
          anvil_chain_id,
        )
      let assert Ok(signed) = transaction.sign_transaction(tx, w)
      let assert Ok(tx_hash) =
        methods.send_raw_transaction(p, signed.raw_transaction)
      let assert Ok(receipt) = methods.wait_for_receipt(p, tx_hash)
      let contract_address = receipt.contract_address

      // Call getCount() - selector 0xa87d942c
      let assert Ok(result) =
        methods.call_contract(p, contract_address, "0xa87d942c")

      // Should return 0 (uint256)
      result
      |> should.equal(
        "0x0000000000000000000000000000000000000000000000000000000000000000",
      )

      // Send increment() transaction - selector 0xd09de08a
      let nonce2 = get_nonce(p, address_0)
      let assert Ok(inc_tx) =
        transaction.create_legacy_transaction(
          contract_address,
          "0x0",
          "0x100000",
          gas_price,
          nonce2,
          "0xd09de08a",
          anvil_chain_id,
        )
      let assert Ok(inc_signed) = transaction.sign_transaction(inc_tx, w)
      let assert Ok(_inc_hash) =
        methods.send_raw_transaction(p, inc_signed.raw_transaction)

      // Call getCount() again - should return 1
      let assert Ok(result2) =
        methods.call_contract(p, contract_address, "0xa87d942c")
      result2
      |> should.equal(
        "0x0000000000000000000000000000000000000000000000000000000000000001",
      )
    }
  }
}

// =============================================================================
// Error paths
// =============================================================================

pub fn anvil_insufficient_gas_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) = wallet.from_private_key_hex(private_key_0)

      let nonce = get_nonce(p, address_0)
      let gas_price = get_gas_price(p)

      // Send with gas limit of 1 (way too low)
      let assert Ok(tx) =
        transaction.create_legacy_transaction(
          address_1,
          "0xde0b6b3a7640000",
          "0x1",
          gas_price,
          nonce,
          "0x",
          anvil_chain_id,
        )
      let assert Ok(signed) = transaction.sign_transaction(tx, w)

      // Broadcasting should fail or the receipt should show failure
      let result = methods.send_raw_transaction(p, signed.raw_transaction)
      let _ = result |> should.be_error
      Nil
    }
  }
}

pub fn anvil_insufficient_balance_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      // Use account 1 and try to send more ETH than it has
      let assert Ok(w) = wallet.from_private_key_hex(private_key_1)

      let nonce = get_nonce(p, address_1)
      let gas_price = get_gas_price(p)

      // Try to send 999999 ETH (way more than the default 10000 ETH)
      // 999999 ETH = 0xD3C20DEE1639F99C0000 wei
      let assert Ok(tx) =
        transaction.create_legacy_transaction(
          address_0,
          "0xD3C20DEE1639F99C0000",
          "0x5208",
          gas_price,
          nonce,
          "0x",
          anvil_chain_id,
        )
      let assert Ok(signed) = transaction.sign_transaction(tx, w)

      // Should fail with insufficient funds
      let result = methods.send_raw_transaction(p, signed.raw_transaction)
      let _ = result |> should.be_error
      Nil
    }
  }
}

pub fn anvil_revert_error_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) = wallet.from_private_key_hex(private_key_0)

      // First deploy the counter contract
      let nonce = get_nonce(p, address_0)
      let gas_price = get_gas_price(p)

      let assert Ok(tx) =
        transaction.create_legacy_transaction(
          "",
          "0x0",
          "0x200000",
          gas_price,
          nonce,
          counter_bytecode,
          anvil_chain_id,
        )
      let assert Ok(signed) = transaction.sign_transaction(tx, w)
      let assert Ok(tx_hash) =
        methods.send_raw_transaction(p, signed.raw_transaction)
      let assert Ok(receipt) = methods.wait_for_receipt(p, tx_hash)
      let contract_address = receipt.contract_address

      // Call failAlways() via eth_call - selector 0x4940e5e2
      // This should revert with "always fails"
      let result = methods.call_contract(p, contract_address, "0x4940e5e2")
      let _ = result |> should.be_error
      Nil
    }
  }
}

pub fn anvil_nonce_too_low_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) = wallet.from_private_key_hex(private_key_0)

      let gas_price = get_gas_price(p)

      // First send a valid transaction to advance the nonce
      let nonce = get_nonce(p, address_0)
      let assert Ok(tx) =
        transaction.create_legacy_transaction(
          address_1,
          "0x1",
          "0x5208",
          gas_price,
          nonce,
          "0x",
          anvil_chain_id,
        )
      let assert Ok(signed) = transaction.sign_transaction(tx, w)
      let assert Ok(_) = methods.send_raw_transaction(p, signed.raw_transaction)

      // Now try to send with the same (now too low) nonce
      let assert Ok(tx2) =
        transaction.create_legacy_transaction(
          address_1,
          "0x1",
          "0x5208",
          gas_price,
          nonce,
          "0x",
          anvil_chain_id,
        )
      let assert Ok(signed2) = transaction.sign_transaction(tx2, w)

      // Should fail with nonce too low
      let result = methods.send_raw_transaction(p, signed2.raw_transaction)
      let _ = result |> should.be_error
      Nil
    }
  }
}

// =============================================================================
// Multi-transaction sequence
// =============================================================================

pub fn anvil_multi_tx_nonce_sequence_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) = wallet.from_private_key_hex(private_key_0)

      let gas_price = get_gas_price(p)
      let base_nonce = get_nonce(p, address_0)

      // Parse the base nonce to increment manually
      let assert Ok(base_nonce_int) = case
        string.starts_with(base_nonce, "0x")
      {
        True -> {
          let hex_str = string.drop_start(base_nonce, 2)
          int.base_parse(hex_str, 16)
        }
        False -> int.parse(base_nonce)
      }

      // Send 3 transactions in sequence
      let assert Ok(tx1) =
        transaction.create_legacy_transaction(
          address_1,
          "0x1",
          "0x5208",
          gas_price,
          int_to_hex(base_nonce_int),
          "0x",
          anvil_chain_id,
        )
      let assert Ok(signed1) = transaction.sign_transaction(tx1, w)
      let assert Ok(hash1) =
        methods.send_raw_transaction(p, signed1.raw_transaction)

      let assert Ok(tx2) =
        transaction.create_legacy_transaction(
          address_1,
          "0x2",
          "0x5208",
          gas_price,
          int_to_hex(base_nonce_int + 1),
          "0x",
          anvil_chain_id,
        )
      let assert Ok(signed2) = transaction.sign_transaction(tx2, w)
      let assert Ok(hash2) =
        methods.send_raw_transaction(p, signed2.raw_transaction)

      let assert Ok(tx3) =
        transaction.create_legacy_transaction(
          address_1,
          "0x3",
          "0x5208",
          gas_price,
          int_to_hex(base_nonce_int + 2),
          "0x",
          anvil_chain_id,
        )
      let assert Ok(signed3) = transaction.sign_transaction(tx3, w)
      let assert Ok(hash3) =
        methods.send_raw_transaction(p, signed3.raw_transaction)

      // All three should have receipts
      let assert Ok(r1) = methods.get_transaction_receipt(p, hash1)
      let assert Ok(r2) = methods.get_transaction_receipt(p, hash2)
      let assert Ok(r3) = methods.get_transaction_receipt(p, hash3)

      // Verify hashes match
      r1.transaction_hash
      |> string.lowercase
      |> should.equal(string.lowercase(hash1))
      r2.transaction_hash
      |> string.lowercase
      |> should.equal(string.lowercase(hash2))
      r3.transaction_hash
      |> string.lowercase
      |> should.equal(string.lowercase(hash3))
    }
  }
}

// =============================================================================
// EIP-1559 integration
// =============================================================================

pub fn anvil_eip1559_deploy_and_interact_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) = wallet.from_private_key_hex(private_key_0)

      let nonce = get_nonce(p, address_0)
      let assert Ok(gas_price) = methods.get_gas_price(p)
      let assert Ok(priority_fee) = methods.get_max_priority_fee(p)

      // Deploy counter with EIP-1559
      let assert Ok(tx) =
        transaction.create_eip1559_transaction(
          "",
          "0x0",
          "0x200000",
          gas_price,
          priority_fee,
          nonce,
          counter_bytecode,
          anvil_chain_id,
          [],
        )
      let assert Ok(signed) = transaction.sign_eip1559_transaction(tx, w)
      let assert Ok(tx_hash) =
        methods.send_raw_transaction(p, signed.raw_transaction)
      let assert Ok(receipt) = methods.wait_for_receipt(p, tx_hash)

      // Should have a contract address
      string.length(receipt.contract_address)
      |> should.equal(42)

      // Call getCount()
      let assert Ok(result) =
        methods.call_contract(p, receipt.contract_address, "0xa87d942c")
      result
      |> should.equal(
        "0x0000000000000000000000000000000000000000000000000000000000000000",
      )
    }
  }
}
