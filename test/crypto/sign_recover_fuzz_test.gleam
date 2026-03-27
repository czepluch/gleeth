/// Fuzz test: generate random private keys, sign messages, recover signer,
/// verify the recovered address matches the wallet address.
import gleam/string
import gleeth/crypto/random
import gleeth/crypto/secp256k1
import gleeth/crypto/wallet
import gleeunit/should
import qcheck

// =============================================================================
// Sign hash -> recover address cycle
// =============================================================================

pub fn fuzz_sign_recover_hash_cycle_test() {
  // Run 100 cycles with different random messages
  use seed <- qcheck.given(qcheck.bounded_int(from: 1, to: 1_000_000_000))

  // Generate a fresh private key for each iteration
  let assert Ok(private_key) = random.generate_private_key()
  let assert Ok(public_key) = secp256k1.create_public_key(private_key)
  let assert Ok(expected_address) = secp256k1.public_key_to_address(public_key)
  let expected_addr_str = secp256k1.address_to_string(expected_address)

  // Create a deterministic "message hash" from the seed (32 bytes)
  let hash_input = <<seed:256>>

  // Sign the hash
  let assert Ok(signature) =
    secp256k1.sign_message_hash(hash_input, private_key)

  // Recover the address
  let assert Ok(recovered_address) =
    secp256k1.recover_address(hash_input, signature)
  let recovered_str = secp256k1.address_to_string(recovered_address)

  // Must match
  string.lowercase(recovered_str)
  |> should.equal(string.lowercase(expected_addr_str))
}

// =============================================================================
// Sign personal message -> recover cycle via wallet module
// =============================================================================

pub fn fuzz_sign_recover_personal_message_cycle_test() {
  use message_seed <- qcheck.given(qcheck.bounded_int(from: 0, to: 1_000_000))

  // Generate fresh wallet
  let assert Ok(w) = wallet.generate()
  let address = wallet.get_address(w)

  // Create a message from the seed
  let message = "test message #" <> int_to_string(message_seed)

  // Sign with personal_sign
  let assert Ok(signature) = wallet.sign_personal_message(w, message)
  let sig_hex = secp256k1.signature_to_hex(signature)

  // Recover and verify
  let assert Ok(recovered) = wallet.recover_personal_message(message, sig_hex)

  string.lowercase(recovered)
  |> should.equal(string.lowercase(address))
}

// =============================================================================
// Verify: wrong message fails recovery
// =============================================================================

pub fn fuzz_wrong_message_fails_verify_test() {
  use seed <- qcheck.given(qcheck.bounded_int(from: 1, to: 1_000_000))

  let assert Ok(w) = wallet.generate()
  let address = wallet.get_address(w)

  let message = "original message " <> int_to_string(seed)
  let wrong_message = "wrong message " <> int_to_string(seed)

  let assert Ok(signature) = wallet.sign_personal_message(w, message)
  let sig_hex = secp256k1.signature_to_hex(signature)

  // Recovery with the wrong message should give a different address
  let assert Ok(recovered) =
    wallet.recover_personal_message(wrong_message, sig_hex)

  // Should NOT match (with overwhelming probability)
  string.lowercase(recovered)
  |> should.not_equal(string.lowercase(address))
}

import gleam/int

fn int_to_string(n: Int) -> String {
  int.to_string(n)
}
