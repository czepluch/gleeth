# gleeth

[![Package Version](https://img.shields.io/hexpm/v/gleeth)](https://hex.pm/packages/gleeth)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleeth/)

An Ethereum library for Gleam, targeting the Erlang (BEAM) runtime. Provides JSON-RPC client, transaction signing, ABI encoding/decoding, and wallet management.

## Installation

```sh
gleam add gleeth
```

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

### Sign and send a transaction

All numeric values (wei amounts, gas, nonce) use `0x`-prefixed hex strings,
matching the Ethereum JSON-RPC format. Values returned by `methods.get_gas_price`,
`methods.get_transaction_count`, etc. can be passed directly to transaction
builders.

```gleam
import gleeth/crypto/transaction
import gleeth/crypto/wallet
import gleeth/provider
import gleeth/rpc/methods

pub fn main() {
  let assert Ok(p) = provider.new("http://localhost:8545")
  let assert Ok(w) = wallet.from_private_key_hex("0xac09...")

  let sender = wallet.get_address(w)

  // These return hex strings that can be passed directly to create_legacy_transaction
  let assert Ok(nonce) = methods.get_transaction_count(p, sender, "pending")
  let assert Ok(gas_price) = methods.get_gas_price(p)

  let assert Ok(tx) = transaction.create_legacy_transaction(
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    "0xde0b6b3a7640000",  // 1 ETH = 1e18 wei in hex
    "0x5208",              // 21000 gas in hex
    gas_price,             // from RPC, already hex
    nonce,                 // from RPC, already hex
    "0x",                  // no calldata
    1,                     // mainnet chain ID (integer, not hex)
  )

  let assert Ok(signed) = transaction.sign_transaction(tx, w)
  let assert Ok(tx_hash) = methods.send_raw_transaction(p, signed.raw_transaction)
}
```

### Call a contract

```gleam
import gleeth/provider
import gleeth/rpc/methods

pub fn main() {
  let assert Ok(p) = provider.new("http://localhost:8545")

  // Call balanceOf(address) on an ERC-20
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

- **JSON-RPC client** - block number, balance, call, code, estimate gas, storage, logs, transactions, receipts, fee history
- **Provider abstraction** - opaque type with URL validation and chain ID caching
- **Transaction signing** - Legacy (Type 0) and EIP-1559 (Type 2) with EIP-155 replay protection
- **ABI system** - full encoding/decoding for all Solidity types, JSON ABI parsing, event log decoding
- **Wallet management** - key generation, message signing, signature recovery
- **Crypto primitives** - keccak256 (via ex_keccak NIF), secp256k1 (via ex_secp256k1 NIF)
- **RLP encoding/decoding** - per Ethereum Yellow Paper spec

## Requirements

- Gleam >= 1.14.0
- Erlang/OTP >= 27
- Elixir (for ex_keccak and ex_secp256k1 NIF compilation)

Run `mix local.hex --force` before first build if Elixir is freshly installed.

## CLI

Gleeth also includes a CLI for quick Ethereum queries:

```sh
gleam run -- block-number --rpc-url http://localhost:8545
gleam run -- balance 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045 --rpc-url http://localhost:8545
gleam run -- send --to 0x... --value 0xde0b6b3a7640000 --private-key 0x... --rpc-url http://localhost:8545
```

Set `GLEETH_RPC_URL` to avoid passing `--rpc-url` every time.

## Development

```sh
gleam build          # Compile
gleam test           # Run all 285 tests
gleam format         # Format code
gleam docs build     # Generate documentation
```

Further documentation can be found at <https://hexdocs.pm/gleeth>.
