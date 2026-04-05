/// EIP-712 tests using the canonical "Mail" example from the specification
/// and sign/recover roundtrips.
import gleam/bit_array
import gleam/dict
import gleam/string
import gleeth/crypto/secp256k1
import gleeth/crypto/wallet
import gleeth/eip712
import gleeth/utils/hex
import gleeunit/should

// The canonical EIP-712 example uses these test values
const test_private_key = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

const test_address = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

// =============================================================================
// Cross-verified against cast keccak
// =============================================================================

pub fn mail_type_hash_matches_cast_test() {
  let types =
    dict.from_list([
      #("Mail", [
        eip712.field("from", "address"),
        eip712.field("to", "address"),
        eip712.field("contents", "string"),
      ]),
    ])
  // cast keccak "Mail(address from,address to,string contents)"
  hex.encode(eip712.hash_type("Mail", types))
  |> should.equal(
    "0x536e54c54e6699204b424f41f6dea846ee38ac369afec3e7c141d2c92c65e67f",
  )
}

pub fn domain_type_hash_matches_cast_test() {
  let types =
    dict.from_list([
      #("EIP712Domain", [
        eip712.field("name", "string"),
        eip712.field("version", "string"),
        eip712.field("chainId", "uint256"),
        eip712.field("verifyingContract", "address"),
      ]),
    ])
  // cast keccak "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
  hex.encode(eip712.hash_type("EIP712Domain", types))
  |> should.equal(
    "0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f",
  )
}

pub fn domain_separator_matches_solidity_test() {
  let d =
    eip712.domain()
    |> eip712.domain_name("Ether Mail")
    |> eip712.domain_version("1")
    |> eip712.domain_chain_id(1)
    |> eip712.domain_verifying_contract(
      "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC",
    )
  let assert Ok(ds) = eip712.hash_domain(d, dict.new())
  // From Solidity: EIP712Verify.domainSeparator()
  hex.encode(ds)
  |> should.equal(
    "0xf2cee375fa42b42143804025fc449deafd50cc031ca257e0b194a650a912090f",
  )
}

pub fn mail_struct_hash_matches_solidity_test() {
  let types =
    dict.from_list([
      #("Mail", [
        eip712.field("from", "address"),
        eip712.field("to", "address"),
        eip712.field("contents", "string"),
      ]),
    ])
  let message =
    dict.from_list([
      #(
        "from",
        eip712.address_val("0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"),
      ),
      #("to", eip712.address_val("0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB")),
      #("contents", eip712.string_val("Hello, Bob!")),
    ])
  let assert Ok(sh) = eip712.hash_struct("Mail", message, types)
  // From Solidity: EIP712Verify.mailStructHash()
  hex.encode(sh)
  |> should.equal(
    "0x91731d77ee842ec57699d1d9f0fba1d65d9b4ab7a074ebd935d3ea7eebbdf214",
  )
}

pub fn mail_digest_matches_solidity_test() {
  let types =
    dict.from_list([
      #("Mail", [
        eip712.field("from", "address"),
        eip712.field("to", "address"),
        eip712.field("contents", "string"),
      ]),
    ])
  let d =
    eip712.domain()
    |> eip712.domain_name("Ether Mail")
    |> eip712.domain_version("1")
    |> eip712.domain_chain_id(1)
    |> eip712.domain_verifying_contract(
      "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC",
    )
  let message =
    dict.from_list([
      #(
        "from",
        eip712.address_val("0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"),
      ),
      #("to", eip712.address_val("0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB")),
      #("contents", eip712.string_val("Hello, Bob!")),
    ])
  let data = eip712.typed_data(types, "Mail", d, message)
  let assert Ok(digest) = eip712.hash_typed_data(data)
  // From Solidity: EIP712Verify.mailDigest()
  hex.encode(digest)
  |> should.equal(
    "0xd26e78c40dcd18c379ca37f0ae84be81178cfd5c9c46598d8e142648d00edd60",
  )
}

