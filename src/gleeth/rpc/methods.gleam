import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleeth/ethereum/types as eth_types
import gleeth/rpc/response_utils
import gleeth/rpc/types as rpc_types

// Get the latest block number
pub fn get_block_number(
  rpc_url: String,
) -> Result(eth_types.BlockNumber, rpc_types.GleethError) {
  response_utils.make_string_request(rpc_url, rpc_types.EthBlockNumber, [])
}

// Get balance of an address
pub fn get_balance(
  rpc_url: String,
  address: eth_types.Address,
) -> Result(eth_types.Wei, rpc_types.GleethError) {
  let params = [json.string(address), json.string("latest")]
  response_utils.make_string_request(rpc_url, rpc_types.EthGetBalance, params)
}

// Get transaction by hash
pub fn get_transaction(
  rpc_url: String,
  hash: String,
) -> Result(eth_types.Transaction, rpc_types.GleethError) {
  let params = [json.string(hash)]

  use response <- result.try(response_utils.make_json_request(
    rpc_url,
    rpc_types.EthGetTransactionByHash,
    params,
  ))

  // Parse the JSON response into a Transaction
  parse_transaction(response)
}

// Make a contract call
pub fn call_contract(
  rpc_url: String,
  contract_address: eth_types.Address,
  data: String,
) -> Result(String, rpc_types.GleethError) {
  let call_object =
    json.object([
      #("to", json.string(contract_address)),
      #("data", json.string(data)),
    ])

  let params = [call_object, json.string("latest")]
  response_utils.make_string_request(rpc_url, rpc_types.EthCall, params)
}

// Get transaction receipt by hash
pub fn get_transaction_receipt(
  rpc_url: String,
  transaction_hash: String,
) -> Result(eth_types.TransactionReceipt, rpc_types.GleethError) {
  let params = [json.string(transaction_hash)]

  use response <- result.try(response_utils.make_json_request(
    rpc_url,
    rpc_types.EthGetTransactionReceipt,
    params,
  ))

  // Parse the JSON response into a TransactionReceipt
  parse_transaction_receipt(response)
}

// Parse JSON response into TransactionReceipt  
pub fn parse_transaction_receipt(
  response: json.Json,
) -> Result(eth_types.TransactionReceipt, rpc_types.GleethError) {
  // The response from client.make_request is the result field as a JSON string
  // We need to remove the quotes and parse the actual JSON object
  let json_str = json.to_string(response)

  // Remove the outer quotes from the JSON string value
  let clean_json_str = case
    string.starts_with(json_str, "\"") && string.ends_with(json_str, "\"")
  {
    True -> {
      json_str
      |> string.drop_start(1)
      |> string.drop_end(1)
      // Also need to unescape the JSON
      |> string.replace("\\\"", "\"")
    }
    False -> json_str
  }

  // Handle null response (transaction not found)  
  case
    string.contains(clean_json_str, "null")
    && string.length(clean_json_str) < 10
  {
    True -> Error(rpc_types.RpcError("Transaction receipt not found"))
    False -> {
      // Extract each field from the cleaned JSON string
      use transaction_hash <- result.try(extract_string_field(
        clean_json_str,
        "transactionHash",
      ))
      use transaction_index <- result.try(extract_string_field(
        clean_json_str,
        "transactionIndex",
      ))
      use block_hash <- result.try(extract_string_field(
        clean_json_str,
        "blockHash",
      ))
      use block_number <- result.try(extract_string_field(
        clean_json_str,
        "blockNumber",
      ))
      use from <- result.try(extract_string_field(clean_json_str, "from"))
      use to <- result.try(extract_nullable_string_field(clean_json_str, "to"))
      use cumulative_gas_used <- result.try(extract_string_field(
        clean_json_str,
        "cumulativeGasUsed",
      ))
      use gas_used <- result.try(extract_string_field(clean_json_str, "gasUsed"))
      use contract_address <- result.try(extract_nullable_string_field(
        clean_json_str,
        "contractAddress",
      ))
      use logs <- result.try(extract_logs_field(clean_json_str))
      use logs_bloom <- result.try(extract_string_field(
        clean_json_str,
        "logsBloom",
      ))
      use status <- result.try(extract_status_field(clean_json_str))
      use effective_gas_price <- result.try(extract_string_field(
        clean_json_str,
        "effectiveGasPrice",
      ))

      Ok(eth_types.TransactionReceipt(
        transaction_hash: transaction_hash,
        transaction_index: transaction_index,
        block_hash: block_hash,
        block_number: block_number,
        from: from,
        to: to,
        cumulative_gas_used: cumulative_gas_used,
        gas_used: gas_used,
        contract_address: contract_address,
        logs: logs,
        logs_bloom: logs_bloom,
        status: status,
        effective_gas_price: effective_gas_price,
      ))
    }
  }
}

