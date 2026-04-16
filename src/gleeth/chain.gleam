//// Multi-chain configuration registry.
////
//// Pre-configured entries for common EVM networks with chain ID, name,
//// RPC URL, block explorer, and native currency. Data sourced from
//// ethereum-lists/chains (the canonical chain registry used by chainlist.org).
////
//// ## Examples
////
//// ```gleam
//// let assert Ok(config) = chain.by_name("arbitrum")
//// let assert Ok(p) = chain.to_provider(config)
////
//// // Or look up by chain ID
//// let assert Ok(config) = chain.by_id(137)
//// config.name  // "Polygon"
//// ```

import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import gleam/string
import gleeth/provider

/// Configuration for an EVM chain.
pub type ChainConfig {
  ChainConfig(
    /// Chain ID (e.g. 1 for mainnet, 42161 for Arbitrum).
    id: Int,
    /// Human-readable chain name.
    name: String,
    /// Default public RPC URL. Empty if none available.
    rpc_url: String,
    /// Block explorer URL. Empty if none.
    explorer_url: String,
    /// Native currency symbol (e.g. "ETH", "POL").
    native_currency: String,
    /// Whether this is a testnet.
    testnet: Bool,
  )
}

/// A chain registry. Start with `default_registry()` and add
/// custom chains with `add`.
pub type Registry {
  Registry(chains: Dict(Int, ChainConfig))
}

/// Look up a chain by ID from the default registry.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(config) = chain.by_id(1)
/// config.name  // "Ethereum Mainnet"
/// ```
pub fn by_id(id: Int) -> Result(ChainConfig, String) {
  by_id_in(default_registry(), id)
}

/// Look up a chain by name from the default registry (case-insensitive).
/// Matches against the full name or common short names.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(config) = chain.by_name("arbitrum")
/// config.id  // 42161
/// ```
pub fn by_name(name: String) -> Result(ChainConfig, String) {
  by_name_in(default_registry(), name)
}

/// Look up a chain by ID in a custom registry.
pub fn by_id_in(registry: Registry, id: Int) -> Result(ChainConfig, String) {
  dict.get(registry.chains, id)
  |> result.map_error(fn(_) { "Unknown chain ID: " <> string.inspect(id) })
}

/// Look up a chain by name in a custom registry (case-insensitive).
pub fn by_name_in(
  registry: Registry,
  name: String,
) -> Result(ChainConfig, String) {
  let lower = string.lowercase(name)
  let found =
    dict.values(registry.chains)
    |> list.find(fn(c) {
      string.lowercase(c.name) == lower || matches_alias(c, lower)
    })
  case found {
    Ok(config) -> Ok(config)
    Error(_) -> Error("Unknown chain: " <> name)
  }
}

/// Create a Provider from a chain config. Uses the chain's default RPC URL
/// with retry enabled and chain ID set.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(config) = chain.by_name("base")
/// let assert Ok(p) = chain.to_provider(config)
/// ```
pub fn to_provider(config: ChainConfig) -> Result(provider.Provider, String) {
  case config.rpc_url {
    "" -> Error("No RPC URL configured for " <> config.name)
    url ->
      case provider.new(url) {
        Ok(p) ->
          Ok(
            p
            |> provider.with_chain_id(config.id)
            |> provider.with_retry(provider.default_retry()),
          )
        Error(_) -> Error("Invalid RPC URL for " <> config.name)
      }
  }
}

/// Add a custom chain to a registry.
///
/// ## Examples
///
/// ```gleam
/// let registry = chain.default_registry()
///   |> chain.add(chain.ChainConfig(
///     id: 56, name: "BNB Smart Chain",
///     rpc_url: "https://bsc-dataseed.binance.org",
///     explorer_url: "https://bscscan.com",
///     native_currency: "BNB", testnet: False,
///   ))
/// ```
pub fn add(registry: Registry, config: ChainConfig) -> Registry {
  Registry(chains: dict.insert(registry.chains, config.id, config))
}

/// List all chains in a registry.
pub fn list(registry: Registry) -> List(ChainConfig) {
  dict.values(registry.chains)
}

/// The default registry with common EVM networks.
/// RPC URLs and metadata sourced from ethereum-lists/chains.
pub fn default_registry() -> Registry {
  Registry(
    chains: dict.from_list([
      #(
        1,
        ChainConfig(
          id: 1,
          name: "Ethereum Mainnet",
          rpc_url: "https://ethereum-rpc.publicnode.com",
          explorer_url: "https://etherscan.io",
          native_currency: "ETH",
          testnet: False,
        ),
      ),
      #(
        11_155_111,
        ChainConfig(
          id: 11_155_111,
          name: "Sepolia",
          rpc_url: "https://rpc.sepolia.org",
          explorer_url: "https://sepolia.etherscan.io",
          native_currency: "ETH",
          testnet: True,
        ),
      ),
      #(
        42_161,
        ChainConfig(
          id: 42_161,
          name: "Arbitrum One",
          rpc_url: "https://arb1.arbitrum.io/rpc",
          explorer_url: "https://arbiscan.io",
          native_currency: "ETH",
          testnet: False,
        ),
      ),
      #(
        10,
        ChainConfig(
          id: 10,
          name: "OP Mainnet",
          rpc_url: "https://mainnet.optimism.io",
          explorer_url: "https://optimistic.etherscan.io",
          native_currency: "ETH",
          testnet: False,
        ),
      ),
      #(
        137,
        ChainConfig(
          id: 137,
          name: "Polygon",
          rpc_url: "https://polygon.drpc.org",
          explorer_url: "https://polygonscan.com",
          native_currency: "POL",
          testnet: False,
        ),
      ),
      #(
        8453,
        ChainConfig(
          id: 8453,
          name: "Base",
          rpc_url: "https://mainnet.base.org",
          explorer_url: "https://basescan.org",
          native_currency: "ETH",
          testnet: False,
        ),
      ),
    ]),
  )
}

// =============================================================================
// Internal
// =============================================================================

/// Match common short names/aliases for chains.
fn matches_alias(config: ChainConfig, lower_name: String) -> Bool {
  case config.id {
    1 -> lower_name == "mainnet" || lower_name == "ethereum"
    11_155_111 -> lower_name == "sepolia"
    42_161 -> lower_name == "arbitrum"
    10 -> lower_name == "optimism" || lower_name == "op"
    137 -> lower_name == "polygon" || lower_name == "matic"
    8453 -> lower_name == "base"
    _ -> False
  }
}
