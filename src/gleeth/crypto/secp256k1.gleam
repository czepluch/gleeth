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
  _message_hash: BitArray,
  _signature: Signature,
) -> Result(PublicKey, String) {
  // Note: This would require additional secp256k1 functionality
  // For now, return an error indicating it's not implemented
  Error("Public key recovery not yet implemented")
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
// Internal Functions
// =============================================================================

// Keccak256 functionality is imported from gleeth/crypto/keccak module
