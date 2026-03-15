import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Test parsing null transaction receipt (transaction not found)
pub fn parse_null_transaction_receipt_test() {
  let body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null}"
  case methods.parse_transaction_receipt(body) {
    Error(rpc_types.ParseError(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}
