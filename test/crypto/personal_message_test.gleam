import gleam/string
import gleeth/crypto/secp256k1
import gleeth/crypto/wallet
import gleeunit/should

const test_private_key = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

const test_address = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

// =============================================================================
// Sign and recover roundtrip
// =============================================================================

pub fn sign_and_recover_personal_message_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let message = "Hello, Ethereum!"

  let assert Ok(signature) = wallet.sign_personal_message(w, message)
  let sig_hex = secp256k1.signature_to_hex(signature)

  let assert Ok(recovered) = wallet.recover_personal_message(message, sig_hex)

  recovered
  |> string.lowercase
  |> should.equal(test_address)
}

pub fn sign_and_verify_personal_message_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let message = "Sign-In with Ethereum"

  let assert Ok(signature) = wallet.sign_personal_message(w, message)
  let sig_hex = secp256k1.signature_to_hex(signature)

  let assert Ok(is_valid) =
    wallet.verify_personal_message(message, sig_hex, test_address)
  is_valid |> should.be_true
}

pub fn verify_wrong_address_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let message = "test message"

  let assert Ok(signature) = wallet.sign_personal_message(w, message)
  let sig_hex = secp256k1.signature_to_hex(signature)

  let wrong_address = "0x70997970c51812dc3a010c7d01b50e0d17dc79c8"
  let assert Ok(is_valid) =
    wallet.verify_personal_message(message, sig_hex, wrong_address)
  is_valid |> should.be_false
}

// =============================================================================
// Different message types
// =============================================================================

pub fn recover_empty_message_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let message = ""

  let assert Ok(signature) = wallet.sign_personal_message(w, message)
  let sig_hex = secp256k1.signature_to_hex(signature)

  let assert Ok(recovered) = wallet.recover_personal_message(message, sig_hex)

  recovered
  |> string.lowercase
  |> should.equal(test_address)
}

pub fn recover_long_message_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  // 200+ character message
  let message =
    "This is a very long message that exceeds the typical length of a personal sign request. It contains multiple sentences and is designed to test that the length prefix is computed correctly for messages over 100 characters."

  let assert Ok(signature) = wallet.sign_personal_message(w, message)
  let sig_hex = secp256k1.signature_to_hex(signature)

  let assert Ok(recovered) = wallet.recover_personal_message(message, sig_hex)

  recovered
  |> string.lowercase
  |> should.equal(test_address)
}

// =============================================================================
// signature_from_hex tests
// =============================================================================

pub fn signature_from_hex_roundtrip_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let assert Ok(signature) = wallet.sign_personal_message(w, "test")
  let hex = secp256k1.signature_to_hex(signature)

  let assert Ok(parsed) = secp256k1.signature_from_hex(hex)
  parsed.r |> should.equal(signature.r)
  parsed.s |> should.equal(signature.s)
  parsed.recovery_id |> should.equal(signature.recovery_id)
}

pub fn signature_from_hex_invalid_length_test() {
  secp256k1.signature_from_hex("0x1234")
  |> should.be_error
}

pub fn signature_from_hex_invalid_hex_test() {
  secp256k1.signature_from_hex("not valid hex")
  |> should.be_error
}
