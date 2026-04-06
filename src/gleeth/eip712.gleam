//// EIP-712 typed structured data hashing and signing.
////
//// Implements the encoding rules from the EIP-712 specification for signing
//// structured data with domain separation. Used for ERC-2612 permits,
//// DEX order signing, meta-transactions, and other off-chain authorization.
////
//// ## Examples
////
//// ```gleam
//// let domain = eip712.domain()
////   |> eip712.domain_name("MyDapp")
////   |> eip712.domain_version("1")
////   |> eip712.domain_chain_id(1)
////
//// let types = dict.from_list([
////   #("Mail", [
////     eip712.field("from", "address"),
////     eip712.field("to", "address"),
////     eip712.field("contents", "string"),
////   ]),
//// ])
////
//// let message = dict.from_list([
////   #("from", eip712.address_val("0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826")),
////   #("to", eip712.address_val("0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB")),
////   #("contents", eip712.string_val("Hello, Bob!")),
//// ])
////
//// let data = eip712.typed_data(types, "Mail", domain, message)
//// let assert Ok(sig) = eip712.sign_typed_data(data, wallet)
//// ```

import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleeth/crypto/keccak
import gleeth/crypto/secp256k1
import gleeth/crypto/wallet
import gleeth/utils/hex

// =============================================================================
// Types
// =============================================================================

/// EIP-712 domain separator fields. All fields are optional - include only
/// those relevant to your application.
pub type Domain {
  Domain(
    name: Option(String),
    version: Option(String),
    chain_id: Option(Int),
    verifying_contract: Option(String),
    salt: Option(String),
  )
}

/// A field in a typed struct definition.
pub type TypedField {
  TypedField(name: String, type_name: String)
}

/// A value in a typed data message. Matches the EIP-712 encoding rules.
pub type TypedValue {
  StringVal(String)
  IntVal(Int)
  BoolVal(Bool)
  AddressVal(String)
  Bytes32Val(BitArray)
  BytesVal(BitArray)
  ArrayVal(List(TypedValue))
  StructVal(Dict(String, TypedValue))
}

/// Complete EIP-712 typed data structure ready for hashing or signing.
pub type TypedData {
  TypedData(
    types: Dict(String, List(TypedField)),
    primary_type: String,
    domain: Domain,
    message: Dict(String, TypedValue),
  )
}

// =============================================================================
// Constructors
// =============================================================================

/// Create an empty domain. Use `domain_name`, `domain_version`, etc. to set fields.
pub fn domain() -> Domain {
  Domain(
    name: None,
    version: None,
    chain_id: None,
    verifying_contract: None,
    salt: None,
  )
}

/// Set the domain name field.
pub fn domain_name(d: Domain, name: String) -> Domain {
  Domain(..d, name: Some(name))
}

/// Set the domain version field.
pub fn domain_version(d: Domain, version: String) -> Domain {
  Domain(..d, version: Some(version))
}

/// Set the domain chain ID field.
pub fn domain_chain_id(d: Domain, id: Int) -> Domain {
  Domain(..d, chain_id: Some(id))
}

/// Set the domain verifying contract address.
pub fn domain_verifying_contract(d: Domain, address: String) -> Domain {
  Domain(..d, verifying_contract: Some(address))
}

/// Set the domain salt field (hex-encoded bytes32).
pub fn domain_salt(d: Domain, salt: String) -> Domain {
  Domain(..d, salt: Some(salt))
}

/// Create a typed field definition.
pub fn field(name: String, type_name: String) -> TypedField {
  TypedField(name: name, type_name: type_name)
}

/// Convenience constructors for typed values.
pub fn string_val(s: String) -> TypedValue {
  StringVal(s)
}

/// Wrap an integer as a typed value (for uint256, int256, etc.).
pub fn int_val(n: Int) -> TypedValue {
  IntVal(n)
}

/// Wrap a boolean as a typed value.
pub fn bool_val(b: Bool) -> TypedValue {
  BoolVal(b)
}

/// Wrap an Ethereum address as a typed value.
pub fn address_val(addr: String) -> TypedValue {
  AddressVal(addr)
}

/// Wrap a fixed 32-byte value as a typed value.
pub fn bytes32_val(b: BitArray) -> TypedValue {
  Bytes32Val(b)
}

/// Wrap dynamic bytes as a typed value.
pub fn bytes_val(b: BitArray) -> TypedValue {
  BytesVal(b)
}

/// Wrap a list of typed values as an array value.
pub fn array_val(items: List(TypedValue)) -> TypedValue {
  ArrayVal(items)
}

/// Wrap a dict of named fields as a struct value.
pub fn struct_val(fields: Dict(String, TypedValue)) -> TypedValue {
  StructVal(fields)
}

