//// Solidity ABI type system for encoding and decoding.
////
//// `AbiType` describes the shape of a value (e.g. `Uint(256)`, `Address`,
//// `Array(Bool)`). `AbiValue` carries an actual value of that shape. Use
//// these with `abi/encode` and `abi/decode` to produce and consume raw
//// calldata.
////
//// ## Examples
////
//// ```gleam
//// // Describe a transfer(address, uint256) signature
//// let types = [Address, Uint(256)]
////
//// // Construct the values
//// let values = [
////   AddressValue("0x70997970C51812dc3A010C7d01b50e0d17dc79C8"),
////   UintValue(1000000),
//// ]
//// ```

import gleam/int
import gleam/list
import gleam/string

/// Describes a Solidity ABI type. Maps directly to the Solidity type system.
pub type AbiType {
  /// Unsigned integer (`uint8` through `uint256`). Size is in bits, must be
  /// a multiple of 8.
  Uint(size: Int)
  /// Signed integer (`int8` through `int256`). Size is in bits.
  Int(size: Int)
  /// 20-byte Ethereum address.
  Address
  /// Boolean value.
  Bool
  /// Fixed-size byte array (`bytes1` through `bytes32`). Size is in bytes.
  FixedBytes(size: Int)
  /// Dynamic-length byte array (`bytes`).
  Bytes
  /// Dynamic-length UTF-8 string.
  String
  /// Dynamic-length array of a single element type (`T[]`).
  Array(element: AbiType)
  /// Fixed-length array of a single element type (`T[k]`).
  FixedArray(element: AbiType, size: Int)
  /// Tuple of heterogeneous types, e.g. `(address, uint256, bool)`.
  Tuple(elements: List(AbiType))
}

/// A concrete value matching an `AbiType`. Passed to `abi/encode.encode`
/// and returned by `abi/decode.decode`.
pub type AbiValue {
  /// Unsigned integer value. Must fit within the bit size of the
  /// corresponding `Uint` type.
  UintValue(Int)
  /// Signed integer value.
  IntValue(Int)
  /// Ethereum address as a hex string with `0x` prefix.
  AddressValue(String)
  /// Boolean value.
  BoolValue(Bool)
  /// Fixed-size byte array.
  FixedBytesValue(BitArray)
  /// Dynamic-length byte array.
  BytesValue(BitArray)
  /// UTF-8 string value.
  StringValue(String)
  /// Array of values (used for both `Array` and `FixedArray` types).
  ArrayValue(List(AbiValue))
  /// Tuple of heterogeneous values.
  TupleValue(List(AbiValue))
}

/// Errors that can occur during ABI encoding, decoding, or type parsing.
pub type AbiError {
  /// Failed to parse a Solidity type string (e.g. `"uint999"`).
  TypeParseError(String)
  /// Failed to encode a value (type mismatch, value out of range).
  EncodeError(String)
  /// Failed to decode calldata (truncated data, invalid encoding).
  DecodeError(String)
  /// Failed to parse a JSON ABI file.
  InvalidAbiJson(String)
}

/// Returns `True` if the type uses dynamic (offset-based) ABI encoding.
///
/// Static types (`uint`, `int`, `address`, `bool`, `bytesN`) are encoded
/// inline. Dynamic types (`bytes`, `string`, `T[]`) use a 32-byte offset
/// pointer in the head region.
pub fn is_dynamic(t: AbiType) -> Bool {
  case t {
    Uint(_) | Int(_) | Address | Bool | FixedBytes(_) -> False
    Bytes | String -> True
    Array(_) -> True
    FixedArray(element, _) -> is_dynamic(element)
    Tuple(elements) -> list.any(elements, is_dynamic)
  }
}

/// Number of bytes this type occupies in the head region of a tuple encoding.
/// Static types are encoded inline (possibly > 32 bytes for arrays/tuples).
/// Dynamic types get a 32-byte offset pointer.
pub fn head_size(t: AbiType) -> Int {
  case is_dynamic(t) {
    True -> 32
    False -> enc_size(t)
  }
}

/// Fixed encoding size for static types.
fn enc_size(t: AbiType) -> Int {
  case t {
    Uint(_) | Int(_) | Address | Bool | FixedBytes(_) -> 32
    FixedArray(element, size) -> size * enc_size(element)
    Tuple(elements) ->
      list.fold(elements, 0, fn(acc, el) { acc + enc_size(el) })
    // Dynamic types - should not be called, but return 32 as fallback
    _ -> 32
  }
}

/// Canonical ABI type string used for function signatures and selectors.
///
/// ## Examples
///
/// ```gleam
/// types.to_string(Uint(256))
/// // -> "uint256"
///
/// types.to_string(Array(Address))
/// // -> "address[]"
///
/// types.to_string(Tuple([Address, Uint(256)]))
/// // -> "(address,uint256)"
/// ```
pub fn to_string(t: AbiType) -> String {
  case t {
    Uint(size) -> "uint" <> int.to_string(size)
    Int(size) -> "int" <> int.to_string(size)
    Address -> "address"
    Bool -> "bool"
    FixedBytes(size) -> "bytes" <> int.to_string(size)
    Bytes -> "bytes"
    String -> "string"
    Array(element) -> to_string(element) <> "[]"
    FixedArray(element, size) ->
      to_string(element) <> "[" <> int.to_string(size) <> "]"
    Tuple(elements) ->
      "(" <> string.join(list.map(elements, to_string), ",") <> ")"
  }
}
