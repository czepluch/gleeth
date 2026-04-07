# Tutorial: Interact with an ERC-20 token

This tutorial walks through a complete ERC-20 interaction using gleeth: checking balances, approving a spender, transferring tokens, and decoding Transfer events.

## Prerequisites

- Gleam >= 1.14.0, Erlang/OTP >= 27, Elixir installed
- An Ethereum RPC endpoint (we'll use a local [anvil](https://book.getfoundry.sh/anvil/) node)

Start anvil:

```sh
anvil
```

This gives you 10 funded test accounts on `http://localhost:8545`.

## Setup

Add gleeth to your project:

```sh
gleam add gleeth
```

## 1. Connect to the network

Every interaction starts with a `Provider` - a validated RPC connection.

```gleam
import gleeth/provider

pub fn main() {
  // Local development
  let assert Ok(p) = provider.new("http://localhost:8545")

  // For public endpoints, enable retry (handles rate limiting)
  let p = provider.with_retry(p, provider.default_retry())
}
```

`provider.mainnet()` and `provider.sepolia()` are shortcuts with retries enabled by default.

## 2. Check a token balance

The simplest way to read from a contract is with the `Contract` type. You need the contract's ABI (a JSON description of its functions).

```gleam
import gleeth/contract
import gleeth/ethereum/abi/json
import gleeth/ethereum/abi/types
import gleeth/provider

// Minimal ERC-20 ABI - just the functions we need
const erc20_abi = "[
  {\"type\":\"function\",\"name\":\"balanceOf\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\"},
  {\"type\":\"function\",\"name\":\"transfer\",\"inputs\":[{\"name\":\"to\",\"type\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"nonpayable\"},
  {\"type\":\"function\",\"name\":\"approve\",\"inputs\":[{\"name\":\"spender\",\"type\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"nonpayable\"},
  {\"type\":\"function\",\"name\":\"transferFrom\",\"inputs\":[{\"name\":\"from\",\"type\":\"address\"},{\"name\":\"to\",\"type\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"nonpayable\"},
  {\"type\":\"event\",\"name\":\"Transfer\",\"inputs\":[{\"name\":\"from\",\"type\":\"address\",\"indexed\":true},{\"name\":\"to\",\"type\":\"address\",\"indexed\":true},{\"name\":\"value\",\"type\":\"uint256\",\"indexed\":false}]},
  {\"type\":\"event\",\"name\":\"Approval\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"indexed\":true},{\"name\":\"spender\",\"type\":\"address\",\"indexed\":true},{\"name\":\"value\",\"type\":\"uint256\",\"indexed\":false}]}
]"

pub fn main() {
  let assert Ok(p) = provider.new("http://localhost:8545")
  let assert Ok(abi) = json.parse_abi(erc20_abi)

  let token = contract.at(p, "0x5FbDB2315678afecb367f032d93F642f64180aa3", abi)

  // call_raw accepts plain strings - the ABI handles type conversion
  let assert Ok([types.UintValue(balance)]) =
    contract.call_raw(token, "balanceOf", [
      "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    ])

  // balance is now an Int representing the token amount
}
```

`call_raw` is the easiest API - you pass strings and the ABI's type definitions handle the conversion. For more control, use `call` with explicit `AbiValue` types.

## 3. Transfer tokens

Write operations use `send_raw`, which encodes the calldata, signs a transaction, broadcasts it, and returns the transaction hash.

```gleam
import gleeth/contract
import gleeth/crypto/wallet
import gleeth/ethereum/abi/json
import gleeth/provider
import gleeth/rpc/methods

pub fn main() {
  let assert Ok(p) = provider.new("http://localhost:8545")
  let assert Ok(abi) = json.parse_abi(erc20_abi)
  let assert Ok(w) = wallet.from_private_key_hex(
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  )

  let token = contract.at(p, "0x5FbDB2315678afecb367f032d93F642f64180aa3", abi)

  // Transfer 1000 tokens (assuming 18 decimals: 1000 * 10^18)
  let assert Ok(tx_hash) =
    contract.send_raw(token, w, "transfer", [
      "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",  // recipient
      "1000000000000000000000",                        // amount (decimal string)
    ], "0x100000", 31337)

  // Wait for the transaction to be mined
  let assert Ok(receipt) = methods.wait_for_receipt(p, tx_hash)
}
```

The chain ID (31337) is anvil's default. For mainnet use 1, for Sepolia use 11155111.

## 4. Approve and transferFrom

The approve/transferFrom pattern allows a third party to spend tokens on your behalf. This is the foundation of DEX interactions, lending protocols, and more.

```gleam
import gleeth/contract
import gleeth/crypto/wallet
import gleeth/ethereum/abi/json
import gleeth/provider

pub fn main() {
  let assert Ok(p) = provider.new("http://localhost:8545")
  let assert Ok(abi) = json.parse_abi(erc20_abi)

  // Owner (account 0) approves spender (account 1)
  let assert Ok(owner) = wallet.from_private_key_hex(
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  )
  let assert Ok(spender) = wallet.from_private_key_hex(
    "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
  )

  let token = contract.at(p, "0x5FbDB2315678afecb367f032d93F642f64180aa3", abi)

  // Step 1: Owner approves spender for 500 tokens
  let assert Ok(_) =
    contract.send_raw(token, owner, "approve", [
      wallet.get_address(spender),
      "500000000000000000000",
    ], "0x100000", 31337)

  // Step 2: Spender transfers 200 tokens from owner to themselves
  let assert Ok(_) =
    contract.send_raw(token, spender, "transferFrom", [
      wallet.get_address(owner),
      wallet.get_address(spender),
      "200000000000000000000",
    ], "0x100000", 31337)
}
```

## 5. Decode Transfer events

After a transfer, you can decode the emitted events to see exactly what happened.

```gleam
import gleeth/contract
import gleeth/crypto/wallet
import gleeth/ethereum/abi/json
import gleeth/ethereum/abi/types
import gleeth/events
import gleeth/provider
import gleeth/rpc/methods

pub fn main() {
  let assert Ok(p) = provider.new("http://localhost:8545")
  let assert Ok(abi) = json.parse_abi(erc20_abi)
  let assert Ok(w) = wallet.from_private_key_hex(
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  )

  let token_address = "0x5FbDB2315678afecb367f032d93F642f64180aa3"
  let token = contract.at(p, token_address, abi)

  // Send a transfer
  let assert Ok(tx_hash) =
    contract.send_raw(token, w, "transfer", [
      "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
      "1000000000000000000000",
    ], "0x100000", 31337)

  let assert Ok(receipt) = methods.wait_for_receipt(p, tx_hash)

  // Decode the Transfer event from the receipt logs
  let decoded = events.decode_logs(receipt.logs, abi)

  // Each result is either Decoded (with event name and params) or Unknown
  case decoded {
    [events.Decoded(event, _log)] -> {
      // event.event_name == "Transfer"
      // event.params contains: [("from", AddressValue(...)), ("to", AddressValue(...)), ("value", UintValue(...))]
      case event.params {
        [#("from", types.AddressValue(from)),
         #("to", types.AddressValue(to)),
         #("value", types.UintValue(value))] -> {
          // from, to, value are now typed Gleam values
        }
        _ -> Nil
      }
    }
    _ -> Nil
  }
}
```

You can also query historical events:

```gleam
// Get all Transfer events in a block range
let assert Ok(transfers) =
  events.get_events_by_name(p, token_address, abi, "Transfer", "0x0", "latest")
```

## 6. Batch reads with Multicall3

When you need to read multiple values efficiently (e.g. balances for a list of addresses), use Multicall3 to batch everything into a single RPC call.

```gleam
import gleam/bit_array
import gleam/string
import gleeth/ethereum/abi/encode
import gleeth/ethereum/abi/types
import gleeth/multicall
import gleeth/provider

pub fn main() {
  let assert Ok(p) = provider.new("http://localhost:8545")
  let token = "0x5FbDB2315678afecb367f032d93F642f64180aa3"

  // Encode balanceOf calldata for each address
  let assert Ok(call1) = encode.encode_call("balanceOf", [
    #(types.Address, types.AddressValue("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")),
  ])
  let assert Ok(call2) = encode.encode_call("balanceOf", [
    #(types.Address, types.AddressValue("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")),
  ])

  let hex1 = "0x" <> string.lowercase(bit_array.base16_encode(call1))
  let hex2 = "0x" <> string.lowercase(bit_array.base16_encode(call2))

  // Batch both reads into a single RPC call
  let assert Ok(results) =
    multicall.new()
    |> multicall.add(token, hex1)
    |> multicall.add(token, hex2)
    |> multicall.execute(p)

  // results: [CallSuccess("0x..."), CallSuccess("0x...")]
}
```

## 7. Convert between units

Token amounts are typically in the smallest unit (like wei for ETH). Use the `wei` module to convert.

```gleam
import gleeth/wei

// Convert 1.5 ETH to wei hex
let assert Ok(hex) = wei.from_ether("1.5")
// hex = "0x14d1120d7b160000"

// Convert back
let assert Ok(eth) = wei.to_ether(hex)
// eth = "1.5"

// Integer to hex (for gas limits etc.)
let gas_hex = wei.from_int(21_000)
// gas_hex = "0x5208"
```

## Next steps

- [API documentation on HexDocs](https://hexdocs.pm/gleeth)
- EIP-712 signing for permits and off-chain orders (`gleeth/eip712`)
- EIP-2612 permit helper for gasless token approvals (`gleeth/permit`)
- Transaction builder with human-readable values (`transaction.build_eip1559()`)
- Batch JSON-RPC for multiple independent queries (`gleeth/rpc/batch`)