/// Create a complete typed data structure.
pub fn typed_data(
  types: Dict(String, List(TypedField)),
  primary_type: String,
  d: Domain,
  message: Dict(String, TypedValue),
) -> TypedData {
  TypedData(
    types: types,
    primary_type: primary_type,
    domain: d,
    message: message,
  )
}

// =============================================================================
// Hashing
// =============================================================================

/// Compute the EIP-712 digest: keccak256("\x19\x01" || domainSeparator || hashStruct(message)).
/// This is the hash that gets signed.
pub fn hash_typed_data(data: TypedData) -> Result(BitArray, String) {
  use domain_sep <- result.try(hash_domain(data.domain, data.types))
  use struct_hash <- result.try(hash_struct(
    data.primary_type,
    data.message,
    data.types,
  ))
  Ok(keccak.keccak256_binary(<<0x19, 0x01, domain_sep:bits, struct_hash:bits>>))
}

/// Compute the domain separator hash.
pub fn hash_domain(
  d: Domain,
  custom_types: Dict(String, List(TypedField)),
) -> Result(BitArray, String) {
  let domain_fields = build_domain_fields(d)
  let domain_values = build_domain_values(d)
  // Merge the EIP712Domain type into the types dict for encoding
  let types = dict.insert(custom_types, "EIP712Domain", domain_fields)
  hash_struct("EIP712Domain", domain_values, types)
}

/// Compute hashStruct: keccak256(typeHash || encodeData(s)).
pub fn hash_struct(
  type_name: String,
  data: Dict(String, TypedValue),
  types: Dict(String, List(TypedField)),
) -> Result(BitArray, String) {
  let type_hash = hash_type(type_name, types)
  use encoded <- result.try(encode_data(type_name, data, types))
  Ok(keccak.keccak256_binary(bit_array.concat([type_hash, encoded])))
}

/// Compute typeHash: keccak256(encodeType(typeName)).
pub fn hash_type(
  type_name: String,
  types: Dict(String, List(TypedField)),
) -> BitArray {
  let type_string = encode_type(type_name, types)
  keccak.keccak256_binary(bit_array.from_string(type_string))
}

// =============================================================================
// Signing and recovery
// =============================================================================

/// Sign typed data with a wallet. Returns the signature.
pub fn sign_typed_data(
  data: TypedData,
  w: wallet.Wallet,
) -> Result(secp256k1.Signature, String) {
  use digest <- result.try(hash_typed_data(data))
  wallet.sign_hash(w, digest)
  |> result.map_error(wallet.error_to_string)
}

/// Recover the signer address from a typed data signature.
pub fn recover_typed_data(
  data: TypedData,
  signature_hex: String,
) -> Result(String, String) {
  use digest <- result.try(hash_typed_data(data))
  use signature <- result.try(secp256k1.signature_from_hex(signature_hex))
  use address <- result.try(secp256k1.recover_address(digest, signature))
  Ok(secp256k1.address_to_string(address))
}

// =============================================================================
// encodeType: canonical type string with sorted referenced types
// =============================================================================

/// Build the canonical type encoding string.
/// Example: "Mail(address from,address to,string contents)"
/// Referenced structs are collected, sorted, and appended.
pub fn encode_type(
  type_name: String,
  types: Dict(String, List(TypedField)),
) -> String {
  let primary = encode_single_type(type_name, types)
  let referenced = collect_referenced_types(type_name, types, [type_name])
  let sorted = list.sort(referenced, string.compare)
  let suffix =
    list.map(sorted, fn(name) { encode_single_type(name, types) })
    |> string.concat
  primary <> suffix
}

fn encode_single_type(
  type_name: String,
  types: Dict(String, List(TypedField)),
) -> String {
  case dict.get(types, type_name) {
    Ok(fields) -> {
      let field_strs = list.map(fields, fn(f) { f.type_name <> " " <> f.name })
      type_name <> "(" <> string.join(field_strs, ",") <> ")"
    }
    Error(_) -> type_name <> "()"
  }
}

/// Recursively collect all struct types referenced by a type's fields,
/// excluding the root type itself. Deduplicates across siblings.
fn collect_referenced_types(
  type_name: String,
  types: Dict(String, List(TypedField)),
  seen: List(String),
) -> List(String) {
  case dict.get(types, type_name) {
    Ok(fields) -> {
      let #(result, _) =
        list.fold(fields, #([], seen), fn(acc, f) {
          let #(collected, current_seen) = acc
          let base_type = strip_array_suffix(f.type_name)
          case
            dict.has_key(types, base_type)
            && !list.contains(current_seen, base_type)
          {
            True -> {
              let new_seen = [base_type, ..current_seen]
              let nested = collect_referenced_types(base_type, types, new_seen)
              let all_new = [base_type, ..nested]
              let updated_seen = list.append(all_new, new_seen)
              #(list.append(collected, all_new), updated_seen)
            }
            False -> acc
          }
        })
      result
    }
    Error(_) -> []
  }
}

