import gleam/json
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Test parsing null transaction receipt (transaction not found)
pub fn parse_null_transaction_receipt_test() {
  case methods.parse_transaction_receipt(json.string("null")) {
    Error(rpc_types.RpcError("Transaction receipt not found")) ->
      should.be_true(True)
    _ -> should.be_true(False)
  }
}
