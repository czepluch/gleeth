import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex

// Execute estimate-gas command
pub fn execute(
  provider: Provider,
  from: String,
  to: String,
  value: String,
  data: String,
) -> Result(Nil, rpc_types.GleethError) {
  use gas_estimate <- result.try(methods.estimate_gas(
    provider,
    from,
    to,
    value,
    data,
  ))
  print_gas_estimate(from, to, value, data, gas_estimate)
  Ok(Nil)
}

// Print gas estimate in a nice format
fn print_gas_estimate(
  from: String,
  to: String,
  value: String,
  data: String,
  gas_estimate: String,
) -> Nil {
  io.println("Gas Estimation:")

  // Show transaction parameters
  case from {
    "" -> Nil
    _ -> io.println("  From: " <> from)
  }

  case to {
    "" -> Nil
    _ -> io.println("  To: " <> to)
  }

  case value {
    "" -> Nil
    _ -> {
      case hex.hex_to_int(value) {
        Ok(decimal_wei) ->
          io.println(
            "  Value: "
            <> int.to_string(decimal_wei)
            <> " wei ("
            <> value
            <> ")",
          )
        Error(_) -> io.println("  Value: " <> value)
      }
    }
  }

  case data {
    "" -> Nil
    _ -> {
      let data_preview = case string.length(data) > 42 {
        True -> string.slice(data, 0, 42) <> "..."
        False -> data
      }
      io.println("  Data: " <> data_preview)
    }
  }

  io.println("")

  // Show gas estimate
  io.println("Estimated Gas: " <> gas_estimate)

  // Convert hex gas estimate to decimal for readability
  case hex.hex_to_int(gas_estimate) {
    Ok(decimal_gas) -> {
      io.println(
        "Estimated Gas (decimal): " <> int.to_string(decimal_gas) <> " units",
      )

      // Estimate cost at different gas prices
      print_cost_estimates(decimal_gas)
    }
    Error(_) -> io.println("(Could not convert gas estimate to decimal)")
  }

  io.println("")
}

// Print cost estimates at different gas prices
fn print_cost_estimates(gas_units: Int) -> Nil {
  io.println("")
  io.println("Cost Estimates:")

  // Common gas prices in gwei
  let gas_prices = [
    #(10, "10 gwei (slow)"),
    #(20, "20 gwei (standard)"),
    #(50, "50 gwei (fast)"),
    #(100, "100 gwei (very fast)"),
  ]

  // Calculate costs
  list.each(gas_prices, fn(price_info) {
    let #(gwei, label) = price_info
    let wei_cost = gas_units * gwei * 1_000_000_000
    // Convert gwei to wei
    let eth_cost = int.to_float(wei_cost) /. 1_000_000_000_000_000_000.0
    // Convert wei to ETH

    io.println("  " <> label <> ": " <> float.to_string(eth_cost) <> " ETH")
  })
}
