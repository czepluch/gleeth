import gleam/result
import gleam/option.{type Option, None}
import gleeth/rpc/methods
import gleeth/ethereum/formatting
import gleeth/ethereum/types as eth_types
import gleeth/rpc/types as rpc_types
import gleeth/commands/parallel_balance

// Execute balance command - handles both single and multiple addresses
pub fn execute(
  rpc_url: String, 
  addresses: List(eth_types.Address), 
  file: Option(String),
) -> Result(Nil, rpc_types.GleethError) {
  case addresses, file {
    [single_address], None -> {
      // Single address - use original formatting
      use balance <- result.try(methods.get_balance(rpc_url, single_address))
      formatting.print_balance(single_address, balance)
      Ok(Nil)
    }
    _, _ -> {
      // Multiple addresses or file input - use parallel processing
      parallel_balance.execute_parallel(rpc_url, addresses, file)
    }
  }
}