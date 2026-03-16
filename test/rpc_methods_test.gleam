import gleam/dynamic/decode
import gleeth/ethereum/types as eth_types
import gleeth/rpc/methods
import gleeth/rpc/response_utils
import gleeth/rpc/types as rpc_types
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// ---------------------------------------------------------------------------
// String result decoding
// ---------------------------------------------------------------------------

pub fn decode_block_number_response_test() {
  let body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":\"0x134a1b0\"}"
  let result = response_utils.decode_rpc_response(body, decode.string)
  should.equal(result, Ok("0x134a1b0"))
}

pub fn decode_balance_response_test() {
  let body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":\"0x1bc16d674ec80000\"}"
  let result = response_utils.decode_rpc_response(body, decode.string)
  should.equal(result, Ok("0x1bc16d674ec80000"))
}

pub fn decode_empty_code_response_test() {
  let body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":\"0x\"}"
  let result = response_utils.decode_rpc_response(body, decode.string)
  should.equal(result, Ok("0x"))
}

// ---------------------------------------------------------------------------
// Error handling
// ---------------------------------------------------------------------------

pub fn decode_rpc_error_response_test() {
  let body =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32602,\"message\":\"invalid argument\"}}"
  let result = response_utils.decode_rpc_response(body, decode.string)
  case result {
    Error(rpc_types.RpcError(msg)) ->
      should.be_true(msg == "RPC Error: invalid argument")
    _ -> should.fail()
  }
}

