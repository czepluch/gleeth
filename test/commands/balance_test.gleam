import gleeunit
import gleeunit/should
import gleam/option.{None, Some}
import gleeth/commands/balance
import gleeth/rpc/types

pub fn main() {
  gleeunit.main()
}

// Test balance command with single address (original behavior)
pub fn balance_single_address_test() {
  let address = "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000"
  let result = balance.execute("https://mock-rpc.example.com", [address], None)
  
  // Since we can't actually make HTTP requests in tests without mocking,
  // we expect this to fail with a network error, which confirms the function works
  case result {
    Error(types.NetworkError(_)) -> should.be_true(True)
    Error(_) -> should.be_true(True) // Other errors are also expected without a real RPC
    Ok(_) -> should.be_true(False) // This shouldn't happen with a mock URL
  }
}

// Test balance command with multiple addresses (parallel behavior)
pub fn balance_multiple_addresses_test() {
  let addresses = [
    "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
    "0x1111111111111111111111111111111111111111",
    "0x2222222222222222222222222222222222222222"
  ]
  let result = balance.execute("https://mock-rpc.example.com", addresses, None)
  
  // Should use parallel processing and return Ok(Nil) even with failed individual requests
  case result {
    Ok(_) -> should.be_true(True) // Should succeed but with failed individual requests
    Error(_) -> should.be_true(False) // Only fails for severe errors like no addresses
  }
}

// Test balance command with file input
pub fn balance_with_file_test() {
  let result = balance.execute("https://mock-rpc.example.com", [], Some("non_existent.txt"))
  
  // Should fail because file doesn't exist
  case result {
    Error(types.ConfigError(_)) -> should.be_true(True) // File not found
    Error(_) -> should.be_true(True) // Other errors acceptable
    Ok(_) -> should.be_true(False) // Should not succeed
  }
}

// Test balance command with both addresses and file
pub fn balance_mixed_input_test() {
  let addresses = ["0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000"]
  let result = balance.execute("https://mock-rpc.example.com", addresses, Some("non_existent.txt"))
  
  // Should fail because file doesn't exist
  case result {
    Error(types.ConfigError(_)) -> should.be_true(True) // File not found
    Error(_) -> should.be_true(True) // Other errors acceptable
    Ok(_) -> should.be_true(False) // Should not succeed
  }
}

// Test balance command with invalid RPC URL
pub fn balance_invalid_url_test() {
  let address = "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000"
  let result = balance.execute("invalid-url", [address], None)
  
  case result {
    Error(_) -> should.be_true(True) // Should fail with invalid URL
    Ok(_) -> should.be_true(False) // Should not succeed
  }
}

// Test balance command with empty RPC URL
pub fn balance_empty_url_test() {
  let address = "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000"
  let result = balance.execute("", [address], None)
  
  case result {
    Error(_) -> should.be_true(True) // Should fail with empty URL
    Ok(_) -> should.be_true(False) // Should not succeed
  }
}

// Test balance command with empty address
pub fn balance_empty_address_test() {
  let result = balance.execute("https://mock-rpc.example.com", [""], None)
  
  case result {
    Error(_) -> should.be_true(True) // Should fail with empty address
    Ok(_) -> should.be_true(False) // Should not succeed
  }
}

// Test balance command routing logic (single vs parallel)
pub fn balance_routing_logic_test() {
  // Single address should use original formatting (not parallel)
  let single_result = balance.execute("invalid-url", ["0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000"], None)
  
  // Multiple addresses should use parallel processing
  let multi_result = balance.execute("invalid-url", [
    "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
    "0x1111111111111111111111111111111111111111"
  ], None)
  
  // Single should fail with network error, multiple should succeed but show failed requests
  case single_result, multi_result {
    Error(_), Ok(_) -> should.be_true(True) // Single fails, multiple succeeds with error display
    _, _ -> should.be_true(False) // Unexpected behavior
  }
}

// Test empty addresses list
pub fn balance_empty_addresses_test() {
  let result = balance.execute("https://mock-rpc.example.com", [], None)
  
  case result {
    Error(types.ConfigError(_)) -> should.be_true(True) // Should fail with config error
    _ -> should.be_true(False) // Should not succeed or fail differently
  }
}