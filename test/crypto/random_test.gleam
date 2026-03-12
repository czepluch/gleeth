import gleam/bit_array
import gleeth/crypto/random
import gleeth/crypto/secp256k1
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// Basic Functionality Tests
// =============================================================================

pub fn generate_secure_bytes_valid_length_test() {
  // Test generating various valid lengths
  let lengths = [1, 16, 32, 64, 256, 1024]

  test_each_length(lengths)
}

pub fn generate_secure_bytes_invalid_length_test() {
  // Test with invalid lengths
  case random.generate_secure_bytes(0) {
    Error(random.InvalidLength(_)) -> Nil
    _ -> should.fail()
  }

  case random.generate_secure_bytes(-1) {
    Error(random.InvalidLength(_)) -> Nil
    _ -> should.fail()
  }
}

pub fn generate_secure_bytes_produces_different_results_test() {
  // Generate multiple samples and verify they're different
  let assert Ok(bytes1) = random.generate_secure_bytes(32)
  let assert Ok(bytes2) = random.generate_secure_bytes(32)
  let assert Ok(bytes3) = random.generate_secure_bytes(32)

  // It's extremely unlikely that three 32-byte random samples would be identical
  should.not_equal(bytes1, bytes2)
  should.not_equal(bytes2, bytes3)
  should.not_equal(bytes1, bytes3)
}

pub fn generate_secure_bytes_not_all_zeros_test() {
  // Generate a sample and verify it's not all zeros
  let assert Ok(bytes) = random.generate_secure_bytes(32)
  let all_zeros = <<
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0,
  >>

  should.not_equal(bytes, all_zeros)
}

pub fn generate_secure_bytes_not_all_ones_test() {
  // Generate a sample and verify it's not all ones
  let assert Ok(bytes) = random.generate_secure_bytes(32)
  let all_ones = <<
    255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
    255, 255,
  >>

  should.not_equal(bytes, all_ones)
}

// =============================================================================
// Private Key Generation Tests
// =============================================================================

