//// High-level contract interaction.
////
//// Binds a provider, address, and parsed ABI together so you can call
//// contract functions without manually encoding calldata or decoding results.
////
//// ## Examples
////
//// ```gleam
//// let assert Ok(abi) = json.parse_abi(erc20_abi_json)
//// let usdc = contract.at(provider, "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", abi)
////
//// // Read-only call
//// let assert Ok(values) = contract.call(usdc, "balanceOf", [
////   types.AddressVal("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"),
//// ])
////
//// // Write call (sends a transaction)
//// let assert Ok(tx_hash) = contract.send(usdc, wallet, "transfer", [
////   types.AddressVal("0x70997970C51812dc3A010C7d01b50e0d17dc79C8"),
////   types.UintValue(1_000_000),
//// ], "0x100000", chain_id)
//// ```

import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeth/crypto/transaction
import gleeth/crypto/wallet
import gleeth/ethereum/abi/decode as abi_decode
import gleeth/ethereum/abi/encode as abi_encode
import gleeth/ethereum/abi/json
import gleeth/ethereum/abi/types as abi_types
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex

/// A contract instance bound to a provider, address, and ABI.
pub type Contract {
  Contract(provider: Provider, address: String, abi: List(json.AbiEntry))
}

/// Create a contract instance.
pub fn at(
  provider: Provider,
  address: String,
  abi: List(json.AbiEntry),
) -> Contract {
  Contract(provider: provider, address: address, abi: abi)
}

/// Call a read-only function on the contract.
/// Encodes the arguments, calls `eth_call`, and decodes the return values.
pub fn call(
  contract: Contract,
  function_name: String,
  args: List(abi_types.AbiValue),
) -> Result(List(abi_types.AbiValue), rpc_types.GleethError) {
  use #(input_types, output_types) <- result.try(find_function_types(
    contract,
    function_name,
  ))
  let params = list.zip(input_types, args)

  use calldata <- result.try(encode_calldata(function_name, params))
  use result_hex <- result.try(methods.call_contract(
    contract.provider,
    contract.address,
    calldata,
  ))
  use decoded <- result.try(
    decode_output(output_types, result_hex)
    |> result.map_error(rpc_types.AbiErr),
  )
  Ok(decoded)
}

/// Send a write transaction to the contract.
/// Encodes the arguments, signs, broadcasts, and returns the transaction hash.
pub fn send(
  contract: Contract,
  w: wallet.Wallet,
  function_name: String,
  args: List(abi_types.AbiValue),
  gas_limit: String,
  chain_id: Int,
) -> Result(String, rpc_types.GleethError) {
  use #(input_types, _output_types) <- result.try(find_function_types(
    contract,
    function_name,
  ))
  let params = list.zip(input_types, args)

  use calldata <- result.try(encode_calldata(function_name, params))

  let sender = wallet.get_address(w)
  use nonce <- result.try(methods.get_transaction_count(
    contract.provider,
    sender,
    "pending",
  ))
  use gas_price <- result.try(methods.get_gas_price(contract.provider))

  use tx <- result.try(
    transaction.create_legacy_transaction(
      contract.address,
      "0x0",
      gas_limit,
      gas_price,
      nonce,
      calldata,
      chain_id,
    )
    |> result.map_error(rpc_types.TransactionErr),
  )
  use signed <- result.try(
    transaction.sign_transaction(tx, w)
    |> result.map_error(rpc_types.TransactionErr),
  )
  methods.send_raw_transaction(contract.provider, signed.raw_transaction)
}

/// Call a read-only function using string arguments that are auto-coerced
/// to the correct ABI types based on the function's ABI definition.
///
/// Addresses are passed as hex strings, integers as decimal strings or hex,
/// booleans as "true"/"false".
///
/// ## Examples
///
/// ```gleam
/// // Instead of: contract.call(c, "balanceOf", [AddressVal("0xf39f...")])
/// contract.call_raw(c, "balanceOf", ["0xf39f..."])
///
/// // Multiple args
/// contract.call_raw(c, "allowance", ["0xf39f...", "0x7099..."])
/// ```
pub fn call_raw(
  contract: Contract,
  function_name: String,
  args: List(String),
) -> Result(List(abi_types.AbiValue), rpc_types.GleethError) {
  use #(input_types, output_types) <- result.try(find_function_types(
    contract,
    function_name,
  ))
  use abi_args <- result.try(coerce_args(input_types, args))
  let params = list.zip(input_types, abi_args)

  use calldata <- result.try(encode_calldata(function_name, params))
  use result_hex <- result.try(methods.call_contract(
    contract.provider,
    contract.address,
    calldata,
  ))
  use decoded <- result.try(
    decode_output(output_types, result_hex)
    |> result.map_error(rpc_types.AbiErr),
  )
  Ok(decoded)
}

/// Send a write transaction using string arguments that are auto-coerced.
pub fn send_raw(
  contract: Contract,
  w: wallet.Wallet,
  function_name: String,
  args: List(String),
  gas_limit: String,
  chain_id: Int,
) -> Result(String, rpc_types.GleethError) {
  use #(input_types, _output_types) <- result.try(find_function_types(
    contract,
    function_name,
  ))
  use abi_args <- result.try(coerce_args(input_types, args))
  let params = list.zip(input_types, abi_args)

  use calldata <- result.try(encode_calldata(function_name, params))

  let sender = wallet.get_address(w)
  use nonce <- result.try(methods.get_transaction_count(
    contract.provider,
    sender,
    "pending",
  ))
  use gas_price <- result.try(methods.get_gas_price(contract.provider))

  use tx <- result.try(
    transaction.create_legacy_transaction(
      contract.address,
      "0x0",
      gas_limit,
      gas_price,
      nonce,
      calldata,
      chain_id,
    )
    |> result.map_error(rpc_types.TransactionErr),
  )
  use signed <- result.try(
    transaction.sign_transaction(tx, w)
    |> result.map_error(rpc_types.TransactionErr),
  )
  methods.send_raw_transaction(contract.provider, signed.raw_transaction)
}

