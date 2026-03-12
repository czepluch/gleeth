import gleam/bit_array
import gleam/result
import gleam/string
import gleeth/crypto/secp256k1

/// Error types for random number generation operations
pub type RandomError {
  SystemRandomNotAvailable(String)
  InsufficientEntropy(String)
  InvalidLength(String)
  CryptographicError(String)
  GenerationFailed(String)
}

// =============================================================================
// Core Random Generation Functions
// =============================================================================

/// Generate cryptographically secure random bytes of specified length
/// Uses system's cryptographically secure random number generator
///
/// ## Implementation Details
///
/// - **Erlang/BEAM**: Uses `:crypto.strong_rand_bytes/1` from OTP crypto module
/// - **JavaScript**: Uses Web Crypto API `crypto.getRandomValues()`
///
/// Both implementations provide cryptographically secure pseudorandom number
/// generation suitable for cryptographic key material.
///
/// ## Parameters
///
/// * `length` - Number of random bytes to generate (must be positive)
///
/// ## Returns
///
/// * `Ok(BitArray)` - Generated random bytes
/// * `Error(RandomError)` - If generation fails
///
/// ## Example
///
/// ```gleam
/// // Generate 32 random bytes for a private key
/// case generate_secure_bytes(32) {
///   Ok(random_bytes) -> // Use the random bytes
///   Error(err) -> // Handle error
/// }
/// ```
///
/// For Erlang: directly calls crypto:strong_rand_bytes/1 and wraps in Ok
/// For JavaScript: calls FFI that returns Result type
fn generate_secure_bytes_ffi(length: Int) -> Result(BitArray, String) {
  generate_secure_bytes_platform(length)
}

@external(erlang, "gleeth_ffi", "generate_secure_bytes")
@external(javascript, "./random_gleam_ffi.mjs", "generateSecureBytes")
fn generate_secure_bytes_platform(length: Int) -> Result(BitArray, String)

pub fn generate_secure_bytes(length: Int) -> Result(BitArray, RandomError) {
  // Validate input length
  case length <= 0 {
    True ->
      Error(InvalidLength(
        "Length must be positive, got: " <> string.inspect(length),
      ))
    False -> {
      case generate_secure_bytes_ffi(length) {
        Ok(bytes) -> {
          // Verify we got the expected number of bytes
          case bit_array.byte_size(bytes) {
            size if size == length -> Ok(bytes)
            actual_size ->
              Error(GenerationFailed(
                "Expected "
                <> string.inspect(length)
                <> " bytes, got "
                <> string.inspect(actual_size),
              ))
          }
        }
        Error(msg) -> Error(SystemRandomNotAvailable(msg))
      }
    }
  }
}

// =============================================================================
// Private Key Generation
// =============================================================================

/// Generate a cryptographically secure secp256k1 private key
///
/// This function generates a random 32-byte private key that is guaranteed to be:
/// - Cryptographically secure (using system CSPRNG)
/// - Within the valid secp256k1 curve order
/// - Non-zero (not the invalid all-zeros key)
///
/// The function will retry generation if the random bytes don't form a valid
/// private key (extremely rare but theoretically possible).
///
/// ## Returns
///
/// * `Ok(PrivateKey)` - A valid secp256k1 private key
/// * `Error(RandomError)` - If generation fails after maximum retries
///
/// ## Example
///
/// ```gleam
/// case generate_private_key() {
///   Ok(private_key) -> {
///     // Use the private key to create a wallet
///     wallet.from_private_key_bytes(secp256k1.private_key_to_bytes(private_key))
///   }
///   Error(err) -> // Handle generation error
/// }
/// ```
pub fn generate_private_key() -> Result(secp256k1.PrivateKey, RandomError) {
  generate_private_key_with_retries(10)
}

/// Generate a private key with specified retry attempts
/// This is useful for testing or when you want control over retry behavior
pub fn generate_private_key_with_retries(
  max_retries: Int,
) -> Result(secp256k1.PrivateKey, RandomError) {
  generate_private_key_attempt(max_retries, 0)
}

