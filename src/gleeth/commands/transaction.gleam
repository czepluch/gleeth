import gleam/int
import gleam/io
import gleam/result
import gleam/string

import gleeth/ethereum/types as eth_types
import gleeth/ethereum/formatting
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex

// Execute transaction command
pub fn execute(
  rpc_url: String,
  transaction_hash: String,
) -> Result(Nil, rpc_types.GleethError) {
  use transaction <- result.try(methods.get_transaction(
    rpc_url,
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
        index -> {
          case hex.hex_to_int(index) {
            Ok(index_int) -> io.println("  Position: " <> int.to_string(index_int))
            Error(_) -> io.println("  Position: " <> index)
          }
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
  case hex.hex_to_int(transaction.gas) {
    Ok(gas_int) -> io.println("  Gas Limit: " <> int.to_string(gas_int))
    Error(_) -> io.println("  Gas Limit: " <> transaction.gas)
  }
  
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
          io.println("  Max Priority Fee: " <> hex.format_wei_to_gwei(priority_fee))
        }
      }
    }
    _, _ -> {
      io.println("  Gas Price: " <> hex.format_wei_to_gwei(transaction.gas_price))
    }
  }
  
  // Display nonce as decimal
  case hex.hex_to_int(transaction.nonce) {
    Ok(nonce_int) -> io.println("  Nonce: " <> int.to_string(nonce_int))
    Error(_) -> io.println("  Nonce: " <> transaction.nonce)
  }
  
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
         True -> string.slice(input, 0, 42) <> "... (" <> int.to_string({len - 2} / 2) <> " bytes)"
         False -> input <> " (" <> int.to_string({len - 2} / 2) <> " bytes)"
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


