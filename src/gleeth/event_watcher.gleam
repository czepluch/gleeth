//// Real-time contract event streaming.
////
//// Combines the block watcher with ABI event decoding to deliver typed
//// contract events as they happen. Internally spawns a block watcher,
//// queries logs for each new block, decodes them, and forwards matches
//// to the caller.
////
//// ## Examples
////
//// ```gleam
//// let assert Ok(abi) = json.parse_abi(erc20_abi_json)
//// let assert Ok(ew) = event_watcher.start(provider, usdc_address, abi)
////
//// // Receive decoded events as they arrive
//// case event_watcher.receive(ew, 30_000) {
////   Ok(event) -> // event.name, event.params, event.log
////   Error(Nil) -> // timeout
//// }
////
//// event_watcher.stop(ew)
//// ```

import gleam/erlang/process.{type Pid, type Subject}
import gleeth/ethereum/abi/json
import gleeth/ethereum/abi/types as abi_types
import gleeth/ethereum/types as eth_types
import gleeth/events
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/watcher

/// A decoded contract event with the original log attached.
pub type ContractEvent {
  ContractEvent(
    /// The event name from the ABI (e.g. "Transfer").
    name: String,
    /// Decoded parameters as name-value pairs.
    params: List(#(String, abi_types.AbiValue)),
    /// The raw log this event was decoded from.
    log: eth_types.Log,
  )
}

/// Configuration for the event watcher.
pub type EventWatcherConfig {
  EventWatcherConfig(
    /// How often to poll for new blocks in milliseconds. Default: 2000.
    poll_interval_ms: Int,
    /// Optional event name filter. Empty string means all events.
    event_name: String,
  )
}

/// Default config: poll every 2s, no event name filter.
pub fn default_config() -> EventWatcherConfig {
  EventWatcherConfig(poll_interval_ms: 2000, event_name: "")
}

/// An opaque handle to a running event watcher.
pub opaque type EventWatcher {
  EventWatcher(
    events: Subject(ContractEvent),
    pid: Pid,
    block_watcher: watcher.Watcher,
  )
}

/// Start watching for all contract events with default config.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(ew) = event_watcher.start(provider, "0xA0b8...", abi)
/// ```
pub fn start(
  provider: Provider,
  address: String,
  abi: List(json.AbiEntry),
) -> Result(EventWatcher, String) {
  start_with_config(provider, address, abi, default_config())
}

/// Start watching for a specific event by name.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(ew) = event_watcher.start_for_event(
///   provider, "0xA0b8...", abi, "Transfer",
/// )
/// ```
pub fn start_for_event(
  provider: Provider,
  address: String,
  abi: List(json.AbiEntry),
  event_name: String,
) -> Result(EventWatcher, String) {
  start_with_config(
    provider,
    address,
    abi,
    EventWatcherConfig(poll_interval_ms: 2000, event_name: event_name),
  )
}

/// Start watching with custom configuration.
pub fn start_with_config(
  provider: Provider,
  address: String,
  abi: List(json.AbiEntry),
  config: EventWatcherConfig,
) -> Result(EventWatcher, String) {
  let event_subject = process.new_subject()
  let watcher_config =
    watcher.WatcherConfig(poll_interval_ms: config.poll_interval_ms)

  // We need to start the block watcher from inside the spawned process
  // so that the block events Subject is owned by that process.
  // Use a startup Subject to pass the result back.
  let startup: Subject(Result(EventWatcher, String)) = process.new_subject()

  let _pid =
    process.spawn_unlinked(fn() {
      // Create block events Subject here - this process owns it
      let block_events: Subject(watcher.BlockEvent) = process.new_subject()

      case watcher.start_with_subject(provider, watcher_config, block_events) {
        Ok(block_watcher) -> {
          let ew =
            EventWatcher(
              events: event_subject,
              pid: process.self(),
              block_watcher: block_watcher,
            )
          process.send(startup, Ok(ew))
          event_loop(
            provider,
            address,
            abi,
            config.event_name,
            block_events,
            event_subject,
          )
        }
        Error(msg) -> {
          process.send(startup, Error("Failed to start block watcher: " <> msg))
        }
      }
    })

  // Wait for the spawned process to report back
  case process.receive(startup, 5000) {
    Ok(result) -> result
    Error(_) -> Error("Event watcher startup timed out")
  }
}

/// Receive the next decoded event, blocking up to `timeout_ms` milliseconds.
///
/// ## Examples
///
/// ```gleam
/// case event_watcher.receive(ew, 10_000) {
///   Ok(event) -> // event.name, event.params
///   Error(Nil) -> // timeout
/// }
/// ```
pub fn receive(ew: EventWatcher, timeout_ms: Int) -> Result(ContractEvent, Nil) {
  process.receive(ew.events, timeout_ms)
}

/// Stop the event watcher and its underlying block watcher.
pub fn stop(ew: EventWatcher) -> Nil {
  watcher.stop(ew.block_watcher)
  process.kill(ew.pid)
}

// =============================================================================
// Internal event loop
// =============================================================================

fn event_loop(
  provider: Provider,
  address: String,
  abi: List(json.AbiEntry),
  event_name: String,
  block_events: Subject(watcher.BlockEvent),
  event_subject: Subject(ContractEvent),
) -> Nil {
  // Wait for a new block (long timeout - blocks come every ~12s on mainnet)
  case process.receive(block_events, 60_000) {
    Ok(watcher.NewBlock(block_number, _hash)) -> {
      // Query events for this block
      let log_result = case event_name {
        "" ->
          methods.get_logs(provider, block_number, block_number, address, [])
        _ -> {
          let topic0 = events.compute_event_topic(abi, event_name)
          let topics = case topic0 {
            "" -> []
            t -> [t]
          }
          methods.get_logs(
            provider,
            block_number,
            block_number,
            address,
            topics,
          )
        }
      }

      case log_result {
        Ok(logs) -> {
          // Decode and forward each event
          let decoded = events.decode_logs(logs, abi)
          forward_events(decoded, event_subject)
        }
        Error(_) -> Nil
      }

      // Continue loop
      event_loop(
        provider,
        address,
        abi,
        event_name,
        block_events,
        event_subject,
      )
    }
    Error(_) -> {
      // Timeout - keep going
      event_loop(
        provider,
        address,
        abi,
        event_name,
        block_events,
        event_subject,
      )
    }
  }
}

fn forward_events(
  results: List(events.EventResult),
  subject: Subject(ContractEvent),
) -> Nil {
  case results {
    [] -> Nil
    [result, ..rest] -> {
      case result {
        events.Decoded(event, log) ->
          process.send(
            subject,
            ContractEvent(
              name: event.event_name,
              params: event.params,
              log: log,
            ),
          )
        events.Unknown(_) -> Nil
      }
      forward_events(rest, subject)
    }
  }
}
