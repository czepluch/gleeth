//// Ethereum domain types used throughout gleeth.
////
//// Most types are hex-encoded string aliases (addresses, hashes, wei values)
//// matching how the JSON-RPC API represents them. Structured types like
//// `Transaction`, `TransactionReceipt`, and `Log` are decoded from RPC
//// responses by the `methods` module.

/// A hex-encoded Ethereum address, e.g. `"0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"`.
pub type Address =
  String

/// A hex-encoded 32-byte hash (transaction hash or block hash).
pub type Hash =
  String

/// A hex-encoded block number, e.g. `"0x10d4f1"`.
pub type BlockNumber =
  String

/// A hex-encoded wei amount, e.g. `"0xde0b6b3a7640000"` for 1 ETH.
pub type Wei =
  String

/// A hex-encoded gas amount.
pub type Gas =
  String

/// A hex-encoded 32-byte storage value returned by `eth_getStorageAt`.
pub type StorageValue =
  String

/// A hex-encoded storage slot position, e.g. `"0x0"` for slot 0.
pub type StorageSlot =
  String

/// Parameters for `eth_estimateGas`. Empty strings are omitted from the
/// request.
pub type GasEstimateTransaction {
  GasEstimateTransaction(from: Address, to: Address, value: Wei, data: String)
}

/// Status of a mined transaction (post-Byzantium).
pub type TransactionStatus {
  /// The transaction executed successfully (`status: 0x1`).
  Success
  /// The transaction reverted (`status: 0x0`).
  Failed
}

/// An event log emitted by a smart contract.
///
/// Returned by `methods.get_logs` and included in `TransactionReceipt`.
pub type Log {
  Log(
    /// Contract address that emitted the log.
    address: Address,
    /// Indexed event parameters (up to 4 topics).
    topics: List(String),
    /// Non-indexed event data (ABI-encoded).
    data: String,
    /// Block number where the log occurred.
    block_number: BlockNumber,
    /// Transaction that produced this log.
    transaction_hash: Hash,
    /// Index of the transaction within the block.
    transaction_index: String,
    /// Hash of the block containing this log.
    block_hash: Hash,
    /// Index of this log within the block.
    log_index: String,
    /// `True` if this log was removed due to a chain reorganization.
    removed: Bool,
  )
}

/// Filter parameters for `eth_getLogs`.
pub type LogFilter {
  LogFilter(
    /// Starting block (hex or tag like `"latest"`). Empty string defaults to `"latest"`.
    from_block: String,
    /// Ending block. Empty string defaults to `"latest"`.
    to_block: String,
    /// Contract address to filter. Empty string means all contracts.
    address: String,
    /// Topic filters. Empty list means all topics.
    topics: List(String),
  )
}

/// A transaction receipt returned after a transaction is mined.
///
/// Returned by `methods.get_transaction_receipt`.
pub type TransactionReceipt {
  TransactionReceipt(
    /// Hash of the transaction.
    transaction_hash: Hash,
    /// Index of the transaction within the block.
    transaction_index: String,
    /// Hash of the block containing this transaction.
    block_hash: Hash,
    /// Number of the block containing this transaction.
    block_number: BlockNumber,
    /// Sender address.
    from: Address,
    /// Receiver address. Empty string for contract creation.
    to: Address,
    /// Total gas used in the block up to and including this transaction.
    cumulative_gas_used: String,
    /// Gas consumed by this specific transaction.
    gas_used: String,
    /// Address of the created contract. Empty string if not a deployment.
    contract_address: Address,
    /// Event logs emitted by this transaction.
    logs: List(Log),
    /// Bloom filter for quick log retrieval by light clients.
    logs_bloom: String,
    /// Whether the transaction succeeded or reverted.
    status: TransactionStatus,
    /// Actual gas price paid per unit (relevant for EIP-1559).
    effective_gas_price: String,
  )
}

/// Block header information.
pub type Block {
  Block(
    number: BlockNumber,
    hash: Hash,
    parent_hash: Hash,
    timestamp: String,
    gas_limit: String,
    gas_used: String,
    transactions: List(Hash),
  )
}

/// Full transaction object as returned by `methods.get_transaction`.
///
/// Fields that are `""` (empty string) indicate null/absent values in the
/// JSON-RPC response - e.g. `block_number` is empty for pending transactions,
/// `to` is empty for contract creation.
pub type Transaction {
  Transaction(
    /// Transaction hash.
    hash: Hash,
    /// Block number. Empty for pending transactions.
    block_number: String,
    /// Block hash. Empty for pending transactions.
    block_hash: String,
    /// Index within the block. Empty for pending transactions.
    transaction_index: String,
    /// Sender address.
    from: Address,
    /// Recipient address. Empty for contract creation.
    to: String,
    /// Value transferred in wei.
    value: Wei,
    /// Gas limit.
    gas: String,
    /// Gas price in wei (legacy transactions). Empty for EIP-1559.
    gas_price: String,
    /// Max fee per gas (EIP-1559). Empty for legacy transactions.
    max_fee_per_gas: String,
    /// Max priority fee per gas (EIP-1559). Empty for legacy transactions.
    max_priority_fee_per_gas: String,
    /// Input data (calldata).
    input: String,
    /// Sender's nonce.
    nonce: String,
    /// Transaction type: `"0x0"` legacy, `"0x1"` EIP-2930, `"0x2"` EIP-1559.
    transaction_type: String,
    /// Chain ID.
    chain_id: String,
    /// ECDSA recovery id.
    v: String,
    /// ECDSA signature r component.
    r: String,
    /// ECDSA signature s component.
    s: String,
  )
}

/// An address paired with its balance.
pub type Balance {
  Balance(address: Address, value: Wei)
}

/// Fee history data returned by `methods.get_fee_history` for EIP-1559 gas
/// estimation.
pub type FeeHistory {
  FeeHistory(
    /// Lowest block number in the returned range.
    oldest_block: BlockNumber,
    /// Base fee per gas for each block. Contains N+1 entries (includes the
    /// next block's base fee).
    base_fee_per_gas: List(String),
    /// Ratio of gas used to gas limit for each block (0.0 to 1.0).
    gas_used_ratio: List(Float),
    /// Priority fee at requested percentiles for each block. Empty if no
    /// percentiles were requested.
    reward: List(List(String)),
  )
}
