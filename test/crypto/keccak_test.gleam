import gleam/bit_array
import gleam/string
import gleeth/crypto/keccak
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Test known Keccac256 hash values from Ethereum test vectors
// These are real values used in the Ethereum ecosystem

pub fn keccac256_empty_string_test() {
  let result = keccak.keccac256_hex("")

  // Known hash of empty string
  should.equal(
    result,
    "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
  )
}

pub fn keccac256_hello_world_test() {
  let result = keccak.keccac256_hex("hello world")

  // Known hash of "hello world"
  should.equal(
    result,
    "0x47173285a8d7341e5e972fc677286384f802f8ef42a5ec5f03bbfa254cb01fad",
  )
}

pub fn keccac256_ethereum_test() {
  let result = keccak.keccac256_hex("ethereum")

  // Known hash of "ethereum"
  should.equal(
    result,
    "0x4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45",
  )
}

// Test function selectors for known ERC-20 functions
pub fn function_selector_balance_of_test() {
  let result = keccak.function_selector("balanceOf(address)")

  // Known selector for balanceOf(address)
  case result {
    Ok(selector) -> should.equal(selector, "0x70a08231")
    Error(_) -> should.be_true(False)
  }
}

pub fn function_selector_transfer_test() {
  let result = keccak.function_selector("transfer(address,uint256)")

  // Known selector for transfer(address,uint256)
  case result {
    Ok(selector) -> should.equal(selector, "0xa9059cbb")
    Error(_) -> should.be_true(False)
  }
}

pub fn function_selector_approve_test() {
  let result = keccak.function_selector("approve(address,uint256)")

  // Known selector for approve(address,uint256)
  case result {
    Ok(selector) -> should.equal(selector, "0x095ea7b3")
    Error(_) -> should.be_true(False)
  }
}

pub fn function_selector_total_supply_test() {
  let result = keccak.function_selector("totalSupply()")

  // Known selector for totalSupply()
  case result {
    Ok(selector) -> should.equal(selector, "0x18160ddd")
    Error(_) -> should.be_true(False)
  }
}

pub fn function_selector_allowance_test() {
  let result = keccak.function_selector("allowance(address,address)")

  // Known selector for allowance(address,address)
  case result {
    Ok(selector) -> should.equal(selector, "0xdd62ed3e")
    Error(_) -> should.be_true(False)
  }
}

pub fn function_selector_name_test() {
  let result = keccak.function_selector("name()")

  // Known selector for name()
  case result {
    Ok(selector) -> should.equal(selector, "0x06fdde03")
    Error(_) -> should.be_true(False)
  }
}

pub fn function_selector_symbol_test() {
  let result = keccak.function_selector("symbol()")

  // Known selector for symbol()
  case result {
    Ok(selector) -> should.equal(selector, "0x95d89b41")
    Error(_) -> should.be_true(False)
  }
}

pub fn function_selector_decimals_test() {
  let result = keccak.function_selector("decimals()")

  // Known selector for decimals()
  case result {
    Ok(selector) -> should.equal(selector, "0x313ce567")
    Error(_) -> should.be_true(False)
  }
}

// Test event topic generation
pub fn event_topic_transfer_test() {
  let topic = keccak.event_topic("Transfer(address,address,uint256)")

  // Known topic hash for Transfer event
  should.equal(
    topic,
    "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
  )
}

pub fn event_topic_approval_test() {
  let topic = keccak.event_topic("Approval(address,address,uint256)")

  // Known topic hash for Approval event
  should.equal(
    topic,
    "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925",
  )
}

// Test Uniswap function selectors
pub fn function_selector_get_reserves_test() {
  let result = keccak.function_selector("getReserves()")

  // Known selector for getReserves()
  case result {
    Ok(selector) -> should.equal(selector, "0x0902f1ac")
    Error(_) -> should.be_true(False)
  }
}

pub fn function_selector_token0_test() {
  let result = keccak.function_selector("token0()")

  // Known selector for token0()
  case result {
    Ok(selector) -> should.equal(selector, "0x0dfe1681")
    Error(_) -> should.be_true(False)
  }
}

pub fn function_selector_token1_test() {
  let result = keccak.function_selector("token1()")

  // Known selector for token1()
  case result {
    Ok(selector) -> should.equal(selector, "0xea18cbe4")
    Error(_) -> should.be_true(False)
  }
}

// Test hex output variants
pub fn keccac256_hex_no_prefix_test() {
  let result = keccak.keccac256_hex_no_prefix("hello")

  // Should not have 0x prefix
  should.be_false(string.starts_with(result, "0x"))

  // Should be 64 characters (32 bytes in hex)
  should.equal(string.length(result), 64)

  // Should be lowercase hex
  should.equal(result, string.lowercase(result))
}

