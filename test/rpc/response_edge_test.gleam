/// Tests for RPC response edge cases: malformed JSON, missing fields,
/// null values, RPC errors, and unexpected formats.
import gleam/dynamic/decode
import gleeth/rpc/response_utils
import gleeunit/should

// =============================================================================
// Malformed JSON handling
// =============================================================================

pub fn decode_empty_string_test() {
  let result = response_utils.decode_rpc_response("", decode.string)
  result |> should.be_error
}

pub fn decode_invalid_json_test() {
  let result =
    response_utils.decode_rpc_response("not json at all", decode.string)
  result |> should.be_error
}

pub fn decode_truncated_json_test() {
  let result = response_utils.decode_rpc_response("{\"result\":", decode.string)
  result |> should.be_error
}

pub fn decode_empty_object_test() {
  // No "result" field at all
  let result = response_utils.decode_rpc_response("{}", decode.string)
  result |> should.be_error
}

// =============================================================================
// RPC error responses
// =============================================================================

pub fn decode_rpc_error_message_test() {
  let json =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32602,\"message\":\"Invalid params\"}}"
  let result = response_utils.decode_rpc_response(json, decode.string)
  let _ = result |> should.be_error
  Nil
}

pub fn decode_rpc_error_with_data_test() {
  let json =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32000,\"message\":\"execution reverted\",\"data\":\"0x08c379a0\"}}"
  let result = response_utils.decode_rpc_response(json, decode.string)
  let _ = result |> should.be_error
  Nil
}

// =============================================================================
// Valid responses with various result types
// =============================================================================

pub fn decode_string_result_test() {
  let json = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":\"0x1234\"}"
  let assert Ok(value) = response_utils.decode_rpc_response(json, decode.string)
  value |> should.equal("0x1234")
}

pub fn decode_null_result_test() {
  // Some RPC methods return null (e.g. getTransactionReceipt for pending tx)
  let json = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null}"
  let result = response_utils.decode_rpc_response(json, decode.string)
  // String decoder should fail on null
  result |> should.be_error
}

pub fn decode_null_result_with_optional_decoder_test() {
  let json = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null}"
  let decoder = decode.optional(decode.string)
  let assert Ok(value) = response_utils.decode_rpc_response(json, decoder)
  value |> should.be_none
}

pub fn decode_empty_hex_result_test() {
  // getCode on an EOA returns "0x"
  let json = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":\"0x\"}"
  let assert Ok(value) = response_utils.decode_rpc_response(json, decode.string)
  value |> should.equal("0x")
}

pub fn decode_empty_array_result_test() {
  // getLogs with no matches returns empty array
  let json = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":[]}"
  let assert Ok(value) =
    response_utils.decode_rpc_response(json, decode.list(decode.string))
  value |> should.equal([])
}

// =============================================================================
// Transaction JSON with null/missing optional fields (pending tx shape)
// =============================================================================

