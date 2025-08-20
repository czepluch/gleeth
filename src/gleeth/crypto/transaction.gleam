import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeth/crypto/keccak
import gleeth/crypto/secp256k1
import gleeth/crypto/wallet

/// Represents an Ethereum transaction before signing
pub type UnsignedTransaction {
  UnsignedTransaction(
    to: String,
    // Recipient address (empty string for contract creation)
    value: String,
    // Value in wei (as hex string)
    gas_limit: String,
    // Gas limit (as hex string)
    gas_price: String,
    // Gas price in wei (as hex string)
    nonce: String,
    // Transaction nonce (as hex string)
    data: String,
    // Transaction data (as hex string, "0x" for empty)
    chain_id: Int,
    // Network chain ID
  )
}

/// Represents a signed Ethereum transaction
pub type SignedTransaction {
  SignedTransaction(
    to: String,
    value: String,
    gas_limit: String,
    gas_price: String,
    nonce: String,
    data: String,
    chain_id: Int,
    v: String,
    // ECDSA recovery parameter
    r: String,
    // ECDSA signature r component
    s: String,
    // ECDSA signature s component
    raw_transaction: String,
    // RLP-encoded transaction for broadcasting
  )
}

/// EIP-1559 transaction parameters (Type 2 transactions)
pub type Eip1559Transaction {
  Eip1559Transaction(
    to: String,
    value: String,
    gas_limit: String,
    max_fee_per_gas: String,
    // Maximum total fee per gas
    max_priority_fee_per_gas: String,
    // Maximum priority fee per gas (tip)
    nonce: String,
    data: String,
    chain_id: Int,
    access_list: List(AccessListEntry),
    // EIP-2930 access list
  )
}

/// Access list entry for EIP-2930
pub type AccessListEntry {
  AccessListEntry(address: String, storage_keys: List(String))
}

/// Transaction type enumeration
pub type TransactionType {
  Legacy
  // Type 0: Legacy transactions
  AccessList
  // Type 1: EIP-2930 access list transactions
  Eip1559
  // Type 2: EIP-1559 fee market transactions
}

/// Error types for transaction operations
pub type TransactionError {
  InvalidAddress(String)
  InvalidAmount(String)
  InvalidGas(String)
  InvalidNonce(String)
  InvalidChainId(String)
  InvalidData(String)
  SigningFailed(String)
  EncodingFailed(String)
  RlpEncodingNotImplemented
}

// =============================================================================
// Transaction Building
// =============================================================================

/// Create a new unsigned legacy transaction
pub fn create_legacy_transaction(
  to: String,
  value: String,
  gas_limit: String,
  gas_price: String,
  nonce: String,
  data: String,
  chain_id: Int,
) -> Result(UnsignedTransaction, TransactionError) {
  // Validate parameters
  use _ <- result.try(validate_address(to))
  use _ <- result.try(validate_hex_amount(value))
  use _ <- result.try(validate_hex_amount(gas_limit))
  use _ <- result.try(validate_hex_amount(gas_price))
  use _ <- result.try(validate_hex_amount(nonce))
  use _ <- result.try(validate_hex_data(data))
  use _ <- result.try(validate_chain_id(chain_id))

  Ok(UnsignedTransaction(
    to: normalize_address(to),
    value: normalize_hex(value),
    gas_limit: normalize_hex(gas_limit),
    gas_price: normalize_hex(gas_price),
    nonce: normalize_hex(nonce),
    data: normalize_hex_data(data),
    chain_id: chain_id,
  ))
}

/// Create a simple ETH transfer transaction
pub fn create_eth_transfer(
  to: String,
  value_wei: String,
  gas_limit: String,
  gas_price: String,
  nonce: String,
  chain_id: Int,
) -> Result(UnsignedTransaction, TransactionError) {
  create_legacy_transaction(
    to,
    value_wei,
    gas_limit,
    gas_price,
    nonce,
    "0x",
    chain_id,
  )
}

/// Create a contract interaction transaction
pub fn create_contract_call(
  contract_address: String,
  call_data: String,
  gas_limit: String,
  gas_price: String,
  nonce: String,
  chain_id: Int,
) -> Result(UnsignedTransaction, TransactionError) {
  create_legacy_transaction(
    contract_address,
    "0x0",
    // No ETH value
    gas_limit,
    gas_price,
    nonce,
    call_data,
    chain_id,
  )
}

// =============================================================================
// Transaction Signing
// =============================================================================

