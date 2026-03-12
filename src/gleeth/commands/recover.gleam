import gleam/bit_array
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleeth/crypto/keccak
import gleeth/crypto/secp256k1
import gleeth/utils/hex

/// Options for signature recovery command
pub type RecoverOptions {
  RecoverOptions(
    message: String,
    signature: String,
    // Hex signature (r+s+v format)
    recovery_mode: RecoveryMode,
    format: OutputFormat,
  )
}

pub type RecoveryMode {
  RecoverPublicKey
  RecoverAddress
  RecoverCandidates
  VerifyAddress(expected: String)
}

pub type OutputFormat {
  Compact
  Detailed
  Json
}

/// Recovery result for output
pub type RecoveryResult {
  PublicKeyResult(public_key: String)
  AddressResult(address: String)
  CandidatesResult(
    public_keys: List(String),
    addresses: List(String),
    recovery_ids: List(Int),
  )
  VerificationResult(is_valid: Bool, recovered_address: String)
}

// =============================================================================
// Main Recovery Function
// =============================================================================

/// Execute signature recovery with given options
pub fn execute_recovery(options: RecoverOptions) -> Result(String, String) {
  use message_hash <- result.try(prepare_message_hash(options.message))
  use signature <- result.try(parse_signature(options.signature))

  case options.recovery_mode {
    RecoverPublicKey -> {
      use public_key <- result.try(secp256k1.recover_public_key(
        message_hash,
        signature,
      ))
      let result = PublicKeyResult(secp256k1.public_key_to_hex(public_key))
      format_output(result, options.format)
    }

    RecoverAddress -> {
      use address <- result.try(secp256k1.recover_address(
        message_hash,
        signature,
      ))
      let result = AddressResult(secp256k1.address_to_string(address))
      format_output(result, options.format)
    }

    RecoverCandidates -> {
      let secp256k1.Signature(r: r, s: s, recovery_id: _) = signature
      use public_keys <- result.try(secp256k1.recover_public_key_candidates(
        message_hash,
        r,
        s,
      ))
      use addresses <- result.try(secp256k1.recover_address_candidates(
        message_hash,
        r,
        s,
      ))

      let recovery_ids = [0, 1, 2, 3]
      let public_key_hexes = list.map(public_keys, secp256k1.public_key_to_hex)
      let address_strings = list.map(addresses, secp256k1.address_to_string)

      let result =
        CandidatesResult(
          public_keys: public_key_hexes,
          addresses: address_strings,
          recovery_ids: recovery_ids,
        )
      format_output(result, options.format)
    }

    VerifyAddress(expected) -> {
      use is_valid <- result.try(secp256k1.verify_signature_recovery(
        message_hash,
        signature,
        expected,
      ))
      use recovered_address <- result.try(secp256k1.recover_address(
        message_hash,
        signature,
      ))

      let result =
        VerificationResult(
          is_valid: is_valid,
          recovered_address: secp256k1.address_to_string(recovered_address),
        )
      format_output(result, options.format)
    }
  }
}

// =============================================================================
// Message and Signature Processing
// =============================================================================

/// Prepare message hash from input string
/// Supports both raw messages and pre-hashed inputs
fn prepare_message_hash(message: String) -> Result(BitArray, String) {
  case string.starts_with(message, "0x") && string.length(message) == 66 {
    // Already a hash
    True -> {
      use hash_bytes <- result.try(hex.decode(message))
      case bit_array.byte_size(hash_bytes) {
        32 -> Ok(hash_bytes)
        _ -> Error("Hash must be exactly 32 bytes")
      }
    }
    // Raw message - need to hash it
    False -> {
      let message_bytes = bit_array.from_string(message)
      Ok(keccak.keccak256_binary(message_bytes))
    }
  }
}

