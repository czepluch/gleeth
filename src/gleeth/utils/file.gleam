import gleam/list
import gleam/string
import gleeth/ethereum/types as eth_types
import gleeth/rpc/types as rpc_types
import gleeth/utils/validation
import simplifile

// Read addresses from a file (one per line)
pub fn read_addresses_from_file(
  filename: String,
) -> Result(List(eth_types.Address), rpc_types.GleethError) {
  case simplifile.read(filename) {
    Ok(content) -> {
      let lines = string.split(content, "\n")
      let trimmed_lines = list.map(lines, string.trim)
      let non_empty_lines =
        list.filter(trimmed_lines, fn(line) {
          !string.is_empty(line) && !string.starts_with(line, "#")
        })
      validate_addresses_from_lines(non_empty_lines)
    }
    Error(_) ->
      Error(rpc_types.ConfigError("Could not read file: " <> filename))
  }
}

// Validate addresses from file lines
fn validate_addresses_from_lines(
  lines: List(String),
) -> Result(List(eth_types.Address), rpc_types.GleethError) {
  case lines {
    [] -> Error(rpc_types.ConfigError("No valid addresses found in file"))
    _ -> list.try_map(lines, validation.validate_address)
  }
}