pub fn decode_null_result_fails_for_string_test() {
  let body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null}"
  let result = response_utils.decode_rpc_response(body, decode.string)
  case result {
    Error(rpc_types.ParseError(_)) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn decode_malformed_json_test() {
  let body = "{not valid json"
  let result = response_utils.decode_rpc_response(body, decode.string)
  case result {
    Error(rpc_types.ParseError(_)) -> should.be_true(True)
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Transaction decoding
// ---------------------------------------------------------------------------

pub fn decode_legacy_transaction_test() {
  let body =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"hash\":\"0xabc123\",\"blockNumber\":\"0x1\",\"blockHash\":\"0xdef456\",\"transactionIndex\":\"0x0\",\"from\":\"0x1111111111111111111111111111111111111111\",\"to\":\"0x2222222222222222222222222222222222222222\",\"value\":\"0xde0b6b3a7640000\",\"gas\":\"0x5208\",\"gasPrice\":\"0x4a817c800\",\"input\":\"0x\",\"nonce\":\"0x0\",\"type\":\"0x0\",\"chainId\":\"0x1\",\"v\":\"0x1b\",\"r\":\"0xaaa\",\"s\":\"0xbbb\"}}"
  let result =
    response_utils.decode_rpc_response(body, transaction_decoder_for_test())
  case result {
    Ok(tx) -> {
      should.equal(tx.hash, "0xabc123")
      should.equal(tx.from, "0x1111111111111111111111111111111111111111")
      should.equal(tx.to, "0x2222222222222222222222222222222222222222")
      should.equal(tx.value, "0xde0b6b3a7640000")
      should.equal(tx.gas, "0x5208")
      should.equal(tx.gas_price, "0x4a817c800")
      should.equal(tx.v, "0x1b")
    }
    Error(_) -> should.fail()
  }
}

pub fn decode_eip1559_transaction_test() {
  let body =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"hash\":\"0xeip1559\",\"blockNumber\":\"0xa\",\"blockHash\":\"0xbhash\",\"transactionIndex\":\"0x3\",\"from\":\"0x1111111111111111111111111111111111111111\",\"to\":\"0x2222222222222222222222222222222222222222\",\"value\":\"0x0\",\"gas\":\"0x7530\",\"maxFeePerGas\":\"0x59682f00\",\"maxPriorityFeePerGas\":\"0x3b9aca00\",\"input\":\"0xa9059cbb\",\"nonce\":\"0x5\",\"type\":\"0x2\",\"chainId\":\"0x1\",\"v\":\"0x0\",\"r\":\"0xrrr\",\"s\":\"0xsss\"}}"
  let result =
    response_utils.decode_rpc_response(body, transaction_decoder_for_test())
  case result {
    Ok(tx) -> {
      should.equal(tx.hash, "0xeip1559")
      should.equal(tx.max_fee_per_gas, "0x59682f00")
      should.equal(tx.max_priority_fee_per_gas, "0x3b9aca00")
      should.equal(tx.transaction_type, "0x2")
      // gasPrice should be empty since not present in EIP-1559
      should.equal(tx.gas_price, "")
    }
    Error(_) -> should.fail()
  }
}

pub fn decode_pending_transaction_test() {
  let body =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"hash\":\"0xpending\",\"blockNumber\":null,\"blockHash\":null,\"transactionIndex\":null,\"from\":\"0x1111111111111111111111111111111111111111\",\"to\":\"0x2222222222222222222222222222222222222222\",\"value\":\"0x0\",\"gas\":\"0x5208\",\"gasPrice\":\"0x4a817c800\",\"input\":\"0x\",\"nonce\":\"0x0\",\"v\":\"0x1b\",\"r\":\"0xr\",\"s\":\"0xs\"}}"
  let result =
    response_utils.decode_rpc_response(body, transaction_decoder_for_test())
  case result {
    Ok(tx) -> {
      should.equal(tx.hash, "0xpending")
      // Null fields should become empty strings
      should.equal(tx.block_number, "")
      should.equal(tx.block_hash, "")
      should.equal(tx.transaction_index, "")
    }
    Error(_) -> should.fail()
  }
}

pub fn decode_null_transaction_test() {
  let body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null}"
  let result =
    response_utils.decode_rpc_response(body, transaction_decoder_for_test())
  case result {
    Error(rpc_types.ParseError(_)) -> should.be_true(True)
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Transaction receipt decoding
// ---------------------------------------------------------------------------

pub fn decode_successful_receipt_test() {
  let body =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"transactionHash\":\"0xtxhash\",\"transactionIndex\":\"0x0\",\"blockHash\":\"0xbhash\",\"blockNumber\":\"0x100\",\"from\":\"0x1111111111111111111111111111111111111111\",\"to\":\"0x2222222222222222222222222222222222222222\",\"cumulativeGasUsed\":\"0x5208\",\"gasUsed\":\"0x5208\",\"logs\":[],\"logsBloom\":\"0x0000\",\"status\":\"0x1\",\"effectiveGasPrice\":\"0x4a817c800\"}}"
  let result = methods.parse_transaction_receipt(body)
  case result {
    Ok(receipt) -> {
      should.equal(receipt.transaction_hash, "0xtxhash")
      should.equal(receipt.status, eth_types.Success)
      should.equal(receipt.gas_used, "0x5208")
      should.equal(receipt.to, "0x2222222222222222222222222222222222222222")
      should.equal(receipt.contract_address, "")
      should.equal(receipt.logs, [])
    }
    Error(_) -> should.fail()
  }
}

pub fn decode_failed_receipt_test() {
  let body =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"transactionHash\":\"0xfailed\",\"transactionIndex\":\"0x1\",\"blockHash\":\"0xbh\",\"blockNumber\":\"0x200\",\"from\":\"0x1111111111111111111111111111111111111111\",\"to\":\"0x2222222222222222222222222222222222222222\",\"cumulativeGasUsed\":\"0xaaa\",\"gasUsed\":\"0xbbb\",\"logs\":[],\"logsBloom\":\"0x00\",\"status\":\"0x0\",\"effectiveGasPrice\":\"0x123\"}}"
  let result = methods.parse_transaction_receipt(body)
  case result {
    Ok(receipt) -> {
      should.equal(receipt.status, eth_types.Failed)
    }
    Error(_) -> should.fail()
  }
}

pub fn decode_contract_creation_receipt_test() {
  let body =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"transactionHash\":\"0xdeploy\",\"transactionIndex\":\"0x0\",\"blockHash\":\"0xbh\",\"blockNumber\":\"0x50\",\"from\":\"0x1111111111111111111111111111111111111111\",\"to\":null,\"cumulativeGasUsed\":\"0xfffff\",\"gasUsed\":\"0xeeeee\",\"contractAddress\":\"0x3333333333333333333333333333333333333333\",\"logs\":[],\"logsBloom\":\"0x00\",\"status\":\"0x1\",\"effectiveGasPrice\":\"0x100\"}}"
  let result = methods.parse_transaction_receipt(body)
  case result {
    Ok(receipt) -> {
      should.equal(receipt.to, "")
      should.equal(
        receipt.contract_address,
        "0x3333333333333333333333333333333333333333",
      )
    }
    Error(_) -> should.fail()
  }
}

pub fn decode_null_transaction_receipt_test() {
  let body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null}"
  case methods.parse_transaction_receipt(body) {
    Error(rpc_types.ParseError(_)) -> should.be_true(True)
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Log decoding
// ---------------------------------------------------------------------------

pub fn decode_receipt_with_logs_test() {
  let body =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"transactionHash\":\"0xwithlogs\",\"transactionIndex\":\"0x0\",\"blockHash\":\"0xbh\",\"blockNumber\":\"0x100\",\"from\":\"0x1111111111111111111111111111111111111111\",\"to\":\"0x2222222222222222222222222222222222222222\",\"cumulativeGasUsed\":\"0x5208\",\"gasUsed\":\"0x5208\",\"logs\":[{\"address\":\"0x4444444444444444444444444444444444444444\",\"topics\":[\"0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef\",\"0x0000000000000000000000001111111111111111111111111111111111111111\"],\"data\":\"0x00000000000000000000000000000000000000000000000000038d7ea4c68000\",\"blockNumber\":\"0x100\",\"transactionHash\":\"0xwithlogs\",\"transactionIndex\":\"0x0\",\"blockHash\":\"0xbh\",\"logIndex\":\"0x0\",\"removed\":false}],\"logsBloom\":\"0x0000\",\"status\":\"0x1\",\"effectiveGasPrice\":\"0x4a817c800\"}}"
  let result = methods.parse_transaction_receipt(body)
  case result {
    Ok(receipt) -> {
      case receipt.logs {
        [log] -> {
          should.equal(
            log.address,
            "0x4444444444444444444444444444444444444444",
          )
          should.equal(log.removed, False)
          case log.topics {
            [topic0, _topic1] ->
              should.equal(
                topic0,
                "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
              )
            _ -> should.fail()
          }
        }
        _ -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn decode_logs_list_test() {
  let body =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":[{\"address\":\"0xaaaa\",\"topics\":[\"0xtopic1\"],\"data\":\"0xdata\",\"blockNumber\":\"0x1\",\"transactionHash\":\"0xth1\",\"transactionIndex\":\"0x0\",\"blockHash\":\"0xbh1\",\"logIndex\":\"0x0\",\"removed\":false},{\"address\":\"0xbbbb\",\"topics\":[],\"data\":\"0x\",\"blockNumber\":\"0x2\",\"transactionHash\":\"0xth2\",\"transactionIndex\":\"0x1\",\"blockHash\":\"0xbh2\",\"logIndex\":\"0x1\",\"removed\":true}]}"
  let result =
    response_utils.decode_rpc_response(
      body,
      decode.list(log_decoder_for_test()),
    )
  case result {
    Ok(logs) -> {
      should.equal(list.length(logs), 2)
      case logs {
        [first, second] -> {
          should.equal(first.address, "0xaaaa")
          should.equal(first.removed, False)
          should.equal(second.address, "0xbbbb")
          should.equal(second.removed, True)
          should.equal(second.topics, [])
        }
        _ -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn decode_empty_logs_list_test() {
  let body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":[]}"
  let result =
    response_utils.decode_rpc_response(
      body,
      decode.list(log_decoder_for_test()),
    )
  should.equal(result, Ok([]))
}

// ---------------------------------------------------------------------------
// Transaction broadcasting / fee estimation decoding
// ---------------------------------------------------------------------------

pub fn decode_send_raw_transaction_response_test() {
  let body =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":\"0x9bab8d3e7893fd77088c164d2834ddcb9fbfa73c93bdee90e396e3e27141f1ba\"}"
  let result = response_utils.decode_rpc_response(body, decode.string)
  should.equal(
    result,
    Ok("0x9bab8d3e7893fd77088c164d2834ddcb9fbfa73c93bdee90e396e3e27141f1ba"),
  )
}

pub fn decode_send_raw_transaction_nonce_error_test() {
  let body =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32000,\"message\":\"nonce too low\"}}"
  let result = response_utils.decode_rpc_response(body, decode.string)
  case result {
    Error(rpc_types.RpcError(msg)) ->
      should.be_true(msg == "RPC Error: nonce too low")
    _ -> should.fail()
  }
}

pub fn decode_transaction_count_response_test() {
  let body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":\"0x2a\"}"
  let result = response_utils.decode_rpc_response(body, decode.string)
  should.equal(result, Ok("0x2a"))
}

pub fn decode_gas_price_response_test() {
  let body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":\"0x3b9aca00\"}"
  let result = response_utils.decode_rpc_response(body, decode.string)
  should.equal(result, Ok("0x3b9aca00"))
}

pub fn decode_max_priority_fee_response_test() {
  let body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":\"0x59682f00\"}"
  let result = response_utils.decode_rpc_response(body, decode.string)
  should.equal(result, Ok("0x59682f00"))
}

pub fn decode_fee_history_response_test() {
  let body =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"oldestBlock\":\"0x1234\",\"baseFeePerGas\":[\"0x3b9aca00\",\"0x3b9aca01\",\"0x3b9aca02\"],\"gasUsedRatio\":[0.5,0.7],\"reward\":[[\"0x59682f00\",\"0x77359400\"],[\"0x3b9aca00\",\"0x59682f00\"]]}}"
  let result =
    response_utils.decode_rpc_response(body, fee_history_decoder_for_test())
  case result {
    Ok(fh) -> {
      should.equal(fh.oldest_block, "0x1234")
      should.equal(fh.base_fee_per_gas, [
        "0x3b9aca00",
        "0x3b9aca01",
        "0x3b9aca02",
      ])
      should.equal(fh.gas_used_ratio, [0.5, 0.7])
      should.equal(fh.reward, [
        ["0x59682f00", "0x77359400"],
        ["0x3b9aca00", "0x59682f00"],
      ])
    }
    Error(_) -> should.fail()
  }
}

pub fn decode_fee_history_no_reward_test() {
  let body =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"oldestBlock\":\"0x100\",\"baseFeePerGas\":[\"0x1\",\"0x2\"],\"gasUsedRatio\":[0.3]}}"
  let result =
    response_utils.decode_rpc_response(body, fee_history_decoder_for_test())
  case result {
    Ok(fh) -> {
      should.equal(fh.oldest_block, "0x100")
      should.equal(fh.reward, [])
    }
    Error(_) -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Decoders duplicated from methods.gleam for testing
// (methods.gleam keeps them private; these mirror the same structure)
// ---------------------------------------------------------------------------

import gleam/list

fn nullable_string() -> decode.Decoder(String) {
  decode.one_of(decode.string, [decode.success("")])
}

fn transaction_decoder_for_test() -> decode.Decoder(eth_types.Transaction) {
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

fn fee_history_decoder_for_test() -> decode.Decoder(eth_types.FeeHistory) {
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

fn log_decoder_for_test() -> decode.Decoder(eth_types.Log) {
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
