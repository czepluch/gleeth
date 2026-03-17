import gleam/bit_array
import gleam/list
import gleam/result
import gleam/string
import gleeth/crypto/keccak
import gleeth/ethereum/abi/decode as abi_decode
import gleeth/ethereum/abi/json.{type AbiEntry, type EventParam, EventEntry}
import gleeth/ethereum/abi/types.{type AbiError, type AbiType, type AbiValue}
import gleeth/ethereum/types as eth_types
import gleeth/utils/hex

pub type DecodedLog {
  DecodedLog(event_name: String, params: List(#(String, AbiValue)))
}

/// Compute the event topic hash: keccak256("EventName(type1,type2,...)")
pub fn event_topic(name: String, param_types: List(AbiType)) -> BitArray {
  let sig =
    name
    <> "("
    <> string.join(list.map(param_types, types.to_string), ",")
    <> ")"
  keccak.keccak256_binary(bit_array.from_string(sig))
}

/// Compute the event topic hash as a hex string with 0x prefix.
pub fn event_topic_hex(name: String, param_types: List(AbiType)) -> String {
  hex.encode(event_topic(name, param_types))
}

/// Decode an event log using known ABI event definitions.
/// Matches topics[0] against event signatures, then decodes indexed
/// and non-indexed parameters.
pub fn decode_log(
  log: eth_types.Log,
  events: List(AbiEntry),
) -> Result(DecodedLog, AbiError) {
  // topics[0] is the event signature hash
  case log.topics {
    [] -> Error(types.DecodeError("Log has no topics (anonymous event)"))
    [topic0, ..indexed_topics] -> {
      // Find matching event
      use event <- result.try(find_event_by_topic(topic0, events))
      case event {
        EventEntry(name, inputs) ->
          decode_event_params(name, inputs, indexed_topics, log.data)
        _ -> Error(types.DecodeError("Matched entry is not an event"))
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Internal
// ---------------------------------------------------------------------------

fn find_event_by_topic(
  topic0: String,
  events: List(AbiEntry),
) -> Result(AbiEntry, AbiError) {
  let topic0_clean = string.lowercase(hex.strip_prefix(topic0))

  let matching =
    list.find(events, fn(entry) {
      case entry {
        EventEntry(name, inputs) -> {
          let param_types = list.map(inputs, fn(p: EventParam) { p.type_ })
          let computed = event_topic(name, param_types)
          let computed_hex = string.lowercase(bit_array.base16_encode(computed))
          computed_hex == topic0_clean
        }
        _ -> False
      }
    })

  case matching {
    Ok(entry) -> Ok(entry)
    Error(_) ->
      Error(types.DecodeError("No matching event for topic: 0x" <> topic0_clean))
  }
}

fn decode_event_params(
  event_name: String,
  inputs: List(EventParam),
  indexed_topics: List(String),
  data_hex: String,
) -> Result(DecodedLog, AbiError) {
  // Split inputs into indexed and non-indexed
  let indexed_inputs = list.filter(inputs, fn(p) { p.indexed })
  let non_indexed_inputs = list.filter(inputs, fn(p) { !p.indexed })

  // Decode indexed params from topics
  use indexed_params <- result.try(decode_indexed_params(
    indexed_inputs,
    indexed_topics,
  ))

  // Decode non-indexed params from data
  use non_indexed_params <- result.try(decode_non_indexed_params(
    non_indexed_inputs,
    data_hex,
  ))

  // Merge indexed and non-indexed in original order
  let all_params =
    merge_params_in_order(inputs, indexed_params, non_indexed_params)

  Ok(DecodedLog(event_name: event_name, params: all_params))
}

fn decode_indexed_params(
  indexed_inputs: List(EventParam),
  topics: List(String),
) -> Result(List(#(String, AbiValue)), AbiError) {
  list.zip(indexed_inputs, topics)
  |> list.try_map(fn(pair) {
    let #(input, topic_hex) = pair
    // For dynamic types, indexed topics contain the keccak256 hash,
    // not the actual value - return as bytes32
    case types.is_dynamic(input.type_) {
      True -> {
        case hex.decode(topic_hex) {
          Ok(bytes) -> Ok(#(input.name, types.FixedBytesValue(bytes)))
          Error(_) ->
            Error(types.DecodeError("Invalid hex in topic: " <> topic_hex))
        }
      }
      False -> {
        // Static types are ABI-encoded in the topic (32 bytes)
        case hex.decode(topic_hex) {
          Ok(bytes) -> {
            use value <- result.try(abi_decode.decode_single(input.type_, bytes))
            Ok(#(input.name, value))
          }
          Error(_) ->
            Error(types.DecodeError("Invalid hex in topic: " <> topic_hex))
        }
      }
    }
  })
}

fn decode_non_indexed_params(
  non_indexed_inputs: List(EventParam),
  data_hex: String,
) -> Result(List(#(String, AbiValue)), AbiError) {
  let non_indexed_types = list.map(non_indexed_inputs, fn(p) { p.type_ })
  let non_indexed_names = list.map(non_indexed_inputs, fn(p) { p.name })

  case data_hex {
    "0x" | "" -> {
      case non_indexed_types {
        [] -> Ok([])
        _ -> Error(types.DecodeError("Expected data for non-indexed params"))
      }
    }
    _ -> {
      case hex.decode(data_hex) {
        Ok(data_bytes) -> {
          use values <- result.try(abi_decode.decode(
            non_indexed_types,
            data_bytes,
          ))
          Ok(list.zip(non_indexed_names, values))
        }
        Error(_) -> Error(types.DecodeError("Invalid hex in log data"))
      }
    }
  }
}

/// Merge indexed and non-indexed params back into the original order.
fn merge_params_in_order(
  all_inputs: List(EventParam),
  indexed_params: List(#(String, AbiValue)),
  non_indexed_params: List(#(String, AbiValue)),
) -> List(#(String, AbiValue)) {
  merge_impl(all_inputs, indexed_params, non_indexed_params, [])
}

fn merge_impl(
  inputs: List(EventParam),
  indexed: List(#(String, AbiValue)),
  non_indexed: List(#(String, AbiValue)),
  acc: List(#(String, AbiValue)),
) -> List(#(String, AbiValue)) {
  case inputs {
    [] -> list.reverse(acc)
    [input, ..rest_inputs] -> {
      case input.indexed {
        True -> {
          case indexed {
            [param, ..rest_indexed] ->
              merge_impl(rest_inputs, rest_indexed, non_indexed, [param, ..acc])
            [] -> merge_impl(rest_inputs, [], non_indexed, acc)
          }
        }
        False -> {
          case non_indexed {
            [param, ..rest_non_indexed] ->
              merge_impl(rest_inputs, indexed, rest_non_indexed, [param, ..acc])
            [] -> merge_impl(rest_inputs, indexed, [], acc)
          }
        }
      }
    }
  }
}
