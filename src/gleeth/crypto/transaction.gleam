import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeth/crypto/keccak
import gleeth/crypto/wallet
import gleeth/encoding/rlp
import gleeth/utils/hex

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

/// Represents a signed EIP-1559 (Type 2) transaction
pub type SignedEip1559Transaction {
  SignedEip1559Transaction(
    to: String,
    value: String,
    gas_limit: String,
    max_fee_per_gas: String,
    max_priority_fee_per_gas: String,
    nonce: String,
    data: String,
    chain_id: Int,
    access_list: List(AccessListEntry),
    v: String,
    r: String,
    s: String,
    raw_transaction: String,
  )
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
}

// =============================================================================
// Transaction Building
// =============================================================================

/// Create a new unsigned legacy (Type 0) transaction.
///
/// All numeric parameters must be `0x`-prefixed hex strings. The Ethereum
/// JSON-RPC API returns values in this format, so results from
/// `methods.get_gas_price`, `methods.get_transaction_count`, etc. can be
/// passed directly.
///
/// - `to` - recipient address (`"0x..."`, 40 hex chars after prefix)
/// - `value` - amount in wei as hex (e.g. `"0xde0b6b3a7640000"` for 1 ETH)
/// - `gas_limit` - gas limit as hex (e.g. `"0x5208"` for 21000)
/// - `gas_price` - gas price in wei as hex
/// - `nonce` - sender's transaction count as hex
/// - `data` - calldata as hex (`"0x"` for simple transfers)
/// - `chain_id` - network chain ID as integer (1 for mainnet, 11155111 for Sepolia)
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(tx) = transaction.create_legacy_transaction(
///   "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
///   "0xde0b6b3a7640000",  // 1 ETH in wei
///   "0x5208",              // 21000 gas
///   "0x3b9aca00",          // 1 gwei gas price
///   "0x0",                 // nonce 0
///   "0x",                  // no calldata
///   1,                     // mainnet
/// )
/// ```
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

/// Create a simple ETH transfer transaction (no calldata).
///
/// Convenience wrapper around `create_legacy_transaction` with `data` set to
/// `"0x"`. All numeric parameters are `0x`-prefixed hex strings.
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

/// Create a contract interaction transaction (zero value).
///
/// Convenience wrapper around `create_legacy_transaction` with `value` set to
/// `"0x0"`. All numeric parameters are `0x`-prefixed hex strings.
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

/// Create and validate an EIP-1559 (Type 2) transaction.
///
/// All numeric parameters must be `0x`-prefixed hex strings. Fee parameters
/// from `methods.get_gas_price` and `methods.get_max_priority_fee` can be
/// passed directly.
///
/// - `to` - recipient address
/// - `value` - amount in wei as hex
/// - `gas_limit` - gas limit as hex
/// - `max_fee_per_gas` - maximum total fee per gas in wei as hex
/// - `max_priority_fee_per_gas` - tip per gas in wei as hex
/// - `nonce` - sender's transaction count as hex
/// - `data` - calldata as hex (`"0x"` for simple transfers)
/// - `chain_id` - network chain ID as integer
/// - `access_list` - EIP-2930 access list (pass `[]` if not needed)
pub fn create_eip1559_transaction(
  to: String,
  value: String,
  gas_limit: String,
  max_fee_per_gas: String,
  max_priority_fee_per_gas: String,
  nonce: String,
  data: String,
  chain_id: Int,
  access_list: List(AccessListEntry),
) -> Result(Eip1559Transaction, TransactionError) {
  use _ <- result.try(validate_address(to))
  use _ <- result.try(validate_hex_amount(value))
  use _ <- result.try(validate_hex_amount(gas_limit))
  use _ <- result.try(validate_hex_amount(max_fee_per_gas))
  use _ <- result.try(validate_hex_amount(max_priority_fee_per_gas))
  use _ <- result.try(validate_hex_amount(nonce))
  use _ <- result.try(validate_hex_data(data))
  use _ <- result.try(validate_chain_id(chain_id))

  Ok(Eip1559Transaction(
    to: normalize_address(to),
    value: normalize_hex(value),
    gas_limit: normalize_hex(gas_limit),
    max_fee_per_gas: normalize_hex(max_fee_per_gas),
    max_priority_fee_per_gas: normalize_hex(max_priority_fee_per_gas),
    nonce: normalize_hex(nonce),
    data: normalize_hex_data(data),
    chain_id: chain_id,
    access_list: access_list,
  ))
}

// =============================================================================
// Transaction Signing
// =============================================================================

/// Sign a legacy (EIP-155) transaction with a wallet.
/// Produces an RLP-encoded raw transaction suitable for eth_sendRawTransaction.
pub fn sign_transaction(
  transaction: UnsignedTransaction,
  wallet: wallet.Wallet,
) -> Result(SignedTransaction, TransactionError) {
  let signing_hash = create_signing_hash(transaction)

  use signature <- result.try(
    wallet.sign_hash(wallet, signing_hash)
    |> result.map_error(fn(err) {
      SigningFailed(
        "Failed to sign transaction: " <> wallet.error_to_string(err),
      )
    }),
  )

  // EIP-155: v = recovery_id + 2 * chain_id + 35
  let eip155_v = signature.recovery_id + 2 * transaction.chain_id + 35
  let v_hex = "0x" <> string.lowercase(int.to_base16(eip155_v))
  let r_hex = hex.encode(signature.r)
  let s_hex = hex.encode(signature.s)

  let raw_tx =
    create_raw_transaction(transaction, eip155_v, signature.r, signature.s)

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

/// Sign an EIP-1559 (Type 2) transaction with a wallet.
/// Produces a type-prefixed RLP-encoded raw transaction: 0x02 || RLP([...]).
pub fn sign_eip1559_transaction(
  transaction: Eip1559Transaction,
  wallet: wallet.Wallet,
) -> Result(SignedEip1559Transaction, TransactionError) {
  let signing_hash = create_eip1559_signing_hash(transaction)

  use signature <- result.try(
    wallet.sign_hash(wallet, signing_hash)
    |> result.map_error(fn(err) {
      SigningFailed(
        "Failed to sign transaction: " <> wallet.error_to_string(err),
      )
    }),
  )

  // EIP-1559: v is just the recovery_id (0 or 1)
  let v = signature.recovery_id
  let v_hex = "0x" <> string.lowercase(int.to_base16(v))
  let r_hex = hex.encode(signature.r)
  let s_hex = hex.encode(signature.s)

  let raw_tx =
    create_eip1559_raw_transaction(transaction, v, signature.r, signature.s)

  Ok(SignedEip1559Transaction(
    to: transaction.to,
    value: transaction.value,
    gas_limit: transaction.gas_limit,
    max_fee_per_gas: transaction.max_fee_per_gas,
    max_priority_fee_per_gas: transaction.max_priority_fee_per_gas,
    nonce: transaction.nonce,
    data: transaction.data,
    chain_id: transaction.chain_id,
    access_list: transaction.access_list,
    v: v_hex,
    r: r_hex,
    s: s_hex,
    raw_transaction: raw_tx,
  ))
}

// =============================================================================
// Transaction Encoding
// =============================================================================

/// EIP-155 signing hash: keccak256(RLP([nonce, gasPrice, gasLimit, to, value, data, chainId, 0, 0]))
fn create_signing_hash(transaction: UnsignedTransaction) -> BitArray {
  let items =
    rlp.RlpList([
      rlp.encode_hex_field(transaction.nonce),
      rlp.encode_hex_field(transaction.gas_price),
      rlp.encode_hex_field(transaction.gas_limit),
      encode_raw_hex(transaction.to),
      rlp.encode_hex_field(transaction.value),
      encode_raw_hex(transaction.data),
      rlp.encode_int(transaction.chain_id),
      rlp.encode_int(0),
      rlp.encode_int(0),
    ])
  keccak.keccak256_binary(rlp.encode(items))
}

/// RLP-encode the signed transaction: [nonce, gasPrice, gasLimit, to, value, data, v, r, s]
fn create_raw_transaction(
  transaction: UnsignedTransaction,
  v: Int,
  r: BitArray,
  s: BitArray,
) -> String {
  let items =
    rlp.RlpList([
      rlp.encode_hex_field(transaction.nonce),
      rlp.encode_hex_field(transaction.gas_price),
      rlp.encode_hex_field(transaction.gas_limit),
      encode_raw_hex(transaction.to),
      rlp.encode_hex_field(transaction.value),
      encode_raw_hex(transaction.data),
      rlp.encode_int(v),
      rlp.RlpBytes(strip_leading_zeros(r)),
      rlp.RlpBytes(strip_leading_zeros(s)),
    ])
  hex.encode(rlp.encode(items))
}

/// EIP-1559 signing hash: keccak256(0x02 || RLP([chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, value, data, accessList]))
fn create_eip1559_signing_hash(transaction: Eip1559Transaction) -> BitArray {
  let items =
    rlp.RlpList([
      rlp.encode_int(transaction.chain_id),
      rlp.encode_hex_field(transaction.nonce),
      rlp.encode_hex_field(transaction.max_priority_fee_per_gas),
      rlp.encode_hex_field(transaction.max_fee_per_gas),
      rlp.encode_hex_field(transaction.gas_limit),
      encode_raw_hex(transaction.to),
      rlp.encode_hex_field(transaction.value),
      encode_raw_hex(transaction.data),
      encode_access_list(transaction.access_list),
    ])
  let payload = rlp.encode(items)
  keccak.keccak256_binary(<<0x02, payload:bits>>)
}

/// RLP-encode the signed EIP-1559 transaction: 0x02 || RLP([chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, value, data, accessList, v, r, s])
fn create_eip1559_raw_transaction(
  transaction: Eip1559Transaction,
  v: Int,
  r: BitArray,
  s: BitArray,
) -> String {
  let items =
    rlp.RlpList([
      rlp.encode_int(transaction.chain_id),
      rlp.encode_hex_field(transaction.nonce),
      rlp.encode_hex_field(transaction.max_priority_fee_per_gas),
      rlp.encode_hex_field(transaction.max_fee_per_gas),
      rlp.encode_hex_field(transaction.gas_limit),
      encode_raw_hex(transaction.to),
      rlp.encode_hex_field(transaction.value),
      encode_raw_hex(transaction.data),
      encode_access_list(transaction.access_list),
      rlp.encode_int(v),
      rlp.RlpBytes(strip_leading_zeros(r)),
      rlp.RlpBytes(strip_leading_zeros(s)),
    ])
  let payload = rlp.encode(items)
  hex.encode(<<0x02, payload:bits>>)
}

/// Encode an access list as an RLP list of [address, [storageKeys]] entries
fn encode_access_list(entries: List(AccessListEntry)) -> rlp.RlpItem {
  rlp.RlpList(list.map(entries, encode_access_list_entry))
}

fn encode_access_list_entry(entry: AccessListEntry) -> rlp.RlpItem {
  let storage_keys = list.map(entry.storage_keys, encode_raw_hex)
  rlp.RlpList([encode_raw_hex(entry.address), rlp.RlpList(storage_keys)])
}

/// Encode a hex string as raw bytes without stripping leading zeros.
/// Used for address and data fields which are byte strings, not integers.
fn encode_raw_hex(hex_string: String) -> rlp.RlpItem {
  case hex.decode(hex_string) {
    Ok(bytes) -> rlp.RlpBytes(bytes)
    Error(_) -> rlp.RlpBytes(<<>>)
  }
}

/// Strip leading zero bytes for minimal big-endian integer encoding
fn strip_leading_zeros(data: BitArray) -> BitArray {
  case data {
    <<0:8, rest:bits>> -> strip_leading_zeros(rest)
    _ -> data
  }
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

/// Get transaction hash from a signed legacy transaction
pub fn get_transaction_hash(tx: SignedTransaction) -> String {
  hash_raw_transaction(tx.raw_transaction)
}

/// Get transaction hash from a signed EIP-1559 transaction
pub fn get_eip1559_transaction_hash(tx: SignedEip1559Transaction) -> String {
  hash_raw_transaction(tx.raw_transaction)
}

/// Hash a raw transaction hex string to get its transaction hash
pub fn hash_raw_transaction(raw_transaction: String) -> String {
  case hex.decode(raw_transaction) {
    Ok(raw_bytes) -> hex.encode(keccak.keccak256_binary(raw_bytes))
    Error(_) -> ""
  }
}

/// Convert signed EIP-1559 transaction to string for display
pub fn signed_eip1559_transaction_to_string(
  tx: SignedEip1559Transaction,
) -> String {
  "SignedEip1559Transaction {\n"
  <> "  to: "
  <> tx.to
  <> "\n"
  <> "  value: "
  <> tx.value
  <> "\n"
  <> "  gas_limit: "
  <> tx.gas_limit
  <> "\n"
  <> "  max_fee_per_gas: "
  <> tx.max_fee_per_gas
  <> "\n"
  <> "  max_priority_fee_per_gas: "
  <> tx.max_priority_fee_per_gas
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

// =============================================================================
// Transaction Decoding
// =============================================================================

/// A decoded transaction, either legacy or EIP-1559.
pub type DecodedTransaction {
  DecodedLegacy(SignedTransaction)
  DecodedEip1559(SignedEip1559Transaction)
}

/// Decode a raw transaction hex string, auto-detecting the type.
/// Legacy transactions start with an RLP list prefix (0xc0-0xff).
/// EIP-1559 transactions start with 0x02.
pub fn decode(raw_hex: String) -> Result(DecodedTransaction, TransactionError) {
  use raw_bytes <- result.try(
    hex.decode(raw_hex)
    |> result.map_error(fn(_) { EncodingFailed("Invalid hex string") }),
  )
  case raw_bytes {
    <<0x02, _rest:bits>> -> {
      use tx <- result.map(decode_eip1559(raw_hex))
      DecodedEip1559(tx)
    }
    _ -> {
      use tx <- result.map(decode_legacy(raw_hex))
      DecodedLegacy(tx)
    }
  }
}

/// Decode a raw signed legacy transaction from its RLP-encoded hex string.
/// Recovers chain_id from the EIP-155 v value: chain_id = (v - 35) / 2.
pub fn decode_legacy(
  raw_hex: String,
) -> Result(SignedTransaction, TransactionError) {
  use raw_bytes <- result.try(
    hex.decode(raw_hex)
    |> result.map_error(fn(_) { EncodingFailed("Invalid hex string") }),
  )
  use rlp_item <- result.try(
    rlp.decode(raw_bytes)
    |> result.map_error(fn(_) { EncodingFailed("Invalid RLP encoding") }),
  )
  case rlp_item {
    rlp.RlpList(items) -> decode_legacy_items(items, raw_hex)
    _ -> Error(EncodingFailed("Expected RLP list for legacy transaction"))
  }
}

fn decode_legacy_items(
  items: List(rlp.RlpItem),
  raw_hex: String,
) -> Result(SignedTransaction, TransactionError) {
  case items {
    [
      nonce_rlp,
      gas_price_rlp,
      gas_limit_rlp,
      to_rlp,
      value_rlp,
      data_rlp,
      v_rlp,
      r_rlp,
      s_rlp,
    ] -> {
      let nonce = rlp_to_hex_amount(nonce_rlp)
      let gas_price = rlp_to_hex_amount(gas_price_rlp)
      let gas_limit = rlp_to_hex_amount(gas_limit_rlp)
      let to = rlp_to_address(to_rlp)
      let value = rlp_to_hex_amount(value_rlp)
      let data = rlp_to_hex_data(data_rlp)
      let v_int = rlp_to_int(v_rlp)
      let r = rlp_to_hex_bytes(r_rlp)
      let s = rlp_to_hex_bytes(s_rlp)

      // EIP-155: v = recovery_id + 2 * chain_id + 35
      // chain_id = (v - 35) / 2
      let chain_id = { v_int - 35 } / 2
      let v_hex = "0x" <> string.lowercase(int.to_base16(v_int))

      Ok(SignedTransaction(
        nonce: nonce,
        gas_price: gas_price,
        gas_limit: gas_limit,
        to: to,
        value: value,
        data: data,
        chain_id: chain_id,
        v: v_hex,
        r: r,
        s: s,
        raw_transaction: raw_hex,
      ))
    }
    _ ->
      Error(EncodingFailed(
        "Legacy transaction must have 9 RLP items, got "
        <> int.to_string(list.length(items)),
      ))
  }
}

/// Decode a raw signed EIP-1559 (Type 2) transaction from its hex string.
/// The input must start with 0x02 (the type prefix).
pub fn decode_eip1559(
  raw_hex: String,
) -> Result(SignedEip1559Transaction, TransactionError) {
  use raw_bytes <- result.try(
    hex.decode(raw_hex)
    |> result.map_error(fn(_) { EncodingFailed("Invalid hex string") }),
  )
  case raw_bytes {
    <<0x02, payload:bits>> -> {
      use rlp_item <- result.try(
        rlp.decode(payload)
        |> result.map_error(fn(_) { EncodingFailed("Invalid RLP encoding") }),
      )
      case rlp_item {
        rlp.RlpList(items) -> decode_eip1559_items(items, raw_hex)
        _ -> Error(EncodingFailed("Expected RLP list for EIP-1559 transaction"))
      }
    }
    _ -> Error(EncodingFailed("EIP-1559 transaction must start with 0x02"))
  }
}

fn decode_eip1559_items(
  items: List(rlp.RlpItem),
  raw_hex: String,
) -> Result(SignedEip1559Transaction, TransactionError) {
  case items {
    [
      chain_id_rlp,
      nonce_rlp,
      max_priority_fee_rlp,
      max_fee_rlp,
      gas_limit_rlp,
      to_rlp,
      value_rlp,
      data_rlp,
      access_list_rlp,
      v_rlp,
      r_rlp,
      s_rlp,
    ] -> {
      let chain_id = rlp_to_int(chain_id_rlp)
      let nonce = rlp_to_hex_amount(nonce_rlp)
      let max_priority_fee = rlp_to_hex_amount(max_priority_fee_rlp)
      let max_fee = rlp_to_hex_amount(max_fee_rlp)
      let gas_limit = rlp_to_hex_amount(gas_limit_rlp)
      let to = rlp_to_address(to_rlp)
      let value = rlp_to_hex_amount(value_rlp)
      let data = rlp_to_hex_data(data_rlp)
      let access_list = decode_access_list(access_list_rlp)
      let v_int = rlp_to_int(v_rlp)
      let v_hex = "0x" <> string.lowercase(int.to_base16(v_int))
      let r = rlp_to_hex_bytes(r_rlp)
      let s = rlp_to_hex_bytes(s_rlp)

      Ok(SignedEip1559Transaction(
        chain_id: chain_id,
        nonce: nonce,
        max_priority_fee_per_gas: max_priority_fee,
        max_fee_per_gas: max_fee,
        gas_limit: gas_limit,
        to: to,
        value: value,
        data: data,
        access_list: access_list,
        v: v_hex,
        r: r,
        s: s,
        raw_transaction: raw_hex,
      ))
    }
    _ ->
      Error(EncodingFailed(
        "EIP-1559 transaction must have 12 RLP items, got "
        <> int.to_string(list.length(items)),
      ))
  }
}

fn decode_access_list(item: rlp.RlpItem) -> List(AccessListEntry) {
  case item {
    rlp.RlpList(entries) -> list.filter_map(entries, decode_access_list_entry)
    _ -> []
  }
}

fn decode_access_list_entry(item: rlp.RlpItem) -> Result(AccessListEntry, Nil) {
  case item {
    rlp.RlpList([addr_rlp, keys_rlp]) -> {
      let address = rlp_to_address(addr_rlp)
      let storage_keys = case keys_rlp {
        rlp.RlpList(keys) ->
          list.map(keys, fn(k) {
            case k {
              rlp.RlpBytes(bytes) ->
                "0x" <> string.lowercase(bit_array.base16_encode(bytes))
              _ -> "0x"
            }
          })
        _ -> []
      }
      Ok(AccessListEntry(address: address, storage_keys: storage_keys))
    }
    _ -> Error(Nil)
  }
}

// =============================================================================
// RLP Item to typed value helpers
// =============================================================================

/// Convert RLP bytes to a hex amount string (0x-prefixed, minimal encoding)
fn rlp_to_hex_amount(item: rlp.RlpItem) -> String {
  case item {
    rlp.RlpBytes(<<>>) -> "0x0"
    rlp.RlpBytes(bytes) -> {
      let hex_str = string.lowercase(bit_array.base16_encode(bytes))
      "0x" <> drop_leading_hex_zeros(hex_str)
    }
    _ -> "0x0"
  }
}

/// Convert RLP bytes to an address string (0x-prefixed, full 40 chars)
fn rlp_to_address(item: rlp.RlpItem) -> String {
  case item {
    rlp.RlpBytes(<<>>) -> ""
    rlp.RlpBytes(bytes) ->
      "0x" <> string.lowercase(bit_array.base16_encode(bytes))
    _ -> ""
  }
}

/// Convert RLP bytes to hex data string (0x-prefixed, preserves all bytes)
fn rlp_to_hex_data(item: rlp.RlpItem) -> String {
  case item {
    rlp.RlpBytes(<<>>) -> "0x"
    rlp.RlpBytes(bytes) ->
      "0x" <> string.lowercase(bit_array.base16_encode(bytes))
    _ -> "0x"
  }
}

/// Convert RLP bytes to hex string preserving all bytes (for r, s values)
fn rlp_to_hex_bytes(item: rlp.RlpItem) -> String {
  case item {
    rlp.RlpBytes(bytes) ->
      "0x" <> string.lowercase(bit_array.base16_encode(bytes))
    _ -> "0x"
  }
}

/// Convert RLP bytes to an integer
fn rlp_to_int(item: rlp.RlpItem) -> Int {
  case item {
    rlp.RlpBytes(<<>>) -> 0
    rlp.RlpBytes(bytes) -> bytes_to_int(bytes)
    _ -> 0
  }
}

/// Convert big-endian bytes to an integer
fn bytes_to_int(data: BitArray) -> Int {
  do_bytes_to_int(data, 0)
}

fn do_bytes_to_int(data: BitArray, acc: Int) -> Int {
  case data {
    <<byte:8, rest:bits>> -> do_bytes_to_int(rest, acc * 256 + byte)
    _ -> acc
  }
}

/// Drop leading zeros from a hex string (but keep at least one digit)
fn drop_leading_hex_zeros(hex_str: String) -> String {
  case hex_str {
    "0" <> rest ->
      case rest {
        "" -> "0"
        _ -> drop_leading_hex_zeros(rest)
      }
    _ -> hex_str
  }
}
