import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleeth/ethereum/types as eth_types
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types

// Execute get-logs command
pub fn execute(
  provider: Provider,
  from_block: String,
  to_block: String,
  address: String,
  topics: List(String),
) -> Result(Nil, rpc_types.GleethError) {
  use logs <- result.try(methods.get_logs(
    provider,
    from_block,
    to_block,
    address,
    topics,
  ))
  print_logs_info(from_block, to_block, address, topics, logs)
  Ok(Nil)
}

// Print logs information in a nice format
fn print_logs_info(
  from_block: String,
  to_block: String,
  address: String,
  topics: List(String),
  logs: List(eth_types.Log),
) -> Nil {
  io.println("Event Logs Query:")

  let from_display = case from_block {
    "" -> "latest"
    _ -> from_block
  }
  io.println("  From Block: " <> from_display)

  let to_display = case to_block {
    "" -> "latest"
    _ -> to_block
  }
  io.println("  To Block: " <> to_display)

  case address {
    "" -> io.println("  Contract: All contracts")
    _ -> io.println("  Contract: " <> address)
  }

  case topics {
    [] -> io.println("  Topics: All topics")
    _ -> {
      io.println("  Topics:")
      list.each(topics, fn(topic) { io.println("    " <> topic) })
    }
  }

  io.println("")

  let log_count = list.length(logs)
  io.println("Found " <> int.to_string(log_count) <> " log(s)")

  case log_count > 0 {
    True -> {
      io.println("")

      // Limit detailed output to prevent overwhelming display
      let display_limit = 10
      let logs_to_show = case log_count > display_limit {
        True -> {
          io.println(
            "Showing first "
            <> int.to_string(display_limit)
            <> " logs (use filters to narrow results):",
          )
          io.println("")
          list.take(logs, display_limit)
        }
        False -> logs
      }

      list.each(
        list.index_map(logs_to_show, fn(log, index) { #(log, index + 1) }),
        fn(log_with_index) {
          let #(log, index) = log_with_index
          print_single_log(log, index)
        },
      )

      // Show truncation message if we limited the output
      case log_count > display_limit {
        True -> {
          io.println("")
          io.println(
            "... and "
            <> int.to_string(log_count - display_limit)
            <> " more logs",
          )
          io.println(
            "Use more specific filters (--address, --topic, smaller block range) to see fewer results",
          )
        }
        False -> Nil
      }
    }
    False -> {
      io.println("No logs found matching the specified criteria.")
    }
  }

  io.println("")
}

// Print a single log entry (concise format)
fn print_single_log(log: eth_types.Log, index: Int) -> Nil {
  io.println("Log #" <> int.to_string(index) <> ":")
  io.println("  Contract: " <> log.address)
  io.println(
    "  Block: "
    <> log.block_number
    <> " | Transaction: "
    <> string.slice(log.transaction_hash, 0, 10)
    <> "...",
  )

  // Show topics concisely
  case log.topics {
    [] -> io.println("  Topics: (none)")
    [topic] -> io.println("  Topics: [" <> string.slice(topic, 0, 10) <> "...]")
    _ ->
      io.println(
        "  Topics: "
        <> int.to_string(list.length(log.topics))
        <> " topics ["
        <> string.slice(list.first(log.topics) |> result.unwrap(""), 0, 10)
        <> "...]",
      )
  }

  // Show data preview
  let data_preview = case string.length(log.data) > 20 {
    True -> string.slice(log.data, 0, 20) <> "..."
    False -> log.data
  }
  io.println("  Data: " <> data_preview)
  io.println(
    "  Status: "
    <> case log.removed {
      True -> "Removed"
      False -> "Active"
    },
  )
  io.println("")
}
