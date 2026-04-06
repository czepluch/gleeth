import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/json
import gleam/result
import gleam/string
import gleeth/provider
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

/// Make a JSON-RPC request with automatic retry on transient errors.
/// Retries on HTTP 429 (rate limited), 503 (service unavailable), and
/// connection failures, using exponential backoff from the retry config.
pub fn make_request_with_retry(
  rpc_url: String,
  method: String,
  params: List(json.Json),
  retry_config: provider.RetryConfig,
) -> Result(String, rpc_types.GleethError) {
  do_request_with_retry(
    rpc_url,
    method,
    params,
    retry_config.max_retries,
    retry_config.initial_backoff_ms,
    retry_config.max_backoff_ms,
    0,
  )
}

fn do_request_with_retry(
  rpc_url: String,
  method: String,
  params: List(json.Json),
  max_retries: Int,
  backoff_ms: Int,
  max_backoff_ms: Int,
  attempt: Int,
) -> Result(String, rpc_types.GleethError) {
  let json_rpc_request =
    rpc_types.JsonRpcRequest(
      jsonrpc: "2.0",
      method: method,
      params: params,
      id: 1,
    )

  case encode_request(json_rpc_request) {
    Error(e) -> Error(e)
    Ok(request_json) -> {
      case send_http_request(rpc_url, request_json) {
        Ok(http_response) ->
          case http_response.status {
            200 -> Ok(http_response.body)
            429 | 503 if attempt < max_retries -> {
              process.sleep(backoff_ms)
              let next_backoff = int.min(backoff_ms * 2, max_backoff_ms)
              do_request_with_retry(
                rpc_url,
                method,
                params,
                max_retries,
                next_backoff,
                max_backoff_ms,
                attempt + 1,
              )
            }
            status ->
              Error(rpc_types.NetworkError(
                "HTTP request failed with status: " <> int.to_string(status),
              ))
          }
        Error(_) if attempt < max_retries -> {
          process.sleep(backoff_ms)
          let next_backoff = int.min(backoff_ms * 2, max_backoff_ms)
          do_request_with_retry(
            rpc_url,
            method,
            params,
            max_retries,
            next_backoff,
            max_backoff_ms,
            attempt + 1,
          )
        }
        Error(e) -> Error(e)
      }
    }
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
