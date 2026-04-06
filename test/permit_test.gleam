/// EIP-2612 permit signing tests.
import gleam/string
import gleeth/crypto/secp256k1
import gleeth/crypto/wallet
import gleeth/eip712
import gleeth/permit
import gleeunit/should

const test_private_key = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

const test_address = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

const spender = "0x70997970c51812dc3a010c7d01b50e0d17dc79c8"

// =============================================================================
// sign_with_domain (no RPC needed)
// =============================================================================

pub fn permit_sign_with_domain_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)

  let domain =
    eip712.domain()
    |> eip712.domain_name("USD Coin")
    |> eip712.domain_version("2")
    |> eip712.domain_chain_id(1)
    |> eip712.domain_verifying_contract(
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    )

  let assert Ok(sig) =
    permit.sign_with_domain(
      domain,
      test_address,
      spender,
      1_000_000,
      0,
      1_700_000_000,
      w,
    )

  // v should be 27 or 28
  case sig.v >= 27 && sig.v <= 28 {
    True -> Nil
    False -> should.fail()
  }

  // r and s should be hex strings
  string.starts_with(sig.r, "0x") |> should.be_true
  string.starts_with(sig.s, "0x") |> should.be_true

  // r and s should be 66 chars (0x + 64 hex)
  string.length(sig.r) |> should.equal(66)
  string.length(sig.s) |> should.equal(66)
}

pub fn permit_signature_is_deterministic_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)

  let domain =
    eip712.domain()
    |> eip712.domain_name("Test Token")
    |> eip712.domain_version("1")
    |> eip712.domain_chain_id(1)

  let assert Ok(sig1) =
    permit.sign_with_domain(domain, test_address, spender, 100, 0, 9_999_999, w)
  let assert Ok(sig2) =
    permit.sign_with_domain(domain, test_address, spender, 100, 0, 9_999_999, w)

  sig1.v |> should.equal(sig2.v)
  sig1.r |> should.equal(sig2.r)
  sig1.s |> should.equal(sig2.s)
}

pub fn permit_different_amounts_produce_different_signatures_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)

  let domain =
    eip712.domain()
    |> eip712.domain_name("Test Token")
    |> eip712.domain_version("1")
    |> eip712.domain_chain_id(1)

  let assert Ok(sig1) =
    permit.sign_with_domain(domain, test_address, spender, 100, 0, 9_999_999, w)
  let assert Ok(sig2) =
    permit.sign_with_domain(domain, test_address, spender, 200, 0, 9_999_999, w)

  // Different amounts should produce different signatures
  should.not_equal(sig1.r, sig2.r)
}

pub fn permit_recoverable_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)

  let domain =
    eip712.domain()
    |> eip712.domain_name("USD Coin")
    |> eip712.domain_version("2")
    |> eip712.domain_chain_id(1)
    |> eip712.domain_verifying_contract(
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    )

  let assert Ok(sig) =
    permit.sign_with_domain(
      domain,
      test_address,
      spender,
      1_000_000,
      0,
      1_700_000_000,
      w,
    )

  // Build the same typed data and recover the signer
  let types =
    gleam_dict.from_list([
      #("Permit", [
        eip712.field("owner", "address"),
        eip712.field("spender", "address"),
        eip712.field("value", "uint256"),
        eip712.field("nonce", "uint256"),
        eip712.field("deadline", "uint256"),
      ]),
    ])
  let message =
    gleam_dict.from_list([
      #("owner", eip712.address_val(test_address)),
      #("spender", eip712.address_val(spender)),
      #("value", eip712.int_val(1_000_000)),
      #("nonce", eip712.int_val(0)),
      #("deadline", eip712.int_val(1_700_000_000)),
    ])
  let data = eip712.typed_data(types, "Permit", domain, message)

  // Reconstruct signature hex from v, r, s
  let assert Ok(r_bytes) = gleeth_hex_decode(sig.r)
  let assert Ok(s_bytes) = gleeth_hex_decode(sig.s)
  let recovery_id = sig.v - 27
  let signature =
    secp256k1.Signature(r: r_bytes, s: s_bytes, recovery_id: recovery_id)
  let sig_hex = secp256k1.signature_to_hex(signature)

  let assert Ok(recovered) = eip712.recover_typed_data(data, sig_hex)
  string.lowercase(recovered) |> should.equal(test_address)
}

import gleam/bit_array
import gleam/dict as gleam_dict

fn gleeth_hex_decode(hex_string: String) -> Result(BitArray, Nil) {
  let clean = case string.starts_with(hex_string, "0x") {
    True -> string.drop_start(hex_string, 2)
    False -> hex_string
  }
  bit_array.base16_decode(string.uppercase(clean))
}
