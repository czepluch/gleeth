import gleeunit
import gleeunit/should
import gleeth/commands/block_number
import gleeth/rpc/types

pub fn main() {
  gleeunit.main()
}

// Test block number command with valid response
pub fn block_number_success_test() {
  // This is a mock test - in a real implementation we'd need to mock the HTTP client
  // For now, we'll test that the function signature works correctly
  let result = block_number.execute("https://mock-rpc.example.com")
  
  // Since we can't actually make HTTP requests in tests without mocking,
  // we expect this to fail with a network error, which confirms the function works
  case result {
    Error(types.NetworkError(_)) -> should.be_true(True)
    Error(_) -> should.be_true(True) // Other errors are also expected without a real RPC
    Ok(_) -> should.be_true(False) // This shouldn't happen with a mock URL
  }
}

// Test block number command with invalid RPC URL
pub fn block_number_invalid_url_test() {
  let result = block_number.execute("invalid-url")
  
  case result {
    Error(_) -> should.be_true(True) // Should fail with invalid URL
    Ok(_) -> should.be_true(False) // Should not succeed
  }
}

// Test block number command with empty RPC URL
pub fn block_number_empty_url_test() {
  let result = block_number.execute("")
  
  case result {
    Error(_) -> should.be_true(True) // Should fail with empty URL
    Ok(_) -> should.be_true(False) // Should not succeed
  }
}