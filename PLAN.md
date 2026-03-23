# Gleeth Development Plan

Gleeth aims to be the Gleam equivalent of alloy.rs / ethers.js - a complete Ethereum library targeting the Erlang/BEAM runtime.

## Current State (v1.1.0, March 2026)

### What works

- JSON-RPC client: block number, balance, call, code, estimate gas, storage, logs, transaction, receipt, fee history
- Provider abstraction: opaque type with URL validation and chain ID caching
- Transaction signing: Legacy (Type 0) and EIP-1559 (Type 2) with EIP-155 replay protection
- Transaction decoding: decode raw legacy and EIP-1559 transactions back into typed structs
- Transaction broadcasting: `eth_sendRawTransaction`, nonce queries, gas/fee estimation
- ABI system: full encoding/decoding for all Solidity types, JSON ABI parsing, event log decoding
- Calldata decoding: decode calldata to function name + arguments given an ABI or signature
- Revert reason decoding: `Error(string)`, `Panic(uint256)`, and custom errors
- Function output decoding: decode `eth_call` return values
- Wallet: creation from private key, random generation, message signing, EIP-191 recovery
- Signature parsing: `signature_from_hex` with v normalization
- Wei conversions: `wei.from_ether`, `wei.to_ether`, `wei.from_gwei`, `wei.to_gwei`, `wei.from_int`, `wei.to_int`
- EIP-55 checksummed addresses: `address.checksum`, `address.is_valid_checksum`
- Crypto: keccak256 (ex_keccak NIF), secp256k1 (ex_secp256k1 NIF)
- RLP encoding/decoding per Yellow Paper spec
- Unified error type: `GleethError` with domain-specific wrapper variants
- CLI for all read operations + wallet + send
- 445 tests including fuzz testing (qcheck), cross-implementation verification (cast), and anvil integration
- CI workflow: Gleam 1.14.0, OTP 28, Elixir 1.19

### Releases

- **v1.0.0** (2026-03-19): initial release - signing, RPC, ABI, wallet, CLI
- **v1.1.0** (2026-03-23): transaction decoder, calldata/revert decoding, EIP-191 recovery, wei conversions, EIP-55 addresses, 160 new tests

## Completed Phases

Phases 1-5 are complete. See git history for details.

- **Phase 1**: CI fixes
- **Phase 2**: RLP encoding/decoding (47 tests)
- **Phase 3**: Transaction signing and broadcasting (legacy + EIP-1559)
- **Phase 4**: ABI system (108 tests)
- **Phase 5**: Provider abstraction and error consolidation

## Phase 6: Code cleanup

Small items to keep the codebase clean.

### 6.1 Remove legacy contract.gleam ParamType shim

`contract.gleam` still has its own `ParamType` enum (UInt256, Address, String,
Bool, Bytes32) that just wraps the ABI type system. The CLI `call` command
should use ABI types directly. GitHub issue #1.

### 6.2 Remove unreachable cases in execute_command

`gleeth.gleam` `execute_command` has `Wallet` and `Help` branches that are
unreachable. GitHub issue #2.

### 6.3 Reduce public API surface

Internal helpers exposed as `pub fn` in `cli.gleam` and `abi/encode.gleam`.
GitHub issue #3.

### 6.4 Fix mock wallet in random_test.gleam

Mock returns hardcoded values, doesn't test real wallet integration.
GitHub issue #4.

### 6.5 CI Node.js deprecation

Update GitHub Actions for Node.js 24 (deadline June 2026). GitHub issue #5.

## Phase 7: Architecture - Library/CLI split

Split `gleeth` into library-only package and separate `gleeth_cli` package.
Library consumers currently pull in CLI dependencies they don't need.
GitHub issues #17, #18.

## Phase 8: Ergonomics and developer experience

### 8.1 Receipt polling - GitHub issue #13

`methods.wait_for_receipt(provider, tx_hash, timeout_ms)` with exponential
backoff.

### 8.2 Gas estimation helpers - GitHub issue #14

Auto-populate gas limit, priority fee, and max fee from the network in a
single call.

### 8.3 Type-safe transaction builders - GitHub issue #15

Builder pattern: `transaction.build() |> to("0x...") |> value_ether("1.5") |> sign(wallet)`.
Depends on wei module (done).

### 8.4 Nonce manager - GitHub issue #16

Track pending nonces locally for sending multiple transactions without waiting.

### 8.5 Sender recovery from signed/RPC transactions - GitHub issue #34

Recover signer address from raw signed transactions and from RPC Transaction
type. Includes EIP-155 v-value handling for legacy transactions.

### 8.6 Function return value decode wrapper - GitHub issue #36

Convenient `decode_outputs(abi_entry, hex_data)` matching the ergonomics of
`encode_call`.

## Phase 9: Remaining testing

Most testing work is done. Remaining items:

### 9.1 ERC-20 integration flow

Full deploy + approve + transferFrom + balanceOf + event log decoding against
anvil. Part of GitHub issue #8.

### 9.2 ABI fuzz testing

Random ABI encode/decode roundtrips with qcheck. Part of GitHub issue #7.

### 9.3 Ethereum Foundation test vectors

Import TransactionTests from ethereum/tests (the canonical shared test suite
used by all execution clients) for cross-implementation verification of
transaction decoding and sender recovery. Part of GitHub issue #7.

## Phase 10: Provider improvements

### 10.1 Middleware - GitHub issue #29

Retry with exponential backoff on transient errors (429, 503), rate limiting,
request logging.

### 10.2 WebSocket support - GitHub issue #23

WebSocket provider for `eth_subscribe` (new blocks, pending txs, logs).

## Phase 11: Advanced features

Each ships independently as a minor version bump. GitHub issues #19-#28.

- **Typed contract bindings** (#19) - generate Gleam modules from ABI JSON
- **EIP-712 typed data signing** (#20) - permits, order books, meta-transactions
- **Batch JSON-RPC** (#21) - multiple RPC calls in single HTTP request
- **Block subscription via polling** (#22) - poll-based new block detection
- **ENS name resolution** (#24) - resolve `.eth` names to addresses
- **HD wallets / BIP39 mnemonics** (#25) - seed phrases, derivation paths
- **Multi-chain configuration** (#26) - chain registry
- **Contract deployment** (#27) - contract creation helper
- **Multicall batching** (#28) - batch reads via Multicall3
