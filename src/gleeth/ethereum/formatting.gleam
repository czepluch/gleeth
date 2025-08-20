import gleam/int
import gleam/io
import gleam/string

import gleeth/ethereum/types.{
  type Address, type BlockNumber, type Hash, type Wei,
}
import gleeth/utils/hex

// Format Wei to Ether with proper decimal places
pub fn format_wei_to_ether(wei: Wei) -> String {
  hex.format_wei_to_ether(wei)
}

// Format block number (remove 0x prefix and convert to decimal)
pub fn format_block_number(block_number: BlockNumber) -> String {
  hex.format_block_number(block_number)
}

// Format address with checksum (simplified - just ensures 0x prefix)
pub fn format_address(address: Address) -> String {
  case string.starts_with(address, "0x") {
    True -> address
    False -> "0x" <> address
  }
}

// Format hash (ensure 0x prefix)
pub fn format_hash(hash: Hash) -> String {
  case string.starts_with(hash, "0x") {
    True -> hash
    False -> "0x" <> hash
  }
}

// Pretty print balance information
pub fn print_balance(address: Address, balance: Wei) -> Nil {
  io.println("Address: " <> format_address(address))
  io.println("Balance: " <> format_wei_to_ether(balance))
  io.println("Raw Wei: " <> balance)
}

// Pretty print block number
pub fn print_block_number(block_number: BlockNumber) -> Nil {
  io.println("Latest Block: " <> format_block_number(block_number))
  io.println("Raw Hex: " <> block_number)
}

// Pretty print transaction hash
pub fn print_transaction_hash(hash: Hash) -> Nil {
  io.println("Transaction: " <> format_hash(hash))
}

// Display error in user-friendly format
pub fn print_error(error: String) -> Nil {
  io.println("Error: " <> error)
}

// =============================================================================
// Common Display Functions
// =============================================================================

/// Format hex value with decimal equivalent for display
pub fn format_hex_with_decimal(hex_value: String, label: String) -> Nil {
  case hex.to_int(hex_value) {
    Ok(decimal_value) ->
      io.println(
        "  "
        <> label
        <> ": "
        <> int.to_string(decimal_value)
        <> " ("
        <> hex.normalize(hex_value)
        <> ")",
      )
    Error(_) -> io.println("  " <> label <> ": " <> hex.normalize(hex_value))
  }
}

/// Print a labeled value
pub fn print_labeled_value(label: String, value: String) -> Nil {
  io.println("  " <> label <> ": " <> value)
}

/// Print a section header
pub fn print_section(title: String) -> Nil {
  io.println("")
  io.println(title <> ":")
}

/// Print success message with emoji
pub fn print_success(message: String) -> Nil {
  io.println("✅ " <> message)
}

/// Print warning message with emoji
pub fn print_warning(message: String) -> Nil {
  io.println("⚠️  " <> message)
}

/// Print info message with emoji
pub fn print_info(message: String) -> Nil {
  io.println("📋 " <> message)
}

/// Format address for display (ensure 0x prefix and lowercase)
pub fn display_address(address: String) -> String {
  hex.normalize(address)
}

/// Format hash for display (ensure 0x prefix and lowercase)
pub fn display_hash(hash: String) -> String {
  hex.normalize(hash)
}
