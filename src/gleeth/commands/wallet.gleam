import gleam/bit_array
import gleam/int
import gleam/io
import gleam/result
import gleam/string
import gleeth/crypto/secp256k1
import gleeth/crypto/wallet
import gleeth/ethereum/formatting
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex
import gleeth/utils/validation

/// Wallet command operations
pub type WalletOperation {
  CreateFromKey(String)
  // Create wallet from private key
  GenerateNew
  // Generate new random wallet
  ShowInfo(String)
  // Show wallet info from private key
  SignMessage(String, String)
  // Sign message with private key
  VerifyMessage(String, String, String)
  // Verify signature against message and public key
}

/// Parse wallet command arguments
pub fn parse_args(args: List(String)) -> Result(WalletOperation, String) {
  case args {
    ["create", "--private-key", key] -> Ok(CreateFromKey(key))
    ["create", "-k", key] -> Ok(CreateFromKey(key))
    ["generate"] -> Ok(GenerateNew)
    ["info", "--private-key", key] -> Ok(ShowInfo(key))
    ["info", "-k", key] -> Ok(ShowInfo(key))
    ["sign", "--private-key", key, "--message", message] ->
      Ok(SignMessage(key, message))
    ["sign", "-k", key, "-m", message] -> Ok(SignMessage(key, message))
    ["verify", "--public-key", pubkey, "--message", message, "--signature", sig] ->
      Ok(VerifyMessage(pubkey, message, sig))
    ["verify", "-p", pubkey, "-m", message, "-s", sig] ->
      Ok(VerifyMessage(pubkey, message, sig))
    _ -> Error("Invalid wallet command. Use: create|generate|info|sign|verify")
  }
}

/// Execute wallet operation
pub fn run(operation: WalletOperation) -> Result(Nil, String) {
  case operation {
    CreateFromKey(private_key) -> handle_create_from_key(private_key)
    GenerateNew -> handle_generate_new()
    ShowInfo(private_key) -> handle_show_info(private_key)
    SignMessage(private_key, message) ->
      handle_sign_message(private_key, message)
    VerifyMessage(public_key, message, signature) ->
      handle_verify_message(public_key, message, signature)
  }
}

/// Handle creating wallet from private key
fn handle_create_from_key(private_key_hex: String) -> Result(Nil, String) {
  use _validated_key <- result.try(
    validation.validate_private_key(private_key_hex)
    |> result.map_error(fn(err) {
      case err {
        rpc_types.ParseError(msg) -> msg
        _ -> "Invalid private key format"
      }
    }),
  )

  use wallet_result <- result.try(
    wallet.from_private_key_hex(private_key_hex)
    |> result.map_error(fn(err) { wallet.error_to_string(err) }),
  )

  formatting.print_success("Wallet created successfully!")
  formatting.print_section("")
  print_wallet_info(wallet_result)
  Ok(Nil)
}

/// Handle generating new wallet
fn handle_generate_new() -> Result(Nil, String) {
  case wallet.generate() {
    Ok(new_wallet) -> {
      formatting.print_success("New wallet generated!")
      formatting.print_warning("WARNING: Save your private key securely!")
      formatting.print_section("")
      print_wallet_info(new_wallet)
      Ok(Nil)
    }
    Error(err) -> {
      Error("Failed to generate wallet: " <> wallet.error_to_string(err))
    }
  }
}

/// Handle showing wallet info
fn handle_show_info(private_key_hex: String) -> Result(Nil, String) {
  use _validated_key <- result.try(
    validation.validate_private_key(private_key_hex)
    |> result.map_error(fn(err) {
      case err {
        rpc_types.ParseError(msg) -> msg
        _ -> "Invalid private key format"
      }
    }),
  )

  use wallet_result <- result.try(
    wallet.from_private_key_hex(private_key_hex)
    |> result.map_error(fn(err) { wallet.error_to_string(err) }),
  )

  formatting.print_info("Wallet Information:")
  formatting.print_section("")
  print_wallet_info(wallet_result)
  Ok(Nil)
}

/// Handle signing a message
fn handle_sign_message(
  private_key_hex: String,
  message: String,
) -> Result(Nil, String) {
  use _validated_key <- result.try(
    validation.validate_private_key(private_key_hex)
    |> result.map_error(fn(err) {
      case err {
        rpc_types.ParseError(msg) -> msg
        _ -> "Invalid private key format"
      }
    }),
  )

  use wallet_result <- result.try(
    wallet.from_private_key_hex(private_key_hex)
    |> result.map_error(fn(err) { wallet.error_to_string(err) }),
  )

  use signature <- result.try(
    wallet.sign_personal_message(wallet_result, message)
    |> result.map_error(fn(err) { wallet.error_to_string(err) }),
  )

  formatting.print_success("Message signed successfully!")
  formatting.print_section("")
  formatting.print_labeled_value("Message", message)
  formatting.print_labeled_value(
    "Signature",
    secp256k1.signature_to_hex(signature),
  )

  let #(v, r, s) = secp256k1.signature_to_vrs(signature)
  formatting.print_section("Signature components")
  formatting.print_labeled_value("v", string.inspect(v))
  formatting.print_labeled_value("r", r)
  formatting.print_labeled_value("s", s)

  Ok(Nil)
}

