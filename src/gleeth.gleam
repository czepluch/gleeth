import argv
import gleeth/cli
import gleeth/commands/balance
import gleeth/commands/block_number
import gleeth/commands/call
import gleeth/commands/code
import gleeth/commands/estimate_gas
import gleeth/commands/get_logs
import gleeth/commands/send
import gleeth/commands/storage_at
import gleeth/commands/transaction as transaction_cmd
import gleeth/commands/wallet
import gleeth/crypto/transaction
import gleeth/crypto/wallet as crypto_wallet
import gleeth/ethereum/abi/types as abi_types
import gleeth/ethereum/formatting
import gleeth/provider
import gleeth/rpc/types as rpc_types

pub fn main() -> Nil {
  case argv.load().arguments {
    [] -> cli.show_help()
    args -> {
      case cli.parse_args(args) {
        Ok(parsed_args) -> {
          case parsed_args.command {
            cli.Help -> cli.show_help()
            cli.Wallet(wallet_args) -> execute_wallet_command(wallet_args)
            _ -> {
              case provider.new(parsed_args.rpc_url) {
                Ok(p) -> execute_command(parsed_args.command, p)
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

fn execute_wallet_command(wallet_args: List(String)) -> Nil {
  case wallet.parse_args(wallet_args) {
    Ok(operation) -> {
      case wallet.run(operation) {
        Ok(_) -> Nil
        Error(msg) -> formatting.print_error("Wallet error: " <> msg)
      }
    }
    Error(msg) -> {
      formatting.print_error("Invalid wallet command: " <> msg)
      wallet.print_usage()
    }
  }
}

fn execute_command(command: cli.Command, p: provider.Provider) -> Nil {
  let result = case command {
    cli.BlockNumber -> block_number.execute(p)
    cli.Balance(addresses, file) -> balance.execute(p, addresses, file)
    cli.Call(contract, function, parameters, abi_file) ->
      call.execute(p, contract, function, parameters, abi_file)
    cli.Transaction(hash) -> transaction_cmd.execute(p, hash)
    cli.Code(address) -> code.execute(p, address)
    cli.EstimateGas(from, to, value, data) ->
      estimate_gas.execute(p, from, to, value, data)
    cli.StorageAt(address, slot, block) ->
      storage_at.execute(p, address, slot, block)
    cli.GetLogs(from_block, to_block, address, topics) ->
      get_logs.execute(p, from_block, to_block, address, topics)
    cli.Send(to, value, private_key, gas_limit, data, legacy) ->
      send.execute(
        p,
        send.SendArgs(to, value, private_key, gas_limit, data, legacy),
      )
    cli.Wallet(_) -> {
      // This case should not occur due to earlier handling
      formatting.print_error("Wallet command should be handled separately")
      Ok(Nil)
    }
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
    rpc_types.AbiErr(err) ->
      formatting.print_error("ABI error: " <> abi_error_message(err))
    rpc_types.WalletErr(err) ->
      formatting.print_error(
        "Wallet error: " <> crypto_wallet.error_to_string(err),
      )
    rpc_types.TransactionErr(err) ->
      formatting.print_error(
        "Transaction error: " <> transaction.error_to_string(err),
      )
  }
}

fn abi_error_message(err: abi_types.AbiError) -> String {
  case err {
    abi_types.EncodeError(msg) -> msg
    abi_types.DecodeError(msg) -> msg
    abi_types.TypeParseError(msg) -> msg
    abi_types.InvalidAbiJson(msg) -> msg
  }
}
