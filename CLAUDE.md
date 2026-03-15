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

## Project State Warning

Many source files referenced in `gleeth.gleam` imports (commands/\*, rpc/\*, ethereum/\*, crypto/\*, utils/\*) were previously deleted from disk but remain staged in git (AD status). The project will not compile until these modules are either restored or the imports are cleaned up. Only `src/gleeth/cli.gleam` and `src/gleeth/config.gleam` currently exist alongside the entrypoint.

## Architecture

### Entrypoint and CLI dispatch

`src/gleeth.gleam` - parses argv, dispatches to command modules. The `wallet` subcommand is handled separately (no RPC URL required); all other commands go through `config.new()` for RPC URL validation, then `execute_command()`.

`src/gleeth/cli.gleam` - defines the `Command` sum type and `Args` record. All CLI argument parsing lives here. RPC URL can come from `--rpc-url` flag or `GLEETH_RPC_URL` env var.

### Module layout (intended design)

- `commands/` - one module per CLI command (balance, block_number, call, etc.), each exporting an `execute()` function
- `rpc/` - JSON-RPC 2.0 client infrastructure: `client.gleam` (HTTP), `methods.gleam` (Ethereum methods), `types.gleam` (GleethError sum type, RPC types), `response_utils.gleam`
- `ethereum/` - domain types (`types.gleam`: Address, Hash, Wei are String aliases), contract ABI encoding/decoding (`contract.gleam`), output formatting (`formatting.gleam`)
- `crypto/` - keccak256 hashing via `ex_keccak` NIF, secp256k1 via `secp256k1_gleam`, wallet key management
- `utils/` - hex conversion, input validation, file I/O

### Error handling

All errors flow through `rpc/types.gleam`'s `GleethError` sum type with variants: `InvalidRpcUrl`, `InvalidAddress`, `InvalidHash`, `RpcError`, `NetworkError`, `ParseError`, `ConfigError`. Commands return `Result(Nil, GleethError)`.

### FFI

- `src/gleeth_ffi.erl` - Erlang FFI for `crypto:strong_rand_bytes/1` (secure random generation)
- JavaScript FFI was used for keccak256 (`@noble/hashes`) and secp256k1 (`@noble/secp256k1`) but the JS FFI file has been deleted

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