pub fn permit_domain_separator_matches_solidity_test() {
  let d =
    eip712.domain()
    |> eip712.domain_name("USD Coin")
    |> eip712.domain_version("2")
    |> eip712.domain_chain_id(1)
    |> eip712.domain_verifying_contract(
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    )
  let assert Ok(ds) = eip712.hash_domain(d, dict.new())
  // From Solidity: EIP712Verify.permitDomainSeparator()
  hex.encode(ds)
  |> should.equal(
    "0x06c37168a7db5138defc7866392bb87a741f9b3d104deb5094588ce041cae335",
  )
}

pub fn permit_struct_hash_matches_solidity_test() {
  let types =
    dict.from_list([
      #("Permit", [
        eip712.field("owner", "address"),
        eip712.field("spender", "address"),
        eip712.field("value", "uint256"),
        eip712.field("nonce", "uint256"),
        eip712.field("deadline", "uint256"),
      ]),
    ])
  let message =
    dict.from_list([
      #(
        "owner",
        eip712.address_val("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"),
      ),
      #(
        "spender",
        eip712.address_val("0x70997970C51812dc3A010C7d01b50e0d17dc79C8"),
      ),
      #("value", eip712.int_val(1_000_000)),
      #("nonce", eip712.int_val(0)),
      #("deadline", eip712.int_val(1_700_000_000)),
    ])
  let assert Ok(sh) = eip712.hash_struct("Permit", message, types)
  // From Solidity: EIP712Verify.permitStructHash()
  hex.encode(sh)
  |> should.equal(
    "0xc9612b1f92c543b5ddd2f9063f52b6a30939780587748aebeef985ca52cbe26b",
  )
}

pub fn permit_digest_matches_solidity_test() {
  let types =
    dict.from_list([
      #("Permit", [
        eip712.field("owner", "address"),
        eip712.field("spender", "address"),
        eip712.field("value", "uint256"),
        eip712.field("nonce", "uint256"),
        eip712.field("deadline", "uint256"),
      ]),
    ])
  let d =
    eip712.domain()
    |> eip712.domain_name("USD Coin")
    |> eip712.domain_version("2")
    |> eip712.domain_chain_id(1)
    |> eip712.domain_verifying_contract(
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    )
  let message =
    dict.from_list([
      #(
        "owner",
        eip712.address_val("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"),
      ),
      #(
        "spender",
        eip712.address_val("0x70997970C51812dc3A010C7d01b50e0d17dc79C8"),
      ),
      #("value", eip712.int_val(1_000_000)),
      #("nonce", eip712.int_val(0)),
      #("deadline", eip712.int_val(1_700_000_000)),
    ])
  let data = eip712.typed_data(types, "Permit", d, message)
  let assert Ok(digest) = eip712.hash_typed_data(data)
  // From Solidity: EIP712Verify.permitDigest()
  hex.encode(digest)
  |> should.equal(
    "0x3368ca109ea474392bce8aa2b852e284f41f4b066c353e2abaf41c9b7ccaf554",
  )
}

// =============================================================================
// encodeType tests
// =============================================================================

pub fn encode_type_simple_test() {
  let types =
    dict.from_list([
      #("Mail", [
        eip712.field("from", "address"),
        eip712.field("to", "address"),
        eip712.field("contents", "string"),
      ]),
    ])
  eip712.encode_type("Mail", types)
  |> should.equal("Mail(address from,address to,string contents)")
}

pub fn encode_type_with_referenced_struct_test() {
  let types =
    dict.from_list([
      #("Mail", [
        eip712.field("from", "Person"),
        eip712.field("to", "Person"),
        eip712.field("contents", "string"),
      ]),
      #("Person", [
        eip712.field("name", "string"),
        eip712.field("wallet", "address"),
      ]),
    ])
  // Referenced types are sorted alphabetically and appended
  eip712.encode_type("Mail", types)
  |> should.equal(
    "Mail(Person from,Person to,string contents)Person(string name,address wallet)",
  )
}

// =============================================================================
// hash_type tests
// =============================================================================

pub fn hash_type_mail_test() {
  let types =
    dict.from_list([
      #("Mail", [
        eip712.field("from", "address"),
        eip712.field("to", "address"),
        eip712.field("contents", "string"),
      ]),
    ])
  let hash = eip712.hash_type("Mail", types)
  // keccak256("Mail(address from,address to,string contents)")
  let hash_hex = hex.encode(hash)

  // Verify it's a 32-byte hash
  bit_array.byte_size(hash) |> should.equal(32)
  string.starts_with(hash_hex, "0x") |> should.be_true
}

