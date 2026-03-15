import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}

import gleam/result
import gleam/string
import gleeth/ethereum/types.{type Address, type Wei}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth/utils/file
import gleeth/utils/hex

// Result type for individual balance checks
pub type BalanceResult {
  BalanceSuccess(address: Address, balance: Wei, ether: Float)
  BalanceError(address: Address, error: String)
}

// Summary statistics for multiple balance checks
pub type BalanceSummary {
  BalanceSummary(
    total_addresses: Int,
    successful: Int,
    failed: Int,
    total_ether: Float,
    average_ether: Float,
  )
}

// Execute parallel balance checks for multiple addresses
pub fn execute_parallel(
  rpc_url: String,
  addresses: List(Address),
  file: Option(String),
) -> Result(Nil, rpc_types.GleethError) {
  use final_addresses <- result.try(get_all_addresses(addresses, file))

  case final_addresses {
    [] -> Error(rpc_types.ConfigError("No addresses to check"))
    addrs -> {
      io.println(
        "Checking " <> int.to_string(list.length(addrs)) <> " addresses...",
      )
      io.println("")

      let results = check_balances_concurrently(rpc_url, addrs)
      display_results(results)
      Ok(Nil)
    }
  }
}

// Get all addresses from direct input and file
fn get_all_addresses(
  direct_addresses: List(Address),
  file: Option(String),
) -> Result(List(Address), rpc_types.GleethError) {
  case file {
    Some(filename) -> {
      use file_addresses <- result.try(file.read_addresses_from_file(filename))
      Ok(list.append(direct_addresses, file_addresses))
    }
    None -> Ok(direct_addresses)
  }
}

// Check balances concurrently, batched into groups of 10 to avoid
// overwhelming the RPC node
fn check_balances_concurrently(
  rpc_url: String,
  addresses: List(Address),
) -> List(BalanceResult) {
  addresses
  |> list.sized_chunk(10)
  |> list.flat_map(fn(batch) { check_batch_concurrently(rpc_url, batch) })
}

// Spawn a process for each address in the batch, collect all results
fn check_batch_concurrently(
  rpc_url: String,
  addresses: List(Address),
) -> List(BalanceResult) {
  let subject = process.new_subject()
  let batch_size = list.length(addresses)

  // Spawn one process per address, each sends its result back on the subject
  list.each(addresses, fn(address) {
    process.spawn(fn() {
      let result = check_single_balance(rpc_url, address)
      process.send(subject, result)
    })
  })

  // Collect all results (30 second timeout per result)
  collect_results(subject, batch_size, [])
}

// Receive exactly `remaining` results from the subject
fn collect_results(
  subject: process.Subject(BalanceResult),
  remaining: Int,
  acc: List(BalanceResult),
) -> List(BalanceResult) {
  case remaining {
    0 -> list.reverse(acc)
    n -> {
      case process.receive(subject, 30_000) {
        Ok(result) -> collect_results(subject, n - 1, [result, ..acc])
        Error(Nil) -> list.reverse(acc)
      }
    }
  }
}

// Check balance for a single address
fn check_single_balance(rpc_url: String, address: Address) -> BalanceResult {
  case methods.get_balance(rpc_url, address) {
    Ok(balance_wei) -> {
      case hex.wei_to_ether(balance_wei) {
        Ok(ether_amount) -> BalanceSuccess(address, balance_wei, ether_amount)
        Error(_) -> BalanceError(address, "Failed to convert Wei to Ether")
      }
    }
    Error(error) -> BalanceError(address, error_to_string(error))
  }
}

// Convert GleethError to string
fn error_to_string(error: rpc_types.GleethError) -> String {
  case error {
    rpc_types.InvalidRpcUrl(msg) -> "Invalid RPC URL: " <> msg
    rpc_types.InvalidAddress(msg) -> "Invalid address: " <> msg
    rpc_types.InvalidHash(msg) -> "Invalid hash: " <> msg
    rpc_types.RpcError(msg) -> "RPC error: " <> msg
    rpc_types.NetworkError(msg) -> "Network error: " <> msg
    rpc_types.ParseError(msg) -> "Parse error: " <> msg
    rpc_types.ConfigError(msg) -> "Config error: " <> msg
  }
}

