//// Ethereum JSON-RPC method wrappers.
////
//// Each public function in this module corresponds to a standard Ethereum
//// JSON-RPC method (e.g. `eth_blockNumber`, `eth_getBalance`). Functions
//// accept a `Provider` as their first argument and return a typed `Result`
//// with `GleethError` on failure.

import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/json
import gleeth/ethereum/types as eth_types
import gleeth/provider.{type Provider}
import gleeth/rpc/response_utils
import gleeth/rpc/types as rpc_types

/// Get the latest block number by calling `eth_blockNumber`.
///
/// Returns the block number as a hex-encoded string.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(p) = provider.new("http://localhost:8545")
/// let assert Ok(block) = get_block_number(p)
/// ```
pub fn get_block_number(
  provider: Provider,
) -> Result(eth_types.BlockNumber, rpc_types.GleethError) {
  response_utils.make_string_request_with_provider(
    provider,
    rpc_types.EthBlockNumber,
    [],
  )
}

/// Get a block by its number by calling `eth_getBlockByNumber`.
///
/// `block` can be a hex block number or a tag like `"latest"`, `"earliest"`,
/// `"pending"`. Returns the block with transaction hashes (not full objects).
pub fn get_block_by_number(
  provider: Provider,
  block: String,
) -> Result(eth_types.Block, rpc_types.GleethError) {
  let block_param = case block {
    "" -> "latest"
    _ -> block
  }
  let params = [json.string(block_param), json.bool(False)]
  response_utils.make_decoded_request_with_provider(
    provider,
    rpc_types.EthGetBlockByNumber,
    params,
    block_decoder(),
  )
}

/// Get a block by its hash by calling `eth_getBlockByHash`.
///
/// Returns the block with transaction hashes (not full objects).
pub fn get_block_by_hash(
  provider: Provider,
  hash: String,
) -> Result(eth_types.Block, rpc_types.GleethError) {
  let params = [json.string(hash), json.bool(False)]
  response_utils.make_decoded_request_with_provider(
    provider,
    rpc_types.EthGetBlockByHash,
    params,
    block_decoder(),
  )
}

/// Get the balance of an address by calling `eth_getBalance`.
///
/// Queries at the `"latest"` block. Returns the balance in wei as a
/// hex-encoded string.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(p) = provider.new("http://localhost:8545")
/// let assert Ok(balance) = get_balance(p, "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
/// ```
pub fn get_balance(
  provider: Provider,
  address: eth_types.Address,
) -> Result(eth_types.Wei, rpc_types.GleethError) {
  let params = [json.string(address), json.string("latest")]
  response_utils.make_string_request_with_provider(
    provider,
    rpc_types.EthGetBalance,
    params,
  )
}

/// Execute a read-only contract call by calling `eth_call`.
///
/// Sends a call object with the given contract address and ABI-encoded
/// calldata, evaluated at the `"latest"` block. Returns the hex-encoded
/// return data.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(p) = provider.new("http://localhost:8545")
/// let calldata = "0x70a08231000000000000000000000000d8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
/// let assert Ok(result) = call_contract(p, "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", calldata)
/// ```
pub fn call_contract(
  provider: Provider,
  contract_address: eth_types.Address,
  data: String,
) -> Result(String, rpc_types.GleethError) {
  let call_object =
    json.object([
      #("to", json.string(contract_address)),
      #("data", json.string(data)),
    ])

  let params = [call_object, json.string("latest")]
  response_utils.make_string_request_with_provider(
    provider,
    rpc_types.EthCall,
    params,
  )
}

/// Get the deployed bytecode at an address by calling `eth_getCode`.
///
/// Returns `"0x"` for externally-owned accounts (EOAs).
pub fn get_code(
  provider: Provider,
  address: eth_types.Address,
) -> Result(String, rpc_types.GleethError) {
  let params = [json.string(address), json.string("latest")]
  response_utils.make_string_request_with_provider(
    provider,
    rpc_types.EthGetCode,
    params,
  )
}

