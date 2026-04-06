//// Provider is the main entry point for interacting with an Ethereum network.
//// It wraps a validated JSON-RPC URL and an optional chain ID, giving library
//// consumers a safe handle they can pass to RPC calls, contract interactions,
//// and transaction builders.
////
//// **Warning**: gleeth has not been audited. Recommended for testnet and
//// development use only.
////
//// Because `Provider` is opaque, the only way to construct one is through
//// `new`, `mainnet`, or `sepolia` - all of which guarantee the URL is valid.
////
//// ## Examples
////
//// ```gleam
//// let assert Ok(local) = provider.new("http://localhost:8545")
//// let url = provider.rpc_url(local)
////
//// let eth = provider.mainnet()
//// let eth = provider.with_chain_id(eth, 1)
//// ```

import gleam/option.{type Option, None}
import gleam/string
import gleeth/rpc/types as rpc_types

/// Retry configuration for transient RPC errors.
pub type RetryConfig {
  RetryConfig(
    /// Maximum number of retry attempts. 0 means no retries.
    max_retries: Int,
    /// Initial backoff in milliseconds before the first retry.
    initial_backoff_ms: Int,
    /// Maximum backoff in milliseconds (backoff is capped at this value).
    max_backoff_ms: Int,
  )
}

/// Default retry config: 3 retries, 1s initial backoff, 8s max.
pub fn default_retry() -> RetryConfig {
  RetryConfig(max_retries: 3, initial_backoff_ms: 1000, max_backoff_ms: 8000)
}

/// No retries - fail immediately on error.
pub fn no_retry() -> RetryConfig {
  RetryConfig(max_retries: 0, initial_backoff_ms: 0, max_backoff_ms: 0)
}

/// An opaque handle representing a connection to an Ethereum JSON-RPC endpoint.
///
/// Holds a validated RPC URL, an optional chain ID, and retry configuration.
/// Use `new` to create one from an arbitrary URL, or the convenience
/// constructors `mainnet` and `sepolia` for well-known networks.
pub opaque type Provider {
  Provider(rpc_url: String, chain_id: Option(Int), retry: RetryConfig)
}

/// Create a new provider from the given RPC URL.
///
/// The URL must be non-empty and start with `http://` or `https://`.
/// Returns `Error(InvalidRpcUrl(...))` if validation fails.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(p) = provider.new("http://localhost:8545")
/// let assert Error(_) = provider.new("")
/// let assert Error(_) = provider.new("ws://bad-scheme")
/// ```
pub fn new(rpc_url: String) -> Result(Provider, rpc_types.GleethError) {
  case rpc_url {
    "" -> Error(rpc_types.InvalidRpcUrl("RPC URL cannot be empty"))
    _ -> {
      case
        string.starts_with(rpc_url, "http://")
        || string.starts_with(rpc_url, "https://")
      {
        True -> Ok(Provider(rpc_url:, chain_id: None, retry: no_retry()))
        False ->
          Error(rpc_types.InvalidRpcUrl(
            "RPC URL must start with http:// or https://",
          ))
      }
    }
  }
}

/// Return the RPC URL held by this provider.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(p) = provider.new("http://localhost:8545")
/// provider.rpc_url(p)
/// // -> "http://localhost:8545"
/// ```
pub fn rpc_url(provider: Provider) -> String {
  provider.rpc_url
}

/// Return the chain ID if one has been set, or `None` otherwise.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(p) = provider.new("http://localhost:8545")
/// provider.chain_id(p)
/// // -> None
/// ```
pub fn chain_id(provider: Provider) -> Option(Int) {
  provider.chain_id
}

/// Return a new provider with the given chain ID attached.
///
/// This does not mutate the original provider - a fresh copy is returned.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(p) = provider.new("http://localhost:8545")
/// let p = provider.with_chain_id(p, 1)
/// provider.chain_id(p)
/// // -> Some(1)
/// ```
pub fn with_chain_id(provider: Provider, id: Int) -> Provider {
  Provider(..provider, chain_id: option.Some(id))
}

/// Convenience constructor for Ethereum mainnet using a public RPC endpoint.
///
/// ## Examples
///
/// ```gleam
/// let eth = provider.mainnet()
/// provider.rpc_url(eth)
/// // -> "https://eth.llamarpc.com"
/// ```
pub fn mainnet() -> Provider {
  Provider(
    rpc_url: "https://eth.llamarpc.com",
    chain_id: None,
    retry: default_retry(),
  )
}

/// Convenience constructor for the Sepolia testnet using a public RPC endpoint.
///
/// ## Examples
///
/// ```gleam
/// let sep = provider.sepolia()
/// provider.rpc_url(sep)
/// // -> "https://ethereum-sepolia.publicnode.com"
/// ```
pub fn sepolia() -> Provider {
  Provider(
    rpc_url: "https://ethereum-sepolia.publicnode.com",
    chain_id: None,
    retry: default_retry(),
  )
}

/// Attach retry configuration to the provider.
///
/// ## Examples
///
/// ```gleam
/// let p = provider.new("http://localhost:8545")
///   |> result.map(provider.with_retry(_, provider.default_retry()))
/// ```
pub fn with_retry(provider: Provider, config: RetryConfig) -> Provider {
  Provider(..provider, retry: config)
}

/// Get the retry configuration from the provider.
pub fn retry_config(provider: Provider) -> RetryConfig {
  provider.retry
}
