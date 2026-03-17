import gleam/int
import gleam/list
import gleam/string

pub type AbiType {
  Uint(size: Int)
  Int(size: Int)
  Address
  Bool
  FixedBytes(size: Int)
  Bytes
  String
  Array(element: AbiType)
  FixedArray(element: AbiType, size: Int)
  Tuple(elements: List(AbiType))
}

pub type AbiValue {
  UintValue(Int)
  IntValue(Int)
  AddressValue(String)
  BoolValue(Bool)
  FixedBytesValue(BitArray)
  BytesValue(BitArray)
  StringValue(String)
  ArrayValue(List(AbiValue))
  TupleValue(List(AbiValue))
}

pub type AbiError {
  TypeParseError(String)
  EncodeError(String)
  DecodeError(String)
  InvalidAbiJson(String)
}

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

/// Canonical ABI type string (used for function signatures / selectors).
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
