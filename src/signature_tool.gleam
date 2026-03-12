import argv
import gleam/bit_array
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleeth/crypto/keccak
import gleeth/crypto/secp256k1
import gleeth/crypto/wallet
import gleeth/utils/hex

pub fn main() {
  case argv.load().arguments {
    ["recover", message, signature_hex] -> {
      recover_from_signature(message, signature_hex)
    }
    ["sign", private_key_hex, message] -> {
      sign_message_with_key(private_key_hex, message)
    }
    ["verify", message, signature_hex, address] -> {
      verify_signature_against_address(message, signature_hex, address)
    }
    ["candidates", message, signature_hex] -> {
      show_all_candidates(message, signature_hex)
    }
    ["demo"] -> {
      run_complete_demo()
    }
    _ -> {
      show_usage()
    }
  }
}

fn show_usage() {
  io.println("")
  io.println("🔐 Gleeth Signature Recovery Tool")
  io.println(string.repeat("=", 35))
  io.println("")
  io.println("COMMANDS:")
  io.println("")
  io.println("  demo")
  io.println("    Run a complete demonstration with sample data")
  io.println("")
  io.println("  sign <private_key> <message>")
  io.println("    Sign a message with a private key")
  io.println(
    "    Example: gleam run -m signature_tool sign 0xac09... \"Hello World\"",
  )
  io.println("")
  io.println("  recover <message> <signature>")
  io.println("    Recover address and public key from signature")
  io.println(
    "    Example: gleam run -m signature_tool recover \"Hello\" 0x1234...",
  )
  io.println("")
  io.println("  verify <message> <signature> <address>")
  io.println("    Verify if signature was created by address")
  io.println(
    "    Example: gleam run -m signature_tool verify \"Hello\" 0x1234... 0xf39f...",
  )
  io.println("")
  io.println("  candidates <message> <signature>")
  io.println("    Show all possible recovery candidates")
  io.println(
    "    Example: gleam run -m signature_tool candidates \"Hello\" 0x1234...",
  )
  io.println("")
}

fn recover_from_signature(message: String, signature_hex: String) {
  io.println("")
  io.println("🔍 Signature Recovery")
  io.println(string.repeat("-", 20))
  io.println("Message: \"" <> message <> "\"")
  io.println("Signature: " <> signature_hex)
  io.println("")

  case parse_signature(signature_hex) {
    Ok(signature) -> {
      let message_hash = keccak.keccak256_binary(bit_array.from_string(message))

      case secp256k1.recover_public_key(message_hash, signature) {
        Ok(public_key) -> {
          io.println("✅ Recovered Public Key:")
          io.println("   " <> secp256k1.public_key_to_hex(public_key))

          case secp256k1.recover_address(message_hash, signature) {
            Ok(address) -> {
              io.println("✅ Recovered Address:")
              io.println("   " <> secp256k1.address_to_string(address))
            }
            Error(err) -> {
              io.println("❌ Failed to recover address: " <> err)
            }
          }
        }
        Error(err) -> {
          io.println("❌ Failed to recover public key: " <> err)
        }
      }
    }
    Error(err) -> {
      io.println("❌ Invalid signature format: " <> err)
    }
  }
  io.println("")
}

fn sign_message_with_key(private_key_hex: String, message: String) {
  io.println("")
  io.println("✍️  Message Signing")
  io.println(string.repeat("-", 17))
  io.println("Private Key: " <> private_key_hex)
  io.println("Message: \"" <> message <> "\"")
  io.println("")

  case wallet.from_private_key_hex(private_key_hex) {
    Ok(wallet_obj) -> {
      let address = wallet.get_address(wallet_obj)
      io.println("Signing Address: " <> address)

      case wallet.sign_message(wallet_obj, bit_array.from_string(message)) {
        Ok(signature) -> {
          let sig_hex = secp256k1.signature_to_hex(signature)
          io.println("✅ Signature Created:")
          io.println("   " <> sig_hex)

          let #(v, r, s) = secp256k1.signature_to_vrs(signature)
          io.println("")
          io.println("Signature Components:")
          io.println("  v: " <> string.inspect(v))
          io.println("  r: " <> r)
          io.println("  s: " <> s)
        }
        Error(err) -> {
          io.println(
            "❌ Failed to sign message: " <> wallet.error_to_string(err),
          )
        }
      }
    }
    Error(err) -> {
      io.println("❌ Invalid private key: " <> wallet.error_to_string(err))
    }
  }
  io.println("")
}