// Display results in a nice table format
fn display_results(results: List(BalanceResult)) -> Nil {
  let summary = calculate_summary(results)

  // Print table header
  print_table_header()
  print_table_separator()

  // Print each result
  list.each(results, print_balance_row)

  // Print table footer
  print_table_separator()
  print_summary(summary)
}

// Print table header
fn print_table_header() -> Nil {
  io.println(
    "┌──────────────────────────────────────────────┬─────────────────┬─────────────┐",
  )
  io.println(
    "│ Address                                      │ Balance (ETH)   │ Status      │",
  )
}

// Print table separator
fn print_table_separator() -> Nil {
  io.println(
    "├──────────────────────────────────────────────┼─────────────────┼─────────────┤",
  )
}

// Print a single balance result row
fn print_balance_row(result: BalanceResult) -> Nil {
  case result {
    BalanceSuccess(address, _wei, ether) -> {
      let formatted_address = pad_right(address, 44)
      let formatted_balance = pad_left(format_ether(ether), 15)
      io.println(
        "│ "
        <> formatted_address
        <> " │ "
        <> formatted_balance
        <> " │ ✓           │",
      )
    }
    BalanceError(address, error) -> {
      let formatted_address = pad_right(address, 44)
      let formatted_error = pad_left("ERROR", 15)
      io.println(
        "│ "
        <> formatted_address
        <> " │ "
        <> formatted_error
        <> " │ ✗           │",
      )
      io.println(
        "│   Error: " <> pad_right(truncate_string(error, 60), 62) <> " │",
      )
    }
  }
}

// Format ether amount to readable string
fn format_ether(ether: Float) -> String {
  case ether {
    e if e >. 1000.0 -> float_to_string_rounded(e, 3) <> " ETH"
    e if e >. 1.0 -> float_to_string_rounded(e, 6) <> " ETH"
    e if e >. 0.001 -> float_to_string_rounded(e, 9) <> " ETH"
    e -> float_to_string_rounded(e, 12) <> " ETH"
  }
}

// Round float to specified decimal places (simplified)
fn float_to_string_rounded(f: Float, _decimals: Int) -> String {
  float.to_string(f)
}

// Pad string to the right with spaces
fn pad_right(str: String, width: Int) -> String {
  let current_length = string.length(str)
  case current_length >= width {
    True -> truncate_string(str, width)
    False -> str <> string.repeat(" ", width - current_length)
  }
}

// Pad string to the left with spaces
fn pad_left(str: String, width: Int) -> String {
  let current_length = string.length(str)
  case current_length >= width {
    True -> truncate_string(str, width)
    False -> string.repeat(" ", width - current_length) <> str
  }
}

// Truncate string to maximum length
fn truncate_string(str: String, max_length: Int) -> String {
  case string.length(str) <= max_length {
    True -> str
    False -> string.slice(str, 0, max_length - 3) <> "..."
  }
}

// Calculate summary statistics
fn calculate_summary(results: List(BalanceResult)) -> BalanceSummary {
  let total_addresses = list.length(results)
  let successful_results =
    list.filter(results, fn(result) {
      case result {
        BalanceSuccess(_, _, _) -> True
        BalanceError(_, _) -> False
      }
    })
  let successful = list.length(successful_results)
  let failed = total_addresses - successful

  let total_ether =
    list.fold(successful_results, 0.0, fn(acc, result) {
      case result {
        BalanceSuccess(_, _, ether) -> acc +. ether
        BalanceError(_, _) -> acc
      }
    })

  let average_ether = case successful {
    0 -> 0.0
    _ -> total_ether /. int.to_float(successful)
  }

  BalanceSummary(
    total_addresses: total_addresses,
    successful: successful,
    failed: failed,
    total_ether: total_ether,
    average_ether: average_ether,
  )
}

// Print summary statistics
fn print_summary(summary: BalanceSummary) -> Nil {
  io.println(
    "└──────────────────────────────────────────────┴─────────────────┴─────────────┘",
  )
  io.println("")
  io.println("Summary:")
  io.println("  Total addresses: " <> int.to_string(summary.total_addresses))
  io.println("  Successful: " <> int.to_string(summary.successful))
  io.println("  Failed: " <> int.to_string(summary.failed))
  case summary.successful > 0 {
    True -> {
      io.println("  Total ETH: " <> format_ether(summary.total_ether))
      io.println("  Average ETH: " <> format_ether(summary.average_ether))
    }
    False -> Nil
  }
}
