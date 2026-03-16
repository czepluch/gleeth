import gleam/dynamic/decode
import gleam/json
import gleeth/ethereum/types as eth_types
import gleeth/rpc/response_utils
import gleeth/rpc/types as rpc_types

// ---------------------------------------------------------------------------
// Simple RPC methods (return a single string)
// ---------------------------------------------------------------------------

// Get the latest block number
pub fn get_block_number(
  rpc_url: String,
) -> Result(eth_types.BlockNumber, rpc_types.GleethError) {
  response_utils.make_string_request(rpc_url, rpc_types.EthBlockNumber, [])
}

// Get balance of an address
pub fn get_balance(
  rpc_url: String,
  address: eth_types.Address,
) -> Result(eth_types.Wei, rpc_types.GleethError) {
  let params = [json.string(address), json.string("latest")]
  response_utils.make_string_request(rpc_url, rpc_types.EthGetBalance, params)
}

// Make a contract call
pub fn call_contract(
  rpc_url: String,
  contract_address: eth_types.Address,
  data: String,
) -> Result(String, rpc_types.GleethError) {
  let call_object =
    json.object([
      #("to", json.string(contract_address)),
      #("data", json.string(data)),
    ])

  let params = [call_object, json.string("latest")]
  response_utils.make_string_request(rpc_url, rpc_types.EthCall, params)
}

// Get contract code (bytecode) at an address
pub fn get_code(
  rpc_url: String,
  address: eth_types.Address,
) -> Result(String, rpc_types.GleethError) {
  let params = [json.string(address), json.string("latest")]
  response_utils.make_string_request(rpc_url, rpc_types.EthGetCode, params)
}

// Estimate gas needed for a transaction
pub fn estimate_gas(
  rpc_url: String,
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
  response_utils.make_string_request(rpc_url, rpc_types.EthEstimateGas, [
    transaction_object,
  ])
}

// Get storage value at a specific slot in a contract
pub fn get_storage_at(
  rpc_url: String,
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

  response_utils.make_string_request(rpc_url, rpc_types.EthGetStorageAt, params)
}

// Get the chain ID of the connected network.
pub fn get_chain_id(rpc_url: String) -> Result(String, rpc_types.GleethError) {
  response_utils.make_string_request(rpc_url, rpc_types.EthChainId, [])
}

// ---------------------------------------------------------------------------
// Transaction broadcasting
// ---------------------------------------------------------------------------

// Broadcast a signed raw transaction to the network.
// raw_tx should be the hex-encoded signed transaction (e.g. "0x02f873...").
// Returns the transaction hash on success.
pub fn send_raw_transaction(
  rpc_url: String,
  raw_tx: String,
) -> Result(eth_types.Hash, rpc_types.GleethError) {
  let params = [json.string(raw_tx)]
  response_utils.make_string_request(
    rpc_url,
    rpc_types.EthSendRawTransaction,
    params,
  )
}

// Get the transaction count (nonce) for an address.
// The block parameter defaults to "pending" to get the next usable nonce.
pub fn get_transaction_count(
  rpc_url: String,
  address: eth_types.Address,
  block: String,
) -> Result(String, rpc_types.GleethError) {
  let block_param = case block {
    "" -> "pending"
    _ -> block
  }
  let params = [json.string(address), json.string(block_param)]
  response_utils.make_string_request(
    rpc_url,
    rpc_types.EthGetTransactionCount,
    params,
  )
}

// Get the current gas price in wei (for legacy transactions).
pub fn get_gas_price(
  rpc_url: String,
) -> Result(eth_types.Wei, rpc_types.GleethError) {
  response_utils.make_string_request(rpc_url, rpc_types.EthGasPrice, [])
}

// Get the current max priority fee per gas suggestion (for EIP-1559 transactions).
pub fn get_max_priority_fee(
  rpc_url: String,
) -> Result(eth_types.Wei, rpc_types.GleethError) {
  response_utils.make_string_request(
    rpc_url,
    rpc_types.EthMaxPriorityFeePerGas,
    [],
  )
}

// Get fee history for recent blocks.
// block_count: number of blocks to return (as decimal integer)
// newest_block: highest block ("latest", "pending", or hex block number)
// reward_percentiles: percentiles of effective priority fees to return (e.g. [25.0, 50.0, 75.0])
pub fn get_fee_history(
  rpc_url: String,
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
  response_utils.make_decoded_request(
    rpc_url,
    rpc_types.EthFeeHistory,
    params,
    fee_history_decoder(),
  )
}

// ---------------------------------------------------------------------------
// Complex RPC methods (return structured data)
// ---------------------------------------------------------------------------

// Get transaction by hash
pub fn get_transaction(
  rpc_url: String,
  hash: String,
) -> Result(eth_types.Transaction, rpc_types.GleethError) {
  let params = [json.string(hash)]
  response_utils.make_decoded_request(
    rpc_url,
    rpc_types.EthGetTransactionByHash,
    params,
    transaction_decoder(),
  )
}

// Get transaction receipt by hash
pub fn get_transaction_receipt(
  rpc_url: String,
  transaction_hash: String,
) -> Result(eth_types.TransactionReceipt, rpc_types.GleethError) {
  let params = [json.string(transaction_hash)]
  response_utils.make_decoded_request(
    rpc_url,
    rpc_types.EthGetTransactionReceipt,
    params,
    transaction_receipt_decoder(),
  )
}

// Parse a transaction receipt from a JSON value (for testing)
pub fn parse_transaction_receipt(
  body: String,
) -> Result(eth_types.TransactionReceipt, rpc_types.GleethError) {
  response_utils.decode_rpc_response(body, transaction_receipt_decoder())
}

// Get event logs based on filter criteria
pub fn get_logs(
  rpc_url: String,
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
  response_utils.make_decoded_request(
    rpc_url,
    rpc_types.EthGetLogs,
    [filter_object],
    decode.list(log_decoder()),
  )
}

// ---------------------------------------------------------------------------
// Decoders
// ---------------------------------------------------------------------------

// Decode a string field, treating null as empty string
fn nullable_string() -> decode.Decoder(String) {
  decode.one_of(decode.string, [decode.success("")])
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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
