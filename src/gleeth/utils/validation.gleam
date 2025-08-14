import gleam/list
import gleam/string
import gleeth/ethereum/types as eth_types
import gleeth/rpc/types as rpc_types

// Validate Ethereum address format
// Consolidates validation logic from cli.gleam and utils/file.gleam
pub fn validate_address(
  address: String,
) -> Result(eth_types.Address, rpc_types.GleethError) {
  case string.length(address) {
    42 -> {
      case string.starts_with(address, "0x") {
        True -> Ok(address)
        False ->
          Error(rpc_types.InvalidAddress(
            "42 character address must start with 0x",
          ))
      }
    }
    40 -> Ok("0x" <> address)
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
