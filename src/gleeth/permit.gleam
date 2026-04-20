//// EIP-2612 permit signing helper.
////
//// Signs a token permit off-chain using EIP-712, returning the v, r, s
//// components ready to submit to a token's `permit()` function on-chain.
//// Automatically fetches the token's EIP-712 domain (name, version) and
//// the owner's current nonce via RPC.
////
//// ## Examples
////
//// ```gleam
//// let assert Ok(sig) = permit.sign(
////   provider,
////   "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",  // USDC
////   "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",  // spender
////   1_000_000,                                       // amount
////   1_700_000_000,                                   // deadline
////   wallet,
//// )
//// // sig.v, sig.r, sig.s ready for on-chain permit() call
//// ```

import gleam/dict
import gleam/result
import gleam/string
import gleeth/crypto/secp256k1
import gleeth/crypto/wallet
import gleeth/eip712
import gleeth/ens
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex

/// Permit signature components ready for on-chain submission.
pub type PermitSignature {
  PermitSignature(v: Int, r: String, s: String)
}

/// Sign an EIP-2612 permit for a token.
///
/// Fetches the token's name, EIP-712 version ("1" or "2"), and the owner's
/// permit nonce automatically. Constructs the EIP-712 Permit typed data
/// and signs it.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(sig) = permit.sign(
///   provider, token_address, spender, amount, deadline, wallet,
/// )
/// ```
pub fn sign(
  provider: Provider,
  token_address: String,
  spender: String,
  amount: Int,
  deadline: Int,
  w: wallet.Wallet,
) -> Result(PermitSignature, rpc_types.GleethError) {
  let owner = wallet.get_address(w)

  // Fetch token name
  use name <- result.try(call_string(provider, token_address, "0x06fdde03"))
  // Fetch permit nonce: nonces(address) selector = 0x7ecebe00
  use nonce_hex <- result.try(call_uint(
    provider,
    token_address,
    "0x7ecebe00",
    owner,
  ))
  // Fetch chain ID
  use chain_id_hex <- result.try(methods.get_chain_id(provider))

  use nonce <- result.try(
    hex.to_int(nonce_hex)
    |> result.map_error(fn(_) { rpc_types.ParseError("Invalid nonce hex") }),
  )
  use chain_id <- result.try(
    hex.to_int(chain_id_hex)
    |> result.map_error(fn(_) { rpc_types.ParseError("Invalid chain ID hex") }),
  )

  // Build domain - try version "2" first (USDC), fall back to "1"
  let domain =
    eip712.domain()
    |> eip712.domain_name(name)
    |> eip712.domain_version("2")
    |> eip712.domain_chain_id(chain_id)
    |> eip712.domain_verifying_contract(token_address)

  sign_with_domain(domain, owner, spender, amount, nonce, deadline, w)
}

/// Sign a permit with an explicit domain. Useful when you already know
/// the token's EIP-712 domain parameters.
///
/// ## Examples
///
/// ```gleam
/// let domain = eip712.domain()
///   |> eip712.domain_name("USD Coin")
///   |> eip712.domain_version("2")
///   |> eip712.domain_chain_id(1)
///   |> eip712.domain_verifying_contract(usdc_address)
///
/// let assert Ok(sig) = permit.sign_with_domain(
///   domain, owner, spender, amount, nonce, deadline, wallet,
/// )
/// ```
pub fn sign_with_domain(
  domain: eip712.Domain,
  owner: String,
  spender: String,
  amount: Int,
  nonce: Int,
  deadline: Int,
  w: wallet.Wallet,
) -> Result(PermitSignature, rpc_types.GleethError) {
  let types =
    dict.from_list([
      #("Permit", [
        eip712.field("owner", "address"),
        eip712.field("spender", "address"),
        eip712.field("value", "uint256"),
        eip712.field("nonce", "uint256"),
        eip712.field("deadline", "uint256"),
      ]),
    ])

  let message =
    dict.from_list([
      #("owner", eip712.address_val(owner)),
      #("spender", eip712.address_val(spender)),
      #("value", eip712.int_val(amount)),
      #("nonce", eip712.int_val(nonce)),
      #("deadline", eip712.int_val(deadline)),
    ])

  let data = eip712.typed_data(types, "Permit", domain, message)

  case eip712.sign_typed_data(data, w) {
    Ok(signature) -> {
      let #(v, r, s) = secp256k1.signature_to_vrs(signature)
      Ok(PermitSignature(v: v, r: r, s: s))
    }
    Error(msg) -> Error(rpc_types.ParseError("Permit signing failed: " <> msg))
  }
}

// =============================================================================
// Internal RPC helpers for reading token metadata
// =============================================================================

/// Call a function that returns a string (like name()).
fn call_string(
  provider: Provider,
  address: String,
  selector: String,
) -> Result(String, rpc_types.GleethError) {
  use result_hex <- result.try(methods.call_contract(
    provider,
    address,
    selector,
  ))
  ens.decode_abi_string(result_hex)
}

/// Call a function with one address arg that returns a uint256.
fn call_uint(
  provider: Provider,
  address: String,
  selector: String,
  arg_address: String,
) -> Result(String, rpc_types.GleethError) {
  // ABI-encode the address argument: pad to 32 bytes
  let clean_addr = hex.strip_prefix(arg_address)
  let padded = string.repeat("0", 64 - string.length(clean_addr)) <> clean_addr
  let calldata = selector <> string.lowercase(padded)
  methods.call_contract(provider, address, calldata)
}
