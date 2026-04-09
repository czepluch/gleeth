//// Block watcher using a BEAM actor (OTP gen_server).
////
//// Spawns a supervised actor process that polls for new blocks and sends
//// events to a caller-owned Subject. Uses the OTP actor pattern for proper
//// lifecycle management and graceful shutdown.
////
//// ## Examples
////
//// ```gleam
//// let assert Ok(w) = watcher.start(provider)
////
//// // Block until a new block arrives (or timeout after 30s)
//// case watcher.receive(w, 30_000) {
////   Ok(watcher.NewBlock(number, hash)) -> io.println("Block: " <> number)
////   Error(Nil) -> io.println("Timeout")
//// }
////
//// watcher.stop(w)
//// ```

import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/utils/hex

/// A block event emitted by the watcher.
pub type BlockEvent {
  /// A new block was detected.
  NewBlock(number: String, hash: String)
}

/// Configuration for the watcher.
pub type WatcherConfig {
  WatcherConfig(
    /// How often to poll in milliseconds. Default: 2000.
    poll_interval_ms: Int,
  )
}

/// Default config: poll every 2 seconds.
pub fn default_config() -> WatcherConfig {
  WatcherConfig(poll_interval_ms: 2000)
}

/// An opaque handle to a running block watcher.
pub opaque type Watcher {
  Watcher(events: Subject(BlockEvent), actor: Subject(WatcherMessage))
}

// Internal messages
type WatcherMessage {
  Init(self: Subject(WatcherMessage))
  Poll
  Stop
}

// Actor state
type WatcherState {
  WatcherState(
    provider: Provider,
    events: Subject(BlockEvent),
    self: Subject(WatcherMessage),
    config: WatcherConfig,
    last_block: String,
  )
}

/// Start watching for new blocks with default config (poll every 2s).
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(w) = watcher.start(provider)
/// ```
pub fn start(provider: Provider) -> Result(Watcher, String) {
  start_with_config(provider, default_config())
}

/// Start watching with custom configuration.
///
/// ## Examples
///
/// ```gleam
/// let config = watcher.WatcherConfig(poll_interval_ms: 500)
/// let assert Ok(w) = watcher.start_with_config(provider, config)
/// ```
pub fn start_with_config(
  provider: Provider,
  config: WatcherConfig,
) -> Result(Watcher, String) {
  start_with_subject(provider, config, process.new_subject())
}

/// Start watching, sending events to a caller-provided Subject.
/// Use this when another process needs to own the receiving Subject
/// (e.g. the event watcher actor).
pub fn start_with_subject(
  provider: Provider,
  config: WatcherConfig,
  events: Subject(BlockEvent),
) -> Result(Watcher, String) {
  case methods.get_block_number(provider) {
    Ok(initial_block) -> {
      let state =
        WatcherState(
          provider: provider,
          events: events,
          self: process.new_subject(),
          config: config,
          last_block: initial_block,
        )

      case
        actor.new(state)
        |> actor.on_message(handle_message)
        |> actor.start
      {
        Ok(started) -> {
          let actor_subject = started.data
          // Tell the actor its own subject so it can schedule future polls
          process.send(actor_subject, Init(actor_subject))
          Ok(Watcher(events: events, actor: actor_subject))
        }
        Error(_) -> Error("Failed to start watcher actor")
      }
    }
    Error(_) -> Error("Failed to fetch initial block number")
  }
}

/// Receive the next block event, blocking up to `timeout_ms` milliseconds.
/// Returns `Error(Nil)` on timeout.
///
/// ## Examples
///
/// ```gleam
/// case watcher.receive(w, 10_000) {
///   Ok(watcher.NewBlock(number, hash)) -> // new block
///   Error(Nil) -> // timeout
/// }
/// ```
pub fn receive(watcher: Watcher, timeout_ms: Int) -> Result(BlockEvent, Nil) {
  process.receive(watcher.events, timeout_ms)
}

/// Stop the watcher gracefully. The actor process exits cleanly.
///
/// ## Examples
///
/// ```gleam
/// watcher.stop(w)
/// ```
pub fn stop(watcher: Watcher) -> Nil {
  process.send(watcher.actor, Stop)
}

// =============================================================================
// Actor message handler
// =============================================================================

fn handle_message(
  state: WatcherState,
  message: WatcherMessage,
) -> actor.Next(WatcherState, WatcherMessage) {
  case message {
    Stop -> actor.stop()

    Init(self) -> {
      let new_state = WatcherState(..state, self: self)
      // Schedule the first poll
      process.send_after(self, new_state.config.poll_interval_ms, Poll)
      actor.continue(new_state)
    }

    Poll -> {
      let new_state = case methods.get_block_number(state.provider) {
        Ok(current_block) -> {
          case is_newer(current_block, state.last_block) {
            True -> {
              emit_new_blocks(
                state.provider,
                state.events,
                state.last_block,
                current_block,
              )
              WatcherState(..state, last_block: current_block)
            }
            False -> state
          }
        }
        Error(_) -> state
      }

      // Schedule next poll
      process.send_after(
        new_state.self,
        new_state.config.poll_interval_ms,
        Poll,
      )
      actor.continue(new_state)
    }
  }
}

// =============================================================================
// Block emission helpers
// =============================================================================

fn emit_new_blocks(
  provider: Provider,
  events: Subject(BlockEvent),
  last_block: String,
  current_block: String,
) -> Nil {
  let assert Ok(last_num) = hex.to_int(last_block)
  let assert Ok(current_num) = hex.to_int(current_block)
  emit_blocks_range(provider, events, last_num + 1, current_num)
}

fn emit_blocks_range(
  provider: Provider,
  events: Subject(BlockEvent),
  from: Int,
  to: Int,
) -> Nil {
  case from > to {
    True -> Nil
    False -> {
      let block_hex = hex.from_int(from)
      let hash = case methods.get_block_by_number(provider, block_hex) {
        Ok(block) -> block.hash
        Error(_) -> ""
      }
      process.send(events, NewBlock(number: block_hex, hash: hash))
      emit_blocks_range(provider, events, from + 1, to)
    }
  }
}

fn is_newer(current: String, last: String) -> Bool {
  case hex.to_int(current), hex.to_int(last) {
    Ok(c), Ok(l) -> c > l
    _, _ -> False
  }
}
