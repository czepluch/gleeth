import gleam/bit_array
import gleam/string
import gleeth/ethereum/abi/decode
import gleeth/ethereum/abi/encode
import gleeth/ethereum/abi/json
import gleeth/ethereum/abi/types
import gleeunit/should

// =============================================================================
// decode_function_input tests
// =============================================================================

// ERC-20 transfer(address,uint256)
pub fn decode_function_input_transfer_test() {
  // Encode a transfer call
  let assert Ok(calldata) =
    encode.encode_call("transfer", [
      #(
        types.Address,
        types.AddressValue("0xdead000000000000000000000000000000000000"),
      ),
      #(types.Uint(256), types.UintValue(1_000_000_000_000_000_000)),
    ])
  let calldata_hex = "0x" <> string.lowercase(bit_array.base16_encode(calldata))

  let assert Ok(values) =
    decode.decode_function_input("transfer(address,uint256)", calldata_hex)
  case values {
    [types.AddressValue(addr), types.UintValue(amount)] -> {
      addr
      |> string.lowercase
      |> should.equal("0xdead000000000000000000000000000000000000")
      amount |> should.equal(1_000_000_000_000_000_000)
    }
    _ -> should.fail()
  }
}

// ERC-20 approve(address,uint256)
pub fn decode_function_input_approve_test() {
  let assert Ok(calldata) =
    encode.encode_call("approve", [
      #(
        types.Address,
        types.AddressValue("0x70997970c51812dc3a010c7d01b50e0d17dc79c8"),
      ),
      #(types.Uint(256), types.UintValue(500)),
    ])
  let calldata_hex = "0x" <> string.lowercase(bit_array.base16_encode(calldata))

  let assert Ok(values) =
    decode.decode_function_input("approve(address,uint256)", calldata_hex)
  case values {
    [types.AddressValue(_), types.UintValue(amount)] ->
      amount |> should.equal(500)
    _ -> should.fail()
  }
}

// Function with no parameters
pub fn decode_function_input_no_params_test() {
  // totalSupply() has selector 0x18160ddd and no params
  let assert Ok(selector) = encode.function_selector("totalSupply", [])
  let calldata_hex = "0x" <> string.lowercase(bit_array.base16_encode(selector))

  let assert Ok(values) =
    decode.decode_function_input("totalSupply()", calldata_hex)
  values |> should.equal([])
}

// Multiple parameter types
pub fn decode_function_input_multi_param_test() {
  let assert Ok(calldata) =
    encode.encode_call("setValues", [
      #(types.Uint(256), types.UintValue(42)),
      #(types.Bool, types.BoolValue(True)),
      #(
        types.Address,
        types.AddressValue("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"),
      ),
    ])
  let calldata_hex = "0x" <> string.lowercase(bit_array.base16_encode(calldata))

  let assert Ok(values) =
    decode.decode_function_input(
      "setValues(uint256,bool,address)",
      calldata_hex,
    )
  case values {
    [types.UintValue(n), types.BoolValue(b), types.AddressValue(_)] -> {
      n |> should.equal(42)
      b |> should.equal(True)
    }
    _ -> should.fail()
  }
}

// Selector mismatch
pub fn decode_function_input_wrong_selector_test() {
  // Encode as transfer but try to decode as approve
  let assert Ok(calldata) =
    encode.encode_call("transfer", [
      #(
        types.Address,
        types.AddressValue("0xdead000000000000000000000000000000000000"),
      ),
      #(types.Uint(256), types.UintValue(100)),
    ])
  let calldata_hex = "0x" <> string.lowercase(bit_array.base16_encode(calldata))

  decode.decode_function_input("approve(address,uint256)", calldata_hex)
  |> should.be_error
}

// Calldata too short
pub fn decode_function_input_too_short_test() {
  decode.decode_function_input("transfer(address,uint256)", "0x1234")
  |> should.be_error
}

// Invalid hex
pub fn decode_function_input_invalid_hex_test() {
  decode.decode_function_input("transfer(address,uint256)", "not hex")
  |> should.be_error
}

// =============================================================================
// decode_calldata with ABI entries
// =============================================================================

pub fn decode_calldata_with_abi_test() {
  let abi_json =
    "[{\"type\":\"function\",\"name\":\"transfer\",\"inputs\":[{\"name\":\"to\",\"type\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"nonpayable\"}]"

  let assert Ok(entries) = json.parse_abi(abi_json)

  let assert Ok(calldata) =
    encode.encode_call("transfer", [
      #(
        types.Address,
        types.AddressValue("0xdead000000000000000000000000000000000000"),
      ),
      #(types.Uint(256), types.UintValue(999)),
    ])
  let calldata_hex = "0x" <> string.lowercase(bit_array.base16_encode(calldata))

  let assert Ok(decoded) = decode.decode_calldata(calldata_hex, entries)
  decoded.function_name |> should.equal("transfer")
  case decoded.arguments {
    [types.AddressValue(_), types.UintValue(amount)] ->
      amount |> should.equal(999)
    _ -> should.fail()
  }
}

// =============================================================================
// decode_function_output tests
// =============================================================================

pub fn decode_function_output_single_uint_test() {
  // Encode a uint256 value as if it were a function return
  let assert Ok(encoded) =
    encode.encode([#(types.Uint(256), types.UintValue(42))])
  let hex = "0x" <> string.lowercase(bit_array.base16_encode(encoded))

  let assert Ok(values) = decode.decode_function_output("uint256", hex)
  case values {
    [types.UintValue(n)] -> n |> should.equal(42)
    _ -> should.fail()
  }
}

pub fn decode_function_output_multi_test() {
  // Encode (uint256, bool) return values
  let assert Ok(encoded) =
    encode.encode([
      #(types.Uint(256), types.UintValue(100)),
      #(types.Bool, types.BoolValue(True)),
    ])
  let hex = "0x" <> string.lowercase(bit_array.base16_encode(encoded))

  let assert Ok(values) = decode.decode_function_output("uint256,bool", hex)
  case values {
    [types.UintValue(n), types.BoolValue(b)] -> {
      n |> should.equal(100)
      b |> should.equal(True)
    }
    _ -> should.fail()
  }
}

// =============================================================================
// Roundtrip: encode_call -> decode_function_input
// =============================================================================

pub fn roundtrip_encode_decode_test() {
  let assert Ok(calldata) =
    encode.encode_call("transferFrom", [
      #(
        types.Address,
        types.AddressValue("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"),
      ),
      #(
        types.Address,
        types.AddressValue("0x70997970c51812dc3a010c7d01b50e0d17dc79c8"),
      ),
      #(types.Uint(256), types.UintValue(12_345)),
    ])
  let calldata_hex = "0x" <> string.lowercase(bit_array.base16_encode(calldata))

  let assert Ok(values) =
    decode.decode_function_input(
      "transferFrom(address,address,uint256)",
      calldata_hex,
    )
  case values {
    [types.AddressValue(from), types.AddressValue(to), types.UintValue(amount)] -> {
      from
      |> string.lowercase
      |> should.equal("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
      to
      |> string.lowercase
      |> should.equal("0x70997970c51812dc3a010c7d01b50e0d17dc79c8")
      amount |> should.equal(12_345)
    }
    _ -> should.fail()
  }
}