fn strip_array_suffix(type_name: String) -> String {
  case string.ends_with(type_name, "[]") {
    True -> string.drop_end(type_name, 2)
    False -> type_name
  }
}

// =============================================================================
// encodeData: encode field values to 32-byte words
// =============================================================================

fn encode_data(
  type_name: String,
  data: Dict(String, TypedValue),
  types: Dict(String, List(TypedField)),
) -> Result(BitArray, String) {
  case dict.get(types, type_name) {
    Ok(fields) -> {
      use encoded_parts <- result.try(
        list.try_map(fields, fn(f) {
          case dict.get(data, f.name) {
            Ok(value) -> encode_value(f.type_name, value, types)
            Error(_) -> Error("Missing field: " <> f.name)
          }
        }),
      )
      Ok(bit_array.concat(encoded_parts))
    }
    Error(_) -> Error("Unknown type: " <> type_name)
  }
}

/// Encode a single value to exactly 32 bytes per EIP-712 rules.
fn encode_value(
  type_name: String,
  value: TypedValue,
  types: Dict(String, List(TypedField)),
) -> Result(BitArray, String) {
  // Check if it's an array type first
  case string.ends_with(type_name, "[]") {
    True -> encode_array_value(type_name, value, types)
    False -> encode_non_array_value(type_name, value, types)
  }
}

fn encode_non_array_value(
  type_name: String,
  value: TypedValue,
  types: Dict(String, List(TypedField)),
) -> Result(BitArray, String) {
  case type_name, value {
    // Dynamic types: hash the contents
    "string", StringVal(s) ->
      Ok(keccak.keccak256_binary(bit_array.from_string(s)))
    "bytes", BytesVal(b) -> Ok(keccak.keccak256_binary(b))

    // Atomic types: left-pad to 32 bytes
    "address", AddressVal(addr) -> encode_address(addr)
    "bool", BoolVal(b) ->
      Ok(case b {
        True -> pad_left(<<1>>, 32)
        False -> pad_left(<<>>, 32)
      })
    "bytes32", Bytes32Val(b) -> Ok(pad_right(b, 32))

    // Integer types (uint256, uint8, int256, etc.)
    _, IntVal(n) ->
      case
        string.starts_with(type_name, "uint")
        || string.starts_with(type_name, "int")
      {
        True -> encode_int(n)
        False -> Error("Type mismatch: expected " <> type_name <> ", got int")
      }

    // bytesN (bytes1-bytes31)
    _, Bytes32Val(b) ->
      case string.starts_with(type_name, "bytes") {
        True -> Ok(pad_right(b, 32))
        False -> Error("Type mismatch: expected " <> type_name <> ", got bytes")
      }

    // Struct types: recursively hashStruct
    _, StructVal(fields) ->
      case dict.has_key(types, type_name) {
        True -> {
          use hashed <- result.try(hash_struct(type_name, fields, types))
          Ok(hashed)
        }
        False -> Error("Unknown struct type: " <> type_name)
      }

    _, _ -> Error("Cannot encode " <> type_name <> " with given value")
  }
}

fn encode_array_value(
  type_name: String,
  value: TypedValue,
  types: Dict(String, List(TypedField)),
) -> Result(BitArray, String) {
  let element_type = string.drop_end(type_name, 2)
  case value {
    ArrayVal(items) -> {
      use encoded_items <- result.try(
        list.try_map(items, fn(item) { encode_value(element_type, item, types) }),
      )
      Ok(keccak.keccak256_binary(bit_array.concat(encoded_items)))
    }
    _ -> Error("Expected array value for " <> type_name)
  }
}

fn encode_address(addr: String) -> Result(BitArray, String) {
  case hex.decode(addr) {
    Ok(bytes) -> Ok(pad_left(bytes, 32))
    Error(_) -> Error("Invalid address: " <> addr)
  }
}

fn encode_int(n: Int) -> Result(BitArray, String) {
  case n >= 0 {
    True -> {
      let bytes = int_to_bytes(n)
      Ok(pad_left(bytes, 32))
    }
    False -> {
      // Two's complement for negative integers
      // For simplicity, compute as 2^256 + n
      let pos = int_to_bytes(-n)
      let padded = pad_left(pos, 32)
      Ok(twos_complement(padded))
    }
  }
}

// =============================================================================
// Domain helpers
// =============================================================================