// Parse JSON response into Transaction
pub fn parse_transaction(
  response: json.Json,
) -> Result(eth_types.Transaction, rpc_types.GleethError) {
  let json_str = json.to_string(response)

  // Remove the outer quotes from the JSON string value
  let clean_json_str = case
    string.starts_with(json_str, "\"") && string.ends_with(json_str, "\"")
  {
    True -> {
      json_str
      |> string.drop_start(1)
      |> string.drop_end(1)
      // Also need to unescape the JSON
      |> string.replace("\\\"", "\"")
    }
    False -> json_str
  }

  // Handle null response (transaction not found)
  case
    string.contains(clean_json_str, "null")
    && string.length(clean_json_str) < 10
  {
    True -> Error(rpc_types.RpcError("Transaction not found"))
    False -> {
      // Extract each field from the cleaned JSON string
      use hash <- result.try(extract_string_field(clean_json_str, "hash"))
      use block_number <- result.try(extract_nullable_string_field(
        clean_json_str,
        "blockNumber",
      ))
      use block_hash <- result.try(extract_nullable_string_field(
        clean_json_str,
        "blockHash",
      ))
      use transaction_index <- result.try(extract_nullable_string_field(
        clean_json_str,
        "transactionIndex",
      ))
      use from <- result.try(extract_string_field(clean_json_str, "from"))
      use to <- result.try(extract_nullable_string_field(clean_json_str, "to"))
      use value <- result.try(extract_string_field(clean_json_str, "value"))
      use gas <- result.try(extract_string_field(clean_json_str, "gas"))
      use gas_price <- result.try(extract_optional_string_field(
        clean_json_str,
        "gasPrice",
      ))
      use max_fee_per_gas <- result.try(extract_optional_string_field(
        clean_json_str,
        "maxFeePerGas",
      ))
      use max_priority_fee_per_gas <- result.try(extract_optional_string_field(
        clean_json_str,
        "maxPriorityFeePerGas",
      ))
      use input <- result.try(extract_string_field(clean_json_str, "input"))
      use nonce <- result.try(extract_string_field(clean_json_str, "nonce"))
      use transaction_type <- result.try(extract_optional_string_field(
        clean_json_str,
        "type",
      ))
      use chain_id <- result.try(extract_optional_string_field(
        clean_json_str,
        "chainId",
      ))
      use v <- result.try(extract_string_field(clean_json_str, "v"))
      use r <- result.try(extract_string_field(clean_json_str, "r"))
      use s <- result.try(extract_string_field(clean_json_str, "s"))

      Ok(eth_types.Transaction(
        hash: hash,
        block_number: block_number,
        block_hash: block_hash,
        transaction_index: transaction_index,
        from: from,
        to: to,
        value: value,
        gas: gas,
        gas_price: gas_price,
        max_fee_per_gas: max_fee_per_gas,
        max_priority_fee_per_gas: max_priority_fee_per_gas,
        input: input,
        nonce: nonce,
        transaction_type: transaction_type,
        chain_id: chain_id,
        v: v,
        r: r,
        s: s,
      ))
    }
  }
}

// Get contract code (bytecode) at an address
pub fn get_code(
  rpc_url: String,
  address: eth_types.Address,
) -> Result(String, rpc_types.GleethError) {
  let params = [json.string(address), json.string("latest")]
  response_utils.make_string_request(rpc_url, rpc_types.EthGetCode, params)
}

