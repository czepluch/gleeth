import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleeth/ethereum/types as eth_types
import gleeth/rpc/types as rpc_types
import gleeth/utils/validation

// CLI command definitions
pub type Command {
  BlockNumber
  Balance(addresses: List(eth_types.Address), file: Option(String))
  Call(
    contract: eth_types.Address,
    function: String,
    parameters: List(String),
    abi_file: Option(String),
  )
  Transaction(hash: eth_types.Hash)
  Code(address: eth_types.Address)
  EstimateGas(from: String, to: String, value: String, data: String)
  StorageAt(address: eth_types.Address, slot: String, block: String)
  GetLogs(
    from_block: String,
    to_block: String,
    address: String,
    topics: List(String),
  )
  Send(
    to: String,
    value: String,
    private_key: String,
    gas_limit: String,
    data: String,
    legacy: Bool,
  )
  Wallet(wallet_args: List(String))
  Help
}

// CLI arguments structure
pub type Args {
  Args(command: Command, rpc_url: String)
}

// Parse command line arguments
pub fn parse_args(args: List(String)) -> Result(Args, rpc_types.GleethError) {
  case args {
    [] -> Ok(Args(Help, ""))
    ["help"] -> Ok(Args(Help, ""))
    ["--help"] -> Ok(Args(Help, ""))
    ["-h"] -> Ok(Args(Help, ""))

    ["block-number", ..rest] -> {
      use rpc_url <- result.try(extract_rpc_url(rest))
      Ok(Args(BlockNumber, rpc_url))
    }

    ["balance", ..args] -> {
      use #(addresses, file, rpc_url) <- result.try(parse_balance_args(args))
      Ok(Args(Balance(addresses, file), rpc_url))
    }

    ["call", contract, function, ..rest] -> {
      use validated_contract <- result.try(validation.validate_address(contract))
      let #(parameters, abi_file, rpc_args) = extract_call_args(rest)
      use rpc_url <- result.try(extract_rpc_url(rpc_args))
      Ok(Args(Call(validated_contract, function, parameters, abi_file), rpc_url))
    }

    ["transaction", hash, ..rest] -> {
      use validated_hash <- result.try(validation.validate_hash(hash))
      use rpc_url <- result.try(extract_rpc_url(rest))
      Ok(Args(Transaction(validated_hash), rpc_url))
    }

    ["code", address, ..rest] -> {
      use validated_address <- result.try(validation.validate_address(address))
      use rpc_url <- result.try(extract_rpc_url(rest))
      Ok(Args(Code(validated_address), rpc_url))
    }

    ["estimate-gas", ..rest] -> {
      use #(from, to, value, data, remaining) <- result.try(
        parse_estimate_gas_args(rest),
      )
      use rpc_url <- result.try(extract_rpc_url(remaining))
      Ok(Args(EstimateGas(from, to, value, data), rpc_url))
    }

    ["storage-at", ..rest] -> {
      use #(address, slot, block, remaining) <- result.try(
        parse_storage_at_args(rest),
      )
      use rpc_url <- result.try(extract_rpc_url(remaining))
      Ok(Args(StorageAt(address, slot, block), rpc_url))
    }

    ["get-logs", ..rest] -> {
      use #(from_block, to_block, address, topics, remaining) <- result.try(
        parse_get_logs_args(rest),
      )
      use rpc_url <- result.try(extract_rpc_url(remaining))
      Ok(Args(GetLogs(from_block, to_block, address, topics), rpc_url))
    }

    ["send", ..rest] -> {
      use #(to, value, private_key, gas_limit, data, legacy, remaining) <- result.try(
        parse_send_args(rest),
      )
      use rpc_url <- result.try(extract_rpc_url(remaining))
      Ok(Args(Send(to, value, private_key, gas_limit, data, legacy), rpc_url))
    }

    ["wallet", ..wallet_args] -> {
      // Wallet commands don't require RPC URL
      Ok(Args(Wallet(wallet_args), ""))
    }

    _ ->
      Error(rpc_types.ConfigError(
        "Invalid command. Use --help for usage information.",
      ))
  }
}

// Extract RPC URL from remaining arguments
fn extract_rpc_url(args: List(String)) -> Result(String, rpc_types.GleethError) {
  case args {
    ["--rpc-url", url, ..] -> Ok(url)
    [] -> {
      // Try to get from environment variable
      case get_env_rpc_url() {
        Ok(url) -> Ok(url)
        Error(_) ->
          Error(rpc_types.ConfigError(
            "RPC URL required. Use --rpc-url or set GLEETH_RPC_URL environment variable.",
          ))
      }
    }
    _ ->
      Error(rpc_types.ConfigError(
        "Invalid arguments. RPC URL must be specified with --rpc-url.",
      ))
  }
}

