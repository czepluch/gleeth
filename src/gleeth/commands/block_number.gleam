import gleam/result
import gleeth/ethereum/formatting
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types

// Execute block number command
pub fn execute(provider: Provider) -> Result(Nil, rpc_types.GleethError) {
  use block_number <- result.try(methods.get_block_number(provider))
  formatting.print_block_number(block_number)
  Ok(Nil)
}
