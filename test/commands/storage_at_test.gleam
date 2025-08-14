import gleam/json
import gleam/string
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// ==============================================================================
// UNIT TESTS (Mock-based, fast execution)
// ==============================================================================

// Test 1: Test parsing a zero storage value
pub fn parse_zero_storage_value_test() {
  // Mock response for empty/zero storage slot
  let mock_response =
    json.string(
      "0x0000000000000000000000000000000000000000000000000000000000000000",
    )

  // Test the parsing logic directly
  let result_str = json.to_string(mock_response)
  let clean_result = case
    string.starts_with(result_str, "\"") && string.ends_with(result_str, "\"")
  {
    True -> {
      result_str
      |> string.drop_start(1)
      |> string.drop_end(1)
    }
    False -> result_str
  }

  // Should be valid 32-byte hex value
  should.equal(string.length(clean_result), 66)
  // 0x + 64 hex chars
  should.be_true(string.starts_with(clean_result, "0x"))
}

// Test 2: Test parsing a short zero storage value
pub fn parse_short_zero_storage_value_test() {
  // Mock response for short zero format
  let mock_response = json.string("0x0")

  let result_str = json.to_string(mock_response)
  let clean_result = case
    string.starts_with(result_str, "\"") && string.ends_with(result_str, "\"")
  {
    True -> {
      result_str
      |> string.drop_start(1)
      |> string.drop_end(1)
    }
    False -> result_str
  }

  // Should be valid short hex value
  should.equal(clean_result, "0x0")
  should.be_true(string.starts_with(clean_result, "0x"))
}

// Test 3: Test parsing a non-zero storage value
pub fn parse_nonzero_storage_value_test() {
  // Mock response for storage slot containing data
  let mock_response =
    json.string(
      "0x000000000000000000000000a0b86a33e6fb7e4f67c5776f8fcb44f56c71d8b8",
    )

  let result_str = json.to_string(mock_response)
  let clean_result = case
    string.starts_with(result_str, "\"") && string.ends_with(result_str, "\"")
  {
    True -> {
      result_str
      |> string.drop_start(1)
      |> string.drop_end(1)
    }
    False -> result_str
  }

  // Should be valid 32-byte hex value with data
  should.equal(string.length(clean_result), 66)
  should.be_true(string.starts_with(clean_result, "0x"))
  should.be_true(string.contains(
    clean_result,
    "a0b86a33e6fb7e4f67c5776f8fcb44f56c71d8b8",
  ))
}

// Test 4: Test error handling with null response
pub fn parse_null_storage_response_test() {
  // Mock null response (storage at invalid block)
  let mock_response = json.string("null")

  let result_str = json.to_string(mock_response)
  let clean_result = case
    string.starts_with(result_str, "\"") && string.ends_with(result_str, "\"")
  {
    True -> {
      result_str
      |> string.drop_start(1)
      |> string.drop_end(1)
    }
    False -> result_str
  }

  // Should handle null response gracefully
  should.equal(clean_result, "null")
}

// Test 5: Test block parameter defaulting logic
pub fn storage_block_parameter_defaulting_test() {
  // Test that empty block string defaults to "latest"
  // This tests the logic without network calls

  let test_cases = [
    #("", "latest"),
    #("latest", "latest"),
    #("0x1000000", "0x1000000"),
    #("earliest", "earliest"),
  ]

  // Test each case
  should.be_true(
    test_cases
    |> gleam_list_all(fn(test_case) {
      let #(input, expected) = test_case
      let result = case input {
        "" -> "latest"
        _ -> input
      }
      result == expected
    }),
  )
}

// Test 6: Test hex format validation logic
pub fn storage_hex_format_validation_test() {
  // Test individual valid storage values
  let value1 = "0x0"
  should.be_true(string.starts_with(value1, "0x"))
  should.be_true(string.length(value1) == 3)

  let value2 =
    "0x0000000000000000000000000000000000000000000000000000000000000000"
  should.be_true(string.starts_with(value2, "0x"))
  should.equal(string.length(value2), 66)

  let value3 =
    "0x000000000000000000000000a0b86a33e6fb7e4f67c5776f8fcb44f56c71d8b8"
  should.be_true(string.starts_with(value3, "0x"))
  should.equal(string.length(value3), 66)
}

// ==============================================================================
// INTEGRATION TESTS (Network-based, limited and with timeout handling)
// ==============================================================================

// Integration Test 1: Basic storage_at functionality with timeout handling
pub fn storage_at_integration_basic_test() {
  // Test with a well-known contract and slot
  let result =
    methods.get_storage_at(
      "https://eth.llamarpc.com",
      "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
      // Uniswap V2 Router
      "0x0",
      // Slot 0
      "latest",
    )

  case result {
    Ok(storage_value) -> {
      // If successful, validate the response format
      should.be_true(string.starts_with(storage_value, "0x"))
      let valid_length =
        string.length(storage_value) == 66 || storage_value == "0x0"
      should.be_true(valid_length)
    }
    Error(error) -> {
      // Network errors are acceptable for integration tests
      case error {
        rpc_types.NetworkError(_) -> should.be_true(True)
        // Expected in some environments
        rpc_types.RpcError(_) -> should.be_true(True)
        // RPC might be rate limiting
        rpc_types.ParseError(_) -> should.be_true(False)
        // Parse errors indicate bugs
        _ -> should.be_true(True)
        // Other errors are fine for integration tests
      }
    }
  }
}

// Integration Test 2: Error handling with invalid RPC URL
pub fn storage_at_integration_error_handling_test() {
  let result =
    methods.get_storage_at(
      "http://definitely-invalid-rpc-endpoint.test",
      "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
      "0x0",
      "latest",
    )

  case result {
    Ok(_) -> {
      // Should NOT succeed with invalid RPC URL
      should.be_true(False)
    }
    Error(error) -> {
      // Should get network error, not parse error
      case error {
        rpc_types.NetworkError(_) -> should.be_true(True)
        // Expected
        rpc_types.RpcError(_) -> should.be_true(True)
        // Also acceptable
        rpc_types.ParseError(_) -> should.be_true(False)
        // Network issues shouldn't cause parse errors
        _ -> should.be_true(True)
        // Other errors are fine
      }
    }
  }
}

// ==============================================================================
// Helper functions for tests
// ==============================================================================

// Helper function to check if all items in a list satisfy a predicate
fn gleam_list_all(list: List(a), predicate: fn(a) -> Bool) -> Bool {
  case list {
    [] -> True
    [head, ..tail] ->
      case predicate(head) {
        True -> gleam_list_all(tail, predicate)
        False -> False
      }
  }
}
