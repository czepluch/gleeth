/// Contract type tests against anvil.
/// Tests read calls, write calls, and error handling.
import gleam/string
import gleeth/contract
import gleeth/crypto/wallet
import gleeth/deploy
import gleeth/ethereum/abi/json
import gleeth/ethereum/abi/types as abi_types
import gleeth/provider
import gleeth/rpc/client
import gleeunit/should

const private_key_0 = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

const anvil_url = "http://localhost:8545"

const anvil_chain_id = 31_337

const counter_bytecode = "0x6080604052348015600e575f5ffd5b5061023f8061001c5f395ff3fe608060405234801561000f575f5ffd5b506004361061004a575f3560e01c806306661abd1461004e5780634940e5e21461006c578063a87d942c14610076578063d09de08a14610094575b5f5ffd5b61005661009e565b6040516100639190610118565b60405180910390f35b6100746100a3565b005b61007e6100de565b60405161008b9190610118565b60405180910390f35b61009c6100e6565b005b5f5481565b6040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016100d59061018b565b60405180910390fd5b5f5f54905090565b60015f5f8282546100f791906101d6565b92505081905550565b5f819050919050565b61011281610100565b82525050565b5f60208201905061012b5f830184610109565b92915050565b5f82825260208201905092915050565b7f616c77617973206661696c7300000000000000000000000000000000000000005f82015250565b5f610175600c83610131565b915061018082610141565b602082019050919050565b5f6020820190508181035f8301526101a281610169565b9050919050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b5f6101e082610100565b91506101eb83610100565b9250828201905080821115610203576102026101a9565b5b9291505056fea2646970667358221220e18be73e90078f4886a349bc2dd104c24c9e81430ac0dd3dd4268a44346d436464736f6c63430008210033"

const counter_abi = "[{\"type\":\"function\",\"name\":\"getCount\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"increment\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"failAlways\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"count\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\"}]"

fn anvil_available() -> Bool {
  case client.make_request(anvil_url, "eth_chainId", []) {
    Ok(_) -> True
    Error(_) -> False
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

// =============================================================================
// Read-only call
// =============================================================================

pub fn contract_call_getcount_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(addr) = deploy_counter()
      let assert Ok(abi) = json.parse_abi(counter_abi)
      let c = contract.at(p, addr, abi)

      let assert Ok(values) = contract.call(c, "getCount", [])
      case values {
        [abi_types.UintValue(n)] -> n |> should.equal(0)
        _ -> should.fail()
      }
    }
  }
}

// =============================================================================
// Write call then read
// =============================================================================

pub fn contract_send_then_call_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) = wallet.from_private_key_hex(private_key_0)
      let assert Ok(addr) = deploy_counter()
      let assert Ok(abi) = json.parse_abi(counter_abi)
      let c = contract.at(p, addr, abi)

      // Increment
      let assert Ok(_tx_hash) =
        contract.send(c, w, "increment", [], "0x100000", anvil_chain_id)

      // Read count - should be 1
      let assert Ok(values) = contract.call(c, "getCount", [])
      case values {
        [abi_types.UintValue(n)] -> n |> should.equal(1)
        _ -> should.fail()
      }
    }
  }
}

// =============================================================================
// Function not found
// =============================================================================

pub fn contract_call_unknown_function_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(addr) = deploy_counter()
      let assert Ok(abi) = json.parse_abi(counter_abi)
      let c = contract.at(p, addr, abi)

      let result = contract.call(c, "doesNotExist", [])
      let _ = result |> should.be_error
      Nil
    }
  }
}

// =============================================================================
// Revert
// =============================================================================

pub fn contract_call_revert_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(addr) = deploy_counter()
      let assert Ok(abi) = json.parse_abi(counter_abi)
      let c = contract.at(p, addr, abi)

      let result = contract.call(c, "failAlways", [])
      let _ = result |> should.be_error
      Nil
    }
  }
}

// =============================================================================
// Multiple calls on same contract instance
// =============================================================================

pub fn contract_multiple_calls_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) = wallet.from_private_key_hex(private_key_0)
      let assert Ok(addr) = deploy_counter()
      let assert Ok(abi) = json.parse_abi(counter_abi)
      let c = contract.at(p, addr, abi)

      // Increment 3 times
      let assert Ok(_) =
        contract.send(c, w, "increment", [], "0x100000", anvil_chain_id)
      let assert Ok(_) =
        contract.send(c, w, "increment", [], "0x100000", anvil_chain_id)
      let assert Ok(_) =
        contract.send(c, w, "increment", [], "0x100000", anvil_chain_id)

      let assert Ok(values) = contract.call(c, "getCount", [])
      case values {
        [abi_types.UintValue(n)] -> n |> should.equal(3)
        _ -> should.fail()
      }
    }
  }
}
