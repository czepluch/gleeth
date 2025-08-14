import gleam/string
import gleeth/rpc/types as rpc_types

// Configuration structure
pub type Config {
  Config(rpc_url: String)
}

// Create config from RPC URL
pub fn new(rpc_url: String) -> Result(Config, rpc_types.GleethError) {
  case validate_rpc_url(rpc_url) {
    Ok(url) -> Ok(Config(url))
    Error(err) -> Error(err)
  }
}

// Get RPC URL from config
pub fn get_rpc_url(config: Config) -> String {
  config.rpc_url
}

// Validate RPC URL format
fn validate_rpc_url(url: String) -> Result(String, rpc_types.GleethError) {
  case url {
    "" -> Error(rpc_types.InvalidRpcUrl("RPC URL cannot be empty"))
    _ -> {
      case starts_with_http(url) {
        True -> Ok(url)
        False -> Error(rpc_types.InvalidRpcUrl("RPC URL must start with http:// or https://"))
      }
    }
  }
}

// Check if URL starts with http or https
fn starts_with_http(url: String) -> Bool {
  string.starts_with(url, "http://") || string.starts_with(url, "https://")
}

// Default configuration for common networks
pub fn mainnet_config() -> Config {
  Config("https://eth.llamarpc.com")
}

pub fn sepolia_config() -> Config {
  Config("https://ethereum-sepolia.publicnode.com")
}