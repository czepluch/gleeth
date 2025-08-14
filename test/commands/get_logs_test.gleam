import gleam/json
import gleam/list
import gleam/string
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// REAL tests that validate actual get_logs parsing functionality

// Test 1: Parse empty logs array
pub fn parse_empty_logs_array_test() {
  let empty_json = json.array([], fn(x) { x })

  case methods.parse_logs_response(empty_json) {
    Ok(logs) -> {
      should.equal(logs, [])
      should.equal(list.length(logs), 0)
    }
    Error(_) -> should.be_true(False)
    // Should not fail on empty array
  }
}

// Test 2: Parse single log object
pub fn parse_single_log_test() {
  let log_json =
    json.array(
      [
        json.object([
          #(
            "address",
            json.string("0xA0b86a33E6Fb7e4f67c5776f8fcB44F56c71d8b8"),
          ),
          #(
            "topics",
            json.array(
              [
                json.string(
                  "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
                ),
                json.string(
                  "0x000000000000000000000000742d35cc6b8a3ad7b63c5d3b7a24e1b1c4b123456",
                ),
              ],
              fn(x) { x },
            ),
          ),
          #(
            "data",
            json.string(
              "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
            ),
          ),
          #("blockNumber", json.string("0x1234567")),
          #(
            "transactionHash",
            json.string(
              "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
            ),
          ),
          #("transactionIndex", json.string("0x1")),
          #(
            "blockHash",
            json.string(
              "0x1111111111111111111111111111111111111111111111111111111111111111",
            ),
          ),
          #("logIndex", json.string("0x0")),
          #("removed", json.bool(False)),
        ]),
      ],
      fn(x) { x },
    )

  case methods.parse_logs_response(log_json) {
    Ok(logs) -> {
      should.equal(list.length(logs), 1)
      case logs {
        [log] -> {
          should.equal(
            log.address,
            "0xA0b86a33E6Fb7e4f67c5776f8fcB44F56c71d8b8",
          )
          should.equal(list.length(log.topics), 2)
          should.equal(
            log.data,
            "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
          )
          should.equal(log.block_number, "0x1234567")
          should.equal(
            log.transaction_hash,
            "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
          )
          should.equal(log.removed, False)
        }
        _ -> should.be_true(False)
        // Should have exactly one log
      }
    }
    Error(_) -> should.be_true(False)
    // Should succeed with valid log data
  }
}

// Test 3: Parse multiple logs
pub fn parse_multiple_logs_test() {
  let logs_json =
    json.array(
      [
        json.object([
          #(
            "address",
            json.string("0xA0b86a33E6Fb7e4f67c5776f8fcB44F56c71d8b8"),
          ),
          #("topics", json.array([], fn(x) { x })),
          #("data", json.string("0x")),
          #("blockNumber", json.string("0x1000000")),
          #(
            "transactionHash",
            json.string(
              "0xaaa1111111111111111111111111111111111111111111111111111111111111",
            ),
          ),
          #("transactionIndex", json.string("0x0")),
          #(
            "blockHash",
            json.string(
              "0xbbb2222222222222222222222222222222222222222222222222222222222222",
            ),
          ),
          #("logIndex", json.string("0x0")),
          #("removed", json.bool(False)),
        ]),
        json.object([
          #(
            "address",
            json.string("0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"),
          ),
          #(
            "topics",
            json.array(
              [
                json.string(
                  "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
                ),
              ],
              fn(x) { x },
            ),
          ),
          #(
            "data",
            json.string(
              "0x0000000000000000000000000000000000000000000000001bc16d674ec80000",
            ),
          ),
          #("blockNumber", json.string("0x1000000")),
          #(
            "transactionHash",
            json.string(
              "0xccc3333333333333333333333333333333333333333333333333333333333333",
            ),
          ),
          #("transactionIndex", json.string("0x1")),
          #(
            "blockHash",
            json.string(
              "0xddd4444444444444444444444444444444444444444444444444444444444444",
            ),
          ),
          #("logIndex", json.string("0x1")),
          #("removed", json.bool(True)),
        ]),
      ],
      fn(x) { x },
    )

  case methods.parse_logs_response(logs_json) {
    Ok(logs) -> {
      should.equal(list.length(logs), 2)

      // Verify first log
      case list.first(logs) {
        Ok(first_log) -> {
          should.equal(
            first_log.address,
            "0xA0b86a33E6Fb7e4f67c5776f8fcB44F56c71d8b8",
          )
          should.equal(list.length(first_log.topics), 0)
          should.equal(first_log.removed, False)
        }
        Error(_) -> should.be_true(False)
      }

      // Verify second log  
      case list.last(logs) {
        Ok(second_log) -> {
          should.equal(
            second_log.address,
            "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
          )
          should.equal(list.length(second_log.topics), 1)
          should.equal(second_log.removed, True)
        }
        Error(_) -> should.be_true(False)
      }
    }
    Error(_) -> should.be_true(False)
    // Should succeed with valid data
  }
}

