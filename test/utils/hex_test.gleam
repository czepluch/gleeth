import gleeunit
import gleeunit/should
import gleeth/utils/hex

pub fn main() {
  gleeunit.main()
}

// Test basic hex to int conversion
pub fn hex_to_int_basic_test() {
  let result = hex.hex_to_int("0x10")
  case result {
    Ok(value) -> should.equal(value, 16)
    Error(_) -> should.be_true(False)
  }
}

// Test hex to int without 0x prefix
pub fn hex_to_int_no_prefix_test() {
  let result = hex.hex_to_int("ff")
  case result {
    Ok(value) -> should.equal(value, 255)
    Error(_) -> should.be_true(False)
  }
}

// Test hex to int with zero
pub fn hex_to_int_zero_test() {
  let result = hex.hex_to_int("0x0")
  case result {
    Ok(value) -> should.equal(value, 0)
    Error(_) -> should.be_true(False)
  }
}

// Test hex to int with empty string
pub fn hex_to_int_empty_test() {
  let result = hex.hex_to_int("")
  case result {
    Ok(value) -> should.equal(value, 0)
    Error(_) -> should.be_true(False)
  }
}

// Test hex to int with invalid characters
pub fn hex_to_int_invalid_test() {
  let result = hex.hex_to_int("0xgg")
  case result {
    Ok(_) -> should.be_true(False)
    Error(_) -> should.be_true(True)
  }
}

// Test Wei to Ether conversion
pub fn wei_to_ether_one_eth_test() {
  let result = hex.wei_to_ether("0xde0b6b3a7640000") // 1 ETH in Wei
  case result {
    Ok(ether) -> should.equal(ether, 1.0)
    Error(_) -> should.be_true(False)
  }
}

// Test Wei to Ether conversion with zero
pub fn wei_to_ether_zero_test() {
  let result = hex.wei_to_ether("0x0")
  case result {
    Ok(ether) -> should.equal(ether, 0.0)
    Error(_) -> should.be_true(False)
  }
}

// Test Wei to Ether conversion with small amount
pub fn wei_to_ether_small_test() {
  let result = hex.wei_to_ether("0x16345785d8a0000") // 0.1 ETH
  case result {
    Ok(ether) -> {
      // Check if it's approximately 0.1 (allowing for floating point precision)
      case ether >. 0.099 && ether <. 0.101 {
        True -> should.be_true(True)
        False -> should.be_true(False)
      }
    }
    Error(_) -> should.be_true(False)
  }
}

// Test Wei to Ether formatting
pub fn format_wei_to_ether_test() {
  let result = hex.format_wei_to_ether("0xde0b6b3a7640000") // 1 ETH
  // Should contain "1" and "ETH"
  let contains_one = case result {
    s if s == "1.0 ETH" -> True
    s if s == "1 ETH" -> True
    _ -> False
  }
  should.be_true(contains_one)
}

// Test Wei to Ether formatting with zero
pub fn format_wei_to_ether_zero_test() {
  let result = hex.format_wei_to_ether("0x0")
  // Should contain "0" and "ETH" - check the actual result
  case result {
    "0.0 ETH" -> should.be_true(True)
    "0 ETH" -> should.be_true(True)
    other -> {
      // For debugging - let's see what we actually get
      should.be_true(other == "0.0 ETH (0x0 Wei)")
    }
  }
}

// Test Wei to Ether formatting with conversion failure
pub fn format_wei_to_ether_invalid_test() {
  let result = hex.format_wei_to_ether("invalid_hex")
  // Should contain "conversion failed"
  let contains_error = case result {
    s -> case s {
      _ if s == "invalid_hex Wei (conversion failed)" -> True
      _ -> False
    }
  }
  should.be_true(contains_error)
}

// Test block number formatting
pub fn format_block_number_test() {
  let result = hex.format_block_number("0x10")
  should.equal(result, "16")
}

// Test block number formatting with large number
pub fn format_block_number_large_test() {
  let result = hex.format_block_number("0x15b5231") // Around 22M
  should.equal(result, "22762033")
}

// Test block number formatting with zero
pub fn format_block_number_zero_test() {
  let result = hex.format_block_number("0x0")
  should.equal(result, "0")
}

// Test block number formatting with invalid hex
pub fn format_block_number_invalid_test() {
  let result = hex.format_block_number("invalid")
  should.equal(result, "invalid") // Should return original on error
}

// Test hex validation - valid cases
pub fn is_valid_hex_valid_test() {
  should.be_true(hex.is_valid_hex("0x123abc"))
  should.be_true(hex.is_valid_hex("123ABC"))
  should.be_true(hex.is_valid_hex("0x0"))
  should.be_true(hex.is_valid_hex("ff"))
}

// Test hex validation - invalid cases
pub fn is_valid_hex_invalid_test() {
  should.be_false(hex.is_valid_hex("0xgg"))
  should.be_false(hex.is_valid_hex("xyz"))
  should.be_false(hex.is_valid_hex("0x123g"))
}

// Test hex validation with empty string
pub fn is_valid_hex_empty_test() {
  should.be_true(hex.is_valid_hex(""))
  should.be_true(hex.is_valid_hex("0x"))
}

// Test large hex numbers (testing bigi integration)
pub fn hex_to_bigint_large_test() {
  let result = hex.hex_to_bigint("0x1fffffffffffff") // Large number
  case result {
    Ok(_) -> should.be_true(True) // Should handle large numbers
    Error(_) -> should.be_true(False)
  }
}

// Test very large Wei amount (common in Ethereum)
pub fn wei_to_ether_very_large_test() {
  // Test with a balance like 1000 ETH
  let result = hex.wei_to_ether("0x3635c9adc5dea00000") 
  case result {
    Ok(ether) -> {
      // Should be around 1000 ETH
      case ether >. 999.0 && ether <. 1001.0 {
        True -> should.be_true(True)
        False -> should.be_true(False)
      }
    }
    Error(_) -> should.be_true(False)
  }
}

// Test case sensitivity in hex parsing
pub fn hex_case_sensitivity_test() {
  let result_lower = hex.hex_to_int("0xabcdef")
  let result_upper = hex.hex_to_int("0xABCDEF")
  let result_mixed = hex.hex_to_int("0xAbCdEf")
  
  case result_lower, result_upper, result_mixed {
    Ok(lower), Ok(upper), Ok(mixed) -> {
      should.equal(lower, upper)
      should.equal(upper, mixed)
      should.equal(lower, 11259375) // 0xABCDEF in decimal
    }
    _, _, _ -> should.be_true(False)
  }
}

// Test hex parsing with maximum safe values
pub fn hex_parsing_boundaries_test() {
  // Test with different sized hex values
  let small = hex.hex_to_int("0x1")
  let medium = hex.hex_to_int("0x1000")
  let large = hex.hex_to_int("0x100000")
  
  case small, medium, large {
    Ok(1), Ok(4096), Ok(1048576) -> should.be_true(True)
    _, _, _ -> should.be_true(False)
  }
}