/// Estimate the gas required for a transaction by calling `eth_estimateGas`.
///
/// Any parameter may be an empty string to omit it from the call object.
pub fn estimate_gas(
  provider: Provider,
  from: String,
  to: String,
  value: String,
  data: String,
) -> Result(eth_types.Gas, rpc_types.GleethError) {
  let transaction_params =
    build_optional_params([
      #("from", from),
      #("to", to),
      #("value", value),
      #("data", data),
    ])

  let transaction_object = json.object(transaction_params)
  response_utils.make_string_request_with_provider(
    provider,
    rpc_types.EthEstimateGas,
    [transaction_object],
  )
}

/// Get the storage value at a specific slot in a contract by calling
/// `eth_getStorageAt`.
///
/// If `block` is an empty string it defaults to `"latest"`.
pub fn get_storage_at(
  provider: Provider,
  address: eth_types.Address,
  slot: eth_types.StorageSlot,
  block: String,
) -> Result(eth_types.StorageValue, rpc_types.GleethError) {
  let block_param = case block {
    "" -> "latest"
    _ -> block
  }

  let params = [
    json.string(address),
    json.string(slot),
    json.string(block_param),
  ]

  response_utils.make_string_request_with_provider(
    provider,
    rpc_types.EthGetStorageAt,
    params,
  )
}

/// Get the chain ID of the connected network by calling `eth_chainId`.
///
/// Returns the chain ID as a hex-encoded string (e.g. `"0x1"` for mainnet).
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(p) = provider.new("http://localhost:8545")
/// let assert Ok(chain_id) = get_chain_id(p)
/// ```
pub fn get_chain_id(provider: Provider) -> Result(String, rpc_types.GleethError) {
  response_utils.make_string_request_with_provider(
    provider,
    rpc_types.EthChainId,
    [],
  )
}

/// Broadcast a signed raw transaction to the network by calling
/// `eth_sendRawTransaction`.
///
/// `raw_tx` should be the hex-encoded signed transaction (e.g. `"0x02f873..."`).
/// Returns the transaction hash on success.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(p) = provider.new("http://localhost:8545")
/// let assert Ok(tx_hash) = send_raw_transaction(p, "0x02f873...")
/// ```
pub fn send_raw_transaction(
  provider: Provider,
  raw_tx: String,
) -> Result(eth_types.Hash, rpc_types.GleethError) {
  let params = [json.string(raw_tx)]
  response_utils.make_string_request_with_provider(
    provider,
    rpc_types.EthSendRawTransaction,
    params,
  )
}

/// Get the transaction count (nonce) for an address by calling
/// `eth_getTransactionCount`.
///
/// If `block` is an empty string it defaults to `"pending"`, which gives the
/// next usable nonce.
pub fn get_transaction_count(
  provider: Provider,
  address: eth_types.Address,
  block: String,
) -> Result(String, rpc_types.GleethError) {
  let block_param = case block {
    "" -> "pending"
    _ -> block
  }
  let params = [json.string(address), json.string(block_param)]
  response_utils.make_string_request_with_provider(
    provider,
    rpc_types.EthGetTransactionCount,
    params,
  )
}

/// Get the current gas price in wei by calling `eth_gasPrice`.
///
/// Primarily useful for legacy (pre-EIP-1559) transactions.
pub fn get_gas_price(
  provider: Provider,
) -> Result(eth_types.Wei, rpc_types.GleethError) {
  response_utils.make_string_request_with_provider(
    provider,
    rpc_types.EthGasPrice,
    [],
  )
}

/// Get the suggested max priority fee per gas by calling
/// `eth_maxPriorityFeePerGas`.
///
/// Used when building EIP-1559 (Type 2) transactions.
pub fn get_max_priority_fee(
  provider: Provider,
) -> Result(eth_types.Wei, rpc_types.GleethError) {
  response_utils.make_string_request_with_provider(
    provider,
    rpc_types.EthMaxPriorityFeePerGas,
    [],
  )
}