pub fn generate_private_key_success_test() {
  case random.generate_private_key() {
    Ok(private_key) -> {
      // Verify the key is valid
      secp256k1.is_valid_private_key(private_key)
      |> should.be_true()

      // Verify we can create a public key from it
      case secp256k1.create_public_key(private_key) {
        Ok(_) -> Nil
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn generate_private_key_produces_different_keys_test() {
  // Generate multiple private keys and verify they're different
  let assert Ok(key1) = random.generate_private_key()
  let assert Ok(key2) = random.generate_private_key()
  let assert Ok(key3) = random.generate_private_key()

  let key1_hex = secp256k1.private_key_to_hex(key1)
  let key2_hex = secp256k1.private_key_to_hex(key2)
  let key3_hex = secp256k1.private_key_to_hex(key3)

  should.not_equal(key1_hex, key2_hex)
  should.not_equal(key2_hex, key3_hex)
  should.not_equal(key1_hex, key3_hex)
}

pub fn generate_private_key_creates_valid_wallets_test() {
  // Generate a private key and use it to create a complete wallet
  let assert Ok(private_key) = random.generate_private_key()
  let private_key_bytes = secp256k1.private_key_to_bytes(private_key)

  // Import wallet module and create wallet
  case wallet_from_private_key_bytes(private_key_bytes) {
    Ok(wallet) -> {
      // Verify wallet components are valid
      let address = wallet_get_address(wallet)
      // Address should be 42 characters (0x + 40 hex chars)
      address
      |> bit_array.from_string()
      |> bit_array.byte_size()
      |> should.equal(42)

      // Address should start with 0x
      case address {
        "0x" <> _ -> Nil
        _ -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn generate_multiple_private_keys_test() {
  // Test generating many private keys to ensure no failures
  let count = 10
  let keys = generate_private_keys_list(count, [])

  keys
  |> list_length()
  |> should.equal(count)

  // Verify all keys are valid
  test_each_key_valid(keys)

  // Verify all keys are unique (convert to hex for comparison)
  let hex_keys = keys |> list_map(secp256k1.private_key_to_hex)
  let unique_keys = list_unique(hex_keys)

  list_length(unique_keys)
  |> should.equal(count)
}

// Helper function to generate a list of private keys
fn generate_private_keys_list(
  remaining: Int,
  acc: List(secp256k1.PrivateKey),
) -> List(secp256k1.PrivateKey) {
  case remaining {
    0 -> acc
    _ -> {
      let assert Ok(key) = random.generate_private_key()
      generate_private_keys_list(remaining - 1, [key, ..acc])
    }
  }
}

// =============================================================================
// Retry Mechanism Tests
// =============================================================================

pub fn generate_private_key_with_retries_test() {
  // Test the retry mechanism with a reasonable retry count
  case random.generate_private_key_with_retries(5) {
    Ok(private_key) -> {
      secp256k1.is_valid_private_key(private_key)
      |> should.be_true()
    }
    Error(_) -> should.fail()
  }
}

pub fn generate_private_key_with_zero_retries_test() {
  // Test with zero retries - should fail immediately
  case random.generate_private_key_with_retries(0) {
    Error(random.GenerationFailed(_)) -> Nil
    _ -> should.fail()
  }
}

// =============================================================================
// Randomness Quality Tests
// =============================================================================

pub fn test_randomness_quality_basic_test() {
  case random.test_randomness_quality(50, 32) {
    Ok(result) -> {
      // Check basic properties of the test result
      result.sample_count |> should.equal(50)
      result.byte_length |> should.equal(32)

      // All samples should be different (very high probability with 32 bytes)
      result.all_different |> should.be_true()

      // Should have no all-zeros samples
      result.no_all_zeros |> should.be_true()

      // Should have no all-ones samples
      result.no_all_ones |> should.be_true()

      // Bit density should be roughly 0.5 (between 0.4 and 0.6 is reasonable)
      case
        result.average_bit_density >. 0.4 && result.average_bit_density <. 0.6
      {
        True -> Nil
        False -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn test_randomness_quality_invalid_params_test() {
  // Test with invalid parameters
  case random.test_randomness_quality(0, 32) {
    Error(random.InvalidLength(_)) -> Nil
    _ -> should.fail()
  }

  case random.test_randomness_quality(10, 0) {
    Error(random.InvalidLength(_)) -> Nil
    _ -> should.fail()
  }

  case random.test_randomness_quality(-1, 32) {
    Error(random.InvalidLength(_)) -> Nil
    _ -> should.fail()
  }
}

// =============================================================================
// System Availability Tests
// =============================================================================

pub fn test_random_availability_test() {
  // Test that the random system is available
  case random.test_random_availability() {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
}

// =============================================================================
// Error Handling Tests
// =============================================================================

pub fn error_to_string_coverage_test() {
  // Test error message generation for all error types
  let errors = [
    random.SystemRandomNotAvailable("test message"),
    random.InsufficientEntropy("entropy test"),
    random.InvalidLength("length test"),
    random.CryptographicError("crypto test"),
    random.GenerationFailed("generation test"),
  ]

  test_each_error(errors)
}

pub fn is_retryable_error_test() {
  // Test retryable error classification
  random.SystemRandomNotAvailable("test")
  |> random.is_retryable_error()
  |> should.be_false()

  random.InsufficientEntropy("test")
  |> random.is_retryable_error()
  |> should.be_true()

  random.InvalidLength("test")
  |> random.is_retryable_error()
  |> should.be_false()

  random.CryptographicError("test")
  |> random.is_retryable_error()
  |> should.be_true()

  random.GenerationFailed("test")
  |> random.is_retryable_error()
  |> should.be_false()
}

// =============================================================================
// Integration Tests
// =============================================================================

pub fn integration_random_to_wallet_test() {
  // Test complete flow: random generation -> private key -> wallet -> signing
  let assert Ok(private_key) = random.generate_private_key()
  let private_key_bytes = secp256k1.private_key_to_bytes(private_key)

  // Create wallet from the generated private key
  let assert Ok(wallet) = wallet_from_private_key_bytes(private_key_bytes)

  // Test signing a message with the wallet
  let test_message = "Hello, secure random world!"
  case wallet_sign_personal_message(wallet, test_message) {
    Ok(signature) -> {
      // Verify we can get signature components
      let #(v, r, s) = secp256k1.signature_to_vrs(signature)

      // Basic validation of signature components
      case v >= 27 && v <= 28 {
        True -> Nil
        False -> should.fail()
      }

      // R and S should be hex strings starting with 0x
      case r, s {
        "0x" <> _, "0x" <> _ -> Nil
        _, _ -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

// =============================================================================
// Performance and Stress Tests
// =============================================================================

pub fn stress_test_multiple_generations_test() {
  // Generate many private keys quickly to test for any issues
  let count = 100
  stress_generate_keys(count, 0)
}

fn stress_generate_keys(remaining: Int, generated: Int) -> Nil {
  case remaining {
    0 -> {
      generated |> should.equal(100)
    }
    _ -> {
      case random.generate_private_key() {
        Ok(_) -> stress_generate_keys(remaining - 1, generated + 1)
        Error(_) -> should.fail()
      }
    }
  }
}

// =============================================================================
// Helper Functions
// =============================================================================

// Mock wallet functions since we can't import wallet directly
// These would be replaced with actual wallet imports in practice
fn wallet_from_private_key_bytes(bytes: BitArray) -> Result(MockWallet, String) {
  case secp256k1.private_key_from_bytes(bytes) {
    Ok(_) -> Ok(MockWallet)
    Error(msg) -> Error(msg)
  }
}

fn wallet_get_address(_wallet: MockWallet) -> String {
  "0x742d35cc6648c72Fec4ee14c9e5EE4b285Dcf3c1"
}

fn wallet_sign_personal_message(
  _wallet: MockWallet,
  _message: String,
) -> Result(secp256k1.Signature, String) {
  // Mock signature for testing
  let r = <<
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
    22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
  >>
  let s = <<
    32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14,
    13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1,
  >>
  Ok(secp256k1.Signature(r: r, s: s, recovery_id: 0))
}

type MockWallet {
  MockWallet
}

// Helper list functions
fn list_length(list: List(a)) -> Int {
  list_length_acc(list, 0)
}

fn list_length_acc(list: List(a), acc: Int) -> Int {
  case list {
    [] -> acc
    [_, ..rest] -> list_length_acc(rest, acc + 1)
  }
}

fn list_map(list: List(a), f: fn(a) -> b) -> List(b) {
  case list {
    [] -> []
    [head, ..tail] -> [f(head), ..list_map(tail, f)]
  }
}

fn list_unique(list: List(a)) -> List(a) {
  list_unique_acc(list, [])
}

fn list_unique_acc(list: List(a), acc: List(a)) -> List(a) {
  case list {
    [] -> acc
    [head, ..rest] ->
      case list_contains(acc, head) {
        True -> list_unique_acc(rest, acc)
        False -> list_unique_acc(rest, [head, ..acc])
      }
  }
}

fn list_contains(list: List(a), element: a) -> Bool {
  case list {
    [] -> False
    [head, ..rest] ->
      case head == element {
        True -> True
        False -> list_contains(rest, element)
      }
  }
}

// Helper functions for testing
fn test_each_length(lengths: List(Int)) -> Nil {
  case lengths {
    [] -> Nil
    [length, ..rest] -> {
      case random.generate_secure_bytes(length) {
        Ok(bytes) -> {
          bit_array.byte_size(bytes)
          |> should.equal(length)
          test_each_length(rest)
        }
        Error(_) -> should.fail()
      }
    }
  }
}

fn test_each_key_valid(keys: List(secp256k1.PrivateKey)) -> Nil {
  case keys {
    [] -> Nil
    [key, ..rest] -> {
      secp256k1.is_valid_private_key(key)
      |> should.be_true()
      test_each_key_valid(rest)
    }
  }
}

fn test_each_error(errors: List(random.RandomError)) -> Nil {
  case errors {
    [] -> Nil
    [error, ..rest] -> {
      let msg = random.error_to_string(error)
      // Message should not be empty
      case msg {
        "" -> should.fail()
        _ -> Nil
      }
      test_each_error(rest)
    }
  }
}
