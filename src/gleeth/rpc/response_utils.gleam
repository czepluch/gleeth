import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleeth/provider
import gleeth/rpc/client
import gleeth/rpc/types as rpc_types

// Decode the JSON-RPC error message from a response body, if present.
fn decode_rpc_error(body: String) -> Option(String) {
  let error_decoder =
    decode.at(["error", "message"], decode.optional(decode.string))

  case json.parse(body, error_decoder) {
    Ok(Some(msg)) -> Some(msg)
    _ -> None
  }
}

// Decode a JSON-RPC response body using a decoder for the "result" field.
// Checks for "error" first, then decodes "result".
pub fn decode_rpc_response(
  body: String,
  result_decoder: decode.Decoder(a),
) -> Result(a, rpc_types.GleethError) {
  case decode_rpc_error(body) {
    Some(msg) -> Error(rpc_types.RpcError("RPC Error: " <> msg))
    None -> {
      let envelope_decoder = decode.at(["result"], result_decoder)
      case json.parse(body, envelope_decoder) {
        Ok(value) -> Ok(value)
        Error(json.UnableToDecode(_)) ->
          Error(rpc_types.ParseError("Failed to decode RPC result"))
        Error(json.UnexpectedEndOfInput) ->
          Error(rpc_types.ParseError("Unexpected end of JSON input"))
        Error(json.UnexpectedByte(b)) ->
          Error(rpc_types.ParseError("Unexpected byte in JSON: " <> b))
        Error(json.UnexpectedSequence(s)) ->
          Error(rpc_types.ParseError("Unexpected sequence in JSON: " <> s))
      }
    }
  }
}

// Make an RPC request and decode the result as a string.
// Uses retry config from the provider if configured.
pub fn make_string_request(
  rpc_url: String,
  method: rpc_types.EthMethod,
  params: List(json.Json),
) -> Result(String, rpc_types.GleethError) {
  use body <- result.try(client.make_request(
    rpc_url,
    rpc_types.method_to_string(method),
    params,
  ))

  decode_rpc_response(body, decode.string)
}

// Make an RPC request with retry support and decode the result as a string.
pub fn make_string_request_with_provider(
  p: provider.Provider,
  method: rpc_types.EthMethod,
  params: List(json.Json),
) -> Result(String, rpc_types.GleethError) {
  let retry = provider.retry_config(p)
  use body <- result.try(case retry.max_retries > 0 {
    True ->
      client.make_request_with_retry(
        provider.rpc_url(p),
        rpc_types.method_to_string(method),
        params,
        retry,
      )
    False ->
      client.make_request(
        provider.rpc_url(p),
        rpc_types.method_to_string(method),
        params,
      )
  })
  decode_rpc_response(body, decode.string)
}

// Make an RPC request and decode the result with a custom decoder.
pub fn make_decoded_request(
  rpc_url: String,
  method: rpc_types.EthMethod,
  params: List(json.Json),
  decoder: decode.Decoder(a),
) -> Result(a, rpc_types.GleethError) {
  use body <- result.try(client.make_request(
    rpc_url,
    rpc_types.method_to_string(method),
    params,
  ))

  decode_rpc_response(body, decoder)
}

// Make an RPC request with retry support and decode with a custom decoder.
pub fn make_decoded_request_with_provider(
  p: provider.Provider,
  method: rpc_types.EthMethod,
  params: List(json.Json),
  decoder: decode.Decoder(a),
) -> Result(a, rpc_types.GleethError) {
  let retry = provider.retry_config(p)
  use body <- result.try(case retry.max_retries > 0 {
    True ->
      client.make_request_with_retry(
        provider.rpc_url(p),
        rpc_types.method_to_string(method),
        params,
        retry,
      )
    False ->
      client.make_request(
        provider.rpc_url(p),
        rpc_types.method_to_string(method),
        params,
      )
  })
  decode_rpc_response(body, decoder)
}