/// Sign a transaction with a wallet
/// Note: This is a simplified implementation that doesn't use proper RLP encoding
/// In production, you would need a proper RLP encoder for Ethereum transactions
pub fn sign_transaction(
  transaction: UnsignedTransaction,
  wallet: wallet.Wallet,
) -> Result(SignedTransaction, TransactionError) {
  // Create the transaction hash for signing
  use signing_hash <- result.try(create_signing_hash(transaction))

  // Sign the hash
  use signature <- result.try(
    wallet.sign_hash(wallet, signing_hash)
    |> result.map_error(fn(err) {
      SigningFailed(
        "Failed to sign transaction: " <> wallet.error_to_string(err),
      )
    }),
  )

  // Extract v, r, s from signature
  let #(v_int, r_hex, s_hex) = secp256k1.signature_to_vrs(signature)

  // For EIP-155 (replay protection), v = recovery_id + 2 * chain_id + 35
  let eip155_v = case transaction.chain_id {
    1 -> v_int + 2 * transaction.chain_id + 35
    // Mainnet and other networks
    _ -> v_int + 2 * transaction.chain_id + 35
  }

  let v_hex = "0x" <> int.to_base16(eip155_v) |> string.lowercase

  // Create raw transaction (placeholder - would need proper RLP encoding)
  let raw_tx =
    create_raw_transaction_placeholder(transaction, v_hex, r_hex, s_hex)

  Ok(SignedTransaction(
    to: transaction.to,
    value: transaction.value,
    gas_limit: transaction.gas_limit,
    gas_price: transaction.gas_price,
    nonce: transaction.nonce,
    data: transaction.data,
    chain_id: transaction.chain_id,
    v: v_hex,
    r: r_hex,
    s: s_hex,
    raw_transaction: raw_tx,
  ))
}

// =============================================================================
// Transaction Hashing
// =============================================================================

/// Create the hash that needs to be signed for a transaction
/// This is a simplified version - proper implementation would use RLP encoding
fn create_signing_hash(
  transaction: UnsignedTransaction,
) -> Result(BitArray, TransactionError) {
  // For EIP-155 transactions, we include chain_id in the signing hash
  // Format: RLP([nonce, gasPrice, gasLimit, to, value, data, chainId, 0, 0])
  // This is a simplified concatenation - proper implementation needs RLP

  let chain_id_hex = "0x" <> int.to_base16(transaction.chain_id)

  let signing_data =
    transaction.nonce
    <> transaction.gas_price
    <> transaction.gas_limit
    <> transaction.to
    <> transaction.value
    <> transaction.data
    <> chain_id_hex
    <> "0x"
    <> "0x"

  let signing_bytes = bit_array.from_string(signing_data)
  let hash = keccak.keccak256_binary(signing_bytes)

  Ok(hash)
}

// =============================================================================
// Raw Transaction Creation
// =============================================================================

/// Create a raw transaction string (placeholder implementation)
/// In production, this would use proper RLP encoding
fn create_raw_transaction_placeholder(
  _transaction: UnsignedTransaction,
  v: String,
  r: String,
  s: String,
) -> String {
  // This is a placeholder that doesn't create a valid raw transaction
  // Proper implementation would need RLP encoding library
  "0x" <> "PLACEHOLDER_RAW_TRANSACTION_" <> v <> r <> s
}

// =============================================================================
// Validation Functions
// =============================================================================

/// Validate Ethereum address format
fn validate_address(address: String) -> Result(Nil, TransactionError) {
  let cleaned = case string.starts_with(address, "0x") {
    True -> string.drop_start(address, 2)
    False -> address
  }

  case string.length(cleaned) {
    40 -> {
      case string.to_graphemes(cleaned) |> list.all(is_hex_char) {
        True -> Ok(Nil)
        False -> Error(InvalidAddress("Address contains non-hex characters"))
      }
    }
    0 -> Ok(Nil)
    // Empty address for contract creation
    _ -> Error(InvalidAddress("Address must be 40 hex characters"))
  }
}

/// Validate hex amount (like value, gas, nonce)
fn validate_hex_amount(amount: String) -> Result(Nil, TransactionError) {
  let cleaned = case string.starts_with(amount, "0x") {
    True -> string.drop_start(amount, 2)
    False -> amount
  }

  case string.to_graphemes(cleaned) |> list.all(is_hex_char) {
    True -> Ok(Nil)
    False -> Error(InvalidAmount("Amount contains non-hex characters"))
  }
}

