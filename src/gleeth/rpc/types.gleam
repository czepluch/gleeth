import gleam/json

// JSON-RPC request structure
pub type JsonRpcRequest {
  JsonRpcRequest(
    jsonrpc: String,
    method: String,
    params: List(json.Json),
    id: Int,
  )
}

// JSON-RPC response structure
pub type JsonRpcResponse {
  JsonRpcResponse(
    jsonrpc: String,
    id: Int,
    result: Result(json.Json, JsonRpcError),
  )
}

// JSON-RPC error structure
pub type JsonRpcError {
  JsonRpcError(code: Int, message: String, data: json.Json)
}

// Ethereum RPC method names
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
  EthChainId
  EthSendRawTransaction
  EthGetTransactionCount
  EthGasPrice
  EthMaxPriorityFeePerGas
  EthFeeHistory
}

// Convert method to string
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
    EthChainId -> "eth_chainId"
    EthSendRawTransaction -> "eth_sendRawTransaction"
    EthGetTransactionCount -> "eth_getTransactionCount"
    EthGasPrice -> "eth_gasPrice"
    EthMaxPriorityFeePerGas -> "eth_maxPriorityFeePerGas"
    EthFeeHistory -> "eth_feeHistory"
  }
}

// Application errors
pub type GleethError {
  InvalidRpcUrl(String)
  InvalidAddress(String)
  InvalidHash(String)
  RpcError(String)
  NetworkError(String)
  ParseError(String)
  ConfigError(String)
}
