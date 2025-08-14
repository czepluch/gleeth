import gleeunit
import gleeunit/should
import gleam/option.{None, Some}
import gleeth/cli
import gleeth/rpc/types

pub fn main() {
  gleeunit.main()
}

// Test parsing help command
pub fn parse_help_test() {
  let result = cli.parse_args(["help"])
  
  case result {
    Ok(args) -> {
      case args.command {
        cli.Help -> should.be_true(True)
        _ -> should.be_true(False)
      }
    }
    Error(_) -> should.be_true(False)
  }
}

// Test parsing block-number command with RPC URL
pub fn parse_block_number_test() {
  let result = cli.parse_args(["block-number", "--rpc-url", "https://eth.llamarpc.com"])
  
  case result {
    Ok(args) -> {
      case args.command {
        cli.BlockNumber -> {
          should.equal(args.rpc_url, "https://eth.llamarpc.com")
        }
        _ -> should.be_true(False)
      }
    }
    Error(_) -> should.be_true(False)
  }
}

// Test parsing balance command with valid address
pub fn parse_balance_test() {
  let result = cli.parse_args([
    "balance", 
    "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
    "--rpc-url", 
    "https://eth.llamarpc.com"
  ])
  
  case result {
    Ok(args) -> {
      case args.command {
        cli.Balance(addresses, file) -> {
          should.equal(addresses, ["0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000"])
          should.equal(file, None)
          should.equal(args.rpc_url, "https://eth.llamarpc.com")
        }
        _ -> should.be_true(False)
      }
    }
    Error(_) -> should.be_true(False)
  }
}

// Test parsing balance command with address without 0x prefix
pub fn parse_balance_no_prefix_test() {
  let result = cli.parse_args([
    "balance", 
    "742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
    "--rpc-url", 
    "https://eth.llamarpc.com"
  ])
  
  case result {
    Ok(args) -> {
      case args.command {
        cli.Balance(addresses, _file) -> {
          should.equal(addresses, ["0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000"])
        }
        _ -> should.be_true(False)
      }
    }
    Error(_) -> should.be_true(False)
  }
}

// Test parsing command without RPC URL (should fail)
pub fn parse_missing_rpc_url_test() {
  let result = cli.parse_args(["block-number"])
  
  case result {
    Error(types.ConfigError(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

// Test parsing invalid command
pub fn parse_invalid_command_test() {
  let result = cli.parse_args(["invalid-command"])
  
  case result {
    Error(types.ConfigError(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

// Test parsing balance with invalid address
pub fn parse_invalid_address_test() {
  let result = cli.parse_args([
    "balance", 
    "invalid-address",
    "--rpc-url", 
    "https://eth.llamarpc.com"
  ])
  
  case result {
    Error(types.InvalidAddress(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

// Test parsing balance command with multiple addresses
pub fn parse_multiple_balance_test() {
  let result = cli.parse_args([
    "balance", 
    "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
    "0x1111111111111111111111111111111111111111",
    "0x2222222222222222222222222222222222222222",
    "--rpc-url", 
    "https://eth.llamarpc.com"
  ])
  
  case result {
    Ok(args) -> {
      case args.command {
        cli.Balance(addresses, file) -> {
          should.equal(addresses, [
            "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
            "0x1111111111111111111111111111111111111111", 
            "0x2222222222222222222222222222222222222222"
          ])
          should.equal(file, None)
          should.equal(args.rpc_url, "https://eth.llamarpc.com")
        }
        _ -> should.be_true(False)
      }
    }
    Error(_) -> should.be_true(False)
  }
}

// Test parsing balance command with file input
pub fn parse_balance_file_test() {
  let result = cli.parse_args([
    "balance",
    "--file",
    "addresses.txt",
    "--rpc-url",
    "https://eth.llamarpc.com"
  ])
  
  case result {
    Ok(args) -> {
      case args.command {
        cli.Balance(addresses, file) -> {
          should.equal(addresses, [])
          should.equal(file, Some("addresses.txt"))
          should.equal(args.rpc_url, "https://eth.llamarpc.com")
        }
        _ -> should.be_true(False)
      }
    }
    Error(_) -> should.be_true(False)
  }
}

// Test parsing balance command with short file flag
pub fn parse_balance_file_short_test() {
  let result = cli.parse_args([
    "balance",
    "-f",
    "test.txt",
    "--rpc-url",
    "https://eth.llamarpc.com"
  ])
  
  case result {
    Ok(args) -> {
      case args.command {
        cli.Balance(addresses, file) -> {
          should.equal(addresses, [])
          should.equal(file, Some("test.txt"))
        }
        _ -> should.be_true(False)
      }
    }
    Error(_) -> should.be_true(False)
  }
}

// Test parsing balance command with no addresses or file (should fail)
pub fn parse_balance_no_args_test() {
  let result = cli.parse_args([
    "balance",
    "--rpc-url",
    "https://eth.llamarpc.com"
  ])
  
  case result {
    Error(types.ConfigError(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

// Test parsing transaction command
pub fn parse_transaction_test() {
  let result = cli.parse_args([
    "transaction",
    "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
    "--rpc-url",
    "https://eth.llamarpc.com"
  ])
  
  case result {
    Ok(args) -> {
      case args.command {
        cli.Transaction(hash) -> {
          should.equal(hash, "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef")
        }
        _ -> should.be_true(False)
      }
    }
    Error(_) -> should.be_true(False)
  }
}