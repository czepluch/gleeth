import gleam/int
import gleam/io
import gleam/result
import gleam/string

import gleeth/ethereum/formatting
import gleeth/ethereum/types as eth_types
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex

// Execute transaction command
pub fn execute(
  provider: Provider,
  transaction_hash: String,
) -> Result(Nil, rpc_types.GleethError) {
  use transaction <- result.try(methods.get_transaction(
    provider,
    transaction_hash,
  ))
  print_transaction(transaction)
  Ok(Nil)
}

// Print transaction in a nice format
fn print_transaction(transaction: eth_types.Transaction) -> Nil {
  io.println("Transaction Details:")
  io.println("  Hash: " <> transaction.hash)

  // Show block information (null for pending transactions)
  case transaction.block_number {
    "" -> io.println("  Status: Pending")
    block_num -> {
      io.println("  Block: " <> formatting.format_block_number(block_num))
      case transaction.transaction_index {
        "" -> Nil
        // Only print transaction index if transaction is confirmed
        index -> {
          formatting.format_hex_with_decimal(index, "Position")
        }
      }
    }
  }

  io.println("  From: " <> transaction.from)
  case transaction.to {
    "" -> io.println("  To: [Contract Creation]")
    address -> io.println("  To: " <> address)
  }

  // Format and display value (format_wei_to_ether already includes "ETH")
  io.println("  Value: " <> formatting.format_wei_to_ether(transaction.value))

  // Display gas information
  formatting.format_hex_with_decimal(transaction.gas, "Gas Limit")

  // Show gas pricing (different for legacy vs EIP-1559 transactions)
  case transaction.gas_price, transaction.max_fee_per_gas {
    "", "" -> Nil
    gas_price, "" -> {
      io.println("  Gas Price: " <> hex.format_wei_to_gwei(gas_price))
    }
    "", max_fee -> {
      io.println("  Max Fee Per Gas: " <> hex.format_wei_to_gwei(max_fee))
      case transaction.max_priority_fee_per_gas {
        "" -> Nil
        priority_fee -> {
          io.println(
            "  Max Priority Fee: " <> hex.format_wei_to_gwei(priority_fee),
          )
        }
      }
    }
    _, _ -> {
      io.println(
        "  Gas Price: " <> hex.format_wei_to_gwei(transaction.gas_price),
      )
    }
  }

  // Display nonce as decimal
  formatting.format_hex_with_decimal(transaction.nonce, "Nonce")

  // Show transaction type if present
  case transaction.transaction_type {
    "" -> Nil
    "0x0" -> io.println("  Type: Legacy")
    "0x1" -> io.println("  Type: EIP-2930 (Access List)")
    "0x2" -> io.println("  Type: EIP-1559 (Dynamic Fee)")
    type_str -> io.println("  Type: " <> type_str)
  }

  // Show chain ID if present
  case transaction.chain_id {
    "" -> Nil
    chain -> io.println("  Chain ID: " <> chain)
  }

  // Show input data
  let input_preview = case transaction.input {
    "0x" -> "None"
    input -> {
      let len = string.length(input)
      case len > 42 {
        True ->
          string.slice(input, 0, 42)
          <> "... ("
          <> int.to_string({ len - 2 } / 2)
          <> " bytes)"
        False -> input <> " (" <> int.to_string({ len - 2 } / 2) <> " bytes)"
      }
    }
  }
  io.println("  Input Data: " <> input_preview)

  // Show signature components
  io.println("")
  io.println("Signature:")
  io.println("  v: " <> transaction.v)
  io.println("  r: " <> transaction.r)
  io.println("  s: " <> transaction.s)
}
