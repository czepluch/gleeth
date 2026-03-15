import gleam/bit_array

import gleam/string

/// Compute the Keccak-256 hash of binary data.
///
/// This function provides the core Keccak-256 hashing functionality used throughout
/// the Ethereum ecosystem. Keccak-256 is a cryptographic hash function that produces
/// a 256-bit (32-byte) digest from arbitrary input data.
///
/// ## Implementation Details
///
/// This function uses Foreign Function Interface (FFI) to call native implementations:
/// - **Erlang/Elixir**: Uses the `ExKeccak` library's `hash_256` function
/// - **JavaScript**: Uses a custom FFI module (`keccak_gleam_ffi.mjs`)
///
/// The ExKeccak library is a well-tested Elixir implementation of the Keccak-256
/// algorithm that provides cryptographically secure hashing compatible with Ethereum.
///
/// ## Usage in Ethereum Context
///
/// Keccak-256 is fundamental to Ethereum and is used for:
/// - Generating function selectors (first 4 bytes of hash)
/// - Creating event topic hashes
/// - Address generation from public keys
/// - Merkle tree construction
/// - General data integrity verification
///
/// ## Parameters
///
/// * `message` - The binary data to hash as a `BitArray`
///
/// ## Returns
///
/// A `BitArray` containing the 32-byte Keccak-256 hash digest
///
/// ## Example
///
/// ```gleam
/// import gleam/bit_array
///
/// let data = bit_array.from_string("hello world")
/// let hash = hash_binary(data)
/// // hash is now a 32-byte BitArray containing the Keccak-256 digest
/// ```
///
/// ## Security Notes
///
/// - This function implements the original Keccak-256 algorithm as used by Ethereum
/// - Note that this is different from SHA-3, which uses a slightly different padding
/// - The output is cryptographically secure for use in blockchain applications
@external(erlang, "Elixir.ExKeccak", "hash_256")
@external(javascript, "./keccak_gleam_ffi.mjs", "hash")
fn hash_binary(message: BitArray) -> BitArray

/// Generate Ethereum function selector (first 4 bytes of keccak256 hash)
pub fn function_selector(signature: String) -> Result(String, String) {
  let input_bytes = bit_array.from_string(signature)
  let hash_bytes = hash_binary(input_bytes)
  let first_4_bytes = bit_array.slice(hash_bytes, 0, 4)
  case first_4_bytes {
    Ok(bytes) -> Ok("0x" <> string.lowercase(bit_array.base16_encode(bytes)))
    Error(_) -> Error("Failed to compute function selector for: " <> signature)
  }
}

/// Generate full keccak256 hash as hex string
pub fn keccak256_hex(input: String) -> String {
  let input_bytes = bit_array.from_string(input)
  let hash_bytes = hash_binary(input_bytes)
  "0x" <> string.lowercase(bit_array.base16_encode(hash_bytes))
}

/// Generate event topic hash using keccak256
pub fn event_topic(signature: String) -> String {
  keccak256_hex(signature)
}

/// Utility functions for hex output without prefix
pub fn keccak256_hex_no_prefix(input: String) -> String {
  let hash = keccak256_hex(input)
  case string.starts_with(hash, "0x") {
    True -> string.drop_start(hash, 2)
    False -> hash
  }
}

/// Verify function selector matches expected value
pub fn verify_function_selector(signature: String, expected: String) -> Bool {
  case function_selector(signature) {
    Ok(computed) -> {
      let normalized_expected = case string.starts_with(expected, "0x") {
        True -> expected
        False -> "0x" <> expected
      }
      string.lowercase(computed) == string.lowercase(normalized_expected)
    }
    Error(_) -> False
  }
}

/// Hash binary data using keccak256
pub fn keccak256_binary(data: BitArray) -> BitArray {
  hash_binary(data)
}

/// Hash string data to binary using keccak256
pub fn keccak256_string(data: String) -> BitArray {
  let input_bytes = bit_array.from_string(data)
  hash_binary(input_bytes)
}

/// Hash binary data to hex string
pub fn hash_binary_to_hex(data: BitArray) -> String {
  let hash_result = keccak256_binary(data)
  "0x" <> string.lowercase(bit_array.base16_encode(hash_result))
}
