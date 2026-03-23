import gleeth/ethereum/address
import gleeunit/should

// =============================================================================
// EIP-55 test vectors from the specification
// https://eips.ethereum.org/EIPS/eip-55
// =============================================================================

pub fn checksum_eip55_vector_1_test() {
  let assert Ok(result) =
    address.checksum("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
  result |> should.equal("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")
}

pub fn checksum_eip55_vector_2_test() {
  let assert Ok(result) =
    address.checksum("0xfb6916095ca1df60bb79ce92ce3ea74c37c5d359")
  result |> should.equal("0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359")
}

pub fn checksum_eip55_vector_3_test() {
  let assert Ok(result) =
    address.checksum("0xdbf03b407c01e7cd3cbea99509d93f8dddc8c6fb")
  result |> should.equal("0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB")
}

pub fn checksum_eip55_vector_4_test() {
  let assert Ok(result) =
    address.checksum("0xd1220a0cf47c7b9be7a2e6ba89f429762e7b9adb")
  result |> should.equal("0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb")
}

// =============================================================================
// Known addresses
// =============================================================================

pub fn checksum_anvil_account_0_test() {
  let assert Ok(result) =
    address.checksum("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
  result |> should.equal("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
}

pub fn checksum_anvil_account_1_test() {
  let assert Ok(result) =
    address.checksum("0x70997970c51812dc3a010c7d01b50e0d17dc79c8")
  result |> should.equal("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")
}

// =============================================================================
// Validation
// =============================================================================

pub fn valid_checksum_correct_test() {
  address.is_valid_checksum("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")
  |> should.be_true
}

pub fn valid_checksum_all_lowercase_test() {
  // All-lowercase is always valid per EIP-55
  address.is_valid_checksum("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
  |> should.be_true
}

pub fn valid_checksum_all_uppercase_test() {
  // All-uppercase is always valid per EIP-55
  address.is_valid_checksum("0x5AAEB6053F3E94C9B9A09F33669435E7EF1BEAED")
  |> should.be_true
}

pub fn invalid_checksum_wrong_case_test() {
  // Intentionally wrong casing (swapped one letter)
  address.is_valid_checksum("0x5aAeb6053f3E94C9b9A09f33669435E7Ef1BeAed")
  |> should.be_false
}

pub fn invalid_checksum_wrong_length_test() {
  address.is_valid_checksum("0x1234")
  |> should.be_false
}

// =============================================================================
// Edge cases
// =============================================================================

pub fn checksum_without_prefix_test() {
  let assert Ok(result) =
    address.checksum("5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
  result |> should.equal("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")
}

pub fn checksum_already_checksummed_test() {
  // Should produce the same result
  let assert Ok(result) =
    address.checksum("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")
  result |> should.equal("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")
}

pub fn checksum_invalid_length_test() {
  address.checksum("0x1234") |> should.be_error
}

pub fn to_lowercase_test() {
  let assert Ok(result) =
    address.to_lowercase("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")
  result |> should.equal("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
}
