# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Gleeth

Gleeth is an Ethereum library and CLI tool written in Gleam, targeting the Erlang (BEAM) runtime. It aims to be a Gleam equivalent of ethers.rs/ethers.js - providing JSON-RPC client functionality, contract interaction, cryptographic operations (keccak256, secp256k1), and wallet management.

## Build Commands

```sh
gleam build          # Compile the project
gleam test           # Run all tests
gleam run            # Run the CLI entrypoint (src/gleeth.gleam)
gleam format         # Format all .gleam files
gleam format --check # Check formatting without modifying files
```

There is no single-test runner built in. Tests are discovered by gleeunit - any public function ending in `_test` in files under `test/` is a test.

## Build Prerequisites

Requires Elixir installed (e.g. `mise install elixir`) for the `ex_keccak` and `ex_secp256k1` NIF dependencies. Run `mix local.hex --force` before first build.

## Architecture

### Module layout

- `rpc/` - JSON-RPC 2.0 client: `client.gleam` (HTTP), `methods.gleam` (Ethereum methods + receipt polling), `types.gleam` (GleethError sum type), `response_utils.gleam`
- `ethereum/` - domain types (`types.gleam`), contract helpers (`contract.gleam`), ABI encoding/decoding (`abi/`), EIP-55 addresses (`address.gleam`)
- `crypto/` - keccak256 (`keccak.gleam`), secp256k1 (`secp256k1.gleam`), wallet (`wallet.gleam`), transaction signing/decoding/builder (`transaction.gleam`), random key generation (`random.gleam`)
- `provider.gleam` - opaque Provider type wrapping validated RPC URL + chain ID + retry config
- `wei.gleam` - ETH/gwei/wei conversions between human-readable and hex formats
- `gas.gleam` - gas estimation helpers (combines multiple RPC calls)
- `nonce.gleam` - local nonce tracking for multi-transaction sequences
- `encoding/` - RLP encoding/decoding
- `eip712.gleam` - EIP-712 typed structured data hashing and signing
- `deploy.gleam` - contract deployment helpers (deploy, deploy_with_args)
- `contract.gleam` - high-level contract interaction (bind provider + address + ABI, call/send with auto encoding)
- `events.gleam` - query and decode contract events with ABI matching
- `permit.gleam` - EIP-2612 permit signing helper
- `rpc/batch.gleam` - batch JSON-RPC requests in a single HTTP call
- `utils/` - hex conversion, input validation

### Error handling

All errors flow through `rpc/types.gleam`'s `GleethError` sum type with variants: `InvalidRpcUrl`, `InvalidAddress`, `InvalidHash`, `RpcError`, `NetworkError`, `ParseError`, `ConfigError`, `AbiErr`, `WalletErr`, `TransactionErr`. Commands return `Result(Nil, GleethError)`. The `error_to_string` function provides human-readable messages.

### FFI

- `src/gleeth_ffi.erl` - Erlang FFI for `crypto:strong_rand_bytes/1` (secure random) and `os:getenv/1` (env vars)
- All keccak256 calls route through `crypto/keccak.gleam` which uses `ex_keccak` NIF
- All secp256k1 calls route through `crypto/secp256k1.gleam` which uses `secp256k1_gleam`/`ex_secp256k1` NIF

### Key dependencies

- `ex_keccak` / `secp256k1_gleam` - Rust NIFs via rustler_precompiled for crypto
- `bigi` - big integer arithmetic for Wei/hex values
- `gleam_otp` - concurrent task execution (parallel balance checks)
- `gleam_httpc` - HTTP client (Erlang only)
- `gleam_json` - JSON-RPC encoding/decoding

## Gleam Conventions

- Pattern match on results with `use x <- result.try(...)` for monadic error chaining
- Public types use constructors as their API (e.g., `Config(rpc_url: String)`)
- Imports use `as` aliases: `import gleeth/rpc/types as rpc_types`
- Test files mirror source structure under `test/` with `_test` suffix
