//// Contract deployment helpers.
////
//// Build deployment transactions from bytecode and optional constructor
//// arguments, broadcast them, and extract the deployed contract address
//// from the receipt.
////
//// ## Examples
////
//// ```gleam
//// // Deploy with no constructor args
//// let assert Ok(address) =
////   deploy.deploy(provider, wallet, bytecode, "0x100000", 1)
////
//// // Deploy with constructor args
//// let assert Ok(address) =
////   deploy.deploy_with_args(
////     provider, wallet, bytecode,
////     [#(types.Uint(256), types.UintValue(1_000_000))],
////     "0x200000", 1,
////   )
//// ```

import gleam/bit_array
import gleam/result
import gleam/string
import gleeth/crypto/transaction
import gleeth/crypto/wallet
import gleeth/ethereum/abi/encode as abi_encode
import gleeth/ethereum/abi/types as abi_types
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types

/// Deploy a contract with no constructor arguments.
/// Returns the deployed contract address.
pub fn deploy(
  provider: Provider,
  w: wallet.Wallet,
  bytecode: String,
  gas_limit: String,
  chain_id: Int,
) -> Result(String, rpc_types.GleethError) {
  deploy_raw(provider, w, bytecode, gas_limit, chain_id)
}

/// Deploy a contract with ABI-encoded constructor arguments appended to the bytecode.
/// Returns the deployed contract address.
pub fn deploy_with_args(
  provider: Provider,
  w: wallet.Wallet,
  bytecode: String,
  constructor_args: List(#(abi_types.AbiType, abi_types.AbiValue)),
  gas_limit: String,
  chain_id: Int,
) -> Result(String, rpc_types.GleethError) {
  use encoded_args <- result.try(
    abi_encode.encode(constructor_args)
    |> result.map_error(rpc_types.AbiErr),
  )
  let args_hex = string.lowercase(bit_array.base16_encode(encoded_args))
  let full_data = append_hex(bytecode, args_hex)
  deploy_raw(provider, w, full_data, gas_limit, chain_id)
}

/// Build a deployment transaction, sign it, broadcast, wait for receipt,
/// and return the contract address.
fn deploy_raw(
  provider: Provider,
  w: wallet.Wallet,
  data: String,
  gas_limit: String,
  chain_id: Int,
) -> Result(String, rpc_types.GleethError) {
  let sender = wallet.get_address(w)
  use nonce <- result.try(methods.get_transaction_count(
    provider,
    sender,
    "pending",
  ))
  use gas_price <- result.try(methods.get_gas_price(provider))

  use tx <- result.try(
    transaction.create_legacy_transaction(
      "",
      "0x0",
      gas_limit,
      gas_price,
      nonce,
      data,
      chain_id,
    )
    |> result.map_error(rpc_types.TransactionErr),
  )
  use signed <- result.try(
    transaction.sign_transaction(tx, w)
    |> result.map_error(rpc_types.TransactionErr),
  )
  use tx_hash <- result.try(methods.send_raw_transaction(
    provider,
    signed.raw_transaction,
  ))
  use receipt <- result.try(methods.wait_for_receipt(provider, tx_hash))

  case receipt.contract_address {
    "" -> Error(rpc_types.ParseError("No contract address in receipt"))
    address -> Ok(address)
  }
}

/// Append hex data to bytecode, handling 0x prefixes.
fn append_hex(bytecode: String, args_hex: String) -> String {
  let base = case string.starts_with(bytecode, "0x") {
    True -> bytecode
    False -> "0x" <> bytecode
  }
  // args_hex should not have 0x prefix
  let args = case string.starts_with(args_hex, "0x") {
    True -> string.drop_start(args_hex, 2)
    False -> args_hex
  }
  base <> args
}
