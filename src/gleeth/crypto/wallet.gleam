import gleam/bit_array
import gleam/result
import gleam/string
import gleeth/crypto/keccak
import gleeth/crypto/random
import gleeth/crypto/secp256k1

/// Represents an Ethereum wallet with private key and derived address
pub type Wallet {
  Wallet(
    private_key: secp256k1.PrivateKey,
    public_key: secp256k1.PublicKey,
    address: secp256k1.EthereumAddress,
  )
}

/// Error types for wallet operations
pub type WalletError {
  InvalidPrivateKey(String)
  InvalidHex(String)
  KeyGenerationFailed(String)
  SigningFailed(String)
}

// =============================================================================
// Wallet Creation
// =============================================================================

/// Create a wallet from a private key hex string
/// Supports both with and without 0x prefix
pub fn from_private_key_hex(hex_string: String) -> Result(Wallet, WalletError) {
  use private_key <- result.try(
    secp256k1.private_key_from_hex(hex_string)
    |> result.map_error(InvalidPrivateKey),
  )

  use public_key <- result.try(
    secp256k1.create_public_key(private_key)
    |> result.map_error(KeyGenerationFailed),
  )

  use address <- result.try(
    secp256k1.public_key_to_address(public_key)
    |> result.map_error(KeyGenerationFailed),
  )

  Ok(Wallet(private_key: private_key, public_key: public_key, address: address))
}

/// Create a wallet from raw private key bytes
pub fn from_private_key_bytes(bytes: BitArray) -> Result(Wallet, WalletError) {
  use private_key <- result.try(
    secp256k1.private_key_from_bytes(bytes)
    |> result.map_error(InvalidPrivateKey),
  )

  use public_key <- result.try(
    secp256k1.create_public_key(private_key)
    |> result.map_error(KeyGenerationFailed),
  )

  use address <- result.try(
    secp256k1.public_key_to_address(public_key)
    |> result.map_error(KeyGenerationFailed),
  )

  Ok(Wallet(private_key: private_key, public_key: public_key, address: address))
}

/// Generate a new random wallet using cryptographically secure randomness
pub fn generate() -> Result(Wallet, WalletError) {
  use private_key <- result.try(
    random.generate_private_key()
    |> result.map_error(fn(err) {
      KeyGenerationFailed(
        "Failed to generate secure private key: " <> random.error_to_string(err),
      )
    }),
  )

  use public_key <- result.try(
    secp256k1.create_public_key(private_key)
    |> result.map_error(KeyGenerationFailed),
  )

  use address <- result.try(
    secp256k1.public_key_to_address(public_key)
    |> result.map_error(KeyGenerationFailed),
  )

  Ok(Wallet(private_key: private_key, public_key: public_key, address: address))
}

// =============================================================================
// Wallet Information
// =============================================================================

/// Get the wallet's Ethereum address as a string
pub fn get_address(wallet: Wallet) -> String {
  secp256k1.address_to_string(wallet.address)
}

/// Get the wallet's private key as a hex string
pub fn get_private_key_hex(wallet: Wallet) -> String {
  secp256k1.private_key_to_hex(wallet.private_key)
}

/// Get the wallet's public key as a hex string
pub fn get_public_key_hex(wallet: Wallet) -> String {
  secp256k1.public_key_to_hex(wallet.public_key)
}

/// Get the wallet's private key as raw bytes
pub fn get_private_key_bytes(wallet: Wallet) -> BitArray {
  secp256k1.private_key_to_bytes(wallet.private_key)
}

/// Get the wallet's public key as raw bytes
pub fn get_public_key_bytes(wallet: Wallet) -> BitArray {
  secp256k1.public_key_to_bytes(wallet.public_key)
}

/// Check if the wallet has a valid private key
pub fn is_valid(wallet: Wallet) -> Bool {
  secp256k1.is_valid_private_key(wallet.private_key)
}

// =============================================================================
// Message Signing
// =============================================================================

