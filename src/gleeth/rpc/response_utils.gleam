import gleam/json
import gleam/result
import gleam/string
import gleeth/rpc/client
import gleeth/rpc/types as rpc_types

// Extract and clean a string result from a JSON-RPC response
// This eliminates the repeated pattern across multiple RPC methods
pub fn extract_string_result(
  response: json.Json,
) -> Result(String, rpc_types.GleethError) {
  // Extract the actual string value, removing quotes
  let result_str = json.to_string(response)
  let clean_result = case
    string.starts_with(result_str, "\"") && string.ends_with(result_str, "\"")
  {
    True -> {
      result_str
      |> string.drop_start(1)
      |> string.drop_end(1)
    }
    False -> result_str
  }
  Ok(clean_result)
}

// Make an RPC request and extract a string result
// This combines the common pattern of make_request + extract_string_result
pub fn make_string_request(
  rpc_url: String,
  method: rpc_types.EthMethod,
  params: List(json.Json),
) -> Result(String, rpc_types.GleethError) {
  use response <- result.try(client.make_request(
    rpc_url,
    rpc_types.method_to_string(method),
    params,
  ))

  extract_string_result(response)
}

// Make an RPC request and return the raw JSON response
// For methods that need custom parsing (like transactions, receipts)
pub fn make_json_request(
  rpc_url: String,
  method: rpc_types.EthMethod,
  params: List(json.Json),
) -> Result(json.Json, rpc_types.GleethError) {
  client.make_request(
    rpc_url,
    rpc_types.method_to_string(method),
    params,
  )
}