/// Parse signature from hex string into Signature type
fn parse_signature(signature_hex: String) -> Result(secp256k1.Signature, String) {
  use signature_bytes <- result.try(hex.decode(signature_hex))

  case bit_array.byte_size(signature_bytes) {
    65 -> {
      // Standard 65-byte signature (r+s+v)
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

    64 -> {
      // 64-byte signature (r+s only, recovery_id must be provided separately)
      Error(
        "64-byte signature requires separate recovery ID. Use 65-byte format (r+s+v) or specify recovery ID.",
      )
    }

    _ -> Error("Signature must be 65 bytes (r+s+v format)")
  }
}

// =============================================================================
// Output Formatting
// =============================================================================

/// Format recovery results for output
fn format_output(
  result: RecoveryResult,
  format: OutputFormat,
) -> Result(String, String) {
  case format {
    Compact -> format_compact(result)
    Detailed -> format_detailed(result)
    Json -> format_json(result)
  }
}

/// Compact output format
fn format_compact(result: RecoveryResult) -> Result(String, String) {
  case result {
    PublicKeyResult(public_key) -> Ok(public_key)
    AddressResult(address) -> Ok(address)
    CandidatesResult(public_keys: keys, addresses: addrs, recovery_ids: _) -> {
      let combined = list.zip(keys, addrs)
      let lines =
        list.map(combined, fn(pair) {
          let #(key, addr) = pair
          key <> " -> " <> addr
        })
      Ok(string.join(lines, "\n"))
    }
    VerificationResult(is_valid: valid, recovered_address: addr) -> {
      let status = case valid {
        True -> "VALID"
        False -> "INVALID"
      }
      Ok(status <> " -> " <> addr)
    }
  }
}

/// Detailed output format
fn format_detailed(result: RecoveryResult) -> Result(String, String) {
  case result {
    PublicKeyResult(public_key) -> {
      Ok("Recovered Public Key:\n" <> public_key)
    }

    AddressResult(address) -> {
      Ok("Recovered Address:\n" <> address)
    }

    CandidatesResult(public_keys: keys, addresses: addrs, recovery_ids: ids) -> {
      let header = "Recovery Candidates:\n" <> string.repeat("=", 50) <> "\n"

      let candidates = zip3(ids, keys, addrs)
      let lines =
        list.map(candidates, fn(candidate) {
          let #(id, key, addr) = candidate
          "Recovery ID "
          <> string.inspect(id)
          <> ":\n"
          <> "  Public Key: "
          <> key
          <> "\n"
          <> "  Address:    "
          <> addr
          <> "\n"
        })

      Ok(header <> string.join(lines, "\n"))
    }

    VerificationResult(is_valid: valid, recovered_address: addr) -> {
      let status = case valid {
        True -> "✓ SIGNATURE VALID"
        False -> "✗ SIGNATURE INVALID"
      }
      Ok(
        "Signature Verification Result:\n"
        <> status
        <> "\n"
        <> "Recovered Address: "
        <> addr,
      )
    }
  }
}

/// JSON output format
fn format_json(result: RecoveryResult) -> Result(String, String) {
  case result {
    PublicKeyResult(public_key) -> {
      Ok("{\"type\":\"public_key\",\"result\":\"" <> public_key <> "\"}")
    }

    AddressResult(address) -> {
      Ok("{\"type\":\"address\",\"result\":\"" <> address <> "\"}")
    }

    CandidatesResult(public_keys: keys, addresses: addrs, recovery_ids: ids) -> {
      let candidates = zip3(ids, keys, addrs)
      let candidate_jsons =
        list.map(candidates, fn(candidate) {
          let #(id, key, addr) = candidate
          "{\"recovery_id\":"
          <> string.inspect(id)
          <> ",\"public_key\":\""
          <> key
          <> "\""
          <> ",\"address\":\""
          <> addr
          <> "\"}"
        })

      Ok(
        "{\"type\":\"candidates\",\"results\":["
        <> string.join(candidate_jsons, ",")
        <> "]}",
      )
    }

    VerificationResult(is_valid: valid, recovered_address: addr) -> {
      let valid_str = case valid {
        True -> "true"
        False -> "false"
      }
      Ok(
        "{\"type\":\"verification\",\"is_valid\":"
        <> valid_str
        <> ",\"recovered_address\":\""
        <> addr
        <> "\"}",
      )
    }
  }
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Create a list of tuples from three lists (zip3 implementation)
fn zip3(list1: List(a), list2: List(b), list3: List(c)) -> List(#(a, b, c)) {
  case list1, list2, list3 {
    [a, ..rest_a], [b, ..rest_b], [c, ..rest_c] -> [
      #(a, b, c),
      ..zip3(rest_a, rest_b, rest_c)
    ]
    _, _, _ -> []
  }
}

// =============================================================================
// Validation and Error Handling
// =============================================================================

/// Validate recovery options
pub fn validate_options(options: RecoverOptions) -> Result(Nil, String) {
  // Validate message
  use _ <- result.try(case string.is_empty(options.message) {
    True -> Error("Message cannot be empty")
    False -> Ok(Nil)
  })

  // Validate signature format
  use _ <- result.try(case hex.is_valid_hex_chars(options.signature) {
    True -> Ok(Nil)
    False -> Error("Signature must be valid hex string")
  })

  // Validate signature length
  use signature_bytes <- result.try(hex.decode(options.signature))
  case bit_array.byte_size(signature_bytes) {
    65 -> Ok(Nil)
    _ -> Error("Signature must be 65 bytes (130 hex characters)")
  }
}

/// Create recovery options with defaults
pub fn default_options() -> RecoverOptions {
  RecoverOptions(
    message: "",
    signature: "",
    recovery_mode: RecoverAddress,
    format: Detailed,
  )
}

// =============================================================================
// CLI Integration Helpers
// =============================================================================

/// Parse recovery mode from string
pub fn parse_recovery_mode(mode_str: String) -> Result(RecoveryMode, String) {
  case string.lowercase(mode_str) {
    "pubkey" | "public-key" | "public_key" -> Ok(RecoverPublicKey)
    "address" | "addr" -> Ok(RecoverAddress)
    "candidates" | "all" -> Ok(RecoverCandidates)
    other -> {
      case string.starts_with(other, "verify:") {
        True -> {
          let address = string.drop_start(other, 7)
          case hex.is_valid_hex_chars(address) && string.length(address) >= 40 {
            True -> Ok(VerifyAddress(address))
            False -> Error("Invalid address for verification: " <> address)
          }
        }
        False ->
          Error(
            "Invalid recovery mode: "
            <> mode_str
            <> ". Valid modes: pubkey, address, candidates, verify:<address>",
          )
      }
    }
  }
}

/// Parse output format from string
pub fn parse_output_format(format_str: String) -> Result(OutputFormat, String) {
  case string.lowercase(format_str) {
    "compact" | "c" -> Ok(Compact)
    "detailed" | "detail" | "d" -> Ok(Detailed)
    "json" | "j" -> Ok(Json)
    _ ->
      Error(
        "Invalid format: "
        <> format_str
        <> ". Valid formats: compact, detailed, json",
      )
  }
}

/// Print usage information
pub fn print_usage() {
  io.println("Signature Recovery Commands:")
  io.println("")
  io.println("  gleeth recover [OPTIONS] <MESSAGE> <SIGNATURE>")
  io.println("")
  io.println("OPTIONS:")
  io.println(
    "  --mode <MODE>      Recovery mode (pubkey|address|candidates|verify:<addr>)",
  )
  io.println("  --format <FORMAT>  Output format (compact|detailed|json)")
  io.println("")
  io.println("EXAMPLES:")
  io.println("  # Recover address from signature")
  io.println("  gleeth recover --mode address \"Hello\" 0x123...abc")
  io.println("")
  io.println("  # Show all recovery candidates")
  io.println("  gleeth recover --mode candidates \"Hello\" 0x123...abc")
  io.println("")
  io.println("  # Verify signature against expected address")
  io.println("  gleeth recover --mode verify:0xf39fd... \"Hello\" 0x123...abc")
  io.println("")
  io.println("  # Recover public key in JSON format")
  io.println(
    "  gleeth recover --mode pubkey --format json \"Hello\" 0x123...abc",
  )
}
