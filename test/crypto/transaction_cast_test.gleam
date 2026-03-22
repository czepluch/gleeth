/// Cross-implementation verification: sign with gleeth, sign with Foundry cast,
/// compare raw bytes. This catches encoding bugs that internal roundtrip tests
/// would miss (if encoder and decoder share the same bug).
///
/// These tests require Foundry (cast) to be installed.
/// They are skipped gracefully if cast is not available.
import gleam/int
import gleam/string
import gleeth/crypto/transaction
import gleeth/crypto/wallet
import gleeunit/should

const test_private_key = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

const recipient = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

@external(erlang, "test_ffi", "run_command")
fn run_command(command: String) -> String

fn cast_available() -> Bool {
  let output = run_command("which cast 2>/dev/null || echo MISSING")
  !string.contains(output, "MISSING")
}

fn int_to_hex(n: Int) -> String {
  case n {
    0 -> "0x0"
    _ -> "0x" <> string.lowercase(int.to_base16(n))
  }
}

// =============================================================================
// Legacy transaction cross-verification
// =============================================================================

pub fn cast_verify_legacy_simple_transfer_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_legacy(0, 1_000_000_000_000_000_000, 21_000, 1_000_000_000, 1)
    }
  }
}

pub fn cast_verify_legacy_zero_value_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_legacy(0, 0, 21_000, 1_000_000_000, 1)
    }
  }
}

pub fn cast_verify_legacy_high_nonce_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_legacy(999, 500_000_000_000_000, 21_000, 50_000_000_000, 1)
    }
  }
}

pub fn cast_verify_legacy_sepolia_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_legacy(
        42,
        500_000_000_000_000_000,
        21_000,
        20_000_000_000,
        11_155_111,
      )
    }
  }
}

pub fn cast_verify_legacy_arbitrum_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_legacy(0, 1_000_000_000_000_000_000, 21_000, 100_000_000, 42_161)
    }
  }
}

pub fn cast_verify_legacy_polygon_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_legacy(5, 0, 100_000, 30_000_000_000, 137)
    }
  }
}

pub fn cast_verify_legacy_optimism_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_legacy(0, 250_000_000_000_000_000, 21_000, 1_000_000, 10)
    }
  }
}

pub fn cast_verify_legacy_high_gas_price_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_legacy(0, 100_000_000_000_000_000, 21_000, 500_000_000_000, 1)
    }
  }
}

pub fn cast_verify_legacy_large_gas_limit_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_legacy(3, 0, 800_000, 10_000_000_000, 1)
    }
  }
}

fn verify_legacy(
  nonce: Int,
  value: Int,
  gas_limit: Int,
  gas_price: Int,
  chain_id: Int,
) -> Nil {
  // Sign with gleeth
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let assert Ok(tx) =
    transaction.create_legacy_transaction(
      recipient,
      int_to_hex(value),
      int_to_hex(gas_limit),
      int_to_hex(gas_price),
      int_to_hex(nonce),
      "0x",
      chain_id,
    )
  let assert Ok(signed) = transaction.sign_transaction(tx, w)

  // Sign with cast
  let cast_cmd =
    "cast mktx --legacy"
    <> " --private-key "
    <> test_private_key
    <> " --chain "
    <> int.to_string(chain_id)
    <> " --nonce "
    <> int.to_string(nonce)
    <> " --gas-price "
    <> int.to_string(gas_price)
    <> " --gas-limit "
    <> int.to_string(gas_limit)
    <> " --value "
    <> int.to_string(value)
    <> " "
    <> recipient
  let cast_output = run_command(cast_cmd)

  // Compare raw bytes
  signed.raw_transaction
  |> string.lowercase
  |> should.equal(string.lowercase(string.trim(cast_output)))
}

// =============================================================================
// EIP-1559 transaction cross-verification
// =============================================================================

pub fn cast_verify_eip1559_simple_transfer_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_eip1559(
        0,
        1_000_000_000_000_000_000,
        21_000,
        20_000_000_000,
        1_000_000_000,
        1,
      )
    }
  }
}

pub fn cast_verify_eip1559_zero_value_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_eip1559(0, 0, 21_000, 1_000_000_000, 0, 1)
    }
  }
}

pub fn cast_verify_eip1559_high_nonce_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_eip1559(
        500,
        100_000_000_000_000_000,
        21_000,
        50_000_000_000,
        2_000_000_000,
        1,
      )
    }
  }
}

pub fn cast_verify_eip1559_sepolia_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_eip1559(
        42,
        500_000_000_000_000_000,
        21_000,
        30_000_000_000,
        2_000_000_000,
        11_155_111,
      )
    }
  }
}

pub fn cast_verify_eip1559_arbitrum_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_eip1559(
        0,
        1_000_000_000_000_000_000,
        21_000,
        1_000_000_000,
        100_000_000,
        42_161,
      )
    }
  }
}

pub fn cast_verify_eip1559_polygon_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_eip1559(10, 0, 100_000, 100_000_000_000, 30_000_000_000, 137)
    }
  }
}

pub fn cast_verify_eip1559_high_priority_fee_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_eip1559(
        0,
        50_000_000_000_000_000,
        21_000,
        100_000_000_000,
        10_000_000_000,
        1,
      )
    }
  }
}

pub fn cast_verify_eip1559_max_fee_equals_priority_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_eip1559(0, 0, 21_000, 5_000_000_000, 5_000_000_000, 1)
    }
  }
}

pub fn cast_verify_eip1559_large_gas_limit_test() {
  case cast_available() {
    False -> Nil
    True -> {
      verify_eip1559(1, 0, 500_000, 20_000_000_000, 1_000_000_000, 1)
    }
  }
}

fn verify_eip1559(
  nonce: Int,
  value: Int,
  gas_limit: Int,
  max_fee: Int,
  priority_fee: Int,
  chain_id: Int,
) -> Nil {
  // Sign with gleeth
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)
  let assert Ok(tx) =
    transaction.create_eip1559_transaction(
      recipient,
      int_to_hex(value),
      int_to_hex(gas_limit),
      int_to_hex(max_fee),
      int_to_hex(priority_fee),
      int_to_hex(nonce),
      "0x",
      chain_id,
      [],
    )
  let assert Ok(signed) = transaction.sign_eip1559_transaction(tx, w)

  // Sign with cast
  let cast_cmd =
    "cast mktx"
    <> " --private-key "
    <> test_private_key
    <> " --chain "
    <> int.to_string(chain_id)
    <> " --nonce "
    <> int.to_string(nonce)
    <> " --gas-price "
    <> int.to_string(max_fee)
    <> " --priority-gas-price "
    <> int.to_string(priority_fee)
    <> " --gas-limit "
    <> int.to_string(gas_limit)
    <> " --value "
    <> int.to_string(value)
    <> " "
    <> recipient
  let cast_output = run_command(cast_cmd)

  // Compare raw bytes
  signed.raw_transaction
  |> string.lowercase
  |> should.equal(string.lowercase(string.trim(cast_output)))
}
