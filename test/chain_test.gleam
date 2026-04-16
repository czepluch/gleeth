/// Chain registry tests.
import gleeth/chain
import gleeth/provider
import gleeunit/should

// =============================================================================
// Lookup by ID
// =============================================================================

pub fn by_id_mainnet_test() {
  let assert Ok(config) = chain.by_id(1)
  config.name |> should.equal("Ethereum Mainnet")
  config.native_currency |> should.equal("ETH")
  config.testnet |> should.equal(False)
}

pub fn by_id_arbitrum_test() {
  let assert Ok(config) = chain.by_id(42_161)
  config.name |> should.equal("Arbitrum One")
}

pub fn by_id_polygon_test() {
  let assert Ok(config) = chain.by_id(137)
  config.native_currency |> should.equal("POL")
}

pub fn by_id_sepolia_test() {
  let assert Ok(config) = chain.by_id(11_155_111)
  config.testnet |> should.equal(True)
}

pub fn by_id_unknown_test() {
  chain.by_id(99_999) |> should.be_error
}

// =============================================================================
// Lookup by name (case-insensitive + aliases)
// =============================================================================

pub fn by_name_full_test() {
  let assert Ok(config) = chain.by_name("Ethereum Mainnet")
  config.id |> should.equal(1)
}

pub fn by_name_alias_test() {
  let assert Ok(config) = chain.by_name("mainnet")
  config.id |> should.equal(1)
}

pub fn by_name_case_insensitive_test() {
  let assert Ok(config) = chain.by_name("ARBITRUM")
  config.id |> should.equal(42_161)
}

pub fn by_name_optimism_alias_test() {
  let assert Ok(config) = chain.by_name("op")
  config.id |> should.equal(10)
}

pub fn by_name_polygon_alias_test() {
  let assert Ok(config) = chain.by_name("matic")
  config.id |> should.equal(137)
}

pub fn by_name_base_test() {
  let assert Ok(config) = chain.by_name("base")
  config.id |> should.equal(8453)
}

pub fn by_name_unknown_test() {
  chain.by_name("nonexistent") |> should.be_error
}

// =============================================================================
// to_provider
// =============================================================================

pub fn to_provider_test() {
  let assert Ok(config) = chain.by_name("arbitrum")
  let assert Ok(p) = chain.to_provider(config)
  provider.rpc_url(p) |> should.equal("https://arb1.arbitrum.io/rpc")
}

// =============================================================================
// Custom registry
// =============================================================================

pub fn add_custom_chain_test() {
  let registry =
    chain.default_registry()
    |> chain.add(chain.ChainConfig(
      id: 56,
      name: "BNB Smart Chain",
      rpc_url: "https://bsc-dataseed.binance.org",
      explorer_url: "https://bscscan.com",
      native_currency: "BNB",
      testnet: False,
    ))

  let assert Ok(config) = chain.by_id_in(registry, 56)
  config.name |> should.equal("BNB Smart Chain")
  config.native_currency |> should.equal("BNB")
}
