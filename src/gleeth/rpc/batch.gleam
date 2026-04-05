//// Batch JSON-RPC requests into a single HTTP call.
////
//// Reduces HTTP overhead when making multiple independent queries by sending
//// them as a JSON array per the JSON-RPC batch specification.
////
//// ## Examples
////
//// ```gleam
//// let assert Ok(results) =
////   batch.new()
////   |> batch.add("eth_blockNumber", [])
////   |> batch.add("eth_gasPrice", [])
////   |> batch.execute_strings(provider)
////
//// // results: [Ok("0x1234"), Ok("0x3b9aca00")]
//// ```

import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleeth/provider.{type Provider}
import gleeth/rpc/client
import gleeth/rpc/types as rpc_types

/// A batch of JSON-RPC requests to be sent together.
pub type Batch {
  Batch(requests: List(BatchRequest))
}

/// A single request within a batch, with an auto-assigned ID.
pub opaque type BatchRequest {
  BatchRequest(method: String, params: List(json.Json), id: Int)
}

/// Create an empty batch.
pub fn new() -> Batch {
  Batch(requests: [])
}

/// Add a raw method name and params to the batch.
pub fn add(batch: Batch, method: String, params: List(json.Json)) -> Batch {
  let id = list.length(batch.requests) + 1
  Batch(requests: [
    BatchRequest(method: method, params: params, id: id),
    ..batch.requests
  ])
}

/// Add a request using an EthMethod value.
pub fn add_method(
  batch: Batch,
  method: rpc_types.EthMethod,
  params: List(json.Json),
) -> Batch {
  add(batch, rpc_types.method_to_string(method), params)
}

/// Execute the batch and decode each response as a string.
/// Returns one `Result(String, GleethError)` per request, in order.
/// This is the most common use case - batching simple hex-returning RPC calls.
pub fn execute_strings(
  batch: Batch,
  provider: Provider,
) -> Result(List(Result(String, rpc_types.GleethError)), rpc_types.GleethError) {
  let requests = list.reverse(batch.requests)
  case requests {
    [] -> Ok([])
    _ -> {
      let batch_json = encode_batch(requests)
      let rpc_url = provider.rpc_url(provider)
      use response_body <- result.try(client.make_batch_request(
        rpc_url,
        batch_json,
      ))
      use parsed <- result.try(parse_batch_response(response_body))
      Ok(match_and_decode_strings(parsed, requests))
    }
  }
}

/// Execute the batch and return raw JSON response bodies per request.
/// Each string is the full `{"jsonrpc":"2.0","id":N,"result":...}` for that
/// request, suitable for passing to `response_utils.decode_rpc_response`
/// with a custom decoder.
pub fn execute_raw(
  batch: Batch,
  provider: Provider,
) -> Result(List(Result(String, rpc_types.GleethError)), rpc_types.GleethError) {
  let requests = list.reverse(batch.requests)
  case requests {
    [] -> Ok([])
    _ -> {
      let batch_json = encode_batch(requests)
      let rpc_url = provider.rpc_url(provider)
      use response_body <- result.try(client.make_batch_request(
        rpc_url,
        batch_json,
      ))
      use parsed <- result.try(parse_batch_response(response_body))
      Ok(match_raw(parsed, requests))
    }
  }
}

// =============================================================================
// Encoding
// =============================================================================

fn encode_batch(requests: List(BatchRequest)) -> String {
  json.to_string(
    json.array(requests, fn(req) {
      json.object([
        #("jsonrpc", json.string("2.0")),
        #("method", json.string(req.method)),
        #("params", json.array(req.params, fn(x) { x })),
        #("id", json.int(req.id)),
      ])
    }),
  )
}

// =============================================================================
// Response parsing
// =============================================================================

/// Parsed response: id, optional result string, optional error message.
type ParsedResponse {
  ParsedResponse(id: Int, result: String, error: String, has_result: Bool)
}

fn parse_batch_response(
  body: String,
) -> Result(List(ParsedResponse), rpc_types.GleethError) {
  let decoder = decode.list(response_decoder())
  case json.parse(body, decoder) {
    Ok(results) -> Ok(results)
    Error(_) ->
      Error(rpc_types.ParseError("Failed to parse batch JSON-RPC response"))
  }
}

fn response_decoder() -> decode.Decoder(ParsedResponse) {
  use id <- decode.field("id", decode.int)
  use result <- decode.optional_field(
    "result",
    "",
    decode.one_of(decode.string, [
      // Handle non-string results by stringifying
      decode.map(decode.int, fn(n) { string.inspect(n) }),
      decode.map(decode.bool, fn(b) {
        case b {
          True -> "true"
          False -> "false"
        }
      }),
      // null result
      decode.success(""),
    ]),
  )
  use error_msg <- decode.optional_field("error", "", error_message_decoder())
  // Determine if we got a result or an error
  let has_result = error_msg == ""
  decode.success(ParsedResponse(
    id: id,
    result: result,
    error: error_msg,
    has_result: has_result,
  ))
}

fn error_message_decoder() -> decode.Decoder(String) {
  // Error is an object with a "message" field
  decode.one_of(
    {
      use msg <- decode.field("message", decode.string)
      decode.success(msg)
    },
    [
      // Fallback: just stringify whatever we get
      decode.map(decode.string, fn(s) { s }),
    ],
  )
}

// =============================================================================
// Response matching
// =============================================================================

fn match_and_decode_strings(
  responses: List(ParsedResponse),
  requests: List(BatchRequest),
) -> List(Result(String, rpc_types.GleethError)) {
  list.map(requests, fn(req) {
    case find_response(responses, req.id) {
      Ok(parsed) ->
        case parsed.has_result {
          True -> Ok(parsed.result)
          False -> Error(rpc_types.RpcError("RPC Error: " <> parsed.error))
        }
      Error(_) -> Error(rpc_types.ParseError("No response for batch request"))
    }
  })
}

fn match_raw(
  responses: List(ParsedResponse),
  requests: List(BatchRequest),
) -> List(Result(String, rpc_types.GleethError)) {
  list.map(requests, fn(req) {
    case find_response(responses, req.id) {
      Ok(parsed) ->
        case parsed.has_result {
          True -> {
            // Rebuild as a full JSON-RPC response body
            let body =
              json.to_string(
                json.object([
                  #("jsonrpc", json.string("2.0")),
                  #("id", json.int(parsed.id)),
                  #("result", json.string(parsed.result)),
                ]),
              )
            Ok(body)
          }
          False -> Error(rpc_types.RpcError("RPC Error: " <> parsed.error))
        }
      Error(_) -> Error(rpc_types.ParseError("No response for batch request"))
    }
  })
}

fn find_response(
  responses: List(ParsedResponse),
  id: Int,
) -> Result(ParsedResponse, Nil) {
  list.find(responses, fn(r) { r.id == id })
}