// =============================================================================
// Internal helpers
// =============================================================================

/// Coerce string arguments to ABI values based on the expected types.
fn coerce_args(
  types: List(abi_types.AbiType),
  args: List(String),
) -> Result(List(abi_types.AbiValue), rpc_types.GleethError) {
  case list.length(types) == list.length(args) {
    False ->
      Error(rpc_types.ParseError(
        "Expected "
        <> int.to_string(list.length(types))
        <> " arguments, got "
        <> int.to_string(list.length(args)),
      ))
    True ->
      list.zip(types, args)
      |> list.try_map(fn(pair) {
        let #(type_, value) = pair
        coerce_value(type_, value)
      })
  }
}

fn coerce_value(
  type_: abi_types.AbiType,
  value: String,
) -> Result(abi_types.AbiValue, rpc_types.GleethError) {
  case type_ {
    abi_types.Address -> Ok(abi_types.AddressValue(value))
    abi_types.Bool ->
      case string.lowercase(value) {
        "true" | "1" -> Ok(abi_types.BoolValue(True))
        "false" | "0" -> Ok(abi_types.BoolValue(False))
        _ -> Error(rpc_types.ParseError("Cannot parse bool: " <> value))
      }
    abi_types.String -> Ok(abi_types.StringValue(value))
    abi_types.Uint(_) -> parse_int_value(value)
    abi_types.Int(_) -> parse_int_value(value)
    abi_types.FixedBytes(size) -> {
      case hex.decode(value) {
        Ok(bytes) -> {
          let pad_size = size - bit_array.byte_size(bytes)
          case pad_size >= 0 {
            True -> {
              let padding = make_zeros(pad_size)
              Ok(abi_types.FixedBytesValue(bit_array.concat([bytes, padding])))
            }
            False -> Error(rpc_types.ParseError("bytes value too long"))
          }
        }
        Error(_) ->
          Error(rpc_types.ParseError("Invalid hex for bytes: " <> value))
      }
    }
    abi_types.Bytes -> {
      case hex.decode(value) {
        Ok(bytes) -> Ok(abi_types.BytesValue(bytes))
        Error(_) ->
          Error(rpc_types.ParseError("Invalid hex for bytes: " <> value))
      }
    }
    _ ->
      Error(rpc_types.ParseError(
        "Unsupported type for string coercion: " <> abi_types.to_string(type_),
      ))
  }
}

fn parse_int_value(
  value: String,
) -> Result(abi_types.AbiValue, rpc_types.GleethError) {
  case int.parse(value) {
    Ok(n) -> Ok(abi_types.UintValue(n))
    Error(_) ->
      case hex.to_int(value) {
        Ok(n) -> Ok(abi_types.UintValue(n))
        Error(_) ->
          Error(rpc_types.ParseError("Cannot parse integer: " <> value))
      }
  }
}

fn make_zeros(n: Int) -> BitArray {
  case n <= 0 {
    True -> <<>>
    False -> make_zeros_acc(n, <<>>)
  }
}

fn make_zeros_acc(n: Int, acc: BitArray) -> BitArray {
  case n <= 0 {
    True -> acc
    False -> make_zeros_acc(n - 1, <<acc:bits, 0:8>>)
  }
}

fn find_function_types(
  contract: Contract,
  name: String,
) -> Result(
  #(List(abi_types.AbiType), List(abi_types.AbiType)),
  rpc_types.GleethError,
) {
  case json.find_function(contract.abi, name) {
    Ok(json.FunctionEntry(_, inputs, outputs, _)) -> {
      let input_types = list.map(inputs, fn(p: json.AbiParam) { p.type_ })
      let output_types = list.map(outputs, fn(p: json.AbiParam) { p.type_ })
      Ok(#(input_types, output_types))
    }
    Ok(_) ->
      Error(rpc_types.ParseError("Expected function entry for: " <> name))
    Error(err) -> Error(rpc_types.AbiErr(err))
  }
}

fn encode_calldata(
  function_name: String,
  params: List(#(abi_types.AbiType, abi_types.AbiValue)),
) -> Result(String, rpc_types.GleethError) {
  case abi_encode.encode_call(function_name, params) {
    Ok(bytes) -> Ok("0x" <> string.lowercase(bit_array.base16_encode(bytes)))
    Error(err) -> Error(rpc_types.AbiErr(err))
  }
}

fn decode_output(
  output_types: List(abi_types.AbiType),
  hex_data: String,
) -> Result(List(abi_types.AbiValue), abi_types.AbiError) {
  case output_types {
    [] -> Ok([])
    types -> {
      case gleeth_hex_decode(hex_data) {
        Ok(bytes) -> abi_decode.decode(types, bytes)
        Error(_) -> Error(abi_types.DecodeError("Invalid hex in response"))
      }
    }
  }
}

fn gleeth_hex_decode(hex_string: String) -> Result(BitArray, Nil) {
  let clean = case string.starts_with(hex_string, "0x") {
    True -> string.drop_start(hex_string, 2)
    False -> hex_string
  }
  bit_array.base16_decode(string.uppercase(clean))
}