// Parse balance command arguments - supports multiple addresses and --file
fn parse_balance_args(
  args: List(String),
) -> Result(
  #(List(eth_types.Address), Option(String), String),
  rpc_types.GleethError,
) {
  case args {
    ["--file", filename, ..rest] -> {
      use rpc_url <- result.try(extract_rpc_url(rest))
      Ok(#([], Some(filename), rpc_url))
    }
    ["-f", filename, ..rest] -> {
      use rpc_url <- result.try(extract_rpc_url(rest))
      Ok(#([], Some(filename), rpc_url))
    }
    _ -> {
      let #(address_args, remaining) = split_until_flag(args)
      case address_args {
        [] ->
          Error(rpc_types.ConfigError(
            "At least one address or --file must be specified",
          ))
        _ -> {
          use validated_addresses <- result.try(validation.validate_addresses(
            address_args,
          ))
          use rpc_url <- result.try(extract_rpc_url(remaining))
          Ok(#(validated_addresses, None, rpc_url))
        }
      }
    }
  }
}

// Split arguments until we hit a flag (--rpc-url, --file, etc.)
fn split_until_flag(args: List(String)) -> #(List(String), List(String)) {
  case args {
    [] -> #([], [])
    [arg, ..rest] -> {
      case string.starts_with(arg, "--") {
        True -> #([], args)
        False -> {
          let #(addresses, remaining) = split_until_flag(rest)
          #([arg, ..addresses], remaining)
        }
      }
    }
  }
}

// Get RPC URL from the GLEETH_RPC_URL environment variable
fn get_env_rpc_url() -> Result(String, Nil) {
  get_env("GLEETH_RPC_URL")
}

@external(erlang, "gleeth_ffi", "get_env")
fn get_env(name: String) -> Result(String, Nil)

// Extract parameters, --abi flag, and RPC arguments from call command args
fn extract_call_args(
  args: List(String),
) -> #(List(String), Option(String), List(String)) {
  extract_call_args_helper(args, [], None)
}

fn extract_call_args_helper(
  args: List(String),
  parameters: List(String),
  abi_file: Option(String),
) -> #(List(String), Option(String), List(String)) {
  case args {
    ["--rpc-url", ..] -> #(list.reverse(parameters), abi_file, args)
    ["--abi", file, ..rest] ->
      extract_call_args_helper(rest, parameters, Some(file))
    [param, ..rest] ->
      extract_call_args_helper(rest, [param, ..parameters], abi_file)
    [] -> #(list.reverse(parameters), abi_file, [])
  }
}

// Parse estimate-gas command arguments
fn parse_estimate_gas_args(
  args: List(String),
) -> Result(
  #(String, String, String, String, List(String)),
  rpc_types.GleethError,
) {
  parse_estimate_gas_args_helper(args, "", "", "", "", [])
}

