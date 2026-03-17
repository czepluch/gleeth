import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/result
import gleeth/ethereum/abi/type_parser
import gleeth/ethereum/abi/types.{type AbiError, type AbiType}

pub type AbiEntry {
  FunctionEntry(
    name: String,
    inputs: List(AbiParam),
    outputs: List(AbiParam),
    state_mutability: String,
  )
  EventEntry(name: String, inputs: List(EventParam))
}

pub type AbiParam {
  AbiParam(name: String, type_: AbiType)
}

pub type EventParam {
  EventParam(name: String, type_: AbiType, indexed: Bool)
}

/// Parse a Solidity JSON ABI string into a list of ABI entries.
pub fn parse_abi(json_string: String) -> Result(List(AbiEntry), AbiError) {
  case json.parse(json_string, decode.list(raw_entry_decoder())) {
    Ok(raw_entries) -> {
      // Filter and convert raw entries into typed ABI entries
      list.try_fold(raw_entries, [], fn(acc, raw) {
        case convert_raw_entry(raw) {
          Ok(entry) -> Ok([entry, ..acc])
          // Skip unsupported entry types (constructor, fallback, receive, error)
          Error(_) -> Ok(acc)
        }
      })
      |> result.map(list.reverse)
    }
    Error(_) -> Error(types.InvalidAbiJson("Failed to parse ABI JSON"))
  }
}

/// Find a function entry by name.
pub fn find_function(
  entries: List(AbiEntry),
  name: String,
) -> Result(AbiEntry, AbiError) {
  case
    list.find(entries, fn(entry) {
      case entry {
        FunctionEntry(n, _, _, _) -> n == name
        _ -> False
      }
    })
  {
    Ok(entry) -> Ok(entry)
    Error(_) -> Error(types.InvalidAbiJson("Function not found: " <> name))
  }
}

/// Find all event entries.
pub fn find_events(entries: List(AbiEntry)) -> List(AbiEntry) {
  list.filter(entries, fn(entry) {
    case entry {
      EventEntry(_, _) -> True
      _ -> False
    }
  })
}

/// Get input types from a function entry.
pub fn input_types(entry: AbiEntry) -> List(AbiType) {
  case entry {
    FunctionEntry(_, inputs, _, _) -> list.map(inputs, fn(p) { p.type_ })
    EventEntry(_, _) -> []
  }
}

/// Get output types from a function entry.
pub fn output_types(entry: AbiEntry) -> List(AbiType) {
  case entry {
    FunctionEntry(_, _, outputs, _) -> list.map(outputs, fn(p) { p.type_ })
    EventEntry(_, _) -> []
  }
}

// ---------------------------------------------------------------------------
// Internal: raw JSON decoding
// ---------------------------------------------------------------------------

/// Raw intermediate representation of a JSON ABI entry.
type RawEntry {
  RawEntry(
    entry_type: String,
    name: String,
    inputs: List(RawParam),
    outputs: List(RawParam),
    state_mutability: String,
  )
}

type RawParam {
  RawParam(name: String, type_string: String, indexed: Bool)
}

fn raw_entry_decoder() -> decode.Decoder(RawEntry) {
  use entry_type <- decode.optional_field("type", "function", decode.string)
  use name <- decode.optional_field("name", "", decode.string)
  use inputs <- decode.optional_field(
    "inputs",
    [],
    decode.list(raw_param_decoder()),
  )
  use outputs <- decode.optional_field(
    "outputs",
    [],
    decode.list(raw_param_decoder()),
  )
  use state_mutability <- decode.optional_field(
    "stateMutability",
    "",
    decode.string,
  )
  decode.success(RawEntry(
    entry_type: entry_type,
    name: name,
    inputs: inputs,
    outputs: outputs,
    state_mutability: state_mutability,
  ))
}

fn raw_param_decoder() -> decode.Decoder(RawParam) {
  use name <- decode.optional_field("name", "", decode.string)
  use type_string <- decode.field("type", decode.string)
  use indexed <- decode.optional_field("indexed", False, decode.bool)
  decode.success(RawParam(
    name: name,
    type_string: type_string,
    indexed: indexed,
  ))
}

fn convert_raw_entry(raw: RawEntry) -> Result(AbiEntry, AbiError) {
  case raw.entry_type {
    "function" -> {
      use inputs <- result.try(list.try_map(raw.inputs, convert_raw_param))
      use outputs <- result.try(list.try_map(raw.outputs, convert_raw_param))
      Ok(FunctionEntry(
        name: raw.name,
        inputs: inputs,
        outputs: outputs,
        state_mutability: raw.state_mutability,
      ))
    }
    "event" -> {
      use inputs <- result.try(list.try_map(raw.inputs, convert_raw_event_param))
      Ok(EventEntry(name: raw.name, inputs: inputs))
    }
    _ ->
      Error(types.InvalidAbiJson(
        "Unsupported ABI entry type: " <> raw.entry_type,
      ))
  }
}

fn convert_raw_param(raw: RawParam) -> Result(AbiParam, AbiError) {
  use t <- result.try(type_parser.parse(raw.type_string))
  Ok(AbiParam(name: raw.name, type_: t))
}

fn convert_raw_event_param(raw: RawParam) -> Result(EventParam, AbiError) {
  use t <- result.try(type_parser.parse(raw.type_string))
  Ok(EventParam(name: raw.name, type_: t, indexed: raw.indexed))
}