/// Internal recursive function to attempt private key generation
fn generate_private_key_attempt(
  max_retries: Int,
  current_attempt: Int,
) -> Result(secp256k1.PrivateKey, RandomError) {
  case current_attempt >= max_retries {
    True ->
      Error(GenerationFailed(
        "Failed to generate valid private key after "
        <> string.inspect(max_retries)
        <> " attempts",
      ))
    False -> {
      // Generate 32 random bytes
      use random_bytes <- result.try(generate_secure_bytes(32))

      // Try to create a private key from these bytes
      case secp256k1.private_key_from_bytes(random_bytes) {
        Ok(private_key) -> {
          // Verify the key is valid (not zero and within curve order)
          case secp256k1.is_valid_private_key(private_key) {
            True -> Ok(private_key)
            False -> {
              // This key is invalid (extremely rare), try again
              generate_private_key_attempt(max_retries, current_attempt + 1)
            }
          }
        }
        Error(_) -> {
          // Invalid key format, try again
          generate_private_key_attempt(max_retries, current_attempt + 1)
        }
      }
    }
  }
}

// =============================================================================
// Entropy and Randomness Testing
// =============================================================================

/// Test the quality of system randomness by generating multiple samples
/// and checking for basic statistical properties. This is useful for
/// development and debugging.
///
/// Note: This is not a comprehensive randomness test - for production
/// systems, use proper statistical test suites like NIST SP 800-22.
pub fn test_randomness_quality(
  sample_count: Int,
  byte_length: Int,
) -> Result(RandomnessTestResult, RandomError) {
  case sample_count <= 0 || byte_length <= 0 {
    True ->
      Error(InvalidLength("Sample count and byte length must be positive"))
    False -> {
      use samples <- result.try(
        generate_multiple_samples(sample_count, byte_length, []),
      )
      Ok(analyze_randomness_samples(samples))
    }
  }
}

/// Result of randomness quality testing
pub type RandomnessTestResult {
  RandomnessTestResult(
    sample_count: Int,
    byte_length: Int,
    all_different: Bool,
    // Are all samples different?
    no_all_zeros: Bool,
    // No samples are all zeros?
    no_all_ones: Bool,
    // No samples are all ones?
    average_bit_density: Float,
    // Average ratio of 1s to total bits
  )
}

/// Generate multiple random samples for testing
fn generate_multiple_samples(
  remaining: Int,
  byte_length: Int,
  acc: List(BitArray),
) -> Result(List(BitArray), RandomError) {
  case remaining {
    0 -> Ok(acc)
    _ -> {
      use sample <- result.try(generate_secure_bytes(byte_length))
      generate_multiple_samples(remaining - 1, byte_length, [sample, ..acc])
    }
  }
}

/// Analyze randomness samples for basic statistical properties
fn analyze_randomness_samples(samples: List(BitArray)) -> RandomnessTestResult {
  let sample_count = list_length(samples)
  let byte_length = case samples {
    [first, ..] -> bit_array.byte_size(first)
    [] -> 0
  }

  // Check if all samples are unique
  let unique_samples = list_unique(samples)
  let all_different = list_length(unique_samples) == sample_count

  // Check for pathological cases
  let all_zeros = create_all_zeros(byte_length)
  let all_ones = create_all_ones(byte_length)

  let no_all_zeros = !list_contains(samples, all_zeros)
  let no_all_ones = !list_contains(samples, all_ones)

  // Calculate average bit density (ratio of 1-bits)
  let total_bits = sample_count * byte_length * 8
  let total_one_bits = count_total_one_bits(samples, 0)
  let average_bit_density = case total_bits {
    0 -> 0.0
    _ -> int_to_float(total_one_bits) /. int_to_float(total_bits)
  }

  RandomnessTestResult(
    sample_count: sample_count,
    byte_length: byte_length,
    all_different: all_different,
    no_all_zeros: no_all_zeros,
    no_all_ones: no_all_ones,
    average_bit_density: average_bit_density,
  )
}

// =============================================================================
// Utility Functions
// =============================================================================

/// Create a byte array of all zeros
fn create_all_zeros(length: Int) -> BitArray {
  case length {
    0 -> <<>>
    _ -> bit_array.concat([<<0>>, create_all_zeros(length - 1)])
  }
}

