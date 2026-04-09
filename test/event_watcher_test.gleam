/// Event watcher tests against anvil.
/// Deploys a Counter contract, sends transactions, and verifies
/// events are received in real-time.
import gleam/bit_array
import gleam/string
import gleeth/contract
import gleeth/crypto/wallet
import gleeth/deploy
import gleeth/ethereum/abi/json
import gleeth/ethereum/abi/types as abi_types
import gleeth/event_watcher
import gleeth/provider
import gleeth/rpc/client
import gleeunit/should

const private_key_0 = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

const anvil_url = "http://localhost:8545"

const anvil_chain_id = 31_337

@external(erlang, "test_ffi", "run_command")
fn run_command(command: String) -> String

fn anvil_available() -> Bool {
  case client.make_request(anvil_url, "eth_chainId", []) {
    Ok(_) -> True
    Error(_) -> False
  }
}

fn mine_block() -> Nil {
  run_command("cast rpc anvil_mine 1 --rpc-url " <> anvil_url <> " 2>/dev/null")
  Nil
}

// TestToken bytecode getter
fn get_token_bytecode() -> String {
  let output =
    run_command(
      "python3 -c \"import json; d=json.load(open('/tmp/gleeth-test-contracts/out/TestToken.sol/TestToken.json')); print(d['bytecode']['object'])\" 2>/dev/null || echo MISSING",
    )
  string.trim(output)
}

const erc20_abi = "[{\"type\":\"function\",\"name\":\"transfer\",\"inputs\":[{\"name\":\"to\",\"type\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"balanceOf\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"Transfer\",\"inputs\":[{\"name\":\"from\",\"type\":\"address\",\"indexed\":true},{\"name\":\"to\",\"type\":\"address\",\"indexed\":true},{\"name\":\"value\",\"type\":\"uint256\",\"indexed\":false}]},{\"type\":\"event\",\"name\":\"Approval\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"indexed\":true},{\"name\":\"spender\",\"type\":\"address\",\"indexed\":true},{\"name\":\"value\",\"type\":\"uint256\",\"indexed\":false}]}]"

// =============================================================================
// Receive a Transfer event
// =============================================================================

pub fn event_watcher_receives_transfer_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let token_bytecode = get_token_bytecode()
      case string.length(token_bytecode) > 100 {
        False -> Nil
        True -> {
          let assert Ok(p) = provider.new(anvil_url)
          let assert Ok(w) = wallet.from_private_key_hex(private_key_0)
          let assert Ok(abi) = json.parse_abi(erc20_abi)

          // Deploy token with initial supply
          let assert Ok(token_address) =
            deploy.deploy_with_args(
              p,
              w,
              token_bytecode,
              [#(abi_types.Uint(256), abi_types.UintValue(1_000_000))],
              "0x500000",
              anvil_chain_id,
            )

          // Start event watcher
          let assert Ok(ew) =
            event_watcher.start_with_config(
              p,
              token_address,
              abi,
              event_watcher.EventWatcherConfig(
                poll_interval_ms: 200,
                event_name: "",
              ),
            )

          // Send a transfer
          let c = contract.at(p, token_address, abi)
          let assert Ok(_) =
            contract.send_raw(
              c,
              w,
              "transfer",
              [
                "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
                "1000",
              ],
              "0x100000",
              anvil_chain_id,
            )

          // Mine a block to ensure the watcher sees it
          mine_block()

          // Should receive a Transfer event
          case event_watcher.receive(ew, 5000) {
            Ok(event) -> {
              event.name |> should.equal("Transfer")
            }
            Error(_) -> should.fail()
          }

          event_watcher.stop(ew)
        }
      }
    }
  }
}

// =============================================================================
// Filter by event name
// =============================================================================

pub fn event_watcher_filter_by_name_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let token_bytecode = get_token_bytecode()
      case string.length(token_bytecode) > 100 {
        False -> Nil
        True -> {
          let assert Ok(p) = provider.new(anvil_url)
          let assert Ok(w) = wallet.from_private_key_hex(private_key_0)
          let assert Ok(abi) = json.parse_abi(erc20_abi)

          let assert Ok(token_address) =
            deploy.deploy_with_args(
              p,
              w,
              token_bytecode,
              [#(abi_types.Uint(256), abi_types.UintValue(1_000_000))],
              "0x500000",
              anvil_chain_id,
            )

          // Watch only Transfer events
          let assert Ok(ew) =
            event_watcher.start_for_event(p, token_address, abi, "Transfer")

          let c = contract.at(p, token_address, abi)
          let assert Ok(_) =
            contract.send_raw(
              c,
              w,
              "transfer",
              [
                "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
                "500",
              ],
              "0x100000",
              anvil_chain_id,
            )

          mine_block()

          case event_watcher.receive(ew, 5000) {
            Ok(event) -> event.name |> should.equal("Transfer")
            Error(_) -> should.fail()
          }

          event_watcher.stop(ew)
        }
      }
    }
  }
}

// =============================================================================
// Stop cleans up
// =============================================================================

pub fn event_watcher_stop_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(abi) = json.parse_abi(erc20_abi)

      let assert Ok(ew) =
        event_watcher.start_with_config(
          p,
          "0x0000000000000000000000000000000000000000",
          abi,
          event_watcher.EventWatcherConfig(
            poll_interval_ms: 200,
            event_name: "",
          ),
        )

      // Stop should not hang
      event_watcher.stop(ew)
    }
  }
}