/// Get fee history for recent blocks by calling `eth_feeHistory`.
///
/// - `block_count` - number of blocks to return (as a decimal integer)
/// - `newest_block` - highest block (`"latest"`, `"pending"`, or a hex block
///   number); defaults to `"latest"` when empty
/// - `reward_percentiles` - percentiles of effective priority fees to include
///   (e.g. `[25.0, 50.0, 75.0]`)
pub fn get_fee_history(
  provider: Provider,
  block_count: Int,
  newest_block: String,
  reward_percentiles: List(Float),
) -> Result(eth_types.FeeHistory, rpc_types.GleethError) {
  let newest = case newest_block {
    "" -> "latest"
    _ -> newest_block
  }
  let params = [
    json.int(block_count),
    json.string(newest),
    json.array(reward_percentiles, json.float),
  ]
  response_utils.make_decoded_request_with_provider(
    provider,
    rpc_types.EthFeeHistory,
    params,
    fee_history_decoder(),
  )
}

/// Get a transaction by its hash by calling `eth_getTransactionByHash`.
///
/// Returns a fully decoded `Transaction` record.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(p) = provider.new("http://localhost:8545")
/// let assert Ok(tx) = get_transaction(p, "0xabc123...")
/// ```
pub fn get_transaction(
  provider: Provider,
  hash: String,
) -> Result(eth_types.Transaction, rpc_types.GleethError) {
  let params = [json.string(hash)]
  response_utils.make_decoded_request_with_provider(
    provider,
    rpc_types.EthGetTransactionByHash,
    params,
    transaction_decoder(),
  )
}

/// Get a transaction receipt by its hash by calling
/// `eth_getTransactionReceipt`.
///
/// Returns a fully decoded `TransactionReceipt` record including logs and
/// status.
pub fn get_transaction_receipt(
  provider: Provider,
  transaction_hash: String,
) -> Result(eth_types.TransactionReceipt, rpc_types.GleethError) {
  let params = [json.string(transaction_hash)]
  response_utils.make_decoded_request_with_provider(
    provider,
    rpc_types.EthGetTransactionReceipt,
    params,
    transaction_receipt_decoder(),
  )
}

/// Parse a transaction receipt from a raw JSON-RPC response body.
///
/// This is primarily intended for testing - it decodes the JSON string
/// directly rather than making an RPC call.
pub fn parse_transaction_receipt(
  body: String,
) -> Result(eth_types.TransactionReceipt, rpc_types.GleethError) {
  response_utils.decode_rpc_response(body, transaction_receipt_decoder())
}

/// Get event logs matching a filter by calling `eth_getLogs`.
///
/// `from_block` and `to_block` default to `"latest"` when empty. `address`
/// and `topics` are omitted from the filter when empty.
pub fn get_logs(
  provider: Provider,
  from_block: String,
  to_block: String,
  address: String,
  topics: List(String),
) -> Result(List(eth_types.Log), rpc_types.GleethError) {
  let from_block_param = case from_block {
    "" -> "latest"
    _ -> from_block
  }
  let to_block_param = case to_block {
    "" -> "latest"
    _ -> to_block
  }

  let filter_params =
    [
      #("fromBlock", json.string(from_block_param)),
      #("toBlock", json.string(to_block_param)),
    ]
    |> append_if_nonempty("address", address)
    |> append_topics(topics)

  let filter_object = json.object(filter_params)
  response_utils.make_decoded_request_with_provider(
    provider,
    rpc_types.EthGetLogs,
    [filter_object],
    decode.list(log_decoder()),
  )
}

/// Poll for a transaction receipt with exponential backoff.
/// Default timeout: 60 seconds. Backoff: 1s, 2s, 4s, 4s, 4s, ...
pub fn wait_for_receipt(
  provider: Provider,
  tx_hash: String,
) -> Result(eth_types.TransactionReceipt, rpc_types.GleethError) {
  wait_for_receipt_with_timeout(provider, tx_hash, 60_000)
}

/// Poll for a transaction receipt with a custom timeout in milliseconds.
/// Uses exponential backoff: 1s, 2s, 4s, 4s, 4s, ... (capped at 4s).
pub fn wait_for_receipt_with_timeout(
  provider: Provider,
  tx_hash: String,
  timeout_ms: Int,
) -> Result(eth_types.TransactionReceipt, rpc_types.GleethError) {
  poll_receipt(provider, tx_hash, timeout_ms, 0, 1000)
}

