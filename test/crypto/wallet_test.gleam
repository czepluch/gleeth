import gleeth/crypto/wallet
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

/// Test wallet creation from private key
pub fn wallet_creation_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  case wallet.from_private_key_hex(hex_key) {
    Ok(wallet_obj) -> {
      wallet.is_valid(wallet_obj) |> should.be_true()
      let address = wallet.get_address(wallet_obj)
      address |> should.equal("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
    }
    Error(_) -> should.fail()
  }
}

/// Test wallet creation with invalid key
pub fn wallet_invalid_key_test() {
  case wallet.from_private_key_hex("invalid") {
    Ok(_) -> should.fail()
    Error(_) -> Nil
  }
}

/// Test message signing
pub fn wallet_signing_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  case wallet.from_private_key_hex(hex_key) {
    Ok(wallet_obj) -> {
      case wallet.sign_personal_message(wallet_obj, "test message") {
        Ok(_signature) -> Nil
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

/// Test wallet info extraction
pub fn wallet_info_test() {
  let hex_key =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  case wallet.from_private_key_hex(hex_key) {
    Ok(wallet_obj) -> {
      wallet.get_private_key_hex(wallet_obj) |> should.equal(hex_key)
      wallet.get_address(wallet_obj)
      |> should.equal("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
    }
    Error(_) -> should.fail()
  }
}
