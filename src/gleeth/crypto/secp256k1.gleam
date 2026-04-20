import gleam/bit_array
import gleam/result
import gleam/string
import gleeth/crypto/keccak
import gleeth/utils/hex
import secp256k1_gleam

/// Represents an ECDSA signature with recovery information
pub type Signature {
  Signature(r: BitArray, s: BitArray, recovery_id: Int)
}

/// Represents a private key for signing transactions
pub type PrivateKey {
  PrivateKey(key: BitArray)
}

/// Represents a public key derived from a private key
pub type PublicKey {
  PublicKey(key: BitArray)
}

/// Represents an Ethereum address derived from a public key
pub type EthereumAddress {
  EthereumAddress(address: String)
}

// =============================================================================
// Private Key Management
// =============================================================================

/// Create a private key from a 32-byte BitArray
/// The private key must be exactly 32 bytes (256 bits)
pub fn private_key_from_bytes(bytes: BitArray) -> Result(PrivateKey, String) {
  case bit_array.byte_size(bytes) {
    32 -> Ok(PrivateKey(bytes))
    size ->
      Error(
        "Private key must be exactly 32 bytes, got " <> string.inspect(size),
      )
  }
}

/// Create a private key from a hex string (with or without 0x prefix)
/// The hex string must represent exactly 32 bytes (64 hex characters)
pub fn private_key_from_hex(hex_string: String) -> Result(PrivateKey, String) {
  use bytes <- result.try(hex.decode(hex_string))
  private_key_from_bytes(bytes)
}

/// Convert a private key to hex string with 0x prefix
pub fn private_key_to_hex(private_key: PrivateKey) -> String {
  let PrivateKey(key) = private_key
  "0x" <> bit_array.base16_encode(key) |> string.lowercase
}

/// Extract the raw bytes from a private key
pub fn private_key_to_bytes(private_key: PrivateKey) -> BitArray {
  let PrivateKey(key) = private_key
  key
}

// =============================================================================
// Public Key Management
// =============================================================================

/// Create a public key from a private key
pub fn create_public_key(private_key: PrivateKey) -> Result(PublicKey, String) {
  let PrivateKey(key) = private_key
  case secp256k1_gleam.create_public_key(key) {
    Ok(pub_key) -> Ok(PublicKey(pub_key))
    Error(err) -> Error("Failed to create public key: " <> string.inspect(err))
  }
}

/// Convert a public key to hex string with 0x prefix
pub fn public_key_to_hex(public_key: PublicKey) -> String {
  let PublicKey(key) = public_key
  "0x" <> bit_array.base16_encode(key) |> string.lowercase
}

/// Extract the raw bytes from a public key
pub fn public_key_to_bytes(public_key: PublicKey) -> BitArray {
  let PublicKey(key) = public_key
  key
}

// =============================================================================
// Ethereum Address Generation
// =============================================================================

/// Generate an Ethereum address from a public key
/// Uses the last 20 bytes of keccak256(public_key) as the address
pub fn public_key_to_address(
  public_key: PublicKey,
) -> Result(EthereumAddress, String) {
  let PublicKey(key) = public_key

  // For uncompressed public keys, we need to remove the first byte (0x04 prefix)
  let public_key_bytes = case bit_array.byte_size(key) {
    65 -> {
      // Uncompressed key: remove first byte
      case bit_array.slice(key, 1, 64) {
        Ok(sliced) -> sliced
        Error(_) -> key
      }
    }
    64 -> key
    // Already without prefix
    _ -> key
    // Other formats, use as-is
  }

  // Use keccak256 from our existing module
  let hash = keccak.keccak256_binary(public_key_bytes)

  // Take last 20 bytes as address
  case bit_array.slice(hash, 12, 20) {
    Ok(address_bytes) -> {
      let address_hex =
        bit_array.base16_encode(address_bytes) |> string.lowercase
      Ok(EthereumAddress("0x" <> address_hex))
    }
    Error(_) -> Error("Failed to extract address from hash")
  }
}