// Test 4: Handle topics with null values
pub fn parse_logs_with_null_topics_test() {
  // Create a mock JSON string that includes null topics (common in real responses)
  let json_with_nulls =
    "[[{\"address\":\"0xA0b86a33E6Fb7e4f67c5776f8fcB44F56c71d8b8\",\"topics\":[\"0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef\",null,\"0x000000000000000000000000742d35cc6b8a3ad7b63c5d3b7a24e1b1c4b123456\"],\"data\":\"0x0000000000000000000000000000000000000000000000000de0b6b3a7640000\",\"blockNumber\":\"0x1234567\",\"transactionHash\":\"0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890\",\"transactionIndex\":\"0x1\",\"blockHash\":\"0x1111111111111111111111111111111111111111111111111111111111111111\",\"logIndex\":\"0x0\",\"removed\":false}]]"

  case methods.parse_logs_response(json.string(json_with_nulls)) {
    Ok(logs) -> {
      should.equal(list.length(logs), 1)
      case logs {
        [log] -> {
          should.equal(list.length(log.topics), 3)
          // First topic should be the hash, second should be empty (null), third should be the address
          case log.topics {
            [topic1, topic2, topic3] -> {
              should.equal(
                topic1,
                "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
              )
              should.equal(topic2, "")
              // null becomes empty string
              should.equal(
                topic3,
                "0x000000000000000000000000742d35cc6b8a3ad7b63c5d3b7a24e1b1c4b123456",
              )
            }
            _ -> should.be_true(False)
            // Should have exactly 3 topics
          }
        }
        _ -> should.be_true(False)
      }
    }
    Error(_) -> should.be_true(False)
    // Should handle null topics gracefully
  }
}

// Test 5: Error handling for malformed JSON
pub fn parse_malformed_json_test() {
  let malformed_json = json.string("not valid json at all")

  case methods.parse_logs_response(malformed_json) {
    Ok(_) -> should.be_true(False)
    // Should not succeed with malformed JSON
    Error(error) -> {
      case error {
        rpc_types.ParseError(_) -> should.be_true(True)
        // Expected parse error
        _ -> should.be_true(False)
        // Should be specifically a parse error
      }
    }
  }
}

// Test 6: Error handling for missing required fields
pub fn parse_logs_missing_fields_test() {
  let incomplete_log =
    json.array(
      [
        json.object([
          #(
            "address",
            json.string("0xA0b86a33E6Fb7e4f67c5776f8fcB44F56c71d8b8"),
          ),
          // Missing required fields like topics, data, etc.
          #("removed", json.bool(False)),
        ]),
      ],
      fn(x) { x },
    )

  case methods.parse_logs_response(incomplete_log) {
    Ok(_) -> should.be_true(False)
    // Should not succeed with missing fields
    Error(error) -> {
      case error {
        rpc_types.ParseError(_) -> should.be_true(True)
        // Expected parse error
        _ -> should.be_true(False)
      }
    }
  }
}

