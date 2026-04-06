/// Multicall3 tests against anvil.
/// Deploys a Counter contract, then uses Multicall3 to batch reads.
import gleam/bit_array
import gleam/list
import gleam/string
import gleeth/crypto/wallet
import gleeth/deploy
import gleeth/ethereum/abi/encode as abi_encode
import gleeth/ethereum/abi/types as abi_types
import gleeth/multicall
import gleeth/provider
import gleeth/rpc/client
import gleeunit/should

const private_key_0 = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

const anvil_url = "http://localhost:8545"

const anvil_chain_id = 31_337

const counter_bytecode = "0x6080604052348015600e575f5ffd5b5061023f8061001c5f395ff3fe608060405234801561000f575f5ffd5b506004361061004a575f3560e01c806306661abd1461004e5780634940e5e21461006c578063a87d942c14610076578063d09de08a14610094575b5f5ffd5b61005661009e565b6040516100639190610118565b60405180910390f35b6100746100a3565b005b61007e6100de565b60405161008b9190610118565b60405180910390f35b61009c6100e6565b005b5f5481565b6040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016100d59061018b565b60405180910390fd5b5f5f54905090565b60015f5f8282546100f791906101d6565b92505081905550565b5f819050919050565b61011281610100565b82525050565b5f60208201905061012b5f830184610109565b92915050565b5f82825260208201905092915050565b7f616c77617973206661696c7300000000000000000000000000000000000000005f82015250565b5f610175600c83610131565b915061018082610141565b602082019050919050565b5f6020820190508181035f8301526101a281610169565b9050919050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b5f6101e082610100565b91506101eb83610100565b9250828201905080821115610203576102026101a9565b5b9291505056fea2646970667358221220e18be73e90078f4886a349bc2dd104c24c9e81430ac0dd3dd4268a44346d436464736f6c63430008210033"

// getCount() selector
const get_count_selector = "0xa87d942c"

@external(erlang, "test_ffi", "run_command")
fn run_command(command: String) -> String

fn anvil_available() -> Bool {
  case client.make_request(anvil_url, "eth_chainId", []) {
    Ok(_) -> True
    Error(_) -> False
  }
}

fn setup_multicall3() -> Nil {
  // Fetch Multicall3 runtime bytecode from mainnet and set it on anvil
  let bytecode =
    run_command(
      "cast code 0xcA11bde05977b3631167028862bE2a173976CA11 --rpc-url https://eth.llamarpc.com 2>/dev/null",
    )
  let trimmed = string.trim(bytecode)
  case string.length(trimmed) > 10 {
    True -> {
      run_command(
        "cast rpc anvil_setCode 0xcA11bde05977b3631167028862bE2a173976CA11 \""
        <> trimmed
        <> "\" --rpc-url "
        <> anvil_url
        <> " 2>/dev/null",
      )
      Nil
    }
    False -> Nil
  }
}

fn deploy_counter() -> Result(String, Nil) {
  let assert Ok(p) = provider.new(anvil_url)
  let assert Ok(w) = wallet.from_private_key_hex(private_key_0)
  case deploy.deploy(p, w, counter_bytecode, "0x200000", anvil_chain_id) {
    Ok(addr) -> Ok(addr)
    Error(_) -> Error(Nil)
  }
}

fn encode_calldata(
  name: String,
  params: List(#(abi_types.AbiType, abi_types.AbiValue)),
) -> String {
  let assert Ok(bytes) = abi_encode.encode_call(name, params)
  "0x" <> string.lowercase(bit_array.base16_encode(bytes))
}

// =============================================================================
// Batch reads
// =============================================================================

pub fn multicall_batch_reads_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      setup_multicall3()
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(counter_addr) = deploy_counter()

      // Batch 3 getCount() calls on the same contract
      let assert Ok(results) =
        multicall.new()
        |> multicall.add(counter_addr, get_count_selector)
        |> multicall.add(counter_addr, get_count_selector)
        |> multicall.add(counter_addr, get_count_selector)
        |> multicall.execute(p)

      list.length(results) |> should.equal(3)

      // All should succeed with value 0
      list.each(results, fn(r) {
        case r {
          multicall.CallSuccess(data) ->
            string.starts_with(data, "0x") |> should.be_true
          multicall.CallFailure(_) -> should.fail()
        }
      })
    }
  }
}

// =============================================================================
// Mixed success and failure with try_add
// =============================================================================

pub fn multicall_try_add_handles_failure_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      setup_multicall3()
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(counter_addr) = deploy_counter()

      // failAlways() selector = 0x4940e5e2
      let assert Ok(results) =
        multicall.new()
        |> multicall.add(counter_addr, get_count_selector)
        |> multicall.try_add(counter_addr, "0x4940e5e2")
        |> multicall.add(counter_addr, get_count_selector)
        |> multicall.execute(p)

      list.length(results) |> should.equal(3)

      // First and third should succeed, second should fail
      case results {
        [
          multicall.CallSuccess(_),
          multicall.CallFailure(_),
          multicall.CallSuccess(_),
        ] -> Nil
        _ -> should.fail()
      }
    }
  }
}

// =============================================================================
// Empty batch
// =============================================================================

pub fn multicall_empty_batch_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(results) = multicall.new() |> multicall.execute(p)
      results |> should.equal([])
    }
  }
}

// =============================================================================
// Multiple contracts
// =============================================================================

pub fn multicall_multiple_contracts_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      setup_multicall3()
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(counter1) = deploy_counter()
      let assert Ok(counter2) = deploy_counter()

      let assert Ok(results) =
        multicall.new()
        |> multicall.add(counter1, get_count_selector)
        |> multicall.add(counter2, get_count_selector)
        |> multicall.execute(p)

      list.length(results) |> should.equal(2)
      case results {
        [multicall.CallSuccess(_), multicall.CallSuccess(_)] -> Nil
        _ -> should.fail()
      }
    }
  }
}