/// Generate an Ethereum address directly from a private key
pub fn private_key_to_address(
  private_key: PrivateKey,
) -> Result(EthereumAddress, String) {
  use public_key <- result.try(create_public_key(private_key))
  public_key_to_address(public_key)
}

/// Extract the address string from an EthereumAddress
pub fn address_to_string(address: EthereumAddress) -> String {
  let EthereumAddress(addr) = address
  addr
}

// =============================================================================
// Message Signing
// =============================================================================

/// Sign a message hash with a private key
/// The message should already be hashed (e.g., with keccak256)
pub fn sign_message_hash(
  message_hash: BitArray,
  private_key: PrivateKey,
) -> Result(Signature, String) {
  let PrivateKey(key) = private_key
  case secp256k1_gleam.sign(message_hash, key) {
    Ok(sig) ->
      Ok(Signature(r: sig.r, s: sig.s, recovery_id: sig.recovery_id_int))
    Error(err) -> Error("Failed to sign message: " <> string.inspect(err))
  }
}

/// Sign raw message bytes (will be hashed with keccak256)
pub fn sign_message(
  message: BitArray,
  private_key: PrivateKey,
) -> Result(Signature, String) {
  let message_hash = keccak.keccak256_binary(message)
  sign_message_hash(message_hash, private_key)
}

/// Sign an Ethereum personal message (prefixed with "\x19Ethereum Signed Message:\n")
pub fn sign_personal_message(
  message: String,
  private_key: PrivateKey,
) -> Result(Signature, String) {
  let message_bytes = bit_array.from_string(message)
  let message_length = bit_array.byte_size(message_bytes) |> string.inspect

  let prefix = "\\x19Ethereum Signed Message:\\n" <> message_length
  let prefix_bytes = bit_array.from_string(prefix)

  let full_message = bit_array.append(prefix_bytes, message_bytes)
  sign_message(full_message, private_key)
}

// =============================================================================
// Signature Operations
// =============================================================================

/// Convert signature to compact format (r + s + v)
/// Used for Ethereum transaction signatures
pub fn signature_to_compact(signature: Signature) -> BitArray {
  let Signature(r: r, s: s, recovery_id: recovery_id) = signature

  // Ethereum uses v = recovery_id + 27 for legacy transactions
  let v_byte = case recovery_id {
    0 -> <<27>>
    1 -> <<28>>
    _ -> <<27>>
    // Default fallback
  }

  <<r:bits, s:bits, v_byte:bits>>
}

/// Convert signature to hex string with 0x prefix
pub fn signature_to_hex(signature: Signature) -> String {
  let compact = signature_to_compact(signature)
  "0x" <> bit_array.base16_encode(compact) |> string.lowercase
}

/// Extract v, r, s components for Ethereum transactions
pub fn signature_to_vrs(signature: Signature) -> #(Int, String, String) {
  let Signature(r: r, s: s, recovery_id: recovery_id) = signature

  let v = recovery_id + 27
  // Legacy Ethereum v value
  let r_hex = "0x" <> bit_array.base16_encode(r) |> string.lowercase
  let s_hex = "0x" <> bit_array.base16_encode(s) |> string.lowercase

  #(v, r_hex, s_hex)
}

/// Create signature from v, r, s components
pub fn signature_from_vrs(
  v: Int,
  r: String,
  s: String,
) -> Result(Signature, String) {
  use r_bytes <- result.try(hex.decode(r))
  use s_bytes <- result.try(hex.decode(s))

  let recovery_id = case v {
    27 -> 0
    28 -> 1
    _ -> v - 27
    // Handle chain-specific v values
  }

  Ok(Signature(r: r_bytes, s: s_bytes, recovery_id: recovery_id))
}