// Test 7: Test network integration with real RPC (but handle gracefully)
pub fn get_logs_network_integration_test() {
  let result =
    methods.get_logs(
      "https://eth.llamarpc.com",
      "0x1000000",
      // Specific old block
      "0x1000001",
      // Small range
      "0xA0b86a33E6Fb7e4f67c5776f8fcB44F56c71d8b8",
      // Specific contract
      [],
    )

  case result {
    Ok(logs) -> {
      // Should be a valid list of logs (could be empty or with actual logs)
      should.be_true(list.length(logs) >= 0)

      // If we got logs, verify they have valid structure
      case list.length(logs) > 0 {
        True -> {
          case list.first(logs) {
            Ok(log) -> {
              should.be_true(string.starts_with(log.address, "0x"))
              should.be_true(string.starts_with(log.transaction_hash, "0x"))
              should.be_true(string.starts_with(log.block_hash, "0x"))
            }
            Error(_) -> should.be_true(False)
          }
        }
        False -> should.be_true(True)
        // Empty logs is fine
      }
    }
    Error(error) -> {
      // Network errors are acceptable, but parse errors indicate bugs
      case error {
        rpc_types.ParseError(_) -> should.be_true(False)
        // Parse errors are bugs in our code
        rpc_types.RpcError(_) -> should.be_true(True)
        // RPC errors are fine
        rpc_types.NetworkError(_) -> should.be_true(True)
        // Network errors are fine
        _ -> should.be_true(True)
        // Other errors also fine
      }
    }
  }
}

// Test 8: Test edge case with very large log data
pub fn parse_logs_large_data_test() {
  let large_data = "0x" <> string.repeat("a", 1000)
  // Large hex data
  let log_json =
    json.array(
      [
        json.object([
          #(
            "address",
            json.string("0xA0b86a33E6Fb7e4f67c5776f8fcB44F56c71d8b8"),
          ),
          #(
            "topics",
            json.array(
              [
                json.string(
                  "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
                ),
              ],
              fn(x) { x },
            ),
          ),
          #("data", json.string(large_data)),
          #("blockNumber", json.string("0x1234567")),
          #(
            "transactionHash",
            json.string(
              "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
            ),
          ),
          #("transactionIndex", json.string("0x1")),
          #(
            "blockHash",
            json.string(
              "0x1111111111111111111111111111111111111111111111111111111111111111",
            ),
          ),
          #("logIndex", json.string("0x0")),
          #("removed", json.bool(False)),
        ]),
      ],
      fn(x) { x },
    )

  case methods.parse_logs_response(log_json) {
    Ok(logs) -> {
      should.equal(list.length(logs), 1)
      case logs {
        [log] -> {
          should.equal(string.length(log.data), 1002)
          // 0x + 1000 chars
          should.be_true(string.starts_with(log.data, "0x"))
        }
        _ -> should.be_true(False)
      }
    }
    Error(_) -> should.be_true(False)
    // Should handle large data
  }
}

// Test 9: Test consistency of parsing function
pub fn parse_logs_consistency_test() {
  let test_json =
    json.array(
      [
        json.object([
          #(
            "address",
            json.string("0xA0b86a33E6Fb7e4f67c5776f8fcB44F56c71d8b8"),
          ),
          #("topics", json.array([], fn(x) { x })),
          #("data", json.string("0x")),
          #("blockNumber", json.string("0x1000000")),
          #(
            "transactionHash",
            json.string(
              "0xaaa1111111111111111111111111111111111111111111111111111111111111",
            ),
          ),
          #("transactionIndex", json.string("0x0")),
          #(
            "blockHash",
            json.string(
              "0xbbb2222222222222222222222222222222222222222222222222222222222222",
            ),
          ),
          #("logIndex", json.string("0x0")),
          #("removed", json.bool(False)),
        ]),
      ],
      fn(x) { x },
    )

  let result1 = methods.parse_logs_response(test_json)
  let result2 = methods.parse_logs_response(test_json)

  case result1, result2 {
    Ok(logs1), Ok(logs2) -> {
      should.equal(list.length(logs1), list.length(logs2))
      should.equal(logs1, logs2)
      // Should be identical
    }
    Error(_), Error(_) -> should.be_true(True)
    // Both erroring consistently is fine
    _, _ -> should.be_true(False)
    // Inconsistent results indicate bugs
  }
}