/// Validate hex data
fn validate_hex_data(data: String) -> Result(Nil, TransactionError) {
  case data {
    "0x" -> Ok(Nil)
    // Empty data
    _ -> {
      let cleaned = case string.starts_with(data, "0x") {
        True -> string.drop_start(data, 2)
        False -> data
      }

      case string.to_graphemes(cleaned) |> list.all(is_hex_char) {
        True -> Ok(Nil)
        False -> Error(InvalidData("Data contains non-hex characters"))
      }
    }
  }
}

/// Validate chain ID
fn validate_chain_id(chain_id: Int) -> Result(Nil, TransactionError) {
  case chain_id > 0 {
    True -> Ok(Nil)
    False -> Error(InvalidChainId("Chain ID must be positive"))
  }
}

/// Check if character is valid hex
fn is_hex_char(char: String) -> Bool {
  case char {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    "a" | "b" | "c" | "d" | "e" | "f" -> True
    "A" | "B" | "C" | "D" | "E" | "F" -> True
    _ -> False
  }
}

// =============================================================================
// Normalization Functions
// =============================================================================

/// Normalize address to lowercase with 0x prefix
fn normalize_address(address: String) -> String {
  case address {
    "" -> ""
    _ -> {
      let cleaned = case string.starts_with(address, "0x") {
        True -> string.drop_start(address, 2)
        False -> address
      }
      "0x" <> string.lowercase(cleaned)
    }
  }
}

/// Normalize hex string to lowercase with 0x prefix
fn normalize_hex(hex: String) -> String {
  let cleaned = case string.starts_with(hex, "0x") {
    True -> string.drop_start(hex, 2)
    False -> hex
  }
  "0x" <> string.lowercase(cleaned)
}

/// Normalize hex data (keep "0x" for empty data)
fn normalize_hex_data(data: String) -> String {
  case data {
    "" -> "0x"
    "0x" -> "0x"
    _ -> normalize_hex(data)
  }
}

// =============================================================================
// Utility Functions
// =============================================================================

/// Convert signed transaction to string for display
pub fn signed_transaction_to_string(tx: SignedTransaction) -> String {
  "SignedTransaction {\n"
  <> "  to: "
  <> tx.to
  <> "\n"
  <> "  value: "
  <> tx.value
  <> "\n"
  <> "  gas_limit: "
  <> tx.gas_limit
  <> "\n"
  <> "  gas_price: "
  <> tx.gas_price
  <> "\n"
  <> "  nonce: "
  <> tx.nonce
  <> "\n"
  <> "  data: "
  <> tx.data
  <> "\n"
  <> "  chain_id: "
  <> int.to_string(tx.chain_id)
  <> "\n"
  <> "  v: "
  <> tx.v
  <> "\n"
  <> "  r: "
  <> tx.r
  <> "\n"
  <> "  s: "
  <> tx.s
  <> "\n"
  <> "  raw: "
  <> tx.raw_transaction
  <> "\n"
  <> "}"
}

/// Get transaction hash from signed transaction
pub fn get_transaction_hash(tx: SignedTransaction) -> String {
  // This would normally hash the RLP-encoded transaction
  // For now, return a placeholder
  keccak.keccak256_hex(tx.raw_transaction)
}

/// Convert TransactionError to string
pub fn error_to_string(error: TransactionError) -> String {
  case error {
    InvalidAddress(msg) -> "Invalid address: " <> msg
    InvalidAmount(msg) -> "Invalid amount: " <> msg
    InvalidGas(msg) -> "Invalid gas: " <> msg
    InvalidNonce(msg) -> "Invalid nonce: " <> msg
    InvalidChainId(msg) -> "Invalid chain ID: " <> msg
    InvalidData(msg) -> "Invalid data: " <> msg
    SigningFailed(msg) -> "Signing failed: " <> msg
    EncodingFailed(msg) -> "Encoding failed: " <> msg
    RlpEncodingNotImplemented -> "RLP encoding not yet implemented"
  }
}

// =============================================================================
// Common Chain IDs
// =============================================================================

/// Ethereum mainnet chain ID
pub const mainnet_chain_id = 1

/// Goerli testnet chain ID
pub const goerli_chain_id = 5

/// Sepolia testnet chain ID
pub const sepolia_chain_id = 11_155_111

/// Polygon mainnet chain ID
pub const polygon_chain_id = 137

/// Arbitrum One chain ID
pub const arbitrum_chain_id = 42_161

/// Optimism mainnet chain ID
pub const optimism_chain_id = 10
