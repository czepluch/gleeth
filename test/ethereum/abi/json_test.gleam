import gleeth/ethereum/abi/json
import gleeth/ethereum/abi/types
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// ---------------------------------------------------------------------------
// ERC-20 ABI parsing
// ---------------------------------------------------------------------------

fn erc20_abi() -> String {
  "[
    {
      \"type\": \"function\",
      \"name\": \"transfer\",
      \"inputs\": [
        {\"name\": \"to\", \"type\": \"address\"},
        {\"name\": \"amount\", \"type\": \"uint256\"}
      ],
      \"outputs\": [{\"name\": \"\", \"type\": \"bool\"}],
      \"stateMutability\": \"nonpayable\"
    },
    {
      \"type\": \"function\",
      \"name\": \"balanceOf\",
      \"inputs\": [{\"name\": \"account\", \"type\": \"address\"}],
      \"outputs\": [{\"name\": \"\", \"type\": \"uint256\"}],
      \"stateMutability\": \"view\"
    },
    {
      \"type\": \"function\",
      \"name\": \"approve\",
      \"inputs\": [
        {\"name\": \"spender\", \"type\": \"address\"},
        {\"name\": \"amount\", \"type\": \"uint256\"}
      ],
      \"outputs\": [{\"name\": \"\", \"type\": \"bool\"}],
      \"stateMutability\": \"nonpayable\"
    },
    {
      \"type\": \"event\",
      \"name\": \"Transfer\",
      \"inputs\": [
        {\"name\": \"from\", \"type\": \"address\", \"indexed\": true},
        {\"name\": \"to\", \"type\": \"address\", \"indexed\": true},
        {\"name\": \"value\", \"type\": \"uint256\", \"indexed\": false}
      ]
    },
    {
      \"type\": \"event\",
      \"name\": \"Approval\",
      \"inputs\": [
        {\"name\": \"owner\", \"type\": \"address\", \"indexed\": true},
        {\"name\": \"spender\", \"type\": \"address\", \"indexed\": true},
        {\"name\": \"value\", \"type\": \"uint256\", \"indexed\": false}
      ]
    }
  ]"
}

pub fn parse_erc20_abi_test() {
  let assert Ok(entries) = json.parse_abi(erc20_abi())
  // 3 functions + 2 events = 5
  should.equal(list.length(entries), 5)
}

pub fn find_transfer_function_test() {
  let assert Ok(entries) = json.parse_abi(erc20_abi())
  let assert Ok(entry) = json.find_function(entries, "transfer")
  case entry {
    json.FunctionEntry(name, inputs, outputs, mutability) -> {
      should.equal(name, "transfer")
      should.equal(list.length(inputs), 2)
      should.equal(list.length(outputs), 1)
      should.equal(mutability, "nonpayable")
    }
    _ -> should.fail()
  }
}

pub fn find_balanceof_function_test() {
  let assert Ok(entries) = json.parse_abi(erc20_abi())
  let assert Ok(entry) = json.find_function(entries, "balanceOf")
  let input_types = json.input_types(entry)
  should.equal(input_types, [types.Address])
  let output_types = json.output_types(entry)
  should.equal(output_types, [types.Uint(256)])
}

pub fn find_nonexistent_function_test() {
  let assert Ok(entries) = json.parse_abi(erc20_abi())
  json.find_function(entries, "nonexistent")
  |> should.be_error()
}

pub fn find_events_test() {
  let assert Ok(entries) = json.parse_abi(erc20_abi())
  let events = json.find_events(entries)
  should.equal(list.length(events), 2)
}

pub fn parse_transfer_event_test() {
  let assert Ok(entries) = json.parse_abi(erc20_abi())
  let events = json.find_events(entries)
  let assert Ok(transfer_event) =
    list.find(events, fn(e) {
      case e {
        json.EventEntry(name, _) -> name == "Transfer"
        _ -> False
      }
    })
  case transfer_event {
    json.EventEntry(_, inputs) -> {
      should.equal(list.length(inputs), 3)
      // First two are indexed, third is not
      let assert [p1, p2, p3] = inputs
      should.equal(p1.indexed, True)
      should.equal(p2.indexed, True)
      should.equal(p3.indexed, False)
    }
    _ -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Edge cases
// ---------------------------------------------------------------------------

pub fn parse_empty_abi_test() {
  let assert Ok(entries) = json.parse_abi("[]")
  should.equal(entries, [])
}

pub fn parse_invalid_json_test() {
  json.parse_abi("not json")
  |> should.be_error()
}

pub fn parse_abi_with_unsupported_types_test() {
  // Constructor, receive, fallback should be silently skipped
  let abi_json =
    "[
    {\"type\": \"constructor\", \"inputs\": []},
    {\"type\": \"receive\", \"stateMutability\": \"payable\"},
    {\"type\": \"function\", \"name\": \"foo\", \"inputs\": [], \"outputs\": [], \"stateMutability\": \"view\"}
  ]"
  let assert Ok(entries) = json.parse_abi(abi_json)
  // Only the function should be kept
  should.equal(list.length(entries), 1)
}

pub fn parse_function_with_tuple_input_test() {
  let abi_json =
    "[{
    \"type\": \"function\",
    \"name\": \"submit\",
    \"inputs\": [{\"name\": \"data\", \"type\": \"bytes\"}],
    \"outputs\": [],
    \"stateMutability\": \"nonpayable\"
  }]"
  let assert Ok(entries) = json.parse_abi(abi_json)
  let assert Ok(entry) = json.find_function(entries, "submit")
  let input_types = json.input_types(entry)
  should.equal(input_types, [types.Bytes])
}

import gleam/list
