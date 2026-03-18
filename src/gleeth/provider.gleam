import gleam/option.{type Option, None}
import gleam/string
import gleeth/rpc/types as rpc_types

pub opaque type Provider {
  Provider(rpc_url: String, chain_id: Option(Int))
}

pub fn new(rpc_url: String) -> Result(Provider, rpc_types.GleethError) {
  case rpc_url {
    "" -> Error(rpc_types.InvalidRpcUrl("RPC URL cannot be empty"))
    _ -> {
      case
        string.starts_with(rpc_url, "http://")
        || string.starts_with(rpc_url, "https://")
      {
        True -> Ok(Provider(rpc_url:, chain_id: None))
        False ->
          Error(rpc_types.InvalidRpcUrl(
            "RPC URL must start with http:// or https://",
          ))
      }
    }
  }
}

pub fn rpc_url(provider: Provider) -> String {
  provider.rpc_url
}

pub fn chain_id(provider: Provider) -> Option(Int) {
  provider.chain_id
}

pub fn with_chain_id(provider: Provider, id: Int) -> Provider {
  Provider(..provider, chain_id: option.Some(id))
}

pub fn mainnet() -> Provider {
  Provider(rpc_url: "https://eth.llamarpc.com", chain_id: None)
}

pub fn sepolia() -> Provider {
  Provider(rpc_url: "https://ethereum-sepolia.publicnode.com", chain_id: None)
}