// =============================================================================
// Domain separator tests
// =============================================================================

pub fn hash_domain_with_all_fields_test() {
  let d =
    eip712.domain()
    |> eip712.domain_name("Ether Mail")
    |> eip712.domain_version("1")
    |> eip712.domain_chain_id(1)
    |> eip712.domain_verifying_contract(
      "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC",
    )

  let assert Ok(domain_sep) = eip712.hash_domain(d, dict.new())
  bit_array.byte_size(domain_sep) |> should.equal(32)
}

pub fn hash_domain_minimal_test() {
  // Only name and version
  let d =
    eip712.domain()
    |> eip712.domain_name("Test")
    |> eip712.domain_version("1")

  let assert Ok(domain_sep) = eip712.hash_domain(d, dict.new())
  bit_array.byte_size(domain_sep) |> should.equal(32)
}

// =============================================================================
// Full hash_typed_data test
// =============================================================================

pub fn hash_typed_data_mail_test() {
  let types =
    dict.from_list([
      #("Mail", [
        eip712.field("from", "address"),
        eip712.field("to", "address"),
        eip712.field("contents", "string"),
      ]),
    ])

  let d =
    eip712.domain()
    |> eip712.domain_name("Ether Mail")
    |> eip712.domain_version("1")
    |> eip712.domain_chain_id(1)
    |> eip712.domain_verifying_contract(
      "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC",
    )

  let message =
    dict.from_list([
      #(
        "from",
        eip712.address_val("0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"),
      ),
      #("to", eip712.address_val("0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB")),
      #("contents", eip712.string_val("Hello, Bob!")),
    ])

  let data = eip712.typed_data(types, "Mail", d, message)
  let assert Ok(digest) = eip712.hash_typed_data(data)

  // Should be a 32-byte hash
  bit_array.byte_size(digest) |> should.equal(32)
}

// =============================================================================
// Sign and recover roundtrip
// =============================================================================

pub fn sign_and_recover_typed_data_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)

  let types =
    dict.from_list([
      #("Mail", [
        eip712.field("from", "address"),
        eip712.field("to", "address"),
        eip712.field("contents", "string"),
      ]),
    ])

  let d =
    eip712.domain()
    |> eip712.domain_name("Ether Mail")
    |> eip712.domain_version("1")
    |> eip712.domain_chain_id(1)

  let message =
    dict.from_list([
      #(
        "from",
        eip712.address_val("0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"),
      ),
      #("to", eip712.address_val("0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB")),
      #("contents", eip712.string_val("Hello, Bob!")),
    ])

  let data = eip712.typed_data(types, "Mail", d, message)

  // Sign
  let assert Ok(signature) = eip712.sign_typed_data(data, w)
  let sig_hex = secp256k1.signature_to_hex(signature)

  // Recover
  let assert Ok(recovered) = eip712.recover_typed_data(data, sig_hex)
  string.lowercase(recovered) |> should.equal(test_address)
}

// =============================================================================
// Nested struct types
// =============================================================================

pub fn sign_nested_struct_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)

  let types =
    dict.from_list([
      #("Mail", [
        eip712.field("from", "Person"),
        eip712.field("to", "Person"),
        eip712.field("contents", "string"),
      ]),
      #("Person", [
        eip712.field("name", "string"),
        eip712.field("wallet", "address"),
      ]),
    ])

  let d =
    eip712.domain()
    |> eip712.domain_name("Ether Mail")
    |> eip712.domain_version("1")
    |> eip712.domain_chain_id(1)

  let message =
    dict.from_list([
      #(
        "from",
        eip712.struct_val(
          dict.from_list([
            #("name", eip712.string_val("Alice")),
            #(
              "wallet",
              eip712.address_val("0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"),
            ),
          ]),
        ),
      ),
      #(
        "to",
        eip712.struct_val(
          dict.from_list([
            #("name", eip712.string_val("Bob")),
            #(
              "wallet",
              eip712.address_val("0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"),
            ),
          ]),
        ),
      ),
      #("contents", eip712.string_val("Hello, Bob!")),
    ])

  let data = eip712.typed_data(types, "Mail", d, message)

  let assert Ok(signature) = eip712.sign_typed_data(data, w)
  let sig_hex = secp256k1.signature_to_hex(signature)

  let assert Ok(recovered) = eip712.recover_typed_data(data, sig_hex)
  string.lowercase(recovered) |> should.equal(test_address)
}

