import gleam/bit_array
import gleam/list
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

/// Test basic public key recovery
pub fn recovery_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  let message = bit_array.from_string("Hello Recovery")

  case secp256k1.private_key_from_hex(hex_key) {
    Ok(private_key) -> {
      case secp256k1.create_public_key(private_key) {
        Ok(original_public_key) -> {
          case secp256k1.sign_message(message, private_key) {
            Ok(signature) -> {
              let message_hash = keccak.keccak256_binary(message)
              case secp256k1.recover_public_key(message_hash, signature) {
                Ok(recovered_public_key) -> {
                  let original_hex =
                    secp256k1.public_key_to_hex(original_public_key)
                  let recovered_hex =
                    secp256k1.public_key_to_hex(recovered_public_key)
                  original_hex |> should.equal(recovered_hex)
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
    Error(_) -> should.fail()
  }
}

/// Test address recovery
pub fn address_recovery_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  let message = bit_array.from_string("Hello Address Recovery")

  case secp256k1.private_key_from_hex(hex_key) {
    Ok(private_key) -> {
      case secp256k1.private_key_to_address(private_key) {
        Ok(original_address) -> {
          case secp256k1.sign_message(message, private_key) {
            Ok(signature) -> {
              let message_hash = keccak.keccak256_binary(message)
              case secp256k1.recover_address(message_hash, signature) {
                Ok(recovered_address) -> {
                  let original_str =
                    secp256k1.address_to_string(original_address)
                  let recovered_str =
                    secp256k1.address_to_string(recovered_address)
                  original_str |> should.equal(recovered_str)
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
    Error(_) -> should.fail()
  }
}

/// Test signature recovery verification
pub fn signature_recovery_verification_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  let message = bit_array.from_string("Verify Recovery")
  let expected_address = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  case secp256k1.private_key_from_hex(hex_key) {
    Ok(private_key) -> {
      case secp256k1.sign_message(message, private_key) {
        Ok(signature) -> {
          let message_hash = keccak.keccak256_binary(message)
          case
            secp256k1.verify_signature_recovery(
              message_hash,
              signature,
              expected_address,
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

/// Test recovery with wrong address (should fail)
pub fn recovery_wrong_address_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  let message = bit_array.from_string("Wrong Address Test")
  let wrong_address = "0x0000000000000000000000000000000000000000"

  case secp256k1.private_key_from_hex(hex_key) {
    Ok(private_key) -> {
      case secp256k1.sign_message(message, private_key) {
        Ok(signature) -> {
          let message_hash = keccak.keccak256_binary(message)
          case
            secp256k1.verify_signature_recovery(
              message_hash,
              signature,
              wrong_address,
            )
          {
            Ok(is_valid) -> is_valid |> should.be_false()
            Error(_) -> should.fail()
          }
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

/// Test recovery candidates (multiple recovery IDs)
pub fn recovery_candidates_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  let message = bit_array.from_string("Candidates Test")

  case secp256k1.private_key_from_hex(hex_key) {
    Ok(private_key) -> {
      case secp256k1.create_public_key(private_key) {
        Ok(original_public_key) -> {
          case secp256k1.sign_message(message, private_key) {
            Ok(signature) -> {
              let secp256k1.Signature(r: r, s: s, recovery_id: _) = signature
              let message_hash = keccak.keccak256_binary(message)

              case secp256k1.recover_public_key_candidates(message_hash, r, s) {
                Ok(candidates) -> {
                  // Should have at least one candidate
                  { candidates != [] } |> should.be_true()

                  // One of the candidates should match our original key
                  let original_hex =
                    secp256k1.public_key_to_hex(original_public_key)
                  let candidate_hexes =
                    list.map(candidates, secp256k1.public_key_to_hex)
                  list.contains(candidate_hexes, original_hex)
                  |> should.be_true()
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
    Error(_) -> should.fail()
  }
}

/// Test finding recovery ID
pub fn find_recovery_id_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  let message = bit_array.from_string("Find Recovery ID Test")
  let expected_address = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  case secp256k1.private_key_from_hex(hex_key) {
    Ok(private_key) -> {
      case secp256k1.sign_message(message, private_key) {
        Ok(signature) -> {
          let secp256k1.Signature(r: r, s: s, recovery_id: original_recovery_id) =
            signature
          let message_hash = keccak.keccak256_binary(message)

          case
            secp256k1.find_recovery_id(message_hash, r, s, expected_address)
          {
            Ok(found_recovery_id) -> {
              found_recovery_id |> should.equal(original_recovery_id)
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

/// Test compact signature recovery
pub fn compact_recovery_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  let message = bit_array.from_string("Compact Recovery Test")

  case secp256k1.private_key_from_hex(hex_key) {
    Ok(private_key) -> {
      case secp256k1.create_public_key(private_key) {
        Ok(original_public_key) -> {
          case secp256k1.sign_message(message, private_key) {
            Ok(signature) -> {
              let compact_sig = secp256k1.signature_to_compact(signature)
              let secp256k1.Signature(recovery_id: recovery_id, ..) = signature
              let message_hash = keccak.keccak256_binary(message)

              // Extract r+s from compact signature (first 64 bytes)
              case bit_array.slice(compact_sig, 0, 64) {
                Ok(rs_bytes) -> {
                  case
                    secp256k1.recover_public_key_compact(
                      message_hash,
                      rs_bytes,
                      recovery_id,
                    )
                  {
                    Ok(recovered_public_key) -> {
                      let original_hex =
                        secp256k1.public_key_to_hex(original_public_key)
                      let recovered_hex =
                        secp256k1.public_key_to_hex(recovered_public_key)
                      original_hex |> should.equal(recovered_hex)
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
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}
