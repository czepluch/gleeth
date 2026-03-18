import gleam/int
import gleam/io
import gleam/result
import gleam/string
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex

// Execute storage-at command
pub fn execute(
  provider: Provider,
  address: String,
  slot: String,
  block: String,
) -> Result(Nil, rpc_types.GleethError) {
  use storage_value <- result.try(methods.get_storage_at(
    provider,
    address,
    slot,
    block,
  ))
  print_storage_info(address, slot, block, storage_value)
  Ok(Nil)
}

// Print storage information in a nice format
fn print_storage_info(
  address: String,
  slot: String,
  block: String,
  value: String,
) -> Nil {
  io.println("Storage Query:")
  io.println("  Contract: " <> address)
  io.println("  Slot: " <> slot)

  let block_display = case block {
    "" -> "latest"
    _ -> block
  }
  io.println("  Block: " <> block_display)
  io.println("")

  io.println("Storage Value:")
  io.println("  Raw (hex): " <> value)

  // Try to interpret the value in different ways
  interpret_storage_value(value)

  io.println("")
}

// Try to interpret the storage value in common formats
fn interpret_storage_value(value: String) -> Nil {
  // Check if it's all zeros (uninitialized storage)
  let is_zero = case value {
    "0x0" -> True
    "0x0000000000000000000000000000000000000000000000000000000000000000" -> True
    _ -> string.replace(value, "0", "") == "0x"
  }

  case is_zero {
    True -> {
      io.println("  Interpretation: Uninitialized storage (all zeros)")
    }
    False -> {
      // Try to convert to decimal if it looks like a number
      case hex.hex_to_int(value) {
        Ok(decimal_val) -> {
          io.println("  As integer: " <> int.to_string(decimal_val))
        }
        Error(_) -> Nil
      }

      // Check if it could be an address (20 bytes, non-zero in the last 40 chars)
      case string.length(value) >= 42 {
        True -> {
          let potential_address =
            "0x" <> string.slice(value, string.length(value) - 40, 40)
          case string.starts_with(potential_address, "0x000000") {
            False -> {
              io.println("  Potential address: " <> potential_address)
            }
            True -> Nil
          }
        }
        False -> Nil
      }

      // Show if it's a small value that could be a boolean
      case value {
        "0x0000000000000000000000000000000000000000000000000000000000000001" -> {
          io.println("  Possible boolean: true")
        }
        _ -> Nil
      }
    }
  }
}
