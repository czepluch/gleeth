import gleam/io
import gleam/result
import gleam/string
import gleeth/ethereum/types as eth_types
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types

// Execute code command - get bytecode at an address
pub fn execute(
  provider: Provider,
  address: eth_types.Address,
) -> Result(Nil, rpc_types.GleethError) {
  use code <- result.try(methods.get_code(provider, address))
  print_code(address, code)
  Ok(Nil)
}

// Print contract code in a nice format
fn print_code(address: eth_types.Address, code: String) -> Nil {
  io.println("Address: " <> address)

  case code {
    "0x" -> {
      io.println("Type: No bytecode found")
      io.println("This could be:")
      io.println("  • EOA (Externally Owned Account/wallet)")
      io.println("  • Uninitialized address (contract could be deployed later)")
      io.println("  • Empty contract (deployed with no runtime code)")
    }
    _ -> {
      io.println("Type: Contract")
      io.println(
        "Code Length: " <> string.inspect(string.length(code)) <> " characters",
      )

      // Show first part of bytecode with truncation for readability
      let preview_length = 100
      case string.length(code) > preview_length {
        True -> {
          io.println(
            "Code Preview: " <> string.slice(code, 0, preview_length) <> "...",
          )
          io.println("Full Code: " <> code)
        }
        False -> {
          io.println("Full Code: " <> code)
        }
      }
    }
  }

  io.println("")
}
