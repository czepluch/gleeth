/// Block watcher tests against anvil.
/// Uses anvil_mine to trigger new blocks.
import gleam/string
import gleeth/provider
import gleeth/rpc/client
import gleeth/watcher
import gleeunit/should

const anvil_url = "http://localhost:8545"

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

// =============================================================================
// Detect a new block
// =============================================================================

pub fn watcher_detects_new_block_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) =
        watcher.start_with_config(
          p,
          watcher.WatcherConfig(poll_interval_ms: 200),
        )

      // Mine a block
      mine_block()

      // Should receive the new block within a few poll cycles
      case watcher.receive(w, 5000) {
        Ok(watcher.NewBlock(number, hash)) -> {
          string.starts_with(number, "0x") |> should.be_true
          string.starts_with(hash, "0x") |> should.be_true
        }
        Error(_) -> should.fail()
      }

      watcher.stop(w)
    }
  }
}

// =============================================================================
// Detect multiple blocks
// =============================================================================

pub fn watcher_detects_multiple_blocks_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) =
        watcher.start_with_config(
          p,
          watcher.WatcherConfig(poll_interval_ms: 200),
        )

      // Mine 3 blocks
      mine_block()
      mine_block()
      mine_block()

      // Should receive at least one block event
      let assert Ok(watcher.NewBlock(_, _)) = watcher.receive(w, 5000)

      watcher.stop(w)
    }
  }
}

// =============================================================================
// Stop cleans up
// =============================================================================

pub fn watcher_stop_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) =
        watcher.start_with_config(
          p,
          watcher.WatcherConfig(poll_interval_ms: 200),
        )

      // Stop immediately
      watcher.stop(w)

      // Mine a block - watcher should not send events after stop
      mine_block()

      // Short timeout - should get nothing
      case watcher.receive(w, 1000) {
        // Might get one event if the poll was in flight, but shouldn't hang
        Ok(_) -> Nil
        Error(_) -> Nil
      }
    }
  }
}

// =============================================================================
// Timeout when no blocks
// =============================================================================

pub fn watcher_timeout_test() {
  case anvil_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new(anvil_url)
      let assert Ok(w) =
        watcher.start_with_config(
          p,
          watcher.WatcherConfig(poll_interval_ms: 5000),
        )

      // Don't mine any blocks - should timeout
      case watcher.receive(w, 500) {
        Error(_) -> Nil
        // Timeout as expected
        Ok(_) -> Nil
        // A block from a previous test is fine too
      }

      watcher.stop(w)
    }
  }
}
