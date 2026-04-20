# gleeth

[![Package Version](https://img.shields.io/hexpm/v/gleeth)](https://hex.pm/packages/gleeth)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleeth/)

An Ethereum library for Gleam, targeting the Erlang (BEAM) runtime. Provides JSON-RPC client, transaction signing, ABI encoding/decoding, and wallet management.

> **Warning**: gleeth has not been audited and is in early development. It is
> recommended for testnet and development use only. Do not use with real funds
> in production without thorough independent review.

## Installation

```sh
gleam add gleeth
```

For a step-by-step walkthrough, see the [ERC-20 tutorial](tutorial.md).

## Quick start

### Read chain state

```gleam
import gleeth/provider
import gleeth/rpc/methods

pub fn main() {
  let assert Ok(p) = provider.new("http://localhost:8545")

  // Get the latest block number
  let assert Ok(block_number) = methods.get_block_number(p)

  // Check an address balance
  let assert Ok(balance) = methods.get_balance(
    p,
    "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
  )
}
```

### Sign and send a transaction (builder API)

The builder API accepts human-readable values - no manual hex conversion needed.

```gleam
import gleeth/crypto/transaction
import gleeth/crypto/wallet
import gleeth/provider
import gleeth/rpc/methods

pub fn main() {
  let assert Ok(p) = provider.new("http://localhost:8545")
  let assert Ok(w) = wallet.from_private_key_hex("0xac09...")

  // EIP-1559 transaction (recommended - used on all major chains)
  let assert Ok(signed) =
    transaction.build_eip1559()
    |> transaction.eip1559_to("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")
    |> transaction.eip1559_value_ether("1.5")
    |> transaction.eip1559_gas_limit_int(21_000)
    |> transaction.eip1559_max_fee_gwei("30.0")
    |> transaction.eip1559_max_priority_fee_gwei("2.0")
    |> transaction.eip1559_nonce_int(0)
    |> transaction.eip1559_chain(1)
    |> transaction.sign_eip1559(w)

  // Broadcast and wait for receipt
  let assert Ok(tx_hash) = methods.send_raw_transaction(p, signed.raw_transaction)
  let assert Ok(receipt) = methods.wait_for_receipt(p, tx_hash)
}
```

Legacy transactions are also supported via `build_legacy()`.

For lower-level control, use `create_eip1559_transaction` or `create_legacy_transaction` with hex strings directly:

```gleam
pub fn main() {
  let assert Ok(p) = provider.new("http://localhost:8545")
  let assert Ok(w) = wallet.from_private_key_hex("0xac09...")

  // Gas estimation in one call
  let sender = wallet.get_address(w)
  let assert Ok(est) = gas.estimate_legacy(p, sender, "0x7099...", "0xde0b6b3a7640000", "0x")
  let assert Ok(nonce) = methods.get_transaction_count(p, sender, "pending")

  let assert Ok(tx) = transaction.create_legacy_transaction(
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    "0xde0b6b3a7640000",  // 1 ETH in wei hex
    est.gas_limit,         // from estimation
    est.gas_price,         // from estimation
    nonce,                 // from RPC
    "0x",                  // no calldata
    1,                     // mainnet
  )

  let assert Ok(signed) = transaction.sign_transaction(tx, w)
  let assert Ok(tx_hash) = methods.send_raw_transaction(p, signed.raw_transaction)
}
```

### Contract interaction

The `contract` module binds a provider, address, and ABI together so you can
call functions by name without manually encoding calldata:

```gleam
import gleeth/contract
import gleeth/crypto/wallet
import gleeth/ethereum/abi/json
import gleeth/provider

pub fn main() {
  let assert Ok(p) = provider.new("http://localhost:8545")
  let assert Ok(w) = wallet.from_private_key_hex("0xac09...")

  // Parse the ABI and create a contract handle
  let assert Ok(abi) = json.parse_abi(erc20_abi_json)
  let usdc = contract.at(p, "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", abi)

  // Read a balance - just pass strings, types are inferred from the ABI
  let assert Ok(values) = contract.call_raw(usdc, "balanceOf", [
    "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
  ])

  // Send a transfer
  let assert Ok(tx_hash) = contract.send_raw(usdc, w, "transfer", [
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    "1000000",
  ], "0x100000", 1)
}
```

### Low-level contract call

```gleam
import gleeth/provider
import gleeth/rpc/methods

pub fn main() {
  let assert Ok(p) = provider.new("http://localhost:8545")

  // Call balanceOf(address) on an ERC-20 with raw calldata
  let assert Ok(result) = methods.call_contract(
    p,
    "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",  // USDC
    "0x70a08231000000000000000000000000d8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
  )
}
```

### ABI encoding

```gleam
import gleeth/ethereum/abi/encode
import gleeth/ethereum/abi/types.{Uint, Address, AbiUintValue, AbiAddressValue}

pub fn main() {
  // Encode a function call: transfer(address, uint256)
  let assert Ok(calldata) = encode.encode_call(
    "transfer(address,uint256)",
    [Uint(256), Address],
    [
      AbiAddressValue("0x70997970C51812dc3A010C7d01b50e0d17dc79C8"),
      AbiUintValue(1000000),
    ],
  )
}
```

## Features

- **Transaction builder** - pipeline API with human-readable values (`value_ether("1.5")`, `gas_price_gwei("20.0")`)
- **Transaction signing** - Legacy (Type 0) and EIP-1559 (Type 2) with EIP-155 replay protection
- **Transaction decoding** - decode raw transactions, recover sender address
- **Gas estimation** - `gas.estimate_legacy` and `gas.estimate_eip1559` in a single call
- **Receipt polling** - `wait_for_receipt` with exponential backoff
- **Nonce manager** - local nonce tracking for multi-transaction sequences
- **Wei conversions** - `wei.from_ether("1.5")`, `wei.to_gwei(hex)`, `wei.from_int(21000)`
- **JSON-RPC client** - block number, balance, call, code, estimate gas, storage, logs, transactions, receipts, fee history
- **Provider abstraction** - opaque type with URL validation, chain ID caching, and configurable retry
- **ABI system** - full encoding/decoding for all Solidity types, calldata decoding, revert reason decoding, JSON ABI parsing, event log decoding
- **EIP-55 addresses** - `address.checksum` and `address.is_valid_checksum`
- **EIP-191 signing** - `sign_personal_message`, `recover_personal_message`, `verify_personal_message`
- **Wallet management** - key generation, message signing, signature recovery
- **Crypto primitives** - keccak256 (via ex_keccak NIF), secp256k1 (via ex_secp256k1 NIF)
- **EIP-712 signing** - `eip712.sign_typed_data` for permits, order books, meta-transactions
- **Batch JSON-RPC** - multiple RPC calls in a single HTTP request via `batch.new() |> batch.add(...) |> batch.execute_strings(provider)`
- **Contract deployment** - `deploy.deploy` and `deploy.deploy_with_args` handle signing, broadcasting, and receipt polling
- **Retry middleware** - automatic retry with exponential backoff on 429/503 via `provider.with_retry`
- **Contract type** - `contract.at(provider, address, abi)` for automatic ABI encoding/decoding on `call` and `send`, with string-coerced `call_raw`/`send_raw`
- **Event streaming** - `events.get_events` combines getLogs + ABI decoding; `get_events_by_name` filters by event
- **EIP-2612 permits** - `permit.sign` for one-liner permit signing with auto domain/nonce fetch
- **Multicall3** - `multicall.new() |> multicall.add(...) |> multicall.execute(provider)` batches contract reads at the EVM level
- **Block watcher** - `watcher.start(provider)` spawns a BEAM actor that polls for new blocks and sends typed events
- **Event watcher** - `event_watcher.start(provider, address, abi)` streams decoded contract events in real-time
- **ENS resolution** - `ens.resolve(provider, "vitalik.eth")` and `ens.reverse_resolve(provider, address)` for forward and reverse name resolution
- **Multi-chain registry** - `chain.by_name("arbitrum") |> chain.to_provider` with pre-configured mainnet, Sepolia, Arbitrum, Optimism, Polygon, Base
- **RLP encoding/decoding** - per Ethereum Yellow Paper spec

## Requirements

- Gleam >= 1.14.0
- Erlang/OTP >= 27
- Elixir (for ex_keccak and ex_secp256k1 NIF compilation)

Run `mix local.hex --force` before first build if Elixir is freshly installed.

## Development

```sh
gleam build          # Compile
gleam test           # Run all tests
gleam format         # Format code
gleam docs build     # Generate documentation
```

Further documentation can be found at <https://hexdocs.pm/gleeth>.
