import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int

import gleam/json
import gleam/result
import gleam/string
import gleeth/rpc/types as rpc_types

// Make a JSON-RPC request to an Ethereum node
pub fn make_request(
  rpc_url: String,
  method: String,
  params: List(json.Json),
) -> Result(json.Json, rpc_types.GleethError) {
  let json_rpc_request =
    rpc_types.JsonRpcRequest(
      jsonrpc: "2.0",
      method: method,
      params: params,
      id: 1,
    )

  use request_json <- result.try(encode_request(json_rpc_request))
  use http_response <- result.try(send_http_request(rpc_url, request_json))
  use response_data <- result.try(parse_response(http_response))

  Ok(response_data)
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
  // Create a new HTTP request
  let req =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_body(body)
    |> request.set_header("content-type", "application/json")
    |> request.set_header("user-agent", "gleeth/1.0")

  // Set the URL - parse the URL to extract host and path
  case parse_url(rpc_url) {
    Ok(#(scheme, host, path)) -> {
      let req_with_scheme = case scheme {
        "https" -> request.set_scheme(req, http.Https)
        _ -> request.set_scheme(req, http.Http)
      }

      let req_with_host = request.set_host(req_with_scheme, host)
      let req_with_path = request.set_path(req_with_host, path)

      // Send the request
      case httpc.send(req_with_path) {
        Ok(response) -> Ok(response)
        Error(_) -> Error(rpc_types.NetworkError("Failed to send HTTP request"))
      }
    }
    Error(err) -> Error(err)
  }
}

// Parse HTTP response and extract JSON-RPC result
fn parse_response(
  response: response.Response(String),
) -> Result(json.Json, rpc_types.GleethError) {
  case response.status {
    200 -> {
      // Parse JSON-RPC response using string operations
      case string.contains(response.body, "\"result\"") {
        True -> {
          case extract_json_field_value(response.body, "result") {
            Ok(result_str) -> {
              // Create a JSON string value
              Ok(json.string(result_str))
            }
            Error(err) -> Error(err)
          }
        }
        False -> {
          case string.contains(response.body, "\"error\"") {
            True -> {
              case extract_error_message(response.body) {
                Ok(error_msg) ->
                  Error(rpc_types.RpcError("RPC Error: " <> error_msg))
                Error(_) -> Error(rpc_types.RpcError("RPC returned an error"))
              }
            }
            False ->
              Error(rpc_types.ParseError("No result or error field found"))
          }
        }
      }
    }
    _ ->
      Error(rpc_types.NetworkError(
        "HTTP request failed with status: " <> int.to_string(response.status),
      ))
  }
}

// Extract the value of a JSON field using string parsing
fn extract_json_field_value(
  json_str: String,
  field_name: String,
) -> Result(String, rpc_types.GleethError) {
  let pattern = "\"" <> field_name <> "\":"
  case string.split(json_str, pattern) {
    [_, rest] -> {
      let trimmed = string.trim(rest)
      case string.starts_with(trimmed, "\"") {
        True -> {
          // Extract quoted string value
          let without_quote = string.drop_start(trimmed, 1)
          case string.split_once(without_quote, "\"") {
            Ok(#(value, _)) -> Ok(value)
            Error(_) -> Error(rpc_types.ParseError("Malformed JSON string"))
          }
        }
        False -> {
          // Extract unquoted value (number, boolean, etc)
          extract_unquoted_value(trimmed)
        }
      }
    }
    _ ->
      Error(rpc_types.ParseError(
        "Field '" <> field_name <> "' not found in JSON",
      ))
  }
}

// Extract unquoted JSON value (like numbers, booleans, objects, and arrays)
fn extract_unquoted_value(text: String) -> Result(String, rpc_types.GleethError) {
  case string.starts_with(text, "{") {
    True -> {
      // This is a JSON object - need to find the matching closing brace
      case extract_complete_json_object(text, 0, 0, "") {
        Ok(obj_str) -> Ok(obj_str)
        Error(_) -> Error(rpc_types.ParseError("Malformed JSON object"))
      }
    }
    False -> {
      case string.starts_with(text, "[") {
        True -> {
          // This is a JSON array - need to find the matching closing bracket
          case extract_complete_json_array(text, 0, 0, "") {
            Ok(arr_str) -> Ok(arr_str)
            Error(_) -> Error(rpc_types.ParseError("Malformed JSON array"))
          }
        }
        False -> {
          // Look for common JSON value terminators for primitive values
          case string.split_once(text, ",") {
            Ok(#(value, _)) -> Ok(string.trim(value))
            Error(_) -> {
              case string.split_once(text, "}") {
                Ok(#(value, _)) -> Ok(string.trim(value))
                Error(_) -> {
                  case string.split_once(text, "]") {
                    Ok(#(value, _)) -> Ok(string.trim(value))
                    Error(_) -> Ok(string.trim(text))
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

// Extract a complete JSON object by counting braces
fn extract_complete_json_object(
  text: String,
  index: Int,
  depth: Int,
  acc: String,
) -> Result(String, Nil) {
  case string.pop_grapheme(text) {
    Ok(#(char, rest)) -> {
      let new_acc = acc <> char
      case char {
        "{" -> extract_complete_json_object(rest, index + 1, depth + 1, new_acc)
        "}" ->
          case depth {
            1 -> Ok(new_acc)
            // Found matching closing brace  
            _ ->
              extract_complete_json_object(rest, index + 1, depth - 1, new_acc)
          }
        _ -> extract_complete_json_object(rest, index + 1, depth, new_acc)
      }
    }
    Error(_) ->
      case depth {
        0 -> Ok(acc)
        // No more text, return what we have
        _ -> Error(Nil)
        // Unmatched braces
      }
  }
}

// Extract a complete JSON array by counting brackets
fn extract_complete_json_array(
  text: String,
  index: Int,
  depth: Int,
  acc: String,
) -> Result(String, Nil) {
  case string.pop_grapheme(text) {
    Ok(#(char, rest)) -> {
      let new_acc = acc <> char
      case char {
        "[" -> extract_complete_json_array(rest, index + 1, depth + 1, new_acc)
        "]" ->
          case depth {
            1 -> Ok(new_acc)
            // Found matching closing bracket  
            _ ->
              extract_complete_json_array(rest, index + 1, depth - 1, new_acc)
          }
        _ -> extract_complete_json_array(rest, index + 1, depth, new_acc)
      }
    }
    Error(_) ->
      case depth {
        0 -> Ok(acc)
        // No more text, return what we have
        _ -> Error(Nil)
        // Unmatched brackets
      }
  }
}

// Extract error message from JSON-RPC error response
fn extract_error_message(
  json_str: String,
) -> Result(String, rpc_types.GleethError) {
  case string.contains(json_str, "\"message\"") {
    True -> extract_json_field_value(json_str, "message")
    False -> Error(rpc_types.ParseError("No error message found"))
  }
}

// Parse URL into scheme, host, and path
fn parse_url(
  url: String,
) -> Result(#(String, String, String), rpc_types.GleethError) {
  // Simple URL parsing - split on ://
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
