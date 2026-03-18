import gleam/option.{type Option, None}
import gleam/result
import gleeth/commands/parallel_balance
import gleeth/ethereum/formatting
import gleeth/ethereum/types as eth_types
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types

// Execute balance command - handles both single and multiple addresses
pub fn execute(
  provider: Provider,
  addresses: List(eth_types.Address),
  file: Option(String),
) -> Result(Nil, rpc_types.GleethError) {
  case addresses, file {
    [single_address], None -> {
      // Single address - use original formatting
      use balance <- result.try(methods.get_balance(provider, single_address))
      formatting.print_balance(single_address, balance)
      Ok(Nil)
    }
    _, _ -> {
      // Multiple addresses or file input - use parallel processing
      parallel_balance.execute_parallel(provider, addresses, file)
    }
  }
}
