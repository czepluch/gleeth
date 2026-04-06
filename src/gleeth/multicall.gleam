//// Multicall3 batching for efficient contract reads.
////
//// Batches multiple contract read calls into a single `eth_call` using the
//// canonical Multicall3 contract (deployed at the same address on all major
//// chains). This reduces RPC round trips when reading state from multiple
//// contracts.
////
//// ## Examples
////
//// ```gleam
//// // Read 3 balances in a single RPC call
//// let assert Ok(results) =
////   multicall.new()
////   |> multicall.add(usdc_address, balance_of_calldata_1)
////   |> multicall.add(usdc_address, balance_of_calldata_2)
////   |> multicall.add(dai_address, balance_of_calldata_3)
////   |> multicall.execute(provider)
//// ```

import gleam/bit_array
import gleam/list
import gleam/result
import gleam/string
import gleeth/ethereum/abi/decode as abi_decode
import gleeth/ethereum/abi/encode as abi_encode
import gleeth/ethereum/abi/types as abi_types
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex

/// Canonical Multicall3 address, deployed on all major EVM chains.
pub const multicall3_address = "0xcA11bde05977b3631167028862bE2a173976CA11"

/// A batch of calls to execute through Multicall3.
pub type Multicall {
  Multicall(calls: List(Call))
}

/// A single call within a multicall batch.
pub type Call {
  Call(target: String, calldata: String, allow_failure: Bool)
}

/// Result of a single call within a multicall batch.
pub type CallResult {
  CallSuccess(data: String)
  CallFailure(data: String)
}

/// Create an empty multicall batch.
pub fn new() -> Multicall {
  Multicall(calls: [])
}

/// Add a call that must succeed (reverts the whole batch on failure).
///
/// ## Examples
///
/// ```gleam
/// multicall.new()
/// |> multicall.add("0xA0b8...", "0x70a08231...")
/// ```
pub fn add(batch: Multicall, target: String, calldata: String) -> Multicall {
  Multicall(calls: [
    Call(target: target, calldata: calldata, allow_failure: False),
    ..batch.calls
  ])
}

/// Add a call that is allowed to fail without reverting the batch.
///
/// ## Examples
///
/// ```gleam
/// multicall.new()
/// |> multicall.try_add("0xA0b8...", "0x70a08231...")
/// ```
pub fn try_add(batch: Multicall, target: String, calldata: String) -> Multicall {
  Multicall(calls: [
    Call(target: target, calldata: calldata, allow_failure: True),
    ..batch.calls
  ])
}

/// Execute the multicall batch using `aggregate3`.
/// Returns one `CallResult` per call in the order they were added.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(results) =
///   multicall.new()
///   |> multicall.add(usdc, calldata1)
///   |> multicall.add(usdc, calldata2)
///   |> multicall.execute(provider)
/// ```
pub fn execute(
  batch: Multicall,
  provider: Provider,
) -> Result(List(CallResult), rpc_types.GleethError) {
  let calls = list.reverse(batch.calls)
  case calls {
    [] -> Ok([])
    _ -> {
      use calldata <- result.try(encode_aggregate3(calls))
      use result_hex <- result.try(methods.call_contract(
        provider,
        multicall3_address,
        calldata,
      ))
      decode_aggregate3_result(result_hex)
    }
  }
}

/// Execute using a custom Multicall3 address (for chains where it's deployed
/// at a non-standard address).
pub fn execute_at(
  batch: Multicall,
  provider: Provider,
  address: String,
) -> Result(List(CallResult), rpc_types.GleethError) {
  let calls = list.reverse(batch.calls)
  case calls {
    [] -> Ok([])
    _ -> {
      use calldata <- result.try(encode_aggregate3(calls))
      use result_hex <- result.try(methods.call_contract(
        provider,
        address,
        calldata,
      ))
      decode_aggregate3_result(result_hex)
    }
  }
}

// =============================================================================
// Encoding: aggregate3(Call3[])
// Call3 = (address target, bool allowFailure, bytes calldata)
// selector: 0x82ad56cb
// =============================================================================

fn encode_aggregate3(calls: List(Call)) -> Result(String, rpc_types.GleethError) {
  // Encode as: aggregate3((address,bool,bytes)[])
  // Each call is a tuple of (address, bool, bytes)
  let call_values =
    list.map(calls, fn(c) {
      let assert Ok(calldata_bytes) = hex.decode(c.calldata)
      abi_types.TupleValue([
        abi_types.AddressValue(c.target),
        abi_types.BoolValue(c.allow_failure),
        abi_types.BytesValue(calldata_bytes),
      ])
    })

  let call_type =
    abi_types.Tuple([abi_types.Address, abi_types.Bool, abi_types.Bytes])
  let array_type = abi_types.Array(call_type)

  case abi_encode.encode([#(array_type, abi_types.ArrayValue(call_values))]) {
    Ok(encoded) -> {
      // Prepend aggregate3 selector: 0x82ad56cb
      let encoded_hex = string.lowercase(bit_array.base16_encode(encoded))
      Ok("0x82ad56cb" <> encoded_hex)
    }
    Error(err) -> Error(rpc_types.AbiErr(err))
  }
}

// =============================================================================
// Decoding: returns (bool success, bytes returnData)[]
// =============================================================================

fn decode_aggregate3_result(
  result_hex: String,
) -> Result(List(CallResult), rpc_types.GleethError) {
  case hex.decode(result_hex) {
    Ok(bytes) -> {
      let result_type =
        abi_types.Array(abi_types.Tuple([abi_types.Bool, abi_types.Bytes]))
      case abi_decode.decode([result_type], bytes) {
        Ok([abi_types.ArrayValue(items)]) -> {
          Ok(
            list.map(items, fn(item) {
              case item {
                abi_types.TupleValue([
                  abi_types.BoolValue(success),
                  abi_types.BytesValue(data),
                ]) -> {
                  let data_hex =
                    "0x" <> string.lowercase(bit_array.base16_encode(data))
                  case success {
                    True -> CallSuccess(data_hex)
                    False -> CallFailure(data_hex)
                  }
                }
                _ -> CallFailure("0x")
              }
            }),
          )
        }
        Ok(_) ->
          Error(rpc_types.ParseError("Unexpected multicall result shape"))
        Error(err) -> Error(rpc_types.AbiErr(err))
      }
    }
    Error(_) -> Error(rpc_types.ParseError("Invalid hex in multicall result"))
  }
}
