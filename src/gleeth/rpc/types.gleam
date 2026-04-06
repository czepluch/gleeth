//// Core types for gleeth's JSON-RPC layer - request/response structures,
//// Ethereum method definitions, and the unified application error type.

import gleam/json
import gleeth/crypto/transaction
import gleeth/crypto/wallet
import gleeth/ethereum/abi/types as abi_types

/// A JSON-RPC 2.0 request to be sent to an Ethereum node.
pub type JsonRpcRequest {
  JsonRpcRequest(
    jsonrpc: String,
    method: String,
    params: List(json.Json),
    id: Int,
  )
}

/// A JSON-RPC 2.0 response received from an Ethereum node.
pub type JsonRpcResponse {
  JsonRpcResponse(
    jsonrpc: String,
    id: Int,
    result: Result(json.Json, JsonRpcError),
  )
}

/// The error object returned inside a JSON-RPC error response.
pub type JsonRpcError {
  JsonRpcError(code: Int, message: String, data: json.Json)
}

/// Supported Ethereum JSON-RPC method names.
pub type EthMethod {
  EthBlockNumber
  EthGetBalance
  EthCall
  EthGetTransactionByHash
  EthGetTransactionReceipt
  EthGetCode
  EthEstimateGas
  EthGetStorageAt
  EthGetLogs
  EthGetBlockByNumber
  EthGetBlockByHash
  EthChainId
  EthSendRawTransaction
  EthGetTransactionCount
  EthGasPrice
  EthMaxPriorityFeePerGas
  EthFeeHistory
}

/// Convert an EthMethod variant to its JSON-RPC method name string.
pub fn method_to_string(method: EthMethod) -> String {
  case method {
    EthBlockNumber -> "eth_blockNumber"
    EthGetBalance -> "eth_getBalance"
    EthCall -> "eth_call"
    EthGetTransactionByHash -> "eth_getTransactionByHash"
    EthGetTransactionReceipt -> "eth_getTransactionReceipt"
    EthGetCode -> "eth_getCode"
    EthEstimateGas -> "eth_estimateGas"
    EthGetStorageAt -> "eth_getStorageAt"
    EthGetLogs -> "eth_getLogs"
    EthGetBlockByNumber -> "eth_getBlockByNumber"
    EthGetBlockByHash -> "eth_getBlockByHash"
    EthChainId -> "eth_chainId"
    EthSendRawTransaction -> "eth_sendRawTransaction"
    EthGetTransactionCount -> "eth_getTransactionCount"
    EthGasPrice -> "eth_gasPrice"
    EthMaxPriorityFeePerGas -> "eth_maxPriorityFeePerGas"
    EthFeeHistory -> "eth_feeHistory"
  }
}

/// Unified error type for all gleeth operations. Commands return
/// `Result(Nil, GleethError)`, making this the single error channel
/// across the entire application.
pub type GleethError {
  /// The provided RPC URL is malformed or empty.
  InvalidRpcUrl(String)
  /// The provided Ethereum address fails validation (bad length, missing 0x prefix, etc.).
  InvalidAddress(String)
  /// The provided transaction or block hash fails validation.
  InvalidHash(String)
  /// The Ethereum node returned a JSON-RPC error response.
  RpcError(String)
  /// A network-level failure occurred (connection refused, timeout, DNS failure).
  NetworkError(String)
  /// Failed to parse a JSON-RPC response or decode a hex value.
  ParseError(String)
  /// Invalid or missing CLI configuration (missing RPC URL, bad flags).
  ConfigError(String)
  /// Wraps an ABI encoding/decoding error, preserving the original AbiError.
  AbiErr(abi_types.AbiError)
  /// Wraps a wallet operation error, preserving the original WalletError.
  WalletErr(wallet.WalletError)
  /// Wraps a transaction signing/building error, preserving the original TransactionError.
  TransactionErr(transaction.TransactionError)
}

/// Convert a `GleethError` to a human-readable message string.
pub fn error_to_string(error: GleethError) -> String {
  case error {
    InvalidRpcUrl(msg) -> "Invalid RPC URL: " <> msg
    InvalidAddress(msg) -> "Invalid address: " <> msg
    InvalidHash(msg) -> "Invalid hash: " <> msg
    RpcError(msg) -> "RPC error: " <> msg
    NetworkError(msg) -> "Network error: " <> msg
    ParseError(msg) -> "Parse error: " <> msg
    ConfigError(msg) -> "Configuration error: " <> msg
    AbiErr(err) -> "ABI error: " <> abi_error_message(err)
    WalletErr(err) -> "Wallet error: " <> wallet.error_to_string(err)
    TransactionErr(err) ->
      "Transaction error: " <> transaction.error_to_string(err)
  }
}

fn abi_error_message(err: abi_types.AbiError) -> String {
  case err {
    abi_types.EncodeError(msg) -> msg
    abi_types.DecodeError(msg) -> msg
    abi_types.TypeParseError(msg) -> msg
    abi_types.InvalidAbiJson(msg) -> msg
  }
}