/// Handle verifying a message signature
fn handle_verify_message(
  public_key_hex: String,
  message: String,
  signature_hex: String,
) -> Result(Nil, String) {
  // Validate and parse public key
  use validated_pubkey <- result.try(
    validation.validate_public_key(public_key_hex)
    |> result.map_error(fn(err) {
      case err {
        rpc_types.ParseError(msg) -> msg
        _ -> "Invalid public key format"
      }
    }),
  )

  use public_key_bytes <- result.try(
    hex.decode(validated_pubkey)
    |> result.map_error(fn(_) { "Failed to decode public key" }),
  )

  let public_key = secp256k1.PublicKey(public_key_bytes)

  // Validate and parse signature
  use validated_signature <- result.try(
    validation.validate_signature(signature_hex)
    |> result.map_error(fn(err) {
      case err {
        rpc_types.ParseError(msg) -> msg
        _ -> "Invalid signature format"
      }
    }),
  )

  use signature <- result.try(parse_signature_hex(validated_signature))

  // Create personal message hash (same as signing)
  let message_bytes = bit_array.from_string(message)
  let message_length = bit_array.byte_size(message_bytes) |> string.inspect
  let prefix = "\\x19Ethereum Signed Message:\\n" <> message_length
  let prefix_bytes = bit_array.from_string(prefix)
  let full_message = bit_array.append(prefix_bytes, message_bytes)
  let message_hash = gleeth_crypto_keccak_keccak256_binary(full_message)

  // Verify signature
  use is_valid <- result.try(secp256k1.verify_signature(
    message_hash,
    signature,
    public_key,
  ))

  case is_valid {
    True -> {
      formatting.print_success("Signature verification successful!")
      formatting.print_section("")
      formatting.print_labeled_value("Message", message)
      formatting.print_labeled_value("Public Key", public_key_hex)
      formatting.print_labeled_value("Signature", signature_hex)
      formatting.print_labeled_value("Status", "VALID ✓")
      Ok(Nil)
    }
    False -> {
      formatting.print_error("Signature verification failed!")
      formatting.print_section("")
      formatting.print_labeled_value("Message", message)
      formatting.print_labeled_value("Public Key", public_key_hex)
      formatting.print_labeled_value("Signature", signature_hex)
      formatting.print_labeled_value("Status", "INVALID ✗")
      Error("Signature is not valid for the given message and public key")
    }
  }
}

/// Parse signature from validated hex string
fn parse_signature_hex(
  signature_hex: String,
) -> Result(secp256k1.Signature, String) {
  let clean_hex = hex.strip_prefix(signature_hex)
  // 65 bytes: r (32) + s (32) + v (1)
  let r_hex = string.slice(clean_hex, 0, 64)
  let s_hex = string.slice(clean_hex, 64, 64)
  let v_hex = string.slice(clean_hex, 128, 2)

  use r_bytes <- result.try(
    hex.decode("0x" <> r_hex)
    |> result.map_error(fn(_) { "Invalid r component in signature" }),
  )
  use s_bytes <- result.try(
    hex.decode("0x" <> s_hex)
    |> result.map_error(fn(_) { "Invalid s component in signature" }),
  )
  use v_int <- result.try(case int.base_parse(v_hex, 16) {
    Ok(v) -> Ok(v - 27)
    // Convert from Ethereum v to recovery_id
    Error(_) -> Error("Invalid v component in signature")
  })

  Ok(secp256k1.Signature(r: r_bytes, s: s_bytes, recovery_id: v_int))
}

/// External function to use keccak256
@external(erlang, "Elixir.ExKeccak", "hash_256")
fn gleeth_crypto_keccak_keccak256_binary(data: BitArray) -> BitArray

/// Print formatted wallet information
fn print_wallet_info(wallet_obj: wallet.Wallet) -> Nil {
  let address = wallet.get_address(wallet_obj)
  let private_key = wallet.get_private_key_hex(wallet_obj)
  let public_key = wallet.get_public_key_hex(wallet_obj)
  let is_valid = wallet.is_valid(wallet_obj)

  formatting.print_labeled_value("Address", formatting.display_address(address))
  formatting.print_labeled_value("Private Key", hex.normalize(private_key))
  formatting.print_labeled_value("Public Key", hex.normalize(public_key))
  formatting.print_labeled_value("Valid", string.inspect(is_valid))
}

/// Print usage information
pub fn print_usage() -> Nil {
  io.println("Usage: gleeth wallet <command> [options]")
  io.println("")
  io.println("Commands:")
  io.println("  create --private-key <key>    Create wallet from private key")
  io.println("  generate                      Generate new random wallet")
  io.println("  info --private-key <key>      Show wallet information")
  io.println("  sign --private-key <key> --message <msg>  Sign a message")
  io.println(
    "  verify --public-key <key> --message <msg> --signature <sig>  Verify a signature",
  )
  io.println("")
  io.println("Options:")
  io.println("  --private-key, -k <key>       Private key (hex format)")
  io.println("  --public-key, -p <key>        Public key (hex format)")
  io.println("  --message, -m <message>       Message to sign/verify")
  io.println("  --signature, -s <signature>   Signature to verify (hex format)")
  io.println("")
  io.println("Examples:")
  io.println("  gleeth wallet create -k 0x1234...")
  io.println("  gleeth wallet generate")
  io.println("  gleeth wallet info -k 0x1234...")
  io.println("  gleeth wallet sign -k 0x1234... -m 'Hello World'")
  io.println(
    "  gleeth wallet verify -p 0x04abc... -m 'Hello World' -s 0xdef...",
  )
}

/// Print help for wallet command
pub fn print_help() -> Nil {
  io.println("Gleeth Wallet Management")
  io.println("========================")
  io.println("")
  io.println("Manage Ethereum wallets and sign messages.")
  io.println("")
  print_usage()
  io.println("")
  io.println("Security Notes:")
  io.println("- Never share your private key")
  io.println("- Store private keys securely")
  io.println("- Use hardware wallets for large amounts")
  io.println("- Test on testnets before mainnet")
}
