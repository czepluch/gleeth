import gleam/bit_array
import gleeth/crypto/keccak
import gleeth/crypto/secp256k1
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

/// Test private key creation and conversion
pub fn private_key_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  case secp256k1.private_key_from_hex(hex_key) {
    Ok(private_key) -> {
      let hex_result = secp256k1.private_key_to_hex(private_key)
      hex_result |> should.equal(hex_key)
    }
    Error(_) -> should.fail()
  }
}

/// Test public key generation
pub fn public_key_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  case secp256k1.private_key_from_hex(hex_key) {
    Ok(private_key) -> {
      case secp256k1.create_public_key(private_key) {
        Ok(public_key) -> {
          let pub_key_hex = secp256k1.public_key_to_hex(public_key)
          should.be_true(pub_key_hex != "")
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

/// Test address generation
pub fn address_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  case secp256k1.private_key_from_hex(hex_key) {
    Ok(private_key) -> {
      case secp256k1.private_key_to_address(private_key) {
        Ok(address) -> {
          let address_str = secp256k1.address_to_string(address)
          address_str
          |> should.equal("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

/// Test message signing
pub fn signing_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  let message = bit_array.from_string("test")

  case secp256k1.private_key_from_hex(hex_key) {
    Ok(private_key) -> {
      case secp256k1.sign_message(message, private_key) {
        Ok(signature) -> {
          let sig_hex = secp256k1.signature_to_hex(signature)
          should.be_true(sig_hex != "")
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

/// Test complete sign-and-verify cycle
pub fn sign_and_verify_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  let message = bit_array.from_string("Hello Ethereum")

  case secp256k1.private_key_from_hex(hex_key) {
    Ok(private_key) -> {
      case secp256k1.create_public_key(private_key) {
        Ok(public_key) -> {
          case secp256k1.sign_message(message, private_key) {
            Ok(signature) -> {
              // Get the message hash for verification
              let message_hash = keccak.keccak256_binary(message)
              case
                secp256k1.verify_signature(message_hash, signature, public_key)
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
    Error(_) -> should.fail()
  }
}

/// Test personal message signing (Ethereum standard)
pub fn personal_message_signing_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  let message = "Hello Ethereum"

  case secp256k1.private_key_from_hex(hex_key) {
    Ok(private_key) -> {
      case secp256k1.sign_personal_message(message, private_key) {
        Ok(signature) -> {
          let #(v, _r, _s) = secp256k1.signature_to_vrs(signature)
          case v {
            27 | 28 -> Nil
            // Valid recovery IDs
            _ -> should.fail()
          }
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}