/// Sign a message hash with the wallet's private key
pub fn sign_hash(
  wallet: Wallet,
  message_hash: BitArray,
) -> Result(secp256k1.Signature, WalletError) {
  secp256k1.sign_message_hash(message_hash, wallet.private_key)
  |> result.map_error(SigningFailed)
}

/// Sign raw message bytes (will be hashed with keccak256)
pub fn sign_message(
  wallet: Wallet,
  message: BitArray,
) -> Result(secp256k1.Signature, WalletError) {
  secp256k1.sign_message(message, wallet.private_key)
  |> result.map_error(SigningFailed)
}

/// Sign an Ethereum personal message
pub fn sign_personal_message(
  wallet: Wallet,
  message: String,
) -> Result(secp256k1.Signature, WalletError) {
  secp256k1.sign_personal_message(message, wallet.private_key)
  |> result.map_error(SigningFailed)
}

// =============================================================================
// Personal Message Recovery (EIP-191)
// =============================================================================

/// Recover the signer address from an EIP-191 personal message signature.
/// Applies the standard prefix before recovery, matching what MetaMask
/// and other wallets produce with personal_sign.
pub fn recover_personal_message(
  message: String,
  signature_hex: String,
) -> Result(String, WalletError) {
  use signature <- result.try(
    secp256k1.signature_from_hex(signature_hex)
    |> result.map_error(InvalidHex),
  )
  let message_hash = personal_message_hash(message)
  use address <- result.try(
    secp256k1.recover_address(message_hash, signature)
    |> result.map_error(SigningFailed),
  )
  Ok(secp256k1.address_to_string(address))
}

/// Verify that a specific address signed a personal message.
pub fn verify_personal_message(
  message: String,
  signature_hex: String,
  expected_address: String,
) -> Result(Bool, WalletError) {
  use recovered <- result.try(recover_personal_message(message, signature_hex))
  Ok(string.lowercase(recovered) == string.lowercase(expected_address))
}

/// Compute the EIP-191 personal message hash.
/// hash = keccak256("\x19Ethereum Signed Message:\n" + len(message) + message)
fn personal_message_hash(message: String) -> BitArray {
  let message_bytes = bit_array.from_string(message)
  let message_length = bit_array.byte_size(message_bytes) |> string.inspect
  let prefix = "\\x19Ethereum Signed Message:\\n" <> message_length
  let prefix_bytes = bit_array.from_string(prefix)
  let full_message = bit_array.append(prefix_bytes, message_bytes)
  keccak.keccak256_binary(full_message)
}

// =============================================================================
// Utility Functions
// =============================================================================

/// Convert a wallet to a summary string for display
pub fn to_string(wallet: Wallet) -> String {
  let address = get_address(wallet)
  let private_key = get_private_key_hex(wallet)

  "Wallet {\n"
  <> "  address: "
  <> address
  <> "\n"
  <> "  private_key: "
  <> private_key
  <> "\n"
  <> "}"
}

/// Convert a wallet to a compact summary for logging
pub fn to_summary(wallet: Wallet) -> String {
  let address = get_address(wallet)
  "Wallet(" <> address <> ")"
}

/// Check if two wallets are the same (have same private key)
pub fn equals(wallet1: Wallet, wallet2: Wallet) -> Bool {
  get_private_key_hex(wallet1) == get_private_key_hex(wallet2)
}

// =============================================================================
// Error Handling Utilities
// =============================================================================

/// Convert WalletError to string for display
pub fn error_to_string(error: WalletError) -> String {
  case error {
    InvalidPrivateKey(msg) -> "Invalid private key: " <> msg
    InvalidHex(msg) -> "Invalid hex format: " <> msg
    KeyGenerationFailed(msg) -> "Key generation failed: " <> msg
    SigningFailed(msg) -> "Signing failed: " <> msg
  }
}

/// Check if an error is recoverable
pub fn is_recoverable_error(error: WalletError) -> Bool {
  case error {
    InvalidPrivateKey(_) -> False
    // Bad key format, not recoverable
    InvalidHex(_) -> False
    // Bad hex format, not recoverable
    KeyGenerationFailed(_) -> True
    // Might work with retry
    SigningFailed(_) -> True
    // Might work with retry
  }
}