fn poll_receipt(
  provider: Provider,
  tx_hash: String,
  timeout_ms: Int,
  elapsed_ms: Int,
  backoff_ms: Int,
) -> Result(eth_types.TransactionReceipt, rpc_types.GleethError) {
  case elapsed_ms >= timeout_ms {
    True ->
      Error(rpc_types.ParseError(
        "Receipt not found within " <> int.to_string(timeout_ms) <> "ms",
      ))
    False -> {
      case get_transaction_receipt(provider, tx_hash) {
        Ok(receipt) -> Ok(receipt)
        Error(_) -> {
          process.sleep(backoff_ms)
          let next_backoff = case backoff_ms * 2 {
            doubled if doubled > 4000 -> 4000
            doubled -> doubled
          }
          poll_receipt(
            provider,
            tx_hash,
            timeout_ms,
            elapsed_ms + backoff_ms,
            next_backoff,
          )
        }
      }
    }
  }
}

// Decode a string field, treating null as empty string
fn nullable_string() -> decode.Decoder(String) {
  decode.one_of(decode.string, [decode.success("")])
}

fn block_decoder() -> decode.Decoder(eth_types.Block) {
  use number <- decode.field("number", decode.string)
  use hash <- decode.field("hash", decode.string)
  use parent_hash <- decode.field("parentHash", decode.string)
  use timestamp <- decode.field("timestamp", decode.string)
  use gas_limit <- decode.field("gasLimit", decode.string)
  use gas_used <- decode.field("gasUsed", decode.string)
  use transactions <- decode.field("transactions", decode.list(decode.string))
  decode.success(eth_types.Block(
    number: number,
    hash: hash,
    parent_hash: parent_hash,
    timestamp: timestamp,
    gas_limit: gas_limit,
    gas_used: gas_used,
    transactions: transactions,
  ))
}

fn transaction_decoder() -> decode.Decoder(eth_types.Transaction) {
  use hash <- decode.field("hash", decode.string)
  use block_number <- decode.optional_field(
    "blockNumber",
    "",
    nullable_string(),
  )
  use block_hash <- decode.optional_field("blockHash", "", nullable_string())
  use transaction_index <- decode.optional_field(
    "transactionIndex",
    "",
    nullable_string(),
  )
  use from <- decode.field("from", decode.string)
  use to <- decode.optional_field("to", "", nullable_string())
  use value <- decode.field("value", decode.string)
  use gas <- decode.field("gas", decode.string)
  use gas_price <- decode.optional_field("gasPrice", "", nullable_string())
  use max_fee_per_gas <- decode.optional_field(
    "maxFeePerGas",
    "",
    nullable_string(),
  )
  use max_priority_fee_per_gas <- decode.optional_field(
    "maxPriorityFeePerGas",
    "",
    nullable_string(),
  )
  use input <- decode.field("input", decode.string)
  use nonce <- decode.field("nonce", decode.string)
  use transaction_type <- decode.optional_field("type", "", nullable_string())
  use chain_id <- decode.optional_field("chainId", "", nullable_string())
  use v <- decode.field("v", decode.string)
  use r <- decode.field("r", decode.string)
  use s <- decode.field("s", decode.string)

  decode.success(eth_types.Transaction(
    hash: hash,
    block_number: block_number,
    block_hash: block_hash,
    transaction_index: transaction_index,
    from: from,
    to: to,
    value: value,
    gas: gas,
    gas_price: gas_price,
    max_fee_per_gas: max_fee_per_gas,
    max_priority_fee_per_gas: max_priority_fee_per_gas,
    input: input,
    nonce: nonce,
    transaction_type: transaction_type,
    chain_id: chain_id,
    v: v,
    r: r,
    s: s,
  ))
}

