import gleam/bit_array
import gleam/io
import gleam/result
import gleam/string
import gleeth/crypto/keccak
import gleeth/crypto/secp256k1
import gleeth/crypto/wallet

pub fn main() {
  io.println("")
  io.println("🔐 Gleeth Signature Recovery Demo")
  io.println(string.repeat("=", 40))
  io.println("")

  // Step 1: Create a wallet and sign a message
  io.println("Step 1: Creating wallet and signing message...")

  let private_key_hex =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  let message_text = "Hello, Gleeth signature recovery!"

  case wallet.from_private_key_hex(private_key_hex) {
    Ok(wallet_obj) -> {
      let wallet_address = wallet.get_address(wallet_obj)
      io.println("Wallet address: " <> wallet_address)
      io.println("Message: \"" <> message_text <> "\"")

      // Sign the message
      case
        wallet.sign_message(wallet_obj, bit_array.from_string(message_text))
      {
        Ok(signature) -> {
          let sig_hex = secp256k1.signature_to_hex(signature)
          io.println("Signature: " <> sig_hex)
          io.println("")

          // Step 2: Demonstrate recovery
          demo_recovery(message_text, signature, wallet_address)
        }
        Error(err) -> {
          io.println(
            "❌ Failed to sign message: " <> wallet.error_to_string(err),
          )
        }
      }
    }
    Error(err) -> {
      io.println("❌ Failed to create wallet: " <> wallet.error_to_string(err))
    }
  }
}

fn demo_recovery(
  message_text: String,
  signature: secp256k1.Signature,
  original_address: String,
) {
  let message_hash =
    keccak.keccak256_binary(bit_array.from_string(message_text))

  io.println("Step 2: Recovering public key from signature...")

  // Recover public key
  case secp256k1.recover_public_key(message_hash, signature) {
    Ok(recovered_public_key) -> {
      let pub_key_hex = secp256k1.public_key_to_hex(recovered_public_key)
      io.println("✅ Recovered public key: " <> pub_key_hex)

      // Recover address
      case secp256k1.recover_address(message_hash, signature) {
        Ok(recovered_address) -> {
          let recovered_addr_str =
            secp256k1.address_to_string(recovered_address)
          io.println("✅ Recovered address: " <> recovered_addr_str)

          // Verify they match
          case recovered_addr_str == original_address {
            True -> io.println("✅ SUCCESS: Recovered address matches original!")
            False -> io.println("❌ FAILED: Addresses don't match")
          }

          io.println("")

          // Step 3: Show all recovery candidates
          demo_candidates(message_hash, signature, original_address)
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

fn demo_candidates(
  message_hash: BitArray,
  signature: secp256k1.Signature,
  original_address: String,
) {
  io.println("Step 3: Finding all recovery candidates...")

  let secp256k1.Signature(r: r, s: s, recovery_id: original_recovery_id) =
    signature

  case secp256k1.recover_address_candidates(message_hash, r, s) {
    Ok(address_candidates) -> {
      io.println(
        "Found "
        <> string.inspect(list.length(address_candidates))
        <> " possible addresses:",
      )

      // Show each candidate with its recovery ID
      list.index_fold(address_candidates, Nil, fn(_, addr, idx) {
        let addr_str = secp256k1.address_to_string(addr)
        let is_correct = addr_str == original_address
        let marker = case is_correct {
          True -> " ⭐ (CORRECT - Recovery ID " <> string.inspect(idx) <> ")"
          False -> ""
        }
        io.println("  [" <> string.inspect(idx) <> "] " <> addr_str <> marker)
      })

      io.println("")
      io.println(
        "Original recovery ID was: " <> string.inspect(original_recovery_id),
      )

      // Step 4: Verify signature
      demo_verification(message_hash, signature, original_address)
    }
    Error(err) -> {
      io.println("❌ Failed to get recovery candidates: " <> err)
    }
  }
}

fn demo_verification(
  message_hash: BitArray,
  signature: secp256k1.Signature,
  original_address: String,
) {
  io.println("")
  io.println("Step 4: Signature verification...")

  // Test with correct address
  case
    secp256k1.verify_signature_recovery(
      message_hash,
      signature,
      original_address,
    )
  {
    Ok(is_valid) -> {
      let status = case is_valid {
        True -> "✅ VALID"
        False -> "❌ INVALID"
      }
      io.println("Verification with correct address: " <> status)
    }
    Error(err) -> {
      io.println("❌ Verification failed: " <> err)
    }
  }

  // Test with wrong address
  let wrong_address = "0x0000000000000000000000000000000000000000"
  case
    secp256k1.verify_signature_recovery(message_hash, signature, wrong_address)
  {
    Ok(is_valid) -> {
      let status = case is_valid {
        True -> "✅ VALID (unexpected!)"
        False -> "❌ INVALID (as expected)"
      }
      io.println("Verification with wrong address: " <> status)
    }
    Error(err) -> {
      io.println("❌ Verification failed: " <> err)
    }
  }

  io.println("")
  io.println("🎉 Signature recovery demo complete!")
  io.println("")
  io.println("What we demonstrated:")
  io.println("• Created a wallet and signed a message")
  io.println("• Recovered the public key from the signature")
  io.println("• Recovered the Ethereum address from the signature")
  io.println("• Found all possible recovery candidates")
  io.println("• Verified the signature against addresses")
  io.println("")
  io.println("This shows how Gleeth can recover signing information")
  io.println("from just a message and its signature - a core capability")
  io.println("for blockchain verification and wallet identification!")
}

import gleam/list
