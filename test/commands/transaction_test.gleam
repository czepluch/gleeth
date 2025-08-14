import gleam/json
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Test that parse_transaction handles null response correctly
pub fn parse_null_transaction_test() {
  let null_json = json.string("null")

  case methods.parse_transaction(null_json) {
    Ok(_) -> should.be_true(False)
    // Should fail for null transaction
    Error(error) -> {
      case error {
        rpc_types.RpcError(message) ->
          should.equal(message, "Transaction not found")
        _ -> should.be_true(False)
        // Should be RpcError type
      }
    }
  }
}

// Test that parse_transaction function exists and can be called
pub fn parse_transaction_function_exists_test() {
  // This test just verifies the function exists and can be called
  let simple_json = json.string("invalid")

  case methods.parse_transaction(simple_json) {
    Ok(_) -> should.be_true(True)
    // Any result is fine
    Error(_) -> should.be_true(True)
    // Any error is fine for this test
  }
}
