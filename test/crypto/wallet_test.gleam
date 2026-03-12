import gleam/bit_array
import gleam/int
import gleeth/crypto/keccak
import gleeth/crypto/secp256k1
import gleeth/crypto/wallet
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

/// Test wallet creation from private key
pub fn wallet_creation_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  case wallet.from_private_key_hex(hex_key) {
    Ok(wallet_obj) -> {
      wallet.is_valid(wallet_obj) |> should.be_true()
      let address = wallet.get_address(wallet_obj)
      address |> should.equal("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
    }
    Error(_) -> should.fail()
  }
}

/// Test wallet creation with invalid key
pub fn wallet_invalid_key_test() {
  case wallet.from_private_key_hex("invalid") {
    Ok(_) -> should.fail()
    Error(_) -> Nil
  }
}

/// Test message signing
pub fn wallet_signing_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  case wallet.from_private_key_hex(hex_key) {
    Ok(wallet_obj) -> {
      case wallet.sign_personal_message(wallet_obj, "test message") {
        Ok(_signature) -> Nil
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

/// Test wallet info extraction
pub fn wallet_info_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  case wallet.from_private_key_hex(hex_key) {
    Ok(wallet_obj) -> {
      wallet.get_private_key_hex(wallet_obj) |> should.equal(hex_key)
      wallet.get_address(wallet_obj)
      |> should.equal("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
    }
    Error(_) -> should.fail()
  }
}

/// Test wallet signature recovery integration
pub fn wallet_signature_recovery_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  let message = bit_array.from_string("Wallet Recovery Test")

  case wallet.from_private_key_hex(hex_key) {
    Ok(wallet_obj) -> {
      let wallet_address = wallet.get_address(wallet_obj)

      case wallet.sign_message(wallet_obj, message) {
        Ok(signature) -> {
          let message_hash = keccak.keccak256_binary(message)

          // Test that we can recover the same address
          case secp256k1.recover_address(message_hash, signature) {
            Ok(recovered_address) -> {
              let recovered_str = secp256k1.address_to_string(recovered_address)
              recovered_str |> should.equal(wallet_address)
            }
            Error(_) -> should.fail()
          }
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

/// Test wallet personal message recovery
pub fn wallet_personal_message_recovery_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  let message_text = "Hello Wallet Recovery"

  case wallet.from_private_key_hex(hex_key) {
    Ok(wallet_obj) -> {
      let wallet_address = wallet.get_address(wallet_obj)

      case wallet.sign_personal_message(wallet_obj, message_text) {
        Ok(signature) -> {
          // Create the same message hash that personal message signing uses
          let message_bytes = bit_array.from_string(message_text)
          let message_length =
            bit_array.byte_size(message_bytes) |> int.to_string
          let prefix = "\\x19Ethereum Signed Message:\\n" <> message_length
          let prefix_bytes = bit_array.from_string(prefix)
          let full_message = bit_array.append(prefix_bytes, message_bytes)
          let message_hash = keccak.keccak256_binary(full_message)

          // Test signature recovery verification
          case
            secp256k1.verify_signature_recovery(
              message_hash,
              signature,
              wallet_address,
            )
          {
            Ok(is_valid) -> is_valid |> should.be_true()
            Error(_) -> should.fail()
          }
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}
