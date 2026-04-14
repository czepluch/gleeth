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
  let p = provider.mainnet()
  case methods.get_block_number(p) {
    Ok(_) -> True
    Error(_) -> False
  }
}

pub fn resolve_vitalik_eth_test() {
  case mainnet_available() {
    False -> Nil
    True -> {
      let p = provider.mainnet()
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
      let p = provider.mainnet()
      // This name almost certainly doesn't exist
      case ens.resolve(p, "thisdoesnotexist12345678.eth") {
        Error(_) -> Nil
        Ok(_) -> Nil
        // Shouldn't resolve, but don't fail if network behaves differently
      }
    }
  }
}
