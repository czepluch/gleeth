//// ENS (Ethereum Name Service) resolution.
////
//// Resolves human-readable `.eth` names to Ethereum addresses (forward)
//// and addresses back to names (reverse) by querying the ENS registry
//// and resolver contracts on-chain.
////
//// ## Examples
////
//// ```gleam
//// // Forward: name -> address
//// let assert Ok(address) = ens.resolve(provider, "vitalik.eth")
////
//// // Reverse: address -> name
//// let assert Ok(name) = ens.reverse_resolve(provider, "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
//// ```

import gleam/bit_array
import gleam/list
import gleam/result
import gleam/string
import gleeth/crypto/keccak
import gleeth/provider.{type Provider}
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex

/// ENS Registry address (same on mainnet, Goerli, Sepolia).
pub const registry_address = "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e"

/// Resolve an ENS name to an Ethereum address.
///
/// Queries the ENS registry for the resolver, then queries the resolver
/// for the address. Returns an error if the name has no resolver or no
/// address set.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(addr) = ens.resolve(provider, "vitalik.eth")
/// ```
pub fn resolve(
  provider: Provider,
  name: String,
) -> Result(String, rpc_types.GleethError) {
  let node = namehash(name)
  let node_hex = hex.encode(node)

  // Step 1: Get resolver address from registry
  // resolver(bytes32) selector = 0x0178b8bf
  use resolver_address <- result.try(call_address(
    provider,
    registry_address,
    "0x0178b8bf",
    node_hex,
  ))

  case resolver_address {
    "" | "0x0000000000000000000000000000000000000000" ->
      Error(rpc_types.ParseError("No resolver found for: " <> name))
    resolver -> {
      // Step 2: Get address from resolver
      // addr(bytes32) selector = 0x3b3b57de
      use address <- result.try(call_address(
        provider,
        resolver,
        "0x3b3b57de",
        node_hex,
      ))
      case address {
        "" | "0x0000000000000000000000000000000000000000" ->
          Error(rpc_types.ParseError("No address set for: " <> name))
        addr -> Ok(addr)
      }
    }
  }
}

/// Compute the ENS namehash for a domain name.
///
/// The namehash algorithm recursively hashes labels:
/// `namehash("") = 0x00...00`
/// `namehash("eth") = keccak256(namehash("") + keccak256("eth"))`
/// `namehash("vitalik.eth") = keccak256(namehash("eth") + keccak256("vitalik"))`
///
/// ## Examples
///
/// ```gleam
/// let hash = ens.namehash("vitalik.eth")
/// ```
pub fn namehash(name: String) -> BitArray {
  case name {
    "" -> <<0:256>>
    _ -> {
      let labels = string.split(name, ".")
      let reversed = list.reverse(labels)
      list.fold(reversed, <<0:256>>, fn(node, label) {
        let label_hash = keccak.keccak256_binary(bit_array.from_string(label))
        keccak.keccak256_binary(bit_array.concat([node, label_hash]))
      })
    }
  }
}

/// Reverse resolve an Ethereum address to its primary ENS name.
///
/// Computes the reverse node (`<addr>.addr.reverse`), queries the ENS
/// registry for the reverse resolver, then calls `name(bytes32)` on it.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(name) = ens.reverse_resolve(
///   provider,
///   "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
/// )
/// // name = "vitalik.eth"
/// ```
pub fn reverse_resolve(
  provider: Provider,
  address: String,
) -> Result(String, rpc_types.GleethError) {
  // Build the reverse node: <lowercase-addr-no-prefix>.addr.reverse
  let clean_addr = string.lowercase(hex.strip_prefix(address))
  let reverse_name = clean_addr <> ".addr.reverse"
  let node = namehash(reverse_name)
  let node_hex = hex.encode(node)

  // Get the reverse resolver from the registry
  use resolver_address <- result.try(call_address(
    provider,
    registry_address,
    "0x0178b8bf",
    node_hex,
  ))

  case resolver_address {
    "" | "0x0000000000000000000000000000000000000000" ->
      Error(rpc_types.ParseError("No reverse resolver for: " <> address))
    resolver -> {
      // Call name(bytes32) on the resolver - selector 0x691f3431
      use name <- result.try(call_string(
        provider,
        resolver,
        "0x691f3431",
        node_hex,
      ))
      case name {
        "" -> Error(rpc_types.ParseError("No reverse record for: " <> address))
        n -> Ok(n)
      }
    }
  }
}

// =============================================================================
// Internal RPC helpers
// =============================================================================

/// Call a function that takes a bytes32 arg and returns a string.
fn call_string(
  provider: Provider,
  contract: String,
  selector: String,
  arg_hex: String,
) -> Result(String, rpc_types.GleethError) {
  let arg_clean = hex.strip_prefix(arg_hex)
  let padded = string.pad_start(arg_clean, to: 64, with: "0")
  let calldata = selector <> padded

  use result_hex <- result.try(methods.call_contract(
    provider,
    contract,
    calldata,
  ))

  // ABI-decode string: offset(32) + length(32) + data
  case hex.decode(result_hex) {
    Ok(bytes) -> {
      case bit_array.byte_size(bytes) >= 64 {
        True -> {
          let assert Ok(offset_bytes) = bit_array.slice(bytes, 0, 32)
          let offset = bytes_to_int(offset_bytes)
          let assert Ok(len_bytes) = bit_array.slice(bytes, offset, 32)
          let len = bytes_to_int(len_bytes)
          case len > 0 {
            True -> {
              let assert Ok(str_bytes) =
                bit_array.slice(bytes, offset + 32, len)
              case bit_array.to_string(str_bytes) {
                Ok(s) -> Ok(s)
                Error(_) -> Ok("")
              }
            }
            False -> Ok("")
          }
        }
        False -> Ok("")
      }
    }
    Error(_) -> Ok("")
  }
}

fn bytes_to_int(data: BitArray) -> Int {
  do_bytes_to_int(data, 0)
}

fn do_bytes_to_int(data: BitArray, acc: Int) -> Int {
  case data {
    <<byte:8, rest:bits>> -> do_bytes_to_int(rest, acc * 256 + byte)
    _ -> acc
  }
}

/// Call a function that takes a bytes32 arg and returns an address.
fn call_address(
  provider: Provider,
  contract: String,
  selector: String,
  arg_hex: String,
) -> Result(String, rpc_types.GleethError) {
  // ABI-encode: selector + bytes32 arg (left-padded to 32 bytes)
  let arg_clean = hex.strip_prefix(arg_hex)
  let padded = string.pad_start(arg_clean, to: 64, with: "0")
  let calldata = selector <> padded

  use result_hex <- result.try(methods.call_contract(
    provider,
    contract,
    calldata,
  ))

  // Decode address from 32-byte return value (last 20 bytes)
  case hex.decode(result_hex) {
    Ok(bytes) -> {
      let size = bit_array.byte_size(bytes)
      case size >= 32 {
        True -> {
          let assert Ok(addr_bytes) = bit_array.slice(bytes, 12, 20)
          let addr =
            "0x" <> string.lowercase(bit_array.base16_encode(addr_bytes))
          Ok(addr)
        }
        False -> Ok("")
      }
    }
    Error(_) -> Ok("")
  }
}