fn verify_signature_against_address(
  message: String,
  signature_hex: String,
  address: String,
) {
  io.println("")
  io.println("✔️  Signature Verification")
  io.println(string.repeat("-", 23))
  io.println("Message: \"" <> message <> "\"")
  io.println("Signature: " <> signature_hex)
  io.println("Expected Address: " <> address)
  io.println("")

  case parse_signature(signature_hex) {
    Ok(signature) -> {
      let message_hash = keccak.keccak256_binary(bit_array.from_string(message))

      case
        secp256k1.verify_signature_recovery(message_hash, signature, address)
      {
        Ok(True) -> {
          io.println("✅ SIGNATURE VALID")
          io.println(
            "   The signature was created by the holder of " <> address,
          )
        }
        Ok(False) -> {
          io.println("❌ SIGNATURE INVALID")
          io.println(
            "   The signature was NOT created by the holder of " <> address,
          )

          // Show what address actually signed it
          case secp256k1.recover_address(message_hash, signature) {
            Ok(actual_address) -> {
              io.println(
                "   Actual signing address: "
                <> secp256k1.address_to_string(actual_address),
              )
            }
            Error(_) -> Nil
          }
        }
        Error(err) -> {
          io.println("❌ Verification failed: " <> err)
        }
      }
    }
    Error(err) -> {
      io.println("❌ Invalid signature format: " <> err)
    }
  }
  io.println("")
}

fn show_all_candidates(message: String, signature_hex: String) {
  io.println("")
  io.println("🎯 Recovery Candidates")
  io.println(string.repeat("-", 20))
  io.println("Message: \"" <> message <> "\"")
  io.println("Signature: " <> signature_hex)
  io.println("")

  case parse_signature(signature_hex) {
    Ok(signature) -> {
      let secp256k1.Signature(r: r, s: s, recovery_id: original_id) = signature
      let message_hash = keccak.keccak256_binary(bit_array.from_string(message))

      case secp256k1.recover_address_candidates(message_hash, r, s) {
        Ok(candidates) -> {
          io.println(
            "Found "
            <> string.inspect(list.length(candidates))
            <> " possible addresses:",
          )
          io.println("")

          list.index_fold(candidates, Nil, fn(_, addr, idx) {
            let addr_str = secp256k1.address_to_string(addr)
            let marker = case idx == original_id {
              True -> " ⭐ (Original Recovery ID)"
              False -> ""
            }
            io.println(
              "  [" <> string.inspect(idx) <> "] " <> addr_str <> marker,
            )
          })

          io.println("")
          io.println("Original recovery ID: " <> string.inspect(original_id))
        }
        Error(err) -> {
          io.println("❌ Failed to get candidates: " <> err)
        }
      }
    }
    Error(err) -> {
      io.println("❌ Invalid signature format: " <> err)
    }
  }
  io.println("")
}

fn run_complete_demo() {
  io.println("")
  io.println("🚀 Complete Signature Recovery Demo")
  io.println(string.repeat("=", 35))
  io.println("")

  // Sample data
  let private_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  let message = "Gleeth signature recovery demo!"

  io.println("Demo Setup:")
  io.println("Private Key: " <> private_key)
  io.println("Message: \"" <> message <> "\"")
  io.println("")

  case wallet.from_private_key_hex(private_key) {
    Ok(wallet_obj) -> {
      let wallet_address = wallet.get_address(wallet_obj)
      io.println("Wallet Address: " <> wallet_address)

      case wallet.sign_message(wallet_obj, bit_array.from_string(message)) {
        Ok(signature) -> {
          let sig_hex = secp256k1.signature_to_hex(signature)
          io.println("Generated Signature: " <> sig_hex)
          io.println("")

          // Now demonstrate recovery
          io.println("Step 1: Recovering from signature...")
          recover_from_signature(message, sig_hex)

          io.println("Step 2: Verifying signature...")
          verify_signature_against_address(message, sig_hex, wallet_address)

          io.println("Step 3: Finding all candidates...")
          show_all_candidates(message, sig_hex)

          io.println("🎉 Demo complete! Try the individual commands:")
          io.println(
            "  gleam run -m signature_tool recover \""
            <> message
            <> "\" "
            <> sig_hex,
          )
          io.println(
            "  gleam run -m signature_tool verify \""
            <> message
            <> "\" "
            <> sig_hex
            <> " "
            <> wallet_address,
          )
        }
        Error(err) -> {
          io.println("❌ Failed to sign: " <> wallet.error_to_string(err))
        }
      }
    }
    Error(err) -> {
      io.println("❌ Failed to create wallet: " <> wallet.error_to_string(err))
    }
  }
}

fn parse_signature(signature_hex: String) -> Result(secp256k1.Signature, String) {
  use signature_bytes <- result.try(hex.decode(signature_hex))

  case bit_array.byte_size(signature_bytes) {
    65 -> {
      use r <- result.try(
        bit_array.slice(signature_bytes, 0, 32)
        |> result.map_error(fn(_) { "Failed to extract r component" }),
      )

      use s <- result.try(
        bit_array.slice(signature_bytes, 32, 32)
        |> result.map_error(fn(_) { "Failed to extract s component" }),
      )

      use v_bytes <- result.try(
        bit_array.slice(signature_bytes, 64, 1)
        |> result.map_error(fn(_) { "Failed to extract v component" }),
      )

      case v_bytes {
        <<v>> -> {
          let recovery_id = case v {
            27 -> 0
            28 -> 1
            _ -> v - 27
            // Handle EIP-155 v values
          }
          Ok(secp256k1.Signature(r: r, s: s, recovery_id: recovery_id))
        }
        _ -> Error("Invalid v component format")
      }
    }
    _ -> Error("Signature must be 65 bytes (130 hex characters)")
  }
}
