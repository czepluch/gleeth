//// Query and decode contract events in a single call.
////
//// Combines `methods.get_logs` with ABI event decoding so you don't have
//// to manually match topic hashes and decode parameters.
////
//// ## Examples
////
//// ```gleam
//// let assert Ok(abi) = json.parse_abi(erc20_abi_json)
//// let assert Ok(decoded) = events.get_events(
////   provider,
////   "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
////   abi,
////   "0x100000",
////   "latest",
//// )
//// // decoded: List(EventResult) - each with event name and typed params
//// ```

import gleeth/ethereum/abi/events as abi_events
import gleeth/ethereum/abi/json
import gleeth/ethereum/types as eth_types
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types

/// Result of decoding a single event log.
pub type EventResult {
  /// Successfully decoded event with name and typed parameters.
  Decoded(event: abi_events.DecodedLog, log: eth_types.Log)
  /// Log could not be matched to any event in the ABI.
  Unknown(log: eth_types.Log)
}

/// Query logs for a contract and decode them against the provided ABI.
/// Logs that match an event in the ABI are decoded; unmatched logs are
/// returned as `Unknown` so no data is lost.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(events) = events.get_events(
///   provider, "0xA0b8...", abi, "0x100000", "latest",
/// )
/// ```
pub fn get_events(
  provider: Provider,
  address: String,
  abi: List(json.AbiEntry),
  from_block: String,
  to_block: String,
) -> Result(List(EventResult), rpc_types.GleethError) {
  use logs <- result.try(
    methods.get_logs(provider, from_block, to_block, address, []),
  )
  Ok(decode_logs(logs, abi))
}

/// Query logs for a specific event name. Filters by the event's topic0 hash,
/// so only matching logs are returned from the RPC.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(transfers) = events.get_events_by_name(
///   provider, "0xA0b8...", abi, "Transfer", "0x100000", "latest",
/// )
/// ```
pub fn get_events_by_name(
  provider: Provider,
  address: String,
  abi: List(json.AbiEntry),
  event_name: String,
  from_block: String,
  to_block: String,
) -> Result(List(EventResult), rpc_types.GleethError) {
  let topic0 = compute_event_topic(abi, event_name)
  let topics = case topic0 {
    "" -> []
    t -> [t]
  }
  use logs <- result.try(methods.get_logs(
    provider,
    from_block,
    to_block,
    address,
    topics,
  ))
  Ok(decode_logs(logs, abi))
}

/// Decode a list of raw logs against an ABI. Useful when you already
/// have logs from another source (e.g. a transaction receipt).
///
/// ## Examples
///
/// ```gleam
/// let results = events.decode_logs(receipt.logs, abi)
/// ```
pub fn decode_logs(
  logs: List(eth_types.Log),
  abi: List(json.AbiEntry),
) -> List(EventResult) {
  list.map(logs, fn(log) {
    case abi_events.decode_log(log, abi) {
      Ok(decoded) -> Decoded(event: decoded, log: log)
      Error(_) -> Unknown(log: log)
    }
  })
}

// =============================================================================
// Internal
// =============================================================================

import gleam/list
import gleam/result

fn compute_event_topic(abi: List(json.AbiEntry), event_name: String) -> String {
  let found =
    list.find(abi, fn(entry) {
      case entry {
        json.EventEntry(name, _) -> name == event_name
        _ -> False
      }
    })
  case found {
    Ok(json.EventEntry(name, inputs)) -> {
      let types = list.map(inputs, fn(p: json.EventParam) { p.type_ })
      abi_events.event_topic_hex(name, types)
    }
    _ -> ""
  }
}