// Estimate gas needed for a transaction
pub fn estimate_gas(
  rpc_url: String,
  from: String,
  to: String,
  value: String,
  data: String,
) -> Result(eth_types.Gas, rpc_types.GleethError) {
  // Build the transaction object
  let transaction_params = []

  // Add 'from' if provided
  let transaction_params = case from {
    "" -> transaction_params
    _ -> [#("from", json.string(from)), ..transaction_params]
  }

  // Add 'to' if provided  
  let transaction_params = case to {
    "" -> transaction_params
    _ -> [#("to", json.string(to)), ..transaction_params]
  }

  // Add 'value' if provided
  let transaction_params = case value {
    "" -> transaction_params
    _ -> [#("value", json.string(value)), ..transaction_params]
  }

  // Add 'data' if provided
  let transaction_params = case data {
    "" -> transaction_params
    _ -> [#("data", json.string(data)), ..transaction_params]
  }

  let transaction_object = json.object(transaction_params)
  let params = [transaction_object]

  response_utils.make_string_request(rpc_url, rpc_types.EthEstimateGas, params)
}

// Get storage value at a specific slot in a contract
pub fn get_storage_at(
  rpc_url: String,
  address: eth_types.Address,
  slot: eth_types.StorageSlot,
  block: String,
) -> Result(eth_types.StorageValue, rpc_types.GleethError) {
  // Use "latest" as default block if empty string is provided
  let block_param = case block {
    "" -> "latest"
    _ -> block
  }

  let params = [
    json.string(address),
    json.string(slot),
    json.string(block_param),
  ]

  response_utils.make_string_request(rpc_url, rpc_types.EthGetStorageAt, params)
}

// Get event logs based on filter criteria
pub fn get_logs(
  rpc_url: String,
  from_block: String,
  to_block: String,
  address: String,
  topics: List(String),
) -> Result(List(eth_types.Log), rpc_types.GleethError) {
  // Build the filter object
  let filter_params = []

  // Add fromBlock if provided, default to "latest"
  let from_block_param = case from_block {
    "" -> "latest"
    _ -> from_block
  }
  let filter_params = [
    #("fromBlock", json.string(from_block_param)),
    ..filter_params
  ]

  // Add toBlock if provided, default to "latest"  
  let to_block_param = case to_block {
    "" -> "latest"
    _ -> to_block
  }
  let filter_params = [
    #("toBlock", json.string(to_block_param)),
    ..filter_params
  ]

  // Add address if provided
  let filter_params = case address {
    "" -> filter_params
    _ -> [#("address", json.string(address)), ..filter_params]
  }

  // Add topics if provided
  let filter_params = case topics {
    [] -> filter_params
    _ -> [#("topics", json.array(topics, json.string)), ..filter_params]
  }

  let filter_object = json.object(filter_params)
  let params = [filter_object]

  use response <- result.try(response_utils.make_json_request(
    rpc_url,
    rpc_types.EthGetLogs,
    params,
  ))

  // Parse the JSON response into a list of Log objects
  parse_logs_response(response)
}

// Parse JSON response into list of Log objects
pub fn parse_logs_response(
  response: json.Json,
) -> Result(List(eth_types.Log), rpc_types.GleethError) {
  let json_str = json.to_string(response)

  // Remove outer quotes if present (like other parsing functions)
  let clean_json_str = case
    string.starts_with(json_str, "\"") && string.ends_with(json_str, "\"")
  {
    True -> {
      json_str
      |> string.drop_start(1)
      |> string.drop_end(1)
      |> string.replace("\\\"", "\"")
    }
    False -> json_str
  }

  // Parse the array of log objects
  parse_log_array(clean_json_str)
}

// Parse JSON array of log objects
fn parse_log_array(
  json_str: String,
) -> Result(List(eth_types.Log), rpc_types.GleethError) {
  // Handle empty array case
  let trimmed = string.trim(json_str)
  case trimmed {
    "[]" -> Ok([])
    _ -> {
      // Extract log objects from array
      case extract_array_elements(trimmed) {
        Ok(log_objects) -> {
          // Parse each log object
          list.try_map(log_objects, parse_single_log)
        }
        Error(err) -> Error(err)
      }
    }
  }
}

// Extract individual objects from JSON array string
fn extract_array_elements(
  array_str: String,
) -> Result(List(String), rpc_types.GleethError) {
  let trimmed = string.trim(array_str)

  // Verify it's an array
  case string.starts_with(trimmed, "[") && string.ends_with(trimmed, "]") {
    False ->
      Error(rpc_types.ParseError("Expected JSON array for logs response"))
    True -> {
      // Remove brackets
      let content =
        trimmed
        |> string.drop_start(1)
        |> string.drop_end(1)
        |> string.trim()

      case content {
        "" -> Ok([])
        // Empty array
        _ -> split_array_objects(content)
      }
    }
  }
}

// Split array content into individual object strings
fn split_array_objects(
  content: String,
) -> Result(List(String), rpc_types.GleethError) {
  // This is complex because we need to split on commas that are outside of nested objects
  // We'll track brace nesting level
  split_objects_recursive(content, [], "", 0, False)
}

// Recursively split objects while tracking nesting level
fn split_objects_recursive(
  remaining: String,
  acc: List(String),
  current_object: String,
  brace_level: Int,
  in_string: Bool,
) -> Result(List(String), rpc_types.GleethError) {
  case string.pop_grapheme(remaining) {
    Error(_) -> {
      // End of string
      case string.trim(current_object) {
        "" -> Ok(list.reverse(acc))
        obj -> Ok(list.reverse([obj, ..acc]))
      }
    }
    Ok(#(char, rest)) -> {
      case char, in_string {
        "\"", False -> {
          // Starting a string
          split_objects_recursive(
            rest,
            acc,
            current_object <> char,
            brace_level,
            True,
          )
        }
        "\"", True -> {
          // Ending a string (unless escaped)
          case string.ends_with(current_object, "\\") {
            True ->
              split_objects_recursive(
                rest,
                acc,
                current_object <> char,
                brace_level,
                True,
              )
            False ->
              split_objects_recursive(
                rest,
                acc,
                current_object <> char,
                brace_level,
                False,
              )
          }
        }
        "{", False -> {
          // Opening brace outside string
          split_objects_recursive(
            rest,
            acc,
            current_object <> char,
            brace_level + 1,
            False,
          )
        }
        "}", False -> {
          // Closing brace outside string
          split_objects_recursive(
            rest,
            acc,
            current_object <> char,
            brace_level - 1,
            False,
          )
        }
        ",", False -> {
          // Comma outside string
          case brace_level {
            0 -> {
              // Top-level comma - split here
              let trimmed_obj = string.trim(current_object)
              case trimmed_obj {
                "" -> split_objects_recursive(rest, acc, "", 0, False)
                _ ->
                  split_objects_recursive(
                    rest,
                    [trimmed_obj, ..acc],
                    "",
                    0,
                    False,
                  )
              }
            }
            _ -> {
              // Comma inside nested object - keep it
              split_objects_recursive(
                rest,
                acc,
                current_object <> char,
                brace_level,
                False,
              )
            }
          }
        }
        _, _ -> {
          // Any other character
          split_objects_recursive(
            rest,
            acc,
            current_object <> char,
            brace_level,
            in_string,
          )
        }
      }
    }
  }
}

// Parse a single log object from JSON string
fn parse_single_log(
  log_json: String,
) -> Result(eth_types.Log, rpc_types.GleethError) {
  use address <- result.try(extract_string_field(log_json, "address"))
  use block_hash <- result.try(extract_string_field(log_json, "blockHash"))
  use block_number <- result.try(extract_string_field(log_json, "blockNumber"))
  use data <- result.try(extract_string_field(log_json, "data"))
  use log_index <- result.try(extract_string_field(log_json, "logIndex"))
  use transaction_hash <- result.try(extract_string_field(
    log_json,
    "transactionHash",
  ))
  use transaction_index <- result.try(extract_string_field(
    log_json,
    "transactionIndex",
  ))
  use removed <- result.try(extract_boolean_field(log_json, "removed"))
  use topics <- result.try(extract_topics_array(log_json))

  Ok(eth_types.Log(
    address: address,
    topics: topics,
    data: data,
    block_number: block_number,
    transaction_hash: transaction_hash,
    transaction_index: transaction_index,
    block_hash: block_hash,
    log_index: log_index,
    removed: removed,
  ))
}

// Extract boolean field from JSON
fn extract_boolean_field(
  json_str: String,
  field_name: String,
) -> Result(Bool, rpc_types.GleethError) {
  let pattern = "\"" <> field_name <> "\":"
  case string.split(json_str, pattern) {
    [_, rest, ..] -> {
      let trimmed = string.trim(rest)
      case { string.starts_with(trimmed, "true") } {
        True -> Ok(True)
        False -> {
          case string.starts_with(trimmed, "false") {
            True -> Ok(False)
            False ->
              Error(rpc_types.ParseError(
                "Expected boolean value for field: " <> field_name,
              ))
          }
        }
      }
    }
    _ ->
      Error(rpc_types.ParseError(
        "Field '" <> field_name <> "' not found in JSON",
      ))
  }
}

// Extract topics array from JSON log object
fn extract_topics_array(
  log_json: String,
) -> Result(List(String), rpc_types.GleethError) {
  let pattern = "\"topics\":"
  case string.split(log_json, pattern) {
    [_, rest, ..] -> {
      let trimmed = string.trim(rest)
      case string.starts_with(trimmed, "[") {
        True -> {
          // Find the matching closing bracket
          case find_array_end(trimmed, 0, 0) {
            Ok(end_pos) -> {
              let array_content = string.slice(trimmed, 0, end_pos + 1)
              parse_topics_array_content(array_content)
            }
            Error(err) -> Error(err)
          }
        }
        False -> Error(rpc_types.ParseError("Expected array for topics field"))
      }
    }
    _ -> Error(rpc_types.ParseError("Topics field not found in log JSON"))
  }
}

// Find the end position of a JSON array
fn find_array_end(
  str: String,
  pos: Int,
  bracket_count: Int,
) -> Result(Int, rpc_types.GleethError) {
  case string.length(str) > pos {
    False -> Error(rpc_types.ParseError("Unclosed array in topics"))
    True -> {
      case string.slice(str, pos, 1) {
        "[" -> find_array_end(str, pos + 1, bracket_count + 1)
        "]" -> {
          case bracket_count {
            1 -> Ok(pos)
            // Found matching closing bracket
            _ -> find_array_end(str, pos + 1, bracket_count - 1)
          }
        }
        _ -> find_array_end(str, pos + 1, bracket_count)
      }
    }
  }
}

// Parse topics array content into list of strings
fn parse_topics_array_content(
  array_str: String,
) -> Result(List(String), rpc_types.GleethError) {
  // Remove brackets
  let content =
    array_str
    |> string.drop_start(1)
    |> string.drop_end(1)
    |> string.trim()

  case content {
    "" -> Ok([])
    // Empty topics array
    _ -> {
      // Split on commas and parse each topic
      let topic_parts = string.split(content, ",")
      list.try_map(topic_parts, parse_single_topic)
    }
  }
}

// Parse a single topic (handle null values and quoted strings)
fn parse_single_topic(
  topic_str: String,
) -> Result(String, rpc_types.GleethError) {
  let trimmed = string.trim(topic_str)
  case trimmed {
    "null" -> Ok("")
    // Convert null to empty string
    _ -> {
      case
        string.starts_with(trimmed, "\"") && string.ends_with(trimmed, "\"")
      {
        True -> {
          // Remove quotes
          let unquoted =
            trimmed
            |> string.drop_start(1)
            |> string.drop_end(1)
          Ok(unquoted)
        }
        False ->
          Error(rpc_types.ParseError("Expected quoted string or null for topic"))
      }
    }
  }
}

// Extract a string field from JSON, handling quotes
fn extract_string_field(
  json_str: String,
  field_name: String,
) -> Result(String, rpc_types.GleethError) {
  let pattern = "\"" <> field_name <> "\":"

  let split_result = string.split(json_str, pattern)

  case split_result {
    [_, rest, ..] -> {
      // Handle 2 or more elements, take first occurrence
      let trimmed = string.trim(rest)
      case string.starts_with(trimmed, "\"") {
        True -> {
          let without_quote = string.drop_start(trimmed, 1)
          case string.split_once(without_quote, "\"") {
            Ok(#(value, _)) -> Ok(value)
            Error(_) ->
              Error(rpc_types.ParseError(
                "Malformed JSON string for field: " <> field_name,
              ))
          }
        }
        False -> {
          // Handle null values or other non-string values
          case string.starts_with(trimmed, "null") {
            True -> Ok("")
            False ->
              Error(rpc_types.ParseError(
                "Expected string value for field: " <> field_name,
              ))
          }
        }
      }
    }
    _ ->
      Error(rpc_types.ParseError(
        "Field '" <> field_name <> "' not found in JSON",
      ))
  }
}

// Extract a nullable string field (returns empty string for null)
fn extract_nullable_string_field(
  json_str: String,
  field_name: String,
) -> Result(String, rpc_types.GleethError) {
  let pattern = "\"" <> field_name <> "\":"
  case string.split(json_str, pattern) {
    [_, rest] -> {
      let trimmed = string.trim(rest)
      case string.starts_with(trimmed, "null") {
        True -> Ok("")
        // Return empty string for null values
        False -> extract_string_field(json_str, field_name)
      }
    }
    _ ->
      Error(rpc_types.ParseError(
        "Field '" <> field_name <> "' not found in JSON",
      ))
  }
}

// Extract an optional string field (returns empty string if field doesn't exist)
fn extract_optional_string_field(
  json_str: String,
  field_name: String,
) -> Result(String, rpc_types.GleethError) {
  let pattern = "\"" <> field_name <> "\":"
  case string.split(json_str, pattern) {
    [_, rest] -> {
      let trimmed = string.trim(rest)
      case string.starts_with(trimmed, "null") {
        True -> Ok("")
        // Return empty string for null values
        False -> extract_string_field(json_str, field_name)
      }
    }
    _ -> Ok("")
    // Return empty string if field doesn't exist at all
  }
}

// Extract transaction status from the status field
fn extract_status_field(
  json_str: String,
) -> Result(eth_types.TransactionStatus, rpc_types.GleethError) {
  let pattern = "\"status\":"
  case string.split(json_str, pattern) {
    [_, rest] -> {
      let trimmed = string.trim(rest)
      case
        string.starts_with(trimmed, "\"0x1\"")
        || string.starts_with(trimmed, "\"0x01\"")
      {
        True -> Ok(eth_types.Success)
        False ->
          case
            string.starts_with(trimmed, "\"0x0\"")
            || string.starts_with(trimmed, "\"0x00\"")
          {
            True -> Ok(eth_types.Failed)
            False -> Error(rpc_types.ParseError("Invalid status value"))
          }
      }
    }
    _ -> Error(rpc_types.ParseError("Status field not found in JSON"))
  }
}

// Extract logs array from transaction receipt JSON
fn extract_logs_field(
  json_str: String,
) -> Result(List(eth_types.Log), rpc_types.GleethError) {
  let pattern = "\"logs\":"
  case string.split(json_str, pattern) {
    [_, rest] -> {
      // Extract the logs array from the remaining JSON
      case extract_logs_array_from_receipt(rest) {
        Ok(logs_json_str) -> parse_log_array(logs_json_str)
        Error(err) -> Error(err)
      }
    }
    _ -> Error(rpc_types.ParseError("Logs field not found in JSON"))
  }
}

// Extract the logs array JSON string from transaction receipt JSON
fn extract_logs_array_from_receipt(
  remaining_json: String,
) -> Result(String, rpc_types.GleethError) {
  let trimmed = string.trim(remaining_json)

  // The logs field starts with [ and we need to find the matching ]
  case string.starts_with(trimmed, "[") {
    True -> {
      case extract_complete_array_from_json(trimmed) {
        Ok(array_str) -> Ok(array_str)
        Error(_) ->
          Error(rpc_types.ParseError(
            "Malformed logs array in transaction receipt",
          ))
      }
    }
    False ->
      Error(rpc_types.ParseError("Expected logs array to start with '['"))
  }
}

// Extract complete array from JSON, handling nested structures
fn extract_complete_array_from_json(json_str: String) -> Result(String, Nil) {
  extract_complete_array_recursive(json_str, 0, 0, "", False)
}

// Recursively extract array while tracking nesting and string context
fn extract_complete_array_recursive(
  remaining: String,
  index: Int,
  depth: Int,
  acc: String,
  in_string: Bool,
) -> Result(String, Nil) {
  case string.pop_grapheme(remaining) {
    Ok(#(char, rest)) -> {
      let new_acc = acc <> char
      case char, in_string {
        "\"", False ->
          extract_complete_array_recursive(
            rest,
            index + 1,
            depth,
            new_acc,
            True,
          )
        "\"", True ->
          extract_complete_array_recursive(
            rest,
            index + 1,
            depth,
            new_acc,
            False,
          )
        "[", False -> {
          let new_depth = case depth {
            0 -> 1
            // First opening bracket
            _ -> depth + 1
          }
          extract_complete_array_recursive(
            rest,
            index + 1,
            new_depth,
            new_acc,
            in_string,
          )
        }
        "]", False -> {
          case depth {
            1 -> Ok(new_acc)
            // Found the matching closing bracket
            _ ->
              extract_complete_array_recursive(
                rest,
                index + 1,
                depth - 1,
                new_acc,
                in_string,
              )
          }
        }
        _, _ ->
          extract_complete_array_recursive(
            rest,
            index + 1,
            depth,
            new_acc,
            in_string,
          )
      }
    }
    Error(_) -> {
      case depth {
        0 -> Ok(acc)
        // No more text, return what we have
        _ -> Error(Nil)
        // Unmatched brackets
      }
    }
  }
}
