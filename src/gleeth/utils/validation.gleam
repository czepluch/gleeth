import gleam/list

import gleam/string
import gleeth/ethereum/types as eth_types
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex

// Validate Ethereum address format
// Consolidates validation logic from cli.gleam and utils/file.gleam
pub fn validate_address(
  address: String,
) -> Result(eth_types.Address, rpc_types.GleethError) {
  case string.length(address) {
    42 -> {
      case string.starts_with(address, "0x") {
        True -> {
          case hex.is_valid_hex_chars(address) {
            True -> Ok(address)
            False ->
              Error(rpc_types.InvalidAddress(
                "Address contains invalid hex characters",
              ))
          }
        }
        False ->
          Error(rpc_types.InvalidAddress(
            "42 character address must start with 0x",
          ))
      }
    }
    40 -> {
      case hex.is_valid_hex_chars(address) {
        True -> Ok("0x" <> address)
        False ->
          Error(rpc_types.InvalidAddress(
            "Address contains invalid hex characters",
          ))
      }
    }
    _ ->
      Error(rpc_types.InvalidAddress(
        "Address must be 40 hex characters, optionally prefixed with 0x",
      ))
  }
}

// Validate multiple addresses
pub fn validate_addresses(
  addresses: List(String),
) -> Result(List(eth_types.Address), rpc_types.GleethError) {
  list.try_map(addresses, validate_address)
}

// Validate transaction hash format
// Consolidates hash validation logic from cli.gleam
pub fn validate_hash(
  hash: String,
) -> Result(eth_types.Hash, rpc_types.GleethError) {
  case string.length(hash) {
    66 -> {
      case string.starts_with(hash, "0x") {
        True -> Ok(hash)
        False ->
          Error(rpc_types.InvalidHash("66 character hash must start with 0x"))
      }
    }
    64 -> Ok("0x" <> hash)
    _ ->
      Error(rpc_types.InvalidHash(
        "Hash must be 64 hex characters, optionally prefixed with 0x",
      ))
  }
}

// Validate a single address from a file line (trimmed and filtered)
// This replaces the file-specific validation logic
pub fn validate_address_from_line(
  line: String,
) -> Result(eth_types.Address, rpc_types.GleethError) {
  let trimmed = string.trim(line)

  // Skip empty lines and comments
  case trimmed {
    "" -> Error(rpc_types.ConfigError("Empty line"))
    _ -> {
      case string.starts_with(trimmed, "#") {
        True -> Error(rpc_types.ConfigError("Comment line"))
        False -> validate_address(trimmed)
      }
    }
  }
}

// =============================================================================
// Enhanced Validation Functions
// =============================================================================

/// Validate hex string with specific byte length requirement
pub fn validate_hex_bytes(
  hex_string: String,
  expected_bytes: Int,
  description: String,
) -> Result(String, rpc_types.GleethError) {
  // Check if it's valid hex
  case hex.is_valid_hex_chars(hex_string) {
    False ->
      Error(rpc_types.ParseError(
        description <> " contains invalid hex characters",
      ))
    True -> {
      // Check length
      case hex.validate_length(hex_string, expected_bytes) {
        Ok(_clean_hex) -> Ok(hex.normalize(hex_string))
        Error(msg) -> Error(rpc_types.ParseError(description <> ": " <> msg))
      }
    }
  }
}

/// Validate private key format (32 bytes)
pub fn validate_private_key(
  private_key: String,
) -> Result(String, rpc_types.GleethError) {
  validate_hex_bytes(private_key, 32, "Private key")
}

/// Validate public key format (33 or 65 bytes)
pub fn validate_public_key(
  public_key: String,
) -> Result(String, rpc_types.GleethError) {
  let clean = hex.strip_prefix(public_key)
  case string.length(clean) {
    66 -> validate_hex_bytes(public_key, 33, "Compressed public key")
    130 -> validate_hex_bytes(public_key, 65, "Uncompressed public key")
    _ ->
      Error(rpc_types.ParseError(
        "Public key must be 33 bytes (compressed) or 65 bytes (uncompressed)",
      ))
  }
}

/// Validate signature format (65 bytes: r + s + v)
pub fn validate_signature(
  signature: String,
) -> Result(String, rpc_types.GleethError) {
  validate_hex_bytes(signature, 65, "Signature")
}

/// Validate Ethereum transaction hash
pub fn validate_transaction_hash(
  hash: String,
) -> Result(String, rpc_types.GleethError) {
  validate_hex_bytes(hash, 32, "Transaction hash")
}

/// Validate block hash
pub fn validate_block_hash(
  hash: String,
) -> Result(String, rpc_types.GleethError) {
  validate_hex_bytes(hash, 32, "Block hash")
}

/// Validate amount/value field (can be any valid hex number)
pub fn validate_hex_amount(
  amount: String,
) -> Result(String, rpc_types.GleethError) {
  case amount {
    "" -> Error(rpc_types.ParseError("Amount cannot be empty"))
    _ ->
      case hex.is_valid_hex_chars(amount) {
        True -> Ok(hex.normalize(amount))
        False ->
          Error(rpc_types.ParseError("Amount contains invalid hex characters"))
      }
  }
}

/// Validate contract call data
pub fn validate_call_data(data: String) -> Result(String, rpc_types.GleethError) {
  case data {
    "0x" -> Ok("0x")
    // Empty data is valid
    _ -> {
      case hex.is_valid_hex_chars(data) {
        True -> {
          let clean = hex.strip_prefix(data)
          // Call data should have even length (whole bytes)
          case string.length(clean) % 2 {
            0 -> Ok(hex.normalize(data))
            _ ->
              Error(rpc_types.ParseError(
                "Call data must have even number of hex characters",
              ))
          }
        }
        False ->
          Error(rpc_types.ParseError(
            "Call data contains invalid hex characters",
          ))
      }
    }
  }
}

/// Validate chain ID (must be positive integer)
pub fn validate_chain_id(chain_id: Int) -> Result(Int, rpc_types.GleethError) {
  case chain_id > 0 {
    True -> Ok(chain_id)
    False -> Error(rpc_types.ConfigError("Chain ID must be a positive integer"))
  }
}

/// Generic validator for non-empty strings
pub fn validate_non_empty(
  value: String,
  field_name: String,
) -> Result(String, rpc_types.GleethError) {
  case string.trim(value) {
    "" -> Error(rpc_types.ConfigError(field_name <> " cannot be empty"))
    trimmed -> Ok(trimmed)
  }
}
