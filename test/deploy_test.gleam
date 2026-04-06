/// Contract deployment tests against anvil.
import gleam/string
import gleeth/crypto/wallet
import gleeth/deploy
import gleeth/ethereum/abi/types as abi_types
import gleeth/provider
import gleeth/rpc/client
import gleeth/rpc/methods
import gleeunit/should

const private_key_0 = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

const anvil_url = "http://localhost:8545"

const anvil_chain_id = 31_337

// Counter contract bytecode (no constructor args)
const counter_bytecode = "0x6080604052348015600e575f5ffd5b5061023f8061001c5f395ff3fe608060405234801561000f575f5ffd5b506004361061004a575f3560e01c806306661abd1461004e5780634940e5e21461006c578063a87d942c14610076578063d09de08a14610094575b5f5ffd5b61005661009e565b6040516100639190610118565b60405180910390f35b6100746100a3565b005b61007e6100de565b60405161008b9190610118565b60405180910390f35b61009c6100e6565b005b5f5481565b6040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016100d59061018b565b60405180910390fd5b5f5f54905090565b60015f5f8282546100f791906101d6565b92505081905550565b5f819050919050565b61011281610100565b82525050565b5f60208201905061012b5f830184610109565b92915050565b5f82825260208201905092915050565b7f616c77617973206661696c7300000000000000000000000000000000000000005f82015250565b5f610175600c83610131565b915061018082610141565b602082019050919050565b5f6020820190508181035f8301526101a281610169565b9050919050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b5f6101e082610100565b91506101eb83610100565b9250828201905080821115610203576102026101a9565b5b9291505056fea2646970667358221220e18be73e90078f4886a349bc2dd104c24c9e81430ac0dd3dd4268a44346d436464736f6c63430008210033"

fn anvil_available() -> Bool {
  case client.make_request(anvil_url, "eth_chainId", []) {
    Ok(_) -> True
    Error(_) -> False
  }
}

// =============================================================================
// Deploy with no constructor args
// =============================================================================

pub fn deploy_counter_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) = wallet.from_private_key_hex(private_key_0)

      let assert Ok(address) =
        deploy.deploy(p, w, counter_bytecode, "0x200000", anvil_chain_id)

      // Should be a valid address
      string.length(address) |> should.equal(42)
      string.starts_with(address, "0x") |> should.be_true
    }
  }
}

// =============================================================================
// Deploy and call a function
// =============================================================================

pub fn deploy_and_call_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) = wallet.from_private_key_hex(private_key_0)

      let assert Ok(address) =
        deploy.deploy(p, w, counter_bytecode, "0x200000", anvil_chain_id)

      // Call getCount() - selector 0xa87d942c
      let assert Ok(result) = methods.call_contract(p, address, "0xa87d942c")
      result
      |> should.equal(
        "0x0000000000000000000000000000000000000000000000000000000000000000",
      )
    }
  }
}

// =============================================================================
// Deploy with constructor args
// =============================================================================

pub fn deploy_with_constructor_args_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) = wallet.from_private_key_hex(private_key_0)

      // Deploy TestToken with initial supply of 1000
      // We need the TestToken bytecode - use forge to get it
      let token_bytecode = get_token_bytecode()
      case string.length(token_bytecode) > 100 {
        False -> Nil
        // Skip if bytecode not available
        True -> {
          let assert Ok(address) =
            deploy.deploy_with_args(
              p,
              w,
              token_bytecode,
              [#(abi_types.Uint(256), abi_types.UintValue(1000))],
              "0x500000",
              anvil_chain_id,
            )

          string.length(address) |> should.equal(42)
        }
      }
    }
  }
}

@external(erlang, "test_ffi", "run_command")
fn run_command(command: String) -> String

fn get_token_bytecode() -> String {
  let output =
    run_command(
      "python3 -c \"import json; d=json.load(open('/tmp/gleeth-test-contracts/out/TestToken.sol/TestToken.json')); print(d['bytecode']['object'])\" 2>/dev/null || echo MISSING",
    )
  string.trim(output)
}