fn transaction_receipt_decoder() -> decode.Decoder(eth_types.TransactionReceipt) {
  use transaction_hash <- decode.field("transactionHash", decode.string)
  use transaction_index <- decode.field("transactionIndex", decode.string)
  use block_hash <- decode.field("blockHash", decode.string)
  use block_number <- decode.field("blockNumber", decode.string)
  use from <- decode.field("from", decode.string)
  use to <- decode.optional_field("to", "", nullable_string())
  use cumulative_gas_used <- decode.field("cumulativeGasUsed", decode.string)
  use gas_used <- decode.field("gasUsed", decode.string)
  use contract_address <- decode.optional_field(
    "contractAddress",
    "",
    nullable_string(),
  )
  use logs <- decode.field("logs", decode.list(log_decoder()))
  use logs_bloom <- decode.field("logsBloom", decode.string)
  use status <- decode.field("status", status_decoder())
  use effective_gas_price <- decode.field("effectiveGasPrice", decode.string)

  decode.success(eth_types.TransactionReceipt(
    transaction_hash: transaction_hash,
    transaction_index: transaction_index,
    block_hash: block_hash,
    block_number: block_number,
    from: from,
    to: to,
    cumulative_gas_used: cumulative_gas_used,
    gas_used: gas_used,
    contract_address: contract_address,
    logs: logs,
    logs_bloom: logs_bloom,
    status: status,
    effective_gas_price: effective_gas_price,
  ))
}

fn log_decoder() -> decode.Decoder(eth_types.Log) {
  use address <- decode.field("address", decode.string)
  use topics <- decode.field("topics", decode.list(nullable_string()))
  use data <- decode.field("data", decode.string)
  use block_number <- decode.field("blockNumber", decode.string)
  use transaction_hash <- decode.field("transactionHash", decode.string)
  use transaction_index <- decode.field("transactionIndex", decode.string)
  use block_hash <- decode.field("blockHash", decode.string)
  use log_index <- decode.field("logIndex", decode.string)
  use removed <- decode.field("removed", decode.bool)

  decode.success(eth_types.Log(
    address: address,
    topics: topics,
    data: data,
    block_number: block_number,
    transaction_hash: transaction_hash,
    transaction_index: transaction_index,
    block_hash: block_hash,
    log_index: log_index,
    removed: removed,
  ))
}

fn fee_history_decoder() -> decode.Decoder(eth_types.FeeHistory) {
  use oldest_block <- decode.field("oldestBlock", decode.string)
  use base_fee_per_gas <- decode.field(
    "baseFeePerGas",
    decode.list(decode.string),
  )
  use gas_used_ratio <- decode.field("gasUsedRatio", decode.list(decode.float))
  use reward <- decode.optional_field(
    "reward",
    [],
    decode.list(decode.list(decode.string)),
  )
  decode.success(eth_types.FeeHistory(
    oldest_block: oldest_block,
    base_fee_per_gas: base_fee_per_gas,
    gas_used_ratio: gas_used_ratio,
    reward: reward,
  ))
}

fn status_decoder() -> decode.Decoder(eth_types.TransactionStatus) {
  use status_str <- decode.then(decode.string)
  case status_str {
    "0x1" | "0x01" -> decode.success(eth_types.Success)
    "0x0" | "0x00" -> decode.success(eth_types.Failed)
    _ -> decode.failure(eth_types.Failed, "TransactionStatus")
  }
}

// Build a list of JSON key-value pairs, skipping empty string values
fn build_optional_params(
  pairs: List(#(String, String)),
) -> List(#(String, json.Json)) {
  case pairs {
    [] -> []
    [#(key, value), ..rest] ->
      case value {
        "" -> build_optional_params(rest)
        _ -> [#(key, json.string(value)), ..build_optional_params(rest)]
      }
  }
}

fn append_if_nonempty(
  params: List(#(String, json.Json)),
  key: String,
  value: String,
) -> List(#(String, json.Json)) {
  case value {
    "" -> params
    _ -> [#(key, json.string(value)), ..params]
  }
}

fn append_topics(
  params: List(#(String, json.Json)),
  topics: List(String),
) -> List(#(String, json.Json)) {
  case topics {
    [] -> params
    _ -> [#("topics", json.array(topics, json.string)), ..params]
  }
}
