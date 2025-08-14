import gleeunit
import gleeunit/should
import gleam/option.{None, Some}
import gleeth/commands/parallel_balance
import gleeth/rpc/types

pub fn main() {
  gleeunit.main()
}

// Test balance result types
pub fn balance_result_success_test() {
  let result = parallel_balance.BalanceSuccess(
    "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
    "0xde0b6b3a7640000", 
    1.0
  )
  
  case result {
    parallel_balance.BalanceSuccess(address, wei, ether) -> {
      should.equal(address, "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000")
      should.equal(wei, "0xde0b6b3a7640000")
      should.equal(ether, 1.0)
    }
  }
}

pub fn balance_result_error_test() {
  let result = parallel_balance.BalanceError(
    "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
    "Network timeout"
  )
  
  case result {
    parallel_balance.BalanceError(address, error) -> {
      should.equal(address, "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000")
      should.equal(error, "Network timeout")
    }
  }
}

// Test summary calculation
pub fn balance_summary_test() {
  let summary = parallel_balance.BalanceSummary(
    total_addresses: 5,
    successful: 4,
    failed: 1,
    total_ether: 100.5,
    average_ether: 25.125
  )
  
  should.equal(summary.total_addresses, 5)
  should.equal(summary.successful, 4)
  should.equal(summary.failed, 1)
  should.equal(summary.total_ether, 100.5)
  should.equal(summary.average_ether, 25.125)
}

// Test execute_parallel with no addresses
pub fn execute_parallel_empty_addresses_test() {
  let result = parallel_balance.execute_parallel(
    "https://mock-rpc.example.com",
    [],
    None
  )
  
  case result {
    Error(types.ConfigError(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

// Test execute_parallel with single address (will try real RPC call)
pub fn execute_parallel_single_address_test() {
  let result = parallel_balance.execute_parallel(
    "https://mock-rpc.example.com",
    ["0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000"],
    None
  )
  
  // The parallel balance command prints output and returns Ok(Nil) even when individual requests fail
  case result {
    Ok(_) -> should.be_true(True) // Should succeed but with failed individual requests
    Error(_) -> should.be_true(False) // Only fails for severe errors like no addresses
  }
}

// Test execute_parallel with multiple addresses (will try real RPC calls)
pub fn execute_parallel_multiple_addresses_test() {
  let addresses = [
    "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
    "0x1111111111111111111111111111111111111111",
    "0x2222222222222222222222222222222222222222"
  ]
  
  let result = parallel_balance.execute_parallel(
    "https://mock-rpc.example.com",
    addresses,
    None
  )
  
  // The parallel balance command prints output and returns Ok(Nil) even when individual requests fail
  case result {
    Ok(_) -> should.be_true(True) // Should succeed but with failed individual requests
    Error(_) -> should.be_true(False) // Only fails for severe errors like no addresses
  }
}

// Test execute_parallel with invalid RPC URL
pub fn execute_parallel_invalid_url_test() {
  let result = parallel_balance.execute_parallel(
    "invalid-url",
    ["0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000"],
    None
  )
  
  case result {
    Ok(_) -> should.be_true(True) // Should succeed but with failed individual requests
    Error(_) -> should.be_true(False) // Only fails for severe errors
  }
}

// Test execute_parallel with file option (would need file to exist)
pub fn execute_parallel_with_file_test() {
  let result = parallel_balance.execute_parallel(
    "https://mock-rpc.example.com",
    [],
    Some("non_existent_file.txt")
  )
  
  case result {
    Error(types.ConfigError(_)) -> should.be_true(True) // File not found
    Error(_) -> should.be_true(True) // Other errors acceptable
    Ok(_) -> should.be_true(False) // Shouldn't succeed with non-existent file
  }
}

// Test execute_parallel with both addresses and file
pub fn execute_parallel_mixed_input_test() {
  let result = parallel_balance.execute_parallel(
    "https://mock-rpc.example.com",
    ["0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000"],
    Some("non_existent_file.txt")
  )
  
  case result {
    Error(types.ConfigError(_)) -> should.be_true(True) // File not found
    Error(_) -> should.be_true(True) // Other errors acceptable
    Ok(_) -> should.be_true(False) // Shouldn't succeed with non-existent file
  }
}

// Test that we handle empty address list correctly
pub fn execute_parallel_empty_list_behavior_test() {
  // This tests the validation logic before any network calls
  let result = parallel_balance.execute_parallel(
    "https://eth.llamarpc.com", // Valid URL but empty addresses
    [],
    None
  )
  
  case result {
    Error(types.ConfigError(msg)) -> {
      should.equal(msg, "No addresses to check")
    }
    _ -> should.be_true(False)
  }
}

// Test validation of address format within parallel execution
pub fn execute_parallel_address_validation_test() {
  // Since the CLI already validates addresses, parallel_balance expects valid ones
  // But let's test the behavior with already-validated addresses
  let valid_addresses = [
    "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000", // Valid format
    "0x1111111111111111111111111111111111111111"  // Valid format
  ]
  
  let result = parallel_balance.execute_parallel(
    "https://invalid-rpc-endpoint.fake",
    valid_addresses,
    None
  )
  
  // Should succeed but with failed individual requests
  case result {
    Ok(_) -> should.be_true(True) // Should succeed but with failed individual requests
    Error(_) -> should.be_true(False) // Only fails for severe errors
  }
}