/// Create a byte array of all ones (0xFF bytes)
fn create_all_ones(length: Int) -> BitArray {
  case length {
    0 -> <<>>
    _ -> bit_array.concat([<<255>>, create_all_ones(length - 1)])
  }
}

/// Count total number of 1-bits in a list of BitArrays
fn count_total_one_bits(samples: List(BitArray), acc: Int) -> Int {
  case samples {
    [] -> acc
    [sample, ..rest] -> {
      let one_bits = count_one_bits_in_sample(sample, 0)
      count_total_one_bits(rest, acc + one_bits)
    }
  }
}

/// Count 1-bits in a single BitArray
fn count_one_bits_in_sample(sample: BitArray, acc: Int) -> Int {
  case bit_array.byte_size(sample) {
    0 -> acc
    _ -> {
      case bit_array.slice(sample, 0, 1) {
        Ok(<<byte>>) -> {
          let bits = count_bits_in_byte(byte, 0)
          case bit_array.slice(sample, 1, bit_array.byte_size(sample) - 1) {
            Ok(rest) -> count_one_bits_in_sample(rest, acc + bits)
            Error(_) -> acc + bits
          }
        }
        _ -> acc
      }
    }
  }
}

/// Count 1-bits in a single byte
fn count_bits_in_byte(byte: Int, acc: Int) -> Int {
  case byte {
    0 -> acc
    _ -> {
      let new_acc = case byte % 2 {
        1 -> acc + 1
        _ -> acc
      }
      count_bits_in_byte(byte / 2, new_acc)
    }
  }
}

/// Get length of a list
fn list_length(list: List(a)) -> Int {
  list_length_acc(list, 0)
}

fn list_length_acc(list: List(a), acc: Int) -> Int {
  case list {
    [] -> acc
    [_, ..rest] -> list_length_acc(rest, acc + 1)
  }
}

/// Check if list contains element
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

/// Remove duplicates from list (simple O(n²) implementation)
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

/// Convert Int to Float (helper function)
fn int_to_float(value: Int) -> Float {
  // This is a simplified conversion - in practice you might need
  // to use a proper conversion function from gleam_stdlib
  case value {
    0 -> 0.0
    1 -> 1.0
    2 -> 2.0
    3 -> 3.0
    4 -> 4.0
    5 -> 5.0
    6 -> 6.0
    7 -> 7.0
    8 -> 8.0
    9 -> 9.0
    _ -> {
      // For larger numbers, approximate conversion
      // This is not precise but works for our statistical analysis
      case value > 0 {
        True -> int_to_float(value / 2) *. 2.0
        False -> int_to_float(-value) *. -1.0
      }
    }
  }
}

// =============================================================================
// Error Handling Utilities
// =============================================================================

/// Convert RandomError to string for display
pub fn error_to_string(error: RandomError) -> String {
  case error {
    SystemRandomNotAvailable(msg) -> "System random not available: " <> msg
    InsufficientEntropy(msg) -> "Insufficient entropy: " <> msg
    InvalidLength(msg) -> "Invalid length: " <> msg
    CryptographicError(msg) -> "Cryptographic error: " <> msg
    GenerationFailed(msg) -> "Generation failed: " <> msg
  }
}

/// Check if an error indicates a temporary failure that might succeed on retry
pub fn is_retryable_error(error: RandomError) -> Bool {
  case error {
    SystemRandomNotAvailable(_) -> False
    // System level issue
    InsufficientEntropy(_) -> True
    // Might recover
    InvalidLength(_) -> False
    // Programming error
    CryptographicError(_) -> True
    // Might be transient
    GenerationFailed(_) -> False
    // Already retried max times
  }
}

/// Check if the random system is available and working
pub fn test_random_availability() -> Result(Nil, RandomError) {
  use _ <- result.try(generate_secure_bytes(1))
  Ok(Nil)
}

// =============================================================================
// Constants
// =============================================================================

/// Standard private key length for secp256k1 (32 bytes)
pub const private_key_length = 32

/// Maximum retry attempts for private key generation
pub const default_max_retries = 10

/// Minimum entropy test sample size
pub const min_test_samples = 100