// Helper function to parse estimate-gas arguments recursively
fn parse_estimate_gas_args_helper(
  args: List(String),
  from: String,
  to: String,
  value: String,
  data: String,
  remaining: List(String),
) -> Result(
  #(String, String, String, String, List(String)),
  rpc_types.GleethError,
) {
  case args {
    [] -> Ok(#(from, to, value, data, remaining))

    ["--from", addr, ..rest] -> {
      use validated_addr <- result.try(validation.validate_address(addr))
      parse_estimate_gas_args_helper(
        rest,
        validated_addr,
        to,
        value,
        data,
        remaining,
      )
    }

    ["--to", addr, ..rest] -> {
      use validated_addr <- result.try(validation.validate_address(addr))
      parse_estimate_gas_args_helper(
        rest,
        from,
        validated_addr,
        value,
        data,
        remaining,
      )
    }

    ["--value", val, ..rest] -> {
      parse_estimate_gas_args_helper(rest, from, to, val, data, remaining)
    }

    ["--data", hex_data, ..rest] -> {
      parse_estimate_gas_args_helper(rest, from, to, value, hex_data, remaining)
    }

    // Any other arguments (like --rpc-url) go to remaining
    _ -> Ok(#(from, to, value, data, args))
  }
}

// Parse storage-at command arguments
fn parse_storage_at_args(
  args: List(String),
) -> Result(#(String, String, String, List(String)), rpc_types.GleethError) {
  parse_storage_at_args_helper(args, "", "", "", [])
}

// Helper function to parse storage-at arguments recursively
fn parse_storage_at_args_helper(
  args: List(String),
  address: String,
  slot: String,
  block: String,
  remaining: List(String),
) -> Result(#(String, String, String, List(String)), rpc_types.GleethError) {
  case args {
    [] -> {
      // Validate required fields
      case address == "" || slot == "" {
        True ->
          Error(rpc_types.ConfigError(
            "storage-at requires --address and --slot flags",
          ))
        False -> Ok(#(address, slot, block, remaining))
      }
    }

    ["--address", addr, ..rest] -> {
      use validated_addr <- result.try(validation.validate_address(addr))
      parse_storage_at_args_helper(rest, validated_addr, slot, block, remaining)
    }

    ["--slot", slot_val, ..rest] -> {
      parse_storage_at_args_helper(rest, address, slot_val, block, remaining)
    }

    ["--block", block_val, ..rest] -> {
      parse_storage_at_args_helper(rest, address, slot, block_val, remaining)
    }

    // Any other arguments (like --rpc-url) go to remaining
    _ -> Ok(#(address, slot, block, args))
  }
}

// Parse get-logs command arguments
fn parse_get_logs_args(
  args: List(String),
) -> Result(
  #(String, String, String, List(String), List(String)),
  rpc_types.GleethError,
) {
  parse_get_logs_args_helper(args, "", "", "", [], [])
}

// Helper function to parse get-logs arguments recursively
fn parse_get_logs_args_helper(
  args: List(String),
  from_block: String,
  to_block: String,
  address: String,
  topics: List(String),
  remaining: List(String),
) -> Result(
  #(String, String, String, List(String), List(String)),
  rpc_types.GleethError,
) {
  case args {
    [] -> Ok(#(from_block, to_block, address, topics, remaining))

    ["--from-block", block, ..rest] -> {
      parse_get_logs_args_helper(
        rest,
        block,
        to_block,
        address,
        topics,
        remaining,
      )
    }

    ["--to-block", block, ..rest] -> {
      parse_get_logs_args_helper(
        rest,
        from_block,
        block,
        address,
        topics,
        remaining,
      )
    }

    ["--address", addr, ..rest] -> {
      use validated_addr <- result.try(validation.validate_address(addr))
      parse_get_logs_args_helper(
        rest,
        from_block,
        to_block,
        validated_addr,
        topics,
        remaining,
      )
    }

    ["--topic", topic, ..rest] -> {
      // Add topic to the list
      let new_topics = [topic, ..topics]
      parse_get_logs_args_helper(
        rest,
        from_block,
        to_block,
        address,
        new_topics,
        remaining,
      )
    }

    // Any other arguments (like --rpc-url) go to remaining
    _ -> Ok(#(from_block, to_block, address, topics, args))
  }
}

// Parse send command arguments
fn parse_send_args(
  args: List(String),
) -> Result(
  #(String, String, String, String, String, Bool, List(String)),
  rpc_types.GleethError,
) {
  parse_send_args_helper(args, "", "", "", "", "0x", False, [])
}

fn parse_send_args_helper(
  args: List(String),
  to: String,
  value: String,
  private_key: String,
  gas_limit: String,
  data: String,
  legacy: Bool,
  remaining: List(String),
) -> Result(
  #(String, String, String, String, String, Bool, List(String)),
  rpc_types.GleethError,
) {
  case args {
    [] -> {
      case to == "" || private_key == "" {
        True ->
          Error(rpc_types.ConfigError(
            "send requires --to and --private-key flags",
          ))
        False ->
          Ok(#(to, value, private_key, gas_limit, data, legacy, remaining))
      }
    }
    ["--to", addr, ..rest] -> {
      use validated_addr <- result.try(validation.validate_address(addr))
      parse_send_args_helper(
        rest,
        validated_addr,
        value,
        private_key,
        gas_limit,
        data,
        legacy,
        remaining,
      )
    }
    ["--value", val, ..rest] ->
      parse_send_args_helper(
        rest,
        to,
        val,
        private_key,
        gas_limit,
        data,
        legacy,
        remaining,
      )
    ["--private-key", key, ..rest] ->
      parse_send_args_helper(
        rest,
        to,
        value,
        key,
        gas_limit,
        data,
        legacy,
        remaining,
      )
    ["--gas-limit", gl, ..rest] ->
      parse_send_args_helper(
        rest,
        to,
        value,
        private_key,
        gl,
        data,
        legacy,
        remaining,
      )
    ["--data", d, ..rest] ->
      parse_send_args_helper(
        rest,
        to,
        value,
        private_key,
        gas_limit,
        d,
        legacy,
        remaining,
      )
    ["--legacy", ..rest] ->
      parse_send_args_helper(
        rest,
        to,
        value,
        private_key,
        gas_limit,
        data,
        True,
        remaining,
      )
    _ -> Ok(#(to, value, private_key, gas_limit, data, legacy, args))
  }
}

// Display help message
pub fn show_help() -> Nil {
  io.println("gleeth - Ethereum blockchain query tool")
  io.println("")
  io.println("USAGE:")
  io.println("  gleeth <COMMAND> [OPTIONS]")
  io.println("")
  io.println("COMMANDS:")
  io.println("  block-number                    Get latest block number")
  io.println(
    "  balance <address> [address2...]  Get balance of one or more addresses",
  )
  io.println(
    "  balance --file <filename>        Get balances from file (one address per line)",
  )
  io.println(
    "  call <contract> <function> [params...]  Call a contract function",
  )
  io.println("  transaction <hash>              Get transaction details")
  io.println(
    "  code <address>                  Get contract bytecode at address",
  )
  io.println("  estimate-gas [OPTIONS]          Estimate gas for a transaction")
  io.println(
    "  storage-at --address <addr> --slot <slot> [OPTIONS]  Get storage value at slot",
  )
  io.println("  get-logs [OPTIONS]              Get event logs with filtering")
  io.println(
    "  send [OPTIONS]                  Sign and broadcast a transaction",
  )
  io.println("  help                           Show this help message")
  io.println("")
  io.println("OPTIONS:")
  io.println("  --rpc-url <URL>                RPC endpoint URL")
  io.println("")
  io.println("CALL OPTIONS:")
  io.println(
    "  --abi <file>                   JSON ABI file for typed encoding/decoding",
  )
  io.println("")
  io.println("ESTIMATE-GAS OPTIONS:")
  io.println("  --from <address>               Sender address (optional)")
  io.println("  --to <address>                 Recipient address (optional)")
  io.println("  --value <wei>                  Wei amount to send (optional)")
  io.println("  --data <hex>                   Transaction data (optional)")
  io.println("")
  io.println("STORAGE-AT OPTIONS:")
  io.println("  --address <address>            Contract address (required)")
  io.println(
    "  --slot <hex>                   Storage slot position (required)",
  )
  io.println(
    "  --block <number|hash|latest>   Block to query (optional, defaults to 'latest')",
  )
  io.println("")
  io.println("GET-LOGS OPTIONS:")
  io.println(
    "  --from-block <number|hash>     Starting block (optional, defaults to 'latest')",
  )
  io.println(
    "  --to-block <number|hash>       Ending block (optional, defaults to 'latest')",
  )
  io.println(
    "  --address <address>            Contract address to filter (optional)",
  )
  io.println(
    "  --topic <hex>                  Topic filter (repeatable for multiple topics)",
  )
  io.println("")
  io.println("ENVIRONMENT VARIABLES:")
  io.println("  GLEETH_RPC_URL                 Default RPC endpoint URL")
  io.println("")
  io.println("EXAMPLES:")
  io.println("  gleeth block-number --rpc-url https://eth.llamarpc.com")
  io.println(
    "  gleeth balance 0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000 --rpc-url https://eth.llamarpc.com",
  )
  io.println(
    "  gleeth balance addr1 addr2 addr3 --rpc-url https://eth.llamarpc.com",
  )
  io.println(
    "  gleeth balance --file addresses.txt --rpc-url https://eth.llamarpc.com",
  )
  io.println(
    "  gleeth call 0xA0b86a33E6Fb7e4f67c5776f8fcB44F56c71d8b8 totalSupply --rpc-url https://eth.llamarpc.com",
  )
  io.println(
    "  gleeth call 0xA0b86a33E6Fb7e4f67c5776f8fcB44F56c71d8b8 balanceOf address:0x742d... --rpc-url https://eth.llamarpc.com",
  )
  io.println(
    "  gleeth send --to 0x7099... --value 0xde0b6b3a7640000 --private-key 0xac09... --rpc-url http://localhost:8545",
  )
  io.println(
    "  gleeth estimate-gas --from 0x742d... --to 0x7a25... --value 0x1000... --rpc-url https://eth.llamarpc.com",
  )
  io.println(
    "  gleeth storage-at --address 0xA0b86a... --slot 0x0 --rpc-url https://eth.llamarpc.com",
  )
  io.println(
    "  gleeth get-logs --address 0xA0b86a... --from-block 0x1000000 --rpc-url https://eth.llamarpc.com",
  )
  io.println("")
  io.println("SEND OPTIONS:")
  io.println("  --to <address>                 Recipient address (required)")
  io.println(
    "  --value <hex>                  Wei amount to send (hex, e.g. 0xde0b6b3a7640000 for 1 ETH)",
  )
  io.println("  --private-key <hex>            Sender's private key (required)")
  io.println(
    "  --gas-limit <hex>              Gas limit (optional, defaults to 21000)",
  )
  io.println("  --data <hex>                   Transaction data (optional)")
  io.println(
    "  --legacy                       Use legacy (Type 0) instead of EIP-1559",
  )
  io.println("")
  io.println("WALLET COMMANDS:")
  io.println("  gleeth wallet create --private-key 0x1234...")
  io.println("  gleeth wallet generate")
  io.println("  gleeth wallet info --private-key 0x1234...")
  io.println(
    "  gleeth wallet sign --private-key 0x1234... --message 'Hello World'",
  )
}
