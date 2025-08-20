import gleam/option.{None}
import gleeth/cli
import gleeth/rpc/types
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

/// Test parsing help command
pub fn parse_help_test() {
  let result = cli.parse_args(["help"])

  case result {
    Ok(args) -> {
      case args.command {
        cli.Help -> Nil
        _ -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

/// Test parsing block-number command
pub fn parse_block_number_test() {
  let result =
    cli.parse_args(["block-number", "--rpc-url", "https://eth.llamarpc.com"])

  case result {
    Ok(args) -> {
      case args.command {
        cli.BlockNumber -> {
          should.equal(args.rpc_url, "https://eth.llamarpc.com")
        }
        _ -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

/// Test parsing balance command
pub fn parse_balance_test() {
  let result =
    cli.parse_args([
      "balance", "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000", "--rpc-url",
      "https://eth.llamarpc.com",
    ])

  case result {
    Ok(args) -> {
      case args.command {
        cli.Balance(addresses, file) -> {
          should.equal(addresses, ["0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000"])
          should.equal(file, None)
        }
        _ -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

/// Test error handling
pub fn parse_missing_rpc_url_test() {
  let result = cli.parse_args(["block-number"])

  case result {
    Error(types.ConfigError(_)) -> Nil
    _ -> should.fail()
  }
}