pub fn keccac256_hex_with_prefix_test() {
  let result = keccak.keccac256_hex("hello")

  // Should have 0x prefix
  should.be_true(string.starts_with(result, "0x"))

  // Should be 66 characters total (2 for 0x + 64 hex chars)
  should.equal(string.length(result), 66)
}

// Test function selector length and format
pub fn function_selector_format_test() {
  let result = keccak.function_selector("test()")

  case result {
    Ok(selector) -> {
      // Should have 0x prefix
      should.be_true(string.starts_with(selector, "0x"))

      // Should be 10 characters total (0x + 8 hex chars = 4 bytes)
      should.equal(string.length(selector), 10)

      // Should be lowercase
      should.equal(selector, string.lowercase(selector))
    }
    Error(_) -> should.be_true(False)
  }
}

// Test verify_function_selector utility
pub fn verify_function_selector_correct_test() {
  let is_correct =
    keccak.verify_function_selector("balanceOf(address)", "0x70a08231")

  should.be_true(is_correct)
}

pub fn verify_function_selector_without_prefix_test() {
  let is_correct =
    keccak.verify_function_selector(
      "balanceOf(address)",
      "70a08231",
      // No 0x prefix
    )

  should.be_true(is_correct)
}

pub fn verify_function_selector_case_insensitive_test() {
  let is_correct =
    keccak.verify_function_selector(
      "balanceOf(address)",
      "0x70A08231",
      // Uppercase
    )

  should.be_true(is_correct)
}

pub fn verify_function_selector_incorrect_test() {
  let is_correct =
    keccak.verify_function_selector(
      "balanceOf(address)",
      "0x12345678",
      // Wrong selector
    )

  should.be_false(is_correct)
}

// Test with actual function signatures from popular contracts
pub fn function_selector_complex_types_test() {
  let result =
    keccak.function_selector(
      "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
    )

  // This is the actual selector from Uniswap V2 Router
  case result {
    Ok(selector) -> should.equal(selector, "0x38ed1739")
    Error(_) -> should.be_true(False)
  }
}

pub fn function_selector_with_structs_test() {
  let result =
    keccak.function_selector(
      "exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))",
    )

  // This is from Uniswap V3 (tuple parameter)
  case result {
    Ok(selector) -> should.equal(selector, "0x414bf389")
    Error(_) -> should.be_true(False)
  }
}

// Test edge cases
pub fn keccac256_single_character_test() {
  let result = keccak.keccac256_hex("a")

  // Should produce valid 32-byte hash
  should.equal(string.length(result), 66)
  // 0x + 64 chars
  should.be_true(string.starts_with(result, "0x"))
}

pub fn function_selector_no_params_test() {
  let result = keccak.function_selector("pause()")

  case result {
    Ok(selector) -> {
      // Should still produce 4-byte selector
      should.equal(string.length(selector), 10)
      // 0x + 8 chars
      should.be_true(string.starts_with(selector, "0x"))
    }
    Error(_) -> should.be_true(False)
  }
}

// Test binary data hashing
pub fn hash_binary_data_test() {
  // Create some binary data
  let data = bit_array.from_string("test data")
  let result = keccak.hash_binary_to_hex(data)

  // Should produce valid hash
  should.equal(string.length(result), 66)
  // 0x + 64 chars
  should.be_true(string.starts_with(result, "0x"))

  // Should be same as string version
  let string_result = keccak.keccac256_hex("test data")
  should.equal(result, string_result)
}

// Test consistency between different input methods
pub fn consistency_string_vs_binary_test() {
  let test_string = "consistency test"
  let string_hash = keccak.keccac256_hex(test_string)

  let binary_data = bit_array.from_string(test_string)
  let binary_hash = keccak.hash_binary_to_hex(binary_data)

  should.equal(string_hash, binary_hash)
}

// Test that different inputs produce different hashes
pub fn different_inputs_different_hashes_test() {
  let hash1 = keccak.keccac256_hex("input1")
  let hash2 = keccak.keccac256_hex("input2")

  should.not_equal(hash1, hash2)
}

// Test function signature variations
pub fn function_selector_spaces_matter_test() {
  let with_spaces_result =
    keccak.function_selector("transfer( address, uint256 )")
  let without_spaces_result =
    keccak.function_selector("transfer(address,uint256)")

  case with_spaces_result, without_spaces_result {
    Ok(with_spaces), Ok(without_spaces) -> {
      // Spaces in function signatures should produce different selectors
      should.not_equal(with_spaces, without_spaces)

      // The version without spaces should match the known selector
      should.equal(without_spaces, "0xa9059cbb")
    }
    _, _ -> should.be_true(False)
  }
}

// Test unknown function selector handling
pub fn function_selector_unknown_function_test() {
  let result = keccak.function_selector("unknownFunction()")

  case result {
    Error(msg) -> {
      should.be_true(string.starts_with(msg, "Unsupported function signature"))
      should.be_true(string.ends_with(msg, "unknownFunction()"))
    }
    Ok(_) -> should.be_true(False)
  }
}
