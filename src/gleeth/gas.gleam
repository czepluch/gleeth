//// Gas estimation helpers for legacy and EIP-1559 transactions.
////
//// These functions combine multiple RPC calls to produce a complete
//// gas estimate that can be passed directly to a transaction builder.

import gleam/list
import gleam/result
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex

/// Gas estimate for a legacy (pre-EIP-1559) transaction.
pub type LegacyGasEstimate {
  LegacyGasEstimate(gas_price: String, gas_limit: String)
}

/// Gas estimate for an EIP-1559 (Type 2) transaction.
pub type Eip1559GasEstimate {
  Eip1559GasEstimate(
    max_fee_per_gas: String,
    max_priority_fee_per_gas: String,
    gas_limit: String,
  )
}

/// Estimate gas for a legacy transaction by fetching gas price and gas limit.
///
/// Combines `eth_gasPrice` and `eth_estimateGas` into a single call.
/// The returned `LegacyGasEstimate` has `gas_price` and `gas_limit` as hex
/// strings, ready to pass to `transaction.create_legacy_transaction`.
///
/// ## Examples
///
/// ```gleam
/// let sender = wallet.get_address(w)
/// let to = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
///
/// let assert Ok(est) = gas.estimate_legacy(provider, sender, to, "0xde0b6b3a7640000", "0x")
///
/// // Use the estimate in a transaction
/// let assert Ok(tx) = transaction.create_legacy_transaction(
///   to, "0xde0b6b3a7640000", est.gas_limit, est.gas_price, nonce, "0x", 1,
/// )
/// ```
pub fn estimate_legacy(
  provider: Provider,
  from: String,
  to: String,
  value: String,
  data: String,
) -> Result(LegacyGasEstimate, rpc_types.GleethError) {
  use gas_price <- result.try(methods.get_gas_price(provider))
  use gas_limit <- result.try(methods.estimate_gas(
    provider,
    from,
    to,
    value,
    data,
  ))
  Ok(LegacyGasEstimate(gas_price: gas_price, gas_limit: gas_limit))
}

/// Estimate gas for an EIP-1559 transaction by fetching priority fee,
/// base fee from fee history, and gas limit.
/// Computes max_fee = 2 * base_fee + priority_fee.
///
/// ## Examples
///
/// ```gleam
/// let sender = wallet.get_address(w)
/// let to = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
///
/// let assert Ok(est) = gas.estimate_eip1559(provider, sender, to, "0xde0b6b3a7640000", "0x")
///
/// // Use the estimate in a Type 2 transaction
/// let assert Ok(tx) = transaction.create_eip1559_transaction(
///   to, "0xde0b6b3a7640000",
///   est.gas_limit, est.max_fee_per_gas, est.max_priority_fee_per_gas,
///   nonce, "0x", 1,
/// )
/// ```
pub fn estimate_eip1559(
  provider: Provider,
  from: String,
  to: String,
  value: String,
  data: String,
) -> Result(Eip1559GasEstimate, rpc_types.GleethError) {
  use priority_fee <- result.try(methods.get_max_priority_fee(provider))
  use fee_history <- result.try(
    methods.get_fee_history(provider, 1, "latest", []),
  )
  use gas_limit <- result.try(methods.estimate_gas(
    provider,
    from,
    to,
    value,
    data,
  ))

  // Get the last element of base_fee_per_gas (next block's base fee)
  use base_fee_hex <- result.try(
    list.last(fee_history.base_fee_per_gas)
    |> result.map_error(fn(_) {
      rpc_types.ParseError("Fee history returned empty base_fee_per_gas")
    }),
  )

  // Parse hex values to ints for arithmetic
  use base_fee_int <- result.try(
    hex.to_int(base_fee_hex)
    |> result.map_error(fn(_) {
      rpc_types.ParseError("Failed to parse base fee hex: " <> base_fee_hex)
    }),
  )
  use priority_fee_int <- result.try(
    hex.to_int(priority_fee)
    |> result.map_error(fn(_) {
      rpc_types.ParseError("Failed to parse priority fee hex: " <> priority_fee)
    }),
  )

  // max_fee = 2 * base_fee + priority_fee
  let max_fee_int = 2 * base_fee_int + priority_fee_int
  let max_fee_hex = hex.from_int(max_fee_int)

  Ok(Eip1559GasEstimate(
    max_fee_per_gas: max_fee_hex,
    max_priority_fee_per_gas: priority_fee,
    gas_limit: gas_limit,
  ))
}