pub fn decode_pending_transaction_json_test() {
  // A pending transaction has null blockNumber, blockHash, transactionIndex
  let json =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"hash\":\"0xabc\",\"blockNumber\":null,\"blockHash\":null,\"transactionIndex\":null,\"from\":\"0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266\",\"to\":\"0x70997970c51812dc3a010c7d01b50e0d17dc79c8\",\"value\":\"0xde0b6b3a7640000\",\"gas\":\"0x5208\",\"gasPrice\":\"0x3b9aca00\",\"input\":\"0x\",\"nonce\":\"0x0\",\"v\":\"0x25\",\"r\":\"0x1234\",\"s\":\"0x5678\"}}"

  // Build the same decoder structure as methods.gleam uses
  let nullable_string = decode.one_of(decode.string, [decode.success("")])
  let tx_decoder = {
    use hash <- decode.field("hash", decode.string)
    use block_number <- decode.optional_field(
      "blockNumber",
      "",
      nullable_string,
    )
    use from <- decode.field("from", decode.string)
    use to <- decode.optional_field("to", "", nullable_string)
    use value <- decode.field("value", decode.string)
    decode.success(#(hash, block_number, from, to, value))
  }

  let assert Ok(#(hash, block_number, from, to, value)) =
    response_utils.decode_rpc_response(json, tx_decoder)
  hash |> should.equal("0xabc")
  block_number |> should.equal("")
  // null decoded as empty string
  from |> should.equal("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
  to |> should.equal("0x70997970c51812dc3a010c7d01b50e0d17dc79c8")
  value |> should.equal("0xde0b6b3a7640000")
}

pub fn decode_contract_creation_transaction_json_test() {
  // Contract creation has null "to" field
  let json =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"hash\":\"0xdef\",\"from\":\"0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266\",\"to\":null,\"value\":\"0x0\",\"gas\":\"0x100000\",\"gasPrice\":\"0x3b9aca00\",\"input\":\"0x6080604052\",\"nonce\":\"0x5\",\"v\":\"0x25\",\"r\":\"0xaaaa\",\"s\":\"0xbbbb\"}}"

  let nullable_string = decode.one_of(decode.string, [decode.success("")])
  let tx_decoder = {
    use hash <- decode.field("hash", decode.string)
    use to <- decode.optional_field("to", "", nullable_string)
    use input <- decode.field("input", decode.string)
    decode.success(#(hash, to, input))
  }

  let assert Ok(#(_hash, to, input)) =
    response_utils.decode_rpc_response(json, tx_decoder)
  to |> should.equal("")
  // null -> empty string
  input |> should.equal("0x6080604052")
}

// =============================================================================
// Receipt with null optional fields
// =============================================================================

pub fn decode_receipt_null_contract_address_test() {
  // Normal transfer receipt: contractAddress is null
  let json =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"transactionHash\":\"0xabc\",\"transactionIndex\":\"0x0\",\"blockHash\":\"0xdef\",\"blockNumber\":\"0x1\",\"from\":\"0xf39f\",\"to\":\"0x7099\",\"cumulativeGasUsed\":\"0x5208\",\"gasUsed\":\"0x5208\",\"contractAddress\":null,\"logs\":[],\"logsBloom\":\"0x00\",\"status\":\"0x1\",\"effectiveGasPrice\":\"0x3b9aca00\"}}"

  let nullable_string = decode.one_of(decode.string, [decode.success("")])
  let receipt_decoder = {
    use tx_hash <- decode.field("transactionHash", decode.string)
    use contract_address <- decode.optional_field(
      "contractAddress",
      "",
      nullable_string,
    )
    use status <- decode.field("status", decode.string)
    decode.success(#(tx_hash, contract_address, status))
  }

  let assert Ok(#(tx_hash, contract_address, status)) =
    response_utils.decode_rpc_response(json, receipt_decoder)
  tx_hash |> should.equal("0xabc")
  contract_address |> should.equal("")
  status |> should.equal("0x1")
}

// =============================================================================
// EIP-1559 transaction fields (missing gasPrice, has maxFeePerGas)
// =============================================================================

pub fn decode_eip1559_transaction_json_test() {
  let json =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"hash\":\"0x123\",\"from\":\"0xf39f\",\"to\":\"0x7099\",\"value\":\"0x0\",\"gas\":\"0x5208\",\"maxFeePerGas\":\"0x4a817c800\",\"maxPriorityFeePerGas\":\"0x3b9aca00\",\"input\":\"0x\",\"nonce\":\"0x0\",\"type\":\"0x2\",\"chainId\":\"0x1\",\"v\":\"0x1\",\"r\":\"0xaaaa\",\"s\":\"0xbbbb\"}}"

  let nullable_string = decode.one_of(decode.string, [decode.success("")])
  let tx_decoder = {
    use hash <- decode.field("hash", decode.string)
    use gas_price <- decode.optional_field("gasPrice", "", nullable_string)
    use max_fee <- decode.optional_field("maxFeePerGas", "", nullable_string)
    use priority_fee <- decode.optional_field(
      "maxPriorityFeePerGas",
      "",
      nullable_string,
    )
    use tx_type <- decode.optional_field("type", "", nullable_string)
    decode.success(#(hash, gas_price, max_fee, priority_fee, tx_type))
  }

  let assert Ok(#(_hash, gas_price, max_fee, priority_fee, tx_type)) =
    response_utils.decode_rpc_response(json, tx_decoder)
  // gasPrice missing for EIP-1559 -> empty string default
  gas_price |> should.equal("")
  max_fee |> should.equal("0x4a817c800")
  priority_fee |> should.equal("0x3b9aca00")
  tx_type |> should.equal("0x2")
}

// =============================================================================
// Fee history with optional reward field
// =============================================================================

pub fn decode_fee_history_no_reward_test() {
  let json =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"oldestBlock\":\"0x1\",\"baseFeePerGas\":[\"0x3b9aca00\",\"0x3b9aca01\"],\"gasUsedRatio\":[0.5]}}"

  let fee_decoder = {
    use oldest_block <- decode.field("oldestBlock", decode.string)
    use base_fees <- decode.field("baseFeePerGas", decode.list(decode.string))
    use ratios <- decode.field("gasUsedRatio", decode.list(decode.float))
    use reward <- decode.optional_field(
      "reward",
      [],
      decode.list(decode.list(decode.string)),
    )
    decode.success(#(oldest_block, base_fees, ratios, reward))
  }

  let assert Ok(#(oldest, base_fees, ratios, reward)) =
    response_utils.decode_rpc_response(json, fee_decoder)
  oldest |> should.equal("0x1")
  base_fees |> should.equal(["0x3b9aca00", "0x3b9aca01"])
  ratios |> should.equal([0.5])
  reward |> should.equal([])
}

// =============================================================================
// Unexpected result types
// =============================================================================

pub fn decode_number_when_string_expected_test() {
  let json = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":12345}"
  let result = response_utils.decode_rpc_response(json, decode.string)
  result |> should.be_error
}

pub fn decode_object_when_string_expected_test() {
  let json =
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"unexpected\":\"object\"}}"
  let result = response_utils.decode_rpc_response(json, decode.string)
  result |> should.be_error
}

pub fn decode_boolean_result_test() {
  let json = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":true}"
  let assert Ok(value) = response_utils.decode_rpc_response(json, decode.bool)
  value |> should.be_true
}
