import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/json
import gleam/result
import gleam/string
import gleeth/rpc/types as rpc_types

// Make a JSON-RPC request to an Ethereum node.
// Returns the raw HTTP response body string for the caller to decode.
pub fn make_request(
  rpc_url: String,
  method: String,
  params: List(json.Json),
) -> Result(String, rpc_types.GleethError) {
  let json_rpc_request =
    rpc_types.JsonRpcRequest(
      jsonrpc: "2.0",
      method: method,
      params: params,
      id: 1,
    )

  use request_json <- result.try(encode_request(json_rpc_request))
  use http_response <- result.try(send_http_request(rpc_url, request_json))

  case http_response.status {
    200 -> Ok(http_response.body)
    status ->
      Error(rpc_types.NetworkError(
        "HTTP request failed with status: " <> int.to_string(status),
      ))
  }
}

// Encode JSON-RPC request to JSON string
fn encode_request(
  req: rpc_types.JsonRpcRequest,
) -> Result(String, rpc_types.GleethError) {
  let json_object =
    json.object([
      #("jsonrpc", json.string(req.jsonrpc)),
      #("method", json.string(req.method)),
      #("params", json.array(req.params, fn(x) { x })),
      #("id", json.int(req.id)),
    ])

  Ok(json.to_string(json_object))
}

// Send HTTP POST request
fn send_http_request(
  rpc_url: String,
  body: String,
) -> Result(response.Response(String), rpc_types.GleethError) {
  let req =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_body(body)
    |> request.set_header("content-type", "application/json")
    |> request.set_header("user-agent", "gleeth/1.0")

  case parse_url(rpc_url) {
    Ok(#(scheme, host, path)) -> {
      let req_with_scheme = case scheme {
        "https" -> request.set_scheme(req, http.Https)
        _ -> request.set_scheme(req, http.Http)
      }

      let req_with_host = request.set_host(req_with_scheme, host)
      let req_with_path = request.set_path(req_with_host, path)

      case httpc.send(req_with_path) {
        Ok(response) -> Ok(response)
        Error(_) -> Error(rpc_types.NetworkError("Failed to send HTTP request"))
      }
    }
    Error(err) -> Error(err)
  }
}

/// Send a batch of JSON-RPC requests in a single HTTP call.
/// The body should be a JSON array of request objects.
/// Returns the raw response body (a JSON array of responses).
pub fn make_batch_request(
  rpc_url: String,
  batch_body: String,
) -> Result(String, rpc_types.GleethError) {
  use http_response <- result.try(send_http_request(rpc_url, batch_body))
  case http_response.status {
    200 -> Ok(http_response.body)
    status ->
      Error(rpc_types.NetworkError(
        "HTTP request failed with status: " <> int.to_string(status),
      ))
  }
}

// Parse URL into scheme, host, and path
fn parse_url(
  url: String,
) -> Result(#(String, String, String), rpc_types.GleethError) {
  case string.split(url, "://") {
    [scheme, rest] -> {
      case string.split_once(rest, "/") {
        Ok(#(host, path)) -> Ok(#(scheme, host, "/" <> path))
        Error(_) -> Ok(#(scheme, rest, "/"))
      }
    }
    _ ->
      Error(rpc_types.InvalidRpcUrl(
        "Invalid URL format - must include scheme (http:// or https://)",
      ))
  }
}
