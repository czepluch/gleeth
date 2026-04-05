/// Batch JSON-RPC tests against anvil.
/// Requires anvil running on localhost:8545.
import gleam/json
import gleam/list
import gleam/string
import gleeth/provider
import gleeth/rpc/batch
import gleeth/rpc/client
import gleeth/rpc/types as rpc_types
import gleeunit/should

const anvil_url = "http://localhost:8545"

fn anvil_available() -> Bool {
  case client.make_request(anvil_url, "eth_chainId", []) {
    Ok(_) -> True
    Error(_) -> False
  }
}

// =============================================================================
// Basic batch execution
// =============================================================================

pub fn batch_two_string_requests_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)

      let assert Ok(results) =
        batch.new()
        |> batch.add("eth_blockNumber", [])
        |> batch.add("eth_chainId", [])
        |> batch.execute_strings(p)

      // Should have 2 results
      list.length(results) |> should.equal(2)

      // Both should be Ok with hex strings
      case results {
        [Ok(block_number), Ok(chain_id)] -> {
          string.starts_with(block_number, "0x") |> should.be_true
          chain_id |> should.equal("0x7a69")
        }
        _ -> should.fail()
      }
    }
  }
}

pub fn batch_three_requests_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)

      let assert Ok(results) =
        batch.new()
        |> batch.add("eth_blockNumber", [])
        |> batch.add("eth_gasPrice", [])
        |> batch.add("eth_getBalance", [
          json.string("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"),
          json.string("latest"),
        ])
        |> batch.execute_strings(p)

      list.length(results) |> should.equal(3)

      // All should be Ok
      list.each(results, fn(r) {
        case r {
          Ok(val) -> string.starts_with(val, "0x") |> should.be_true
          Error(_) -> should.fail()
        }
      })
    }
  }
}

// =============================================================================
// Order preservation
// =============================================================================

pub fn batch_preserves_order_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)

      // Chain ID should always be 0x7a69 on anvil
      let assert Ok(results) =
        batch.new()
        |> batch.add("eth_chainId", [])
        |> batch.add("eth_blockNumber", [])
        |> batch.add("eth_chainId", [])
        |> batch.execute_strings(p)

      case results {
        [Ok(first), Ok(_), Ok(third)] -> {
          // First and third are both chain ID calls - should match
          first |> should.equal("0x7a69")
          third |> should.equal("0x7a69")
        }
        _ -> should.fail()
      }
    }
  }
}

// =============================================================================
// Error handling
// =============================================================================

pub fn batch_with_error_doesnt_break_batch_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)

      // Mix a valid request with an invalid one
      let assert Ok(results) =
        batch.new()
        |> batch.add("eth_chainId", [])
        |> batch.add("eth_getBalance", [
          json.string("not_an_address"),
          json.string("latest"),
        ])
        |> batch.add("eth_blockNumber", [])
        |> batch.execute_strings(p)

      list.length(results) |> should.equal(3)

      // First and third should succeed
      case results {
        [Ok(chain_id), _, Ok(block_number)] -> {
          chain_id |> should.equal("0x7a69")
          string.starts_with(block_number, "0x") |> should.be_true
        }
        _ -> should.fail()
      }
    }
  }
}

// =============================================================================
// Empty batch
// =============================================================================

pub fn batch_empty_returns_empty_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(results) = batch.new() |> batch.execute_strings(p)
      results |> should.equal([])
    }
  }
}

// =============================================================================
// add_method convenience
// =============================================================================

pub fn batch_add_method_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)

      let assert Ok(results) =
        batch.new()
        |> batch.add_method(rpc_types.EthBlockNumber, [])
        |> batch.add_method(rpc_types.EthChainId, [])
        |> batch.execute_strings(p)

      list.length(results) |> should.equal(2)
      case results {
        [Ok(_), Ok(chain_id)] -> chain_id |> should.equal("0x7a69")
        _ -> should.fail()
      }
    }
  }
}