// =============================================================================
// ERC-2612 Permit example
// =============================================================================

pub fn sign_permit_test() {
  let assert Ok(w) = wallet.from_private_key_hex(test_private_key)

  let types =
    dict.from_list([
      #("Permit", [
        eip712.field("owner", "address"),
        eip712.field("spender", "address"),
        eip712.field("value", "uint256"),
        eip712.field("nonce", "uint256"),
        eip712.field("deadline", "uint256"),
      ]),
    ])

  let d =
    eip712.domain()
    |> eip712.domain_name("USD Coin")
    |> eip712.domain_version("2")
    |> eip712.domain_chain_id(1)
    |> eip712.domain_verifying_contract(
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    )

  let message =
    dict.from_list([
      #("owner", eip712.address_val(test_address)),
      #(
        "spender",
        eip712.address_val("0x70997970c51812dc3a010c7d01b50e0d17dc79c8"),
      ),
      #("value", eip712.int_val(1_000_000)),
      #("nonce", eip712.int_val(0)),
      #("deadline", eip712.int_val(1_700_000_000)),
    ])

  let data = eip712.typed_data(types, "Permit", d, message)

  // Should produce a valid signature
  let assert Ok(signature) = eip712.sign_typed_data(data, w)
  let sig_hex = secp256k1.signature_to_hex(signature)

  // Should recover correctly
  let assert Ok(recovered) = eip712.recover_typed_data(data, sig_hex)
  string.lowercase(recovered) |> should.equal(test_address)
}

// =============================================================================
// Integer encoding
// =============================================================================

pub fn hash_with_uint256_test() {
  let types =
    dict.from_list([
      #("Order", [
        eip712.field("amount", "uint256"),
        eip712.field("price", "uint256"),
      ]),
    ])

  let d =
    eip712.domain() |> eip712.domain_name("DEX") |> eip712.domain_version("1")

  let message =
    dict.from_list([
      #("amount", eip712.int_val(1_000_000_000_000_000_000)),
      #("price", eip712.int_val(2000)),
    ])

  let data = eip712.typed_data(types, "Order", d, message)
  let assert Ok(digest) = eip712.hash_typed_data(data)
  bit_array.byte_size(digest) |> should.equal(32)
}

// =============================================================================
// Bool encoding
// =============================================================================

pub fn hash_with_bool_test() {
  let types =
    dict.from_list([
      #("Config", [
        eip712.field("enabled", "bool"),
        eip712.field("count", "uint256"),
      ]),
    ])

  let d = eip712.domain() |> eip712.domain_name("App")

  let msg_true =
    dict.from_list([
      #("enabled", eip712.bool_val(True)),
      #("count", eip712.int_val(42)),
    ])
  let msg_false =
    dict.from_list([
      #("enabled", eip712.bool_val(False)),
      #("count", eip712.int_val(42)),
    ])

  let data_true = eip712.typed_data(types, "Config", d, msg_true)
  let data_false = eip712.typed_data(types, "Config", d, msg_false)

  let assert Ok(hash_true) = eip712.hash_typed_data(data_true)
  let assert Ok(hash_false) = eip712.hash_typed_data(data_false)

  // Different bool values should produce different hashes
  should.not_equal(hash_true, hash_false)
}

// =============================================================================
// Determinism: same input produces same hash
// =============================================================================

pub fn deterministic_hash_test() {
  let types =
    dict.from_list([
      #("Mail", [
        eip712.field("from", "address"),
        eip712.field("contents", "string"),
      ]),
    ])

  let d = eip712.domain() |> eip712.domain_name("Test")

  let message =
    dict.from_list([
      #(
        "from",
        eip712.address_val("0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"),
      ),
      #("contents", eip712.string_val("Hello")),
    ])

  let data = eip712.typed_data(types, "Mail", d, message)

  let assert Ok(hash1) = eip712.hash_typed_data(data)
  let assert Ok(hash2) = eip712.hash_typed_data(data)
  hash1 |> should.equal(hash2)
}