fn build_domain_fields(d: Domain) -> List(TypedField) {
  []
  |> append_if(d.name, "string", "name")
  |> append_if(d.version, "string", "version")
  |> append_if(d.chain_id, "uint256", "chainId")
  |> append_if(d.verifying_contract, "address", "verifyingContract")
  |> append_if(d.salt, "bytes32", "salt")
  |> list.reverse
}

fn build_domain_values(d: Domain) -> Dict(String, TypedValue) {
  let entries =
    []
    |> append_val_if(d.name, "name", fn(v) { StringVal(v) })
    |> append_val_if(d.version, "version", fn(v) { StringVal(v) })
    |> append_val_if(d.chain_id, "chainId", fn(v) { IntVal(v) })
    |> append_val_if(d.verifying_contract, "verifyingContract", fn(v) {
      AddressVal(v)
    })
    |> append_val_if(d.salt, "salt", fn(v) {
      case hex.decode(v) {
        Ok(bytes) -> Bytes32Val(bytes)
        Error(_) -> Bytes32Val(<<>>)
      }
    })
  dict.from_list(entries)
}

fn append_if(
  acc: List(TypedField),
  opt: Option(a),
  type_name: String,
  name: String,
) -> List(TypedField) {
  case opt {
    Some(_) -> [TypedField(name: name, type_name: type_name), ..acc]
    None -> acc
  }
}

fn append_val_if(
  acc: List(#(String, TypedValue)),
  opt: Option(a),
  name: String,
  to_val: fn(a) -> TypedValue,
) -> List(#(String, TypedValue)) {
  case opt {
    Some(v) -> [#(name, to_val(v)), ..acc]
    None -> acc
  }
}

// =============================================================================
// Byte manipulation helpers
// =============================================================================

fn pad_left(data: BitArray, target: Int) -> BitArray {
  let size = bit_array.byte_size(data)
  case size >= target {
    True -> {
      // Take the last `target` bytes
      let assert Ok(result) = bit_array.slice(data, size - target, target)
      result
    }
    False -> {
      let padding = make_zeros(target - size)
      bit_array.concat([padding, data])
    }
  }
}

fn pad_right(data: BitArray, target: Int) -> BitArray {
  let size = bit_array.byte_size(data)
  case size >= target {
    True -> {
      let assert Ok(result) = bit_array.slice(data, 0, target)
      result
    }
    False -> {
      let padding = make_zeros(target - size)
      bit_array.concat([data, padding])
    }
  }
}

fn make_zeros(n: Int) -> BitArray {
  case n <= 0 {
    True -> <<>>
    False -> make_zeros_acc(n, <<>>)
  }
}

fn make_zeros_acc(n: Int, acc: BitArray) -> BitArray {
  case n <= 0 {
    True -> acc
    False -> make_zeros_acc(n - 1, <<acc:bits, 0:8>>)
  }
}

fn int_to_bytes(n: Int) -> BitArray {
  case n {
    0 -> <<0>>
    _ -> int_to_bytes_acc(n, <<>>)
  }
}

fn int_to_bytes_acc(n: Int, acc: BitArray) -> BitArray {
  case n {
    0 -> acc
    _ -> {
      let byte = int.bitwise_and(n, 0xff)
      let rest = int.bitwise_shift_right(n, 8)
      int_to_bytes_acc(rest, <<byte:8, acc:bits>>)
    }
  }
}

fn twos_complement(bytes: BitArray) -> BitArray {
  // Invert all bits, then add 1
  let inverted = invert_bytes(bytes, <<>>)
  add_one(inverted)
}

fn invert_bytes(data: BitArray, acc: BitArray) -> BitArray {
  case data {
    <<byte:8, rest:bits>> ->
      invert_bytes(rest, <<
        acc:bits,
        { int.bitwise_exclusive_or(byte, 0xff) }:8,
      >>)
    _ -> acc
  }
}

fn add_one(data: BitArray) -> BitArray {
  let size = bit_array.byte_size(data)
  add_one_at(data, size - 1, 1)
}

fn add_one_at(data: BitArray, pos: Int, carry: Int) -> BitArray {
  case pos < 0 {
    True -> data
    False -> {
      let assert Ok(<<byte:8>>) = bit_array.slice(data, pos, 1)
      let sum = byte + carry
      let new_byte = int.bitwise_and(sum, 0xff)
      let new_carry = int.bitwise_shift_right(sum, 8)
      let assert Ok(before) = bit_array.slice(data, 0, pos)
      let after_start = pos + 1
      let after_len = bit_array.byte_size(data) - after_start
      let assert Ok(after) = bit_array.slice(data, after_start, after_len)
      let new_data = bit_array.concat([before, <<new_byte:8>>, after])
      case new_carry {
        0 -> new_data
        _ -> add_one_at(new_data, pos - 1, new_carry)
      }
    }
  }
}