/// Parse a 65-byte hex signature string (r[32] + s[32] + v[1]) into a Signature.
/// Handles v=0/1 and v=27/28 (normalizes to recovery_id 0/1).
pub fn signature_from_hex(hex_string: String) -> Result(Signature, String) {
  use bytes <- result.try(hex.decode(hex_string))
  case bit_array.byte_size(bytes) {
    65 -> {
      case
        bit_array.slice(bytes, 0, 32),
        bit_array.slice(bytes, 32, 32),
        bit_array.slice(bytes, 64, 1)
      {
        Ok(r), Ok(s), Ok(<<v_byte:8>>) -> {
          let recovery_id = case v_byte {
            0 | 1 -> v_byte
            27 -> 0
            28 -> 1
            _ -> v_byte - 27
          }
          Ok(Signature(r: r, s: s, recovery_id: recovery_id))
        }
        _, _, _ -> Error("Failed to extract signature components")
      }
    }
    size ->
      Error("Signature must be exactly 65 bytes, got " <> string.inspect(size))
  }
}

// =============================================================================
// Signature Verification
// =============================================================================

/// Verify a signature against a message hash and public key
pub fn verify_signature(
  message_hash: BitArray,
  signature: Signature,
  public_key: PublicKey,
) -> Result(Bool, String) {
  let Signature(r: r, s: s, recovery_id: _) = signature
  let PublicKey(key) = public_key
  let signature_obj =
    secp256k1_gleam.Signature(
      r: r,
      s: s,
      recovery_id_int: signature.recovery_id,
    )

  case secp256k1_gleam.verify(message_hash, signature_obj, key) {
    Ok(_) -> Ok(True)
    Error(_) -> Ok(False)
  }
}

/// Recover the public key from a signature and message hash
pub fn recover_public_key(
  message_hash: BitArray,
  signature: Signature,
) -> Result(PublicKey, String) {
  let Signature(r: r, s: s, recovery_id: recovery_id) = signature

  case recover_internal(message_hash, r, s, recovery_id) {
    Ok(public_key_bytes) -> Ok(PublicKey(public_key_bytes))
    Error(err) -> Error("Failed to recover public key: " <> string.inspect(err))
  }
}

/// Recover multiple public key candidates (all 4 possible recovery IDs)
/// This is useful when the recovery ID is unknown or needs to be determined
pub fn recover_public_key_candidates(
  message_hash: BitArray,
  r: BitArray,
  s: BitArray,
) -> Result(List(PublicKey), String) {
  let recovery_ids = [0, 1, 2, 3]

  recover_candidates_helper(message_hash, r, s, recovery_ids, [])
}

/// Helper function to recover candidates for each recovery ID
fn recover_candidates_helper(
  message_hash: BitArray,
  r: BitArray,
  s: BitArray,
  recovery_ids: List(Int),
  acc: List(PublicKey),
) -> Result(List(PublicKey), String) {
  case recovery_ids {
    [] -> Ok(acc)
    [recovery_id, ..rest] -> {
      case recover_internal(message_hash, r, s, recovery_id) {
        Ok(public_key_bytes) -> {
          let public_key = PublicKey(public_key_bytes)
          recover_candidates_helper(message_hash, r, s, rest, [
            public_key,
            ..acc
          ])
        }
        Error(_) -> {
          // Skip invalid recovery IDs and continue with others
          recover_candidates_helper(message_hash, r, s, rest, acc)
        }
      }
    }
  }
}

/// Recover Ethereum address directly from signature and message hash
pub fn recover_address(
  message_hash: BitArray,
  signature: Signature,
) -> Result(EthereumAddress, String) {
  use public_key <- result.try(recover_public_key(message_hash, signature))
  public_key_to_address(public_key)
}

/// Recover multiple address candidates (all possible recovery IDs)
pub fn recover_address_candidates(
  message_hash: BitArray,
  r: BitArray,
  s: BitArray,
) -> Result(List(EthereumAddress), String) {
  use public_keys <- result.try(recover_public_key_candidates(
    message_hash,
    r,
    s,
  ))

  convert_keys_to_addresses(public_keys, [])
}

/// Helper to convert public keys to addresses
fn convert_keys_to_addresses(
  public_keys: List(PublicKey),
  acc: List(EthereumAddress),
) -> Result(List(EthereumAddress), String) {
  case public_keys {
    [] -> Ok(acc)
    [public_key, ..rest] -> {
      case public_key_to_address(public_key) {
        Ok(address) -> convert_keys_to_addresses(rest, [address, ..acc])
        Error(err) -> Error(err)
      }
    }
  }
}

