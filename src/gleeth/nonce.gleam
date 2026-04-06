//// Nonce manager for tracking and auto-incrementing transaction nonces.
////
//// Fetches the initial nonce from the network and increments locally on
//// each call to `next`, avoiding redundant RPC round-trips when sending
//// multiple transactions in sequence.

import gleam/option.{type Option, None, Some}
import gleam/result
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth/wei

/// Tracks the current nonce for an address.
/// Use `next` to get the next nonce and advance the counter.
pub type NonceManager {
  NonceManager(address: String, current: Option(Int), provider_url: String)
}

/// Create a new nonce manager for the given address.
/// Fetches the current pending nonce from the network.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(p) = provider.new("http://localhost:8545")
/// let address = wallet.get_address(w)
///
/// let assert Ok(nm) = nonce.new(p, address)
/// ```
pub fn new(
  provider: Provider,
  address: String,
) -> Result(NonceManager, rpc_types.GleethError) {
  use nonce_hex <- result.try(methods.get_transaction_count(
    provider,
    address,
    "pending",
  ))
  use nonce_int <- result.try(
    wei.to_int(nonce_hex)
    |> result.map_error(fn(msg) { rpc_types.ParseError(msg) }),
  )
  Ok(NonceManager(
    address: address,
    current: Some(nonce_int),
    provider_url: provider.rpc_url(provider),
  ))
}

/// Get the next nonce as a hex string and return an updated manager.
/// The first call returns the nonce fetched during `new`.
/// Subsequent calls increment locally without an RPC call.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(nm) = nonce.new(provider, address)
///
/// // First call returns the nonce fetched from the network
/// let assert Ok(#(nm, nonce_hex)) = nonce.next(nm)
/// // nonce_hex is e.g. "0x5"
///
/// // Second call increments locally - no RPC round-trip
/// let assert Ok(#(nm, next_hex)) = nonce.next(nm)
/// // next_hex is "0x6"
/// ```
pub fn next(
  manager: NonceManager,
) -> Result(#(NonceManager, String), rpc_types.GleethError) {
  case manager.current {
    Some(n) -> {
      let hex_nonce = wei.from_int(n)
      let updated = NonceManager(..manager, current: Some(n + 1))
      Ok(#(updated, hex_nonce))
    }
    None ->
      Error(rpc_types.ParseError(
        "Nonce manager not initialized - call new() first",
      ))
  }
}

/// Reset the nonce manager by re-fetching the nonce from the network.
/// Useful after a transaction fails or when the on-chain nonce may have
/// changed due to activity from another client.
///
/// ## Examples
///
/// ```gleam
/// // After a failed transaction, resync with the network
/// let assert Ok(nm) = nonce.reset(nm, provider)
///
/// // Continue sending with the correct nonce
/// let assert Ok(#(nm, nonce_hex)) = nonce.next(nm)
/// ```
pub fn reset(
  manager: NonceManager,
  provider: Provider,
) -> Result(NonceManager, rpc_types.GleethError) {
  use nonce_hex <- result.try(methods.get_transaction_count(
    provider,
    manager.address,
    "pending",
  ))
  use nonce_int <- result.try(
    wei.to_int(nonce_hex)
    |> result.map_error(fn(msg) { rpc_types.ParseError(msg) }),
  )
  Ok(
    NonceManager(
      ..manager,
      current: Some(nonce_int),
      provider_url: provider.rpc_url(provider),
    ),
  )
}
