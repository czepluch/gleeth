import gleam/io
import gleam/string

import gleeth/ethereum/types.{type Address, type Hash, type BlockNumber, type Wei}
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

// Display success message
pub fn print_success(message: String) -> Nil {
  io.println("✓ " <> message)
}