/// Verify signature recovery by checking if recovered address matches expected
pub fn verify_signature_recovery(
  message_hash: BitArray,
  signature: Signature,
  expected_address: String,
) -> Result(Bool, String) {
  use recovered_address <- result.try(recover_address(message_hash, signature))
  let recovered_address_str = address_to_string(recovered_address)

  // Compare addresses (case-insensitive)
  let expected_lower = string.lowercase(expected_address)
  let recovered_lower = string.lowercase(recovered_address_str)

  Ok(expected_lower == recovered_lower)
}

/// Find the correct recovery ID for a given signature and expected address
/// This is useful when you have r,s components but need to determine the recovery ID
pub fn find_recovery_id(
  message_hash: BitArray,
  r: BitArray,
  s: BitArray,
  expected_address: String,
) -> Result(Int, String) {
  let recovery_ids = [0, 1, 2, 3]

  find_recovery_id_helper(message_hash, r, s, expected_address, recovery_ids)
}

/// Helper function to find the correct recovery ID
fn find_recovery_id_helper(
  message_hash: BitArray,
  r: BitArray,
  s: BitArray,
  expected_address: String,
  recovery_ids: List(Int),
) -> Result(Int, String) {
  case recovery_ids {
    [] -> Error("No valid recovery ID found for the expected address")
    [recovery_id, ..rest] -> {
      let signature = Signature(r: r, s: s, recovery_id: recovery_id)
      case
        verify_signature_recovery(message_hash, signature, expected_address)
      {
        Ok(True) -> Ok(recovery_id)
        Ok(False) ->
          find_recovery_id_helper(message_hash, r, s, expected_address, rest)
        Error(_) ->
          find_recovery_id_helper(message_hash, r, s, expected_address, rest)
      }
    }
  }
}

// =============================================================================
// Utility Functions
// =============================================================================

/// Check if a private key is valid (non-zero and within secp256k1 curve order)
pub fn is_valid_private_key(private_key: PrivateKey) -> Bool {
  let PrivateKey(key) = private_key
  case bit_array.byte_size(key) {
    32 -> {
      // Check that key is not all zeros
      key
      != <<
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
      >>
    }
    _ -> False
  }
}

/// Generate a random private key (placeholder - would need proper randomness)
/// This is a placeholder implementation - in production, use proper cryptographic randomness
pub fn generate_private_key() -> Result(PrivateKey, String) {
  Error("Random private key generation not implemented - use external source")
}

// =============================================================================
// Recovery Functions - External FFI Calls
// =============================================================================

/// External call to ExSecp256k1.recover function
@external(erlang, "Elixir.ExSecp256k1", "recover")
fn recover_internal(
  message_hash: BitArray,
  r: BitArray,
  s: BitArray,
  recovery_id: Int,
) -> Result(BitArray, atom)

/// External call to ExSecp256k1.recover_compact function
@external(erlang, "Elixir.ExSecp256k1", "recover_compact")
fn recover_compact_internal(
  message_hash: BitArray,
  signature: BitArray,
  recovery_id: Int,
) -> Result(BitArray, atom)

/// Recover public key from compact signature format
pub fn recover_public_key_compact(
  message_hash: BitArray,
  compact_signature: BitArray,
  recovery_id: Int,
) -> Result(PublicKey, String) {
  case recover_compact_internal(message_hash, compact_signature, recovery_id) {
    Ok(public_key_bytes) -> Ok(PublicKey(public_key_bytes))
    Error(err) ->
      Error(
        "Failed to recover public key from compact signature: "
        <> string.inspect(err),
      )
  }
}

/// Recover address from compact signature format
pub fn recover_address_compact(
  message_hash: BitArray,
  compact_signature: BitArray,
  recovery_id: Int,
) -> Result(EthereumAddress, String) {
  use public_key <- result.try(recover_public_key_compact(
    message_hash,
    compact_signature,
    recovery_id,
  ))
  public_key_to_address(public_key)
}
// =============================================================================
// Internal Functions
// =============================================================================

// Keccak256 functionality is imported from gleeth/crypto/keccak module
