import gleam/result
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

/// Generate a new random wallet
/// This is a placeholder - in production, use proper cryptographic randomness
pub fn generate() -> Result(Wallet, WalletError) {
  case secp256k1.generate_private_key() {
    Ok(private_key) -> {
      use public_key <- result.try(
        secp256k1.create_public_key(private_key)
        |> result.map_error(KeyGenerationFailed),
      )

      use address <- result.try(
        secp256k1.public_key_to_address(public_key)
        |> result.map_error(KeyGenerationFailed),
      )

      Ok(Wallet(
        private_key: private_key,
        public_key: public_key,
        address: address,
      ))
    }
    Error(msg) -> Error(KeyGenerationFailed(msg))
  }
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
// Transaction Signing (Placeholder for future implementation)
// =============================================================================

/// Transaction parameters for signing
pub type TransactionParams {
  TransactionParams(
    to: String,
    // Recipient address
    value: String,
    // Value in wei (as hex string)
    gas_limit: String,
    // Gas limit (as hex string)
    gas_price: String,
    // Gas price in wei (as hex string)
    nonce: String,
    // Transaction nonce (as hex string)
    data: String,
    // Transaction data (as hex string)
    chain_id: Int,
    // Network chain ID
  )
}

/// Sign a transaction (placeholder for future implementation)
/// This would require RLP encoding which is not yet implemented
pub fn sign_transaction(
  _wallet: Wallet,
  _params: TransactionParams,
) -> Result(String, WalletError) {
  // Placeholder implementation
  Error(SigningFailed(
    "Transaction signing not yet implemented - requires RLP encoding",
  ))
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
