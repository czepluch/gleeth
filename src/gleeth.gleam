import argv
import gleeth/cli
import gleeth/commands/balance
import gleeth/commands/block_number
import gleeth/commands/call
import gleeth/commands/code
import gleeth/commands/estimate_gas
import gleeth/commands/get_logs
import gleeth/commands/storage_at
import gleeth/commands/transaction
import gleeth/config
import gleeth/ethereum/formatting
import gleeth/rpc/types as rpc_types

pub fn main() -> Nil {
  case argv.load().arguments {
    [] -> cli.show_help()
    args -> {
      case cli.parse_args(args) {
        Ok(parsed_args) -> {
          case parsed_args.command {
            cli.Help -> cli.show_help()
            _ -> {
              case config.new(parsed_args.rpc_url) {
                Ok(cfg) ->
                  execute_command(parsed_args.command, config.get_rpc_url(cfg))
                Error(err) -> print_error(err)
              }
            }
          }
        }
        Error(err) -> print_error(err)
      }
    }
  }
}

fn execute_command(command: cli.Command, rpc_url: String) -> Nil {
  let result = case command {
    cli.BlockNumber -> block_number.execute(rpc_url)
    cli.Balance(addresses, file) -> balance.execute(rpc_url, addresses, file)
    cli.Call(contract, function, parameters) ->
      call.execute(rpc_url, contract, function, parameters)
    cli.Transaction(hash) -> transaction.execute(rpc_url, hash)
    cli.Code(address) -> code.execute(rpc_url, address)
    cli.EstimateGas(from, to, value, data) ->
      estimate_gas.execute(rpc_url, from, to, value, data)
    cli.StorageAt(address, slot, block) ->
      storage_at.execute(rpc_url, address, slot, block)
    cli.GetLogs(from_block, to_block, address, topics) ->
      get_logs.execute(rpc_url, from_block, to_block, address, topics)
    cli.Help -> {
      cli.show_help()
      Ok(Nil)
    }
  }

  case result {
    Ok(_) -> Nil
    Error(err) -> print_error(err)
  }
}

fn print_error(error: rpc_types.GleethError) -> Nil {
  case error {
    rpc_types.InvalidRpcUrl(msg) ->
      formatting.print_error("Invalid RPC URL: " <> msg)
    rpc_types.InvalidAddress(msg) ->
      formatting.print_error("Invalid address: " <> msg)
    rpc_types.InvalidHash(msg) ->
      formatting.print_error("Invalid hash: " <> msg)
    rpc_types.RpcError(msg) -> formatting.print_error("RPC error: " <> msg)
    rpc_types.NetworkError(msg) ->
      formatting.print_error("Network error: " <> msg)
    rpc_types.ParseError(msg) -> formatting.print_error("Parse error: " <> msg)
    rpc_types.ConfigError(msg) ->
      formatting.print_error("Configuration error: " <> msg)
  }
}
