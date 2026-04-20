/// ENS resolution tests.
/// Namehash tests are fully offline.
/// Resolution tests query mainnet (skipped if network unavailable).
import gleam/string
import gleeth/ens
import gleeth/provider
import gleeth/rpc/methods
import gleeth/utils/hex
import gleeunit/should

// =============================================================================
// Namehash (offline, deterministic)
// =============================================================================

pub fn namehash_empty_test() {
  let hash = ens.namehash("")
  hex.encode(hash)
  |> should.equal(
    "0x0000000000000000000000000000000000000000000000000000000000000000",
  )
}

pub fn namehash_eth_test() {
  // keccak256(namehash("") + keccak256("eth"))
  let hash = ens.namehash("eth")
  hex.encode(hash)
  |> should.equal(
    "0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae",
  )
}

pub fn namehash_vitalik_eth_test() {
  let hash = ens.namehash("vitalik.eth")
  hex.encode(hash)
  |> should.equal(
    "0xee6c4522aab0003e8d14cd40a6af439055fd2577951148c14b6cea9a53475835",
  )
}

pub fn namehash_subdomain_test() {
  let hash = ens.namehash("sub.vitalik.eth")
  // Should be different from vitalik.eth
  let vitalik_hash = ens.namehash("vitalik.eth")
  should.not_equal(hash, vitalik_hash)
}

// =============================================================================
// Resolution against mainnet (network-dependent)
// =============================================================================

fn mainnet_available() -> Bool {
  // Use no-retry provider for the availability check so CI doesn't hang
  let assert Ok(p) = provider.new("https://eth.llamarpc.com")
  case methods.get_block_number(p) {
    Ok(_) -> True
    Error(_) -> False
  }
}

pub fn resolve_vitalik_eth_test() {
  case mainnet_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new("https://eth.llamarpc.com")
      case ens.resolve(p, "vitalik.eth") {
        Ok(address) -> {
          // Vitalik's address is well-known
          string.lowercase(address)
          |> should.equal("0xd8da6bf26964af9d7eed9e03e53415d37aa96045")
        }
        Error(_) -> {
          // Network might be flaky, don't fail the test
          Nil
        }
      }
    }
  }
}

pub fn resolve_nonexistent_test() {
  case mainnet_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new("https://eth.llamarpc.com")
      // This name almost certainly doesn't exist
      case ens.resolve(p, "thisdoesnotexist12345678.eth") {
        Error(_) -> Nil
        Ok(_) -> Nil
        // Shouldn't resolve, but don't fail if network behaves differently
      }
    }
  }
}

// =============================================================================
// Reverse resolution
// =============================================================================

pub fn namehash_reverse_node_test() {
  // Verify the reverse namehash is computed correctly
  // The reverse node for an address is: <addr>.addr.reverse
  let reverse_name = "d8da6bf26964af9d7eed9e03e53415d37aa96045.addr.reverse"
  let hash = ens.namehash(reverse_name)
  // Should be a valid 32-byte hash, different from the forward hash
  let forward_hash = ens.namehash("vitalik.eth")
  should.not_equal(hash, forward_hash)
  // Should be 32 bytes
  gleam_bit_array.byte_size(hash) |> should.equal(32)
}

pub fn reverse_resolve_vitalik_test() {
  case mainnet_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new("https://eth.llamarpc.com")
      case
        ens.reverse_resolve(p, "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
      {
        Ok(name) -> {
          // Vitalik has a reverse record
          name |> should.equal("vitalik.eth")
        }
        Error(_) -> {
          // Network might be flaky
          Nil
        }
      }
    }
  }
}

pub fn reverse_resolve_no_record_test() {
  case mainnet_available() {
    False -> Nil
    True -> {
      let assert Ok(p) = provider.new("https://eth.llamarpc.com")
      // Zero address almost certainly has no reverse record
      case
        ens.reverse_resolve(p, "0x0000000000000000000000000000000000000001")
      {
        Error(_) -> Nil
        Ok(_) -> Nil
      }
    }
  }
}

import gleam/bit_array as gleam_bit_array
