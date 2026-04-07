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
- EIP-712 typed structured data hashing and signing (permits, order books, meta-transactions)
- Batch JSON-RPC: multiple calls in a single HTTP request
- Contract deployment: deploy and deploy_with_args with receipt polling
- Retry middleware: exponential backoff on transient errors (429, 503) via provider.with_retry
- Contract type: bind provider + address + ABI, with call/send (typed) and call_raw/send_raw (string-coerced)
- Block queries: get_block_by_number and get_block_by_hash
- Event streaming: get_events combines getLogs + ABI event decoding in one call
- EIP-2612 permits: sign permits with auto domain/nonce fetch
- Multicall3: batch contract reads at the EVM level via canonical Multicall3 contract
- Block watcher: OTP actor that polls for new blocks and sends typed events to callers
- Unified error type: `GleethError` with domain-specific wrapper variants
- CLI for all read operations + wallet + send
- Fuzz testing (qcheck), cross-implementation verification (cast), and anvil integration tests
- CI workflow: Gleam 1.14.0, OTP 28, Elixir 1.19

## Completed Phases

Phases 1-8 are complete. See git history and CHANGELOG.md for details.

- **Phase 1**: CI fixes
- **Phase 2**: RLP encoding/decoding
- **Phase 3**: Transaction signing and broadcasting (legacy + EIP-1559)
- **Phase 4**: ABI system
- **Phase 5**: Provider abstraction and error consolidation
- **Phase 6**: Code cleanup (legacy ParamType removed, unreachable cases, mock wallet, CI updated)
- **Phase 8**: Ergonomics (receipt polling, gas estimation, transaction builder, nonce manager, sender recovery, decode_outputs)

## Phase 7: Architecture - Library/CLI split

Split `gleeth` into library-only package and separate `gleeth_cli` package.
Library consumers currently pull in CLI dependencies they don't need.
GitHub issues #17, #18.

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

### 10.1 Middleware - GitHub issue #29 - DONE

Retry with exponential backoff on transient errors (429, 503) via
`provider.with_retry` and `RetryConfig`. Rate limiting and request logging
remain future work.

### 10.2 WebSocket support - GitHub issue #23

WebSocket provider for `eth_subscribe` (new blocks, pending txs, logs).

## Phase 11: Advanced features

Each ships independently as a minor version bump.

- **Contract type** (#37) - DONE - bind provider + address + ABI for simplified contract interaction
- **Typed contract bindings** (#19) - DONE (runtime wrapper: call_raw/send_raw with auto string coercion). Code generation deferred.
- **EIP-712 typed data signing** (#20) - DONE
- **Batch JSON-RPC** (#21) - DONE
- **Block subscription via polling** (#22) - DONE - OTP actor with typed events
- **ENS name resolution** (#24) - resolve `.eth` names to addresses
- **HD wallets / BIP39 mnemonics** (#25) - seed phrases, derivation paths
- **Multi-chain configuration** (#26) - chain registry
- **Contract deployment** (#27) - DONE
- **Multicall batching** (#28) - DONE - batch reads via Multicall3
- **EIP-2612 permit helper** (#38) - DONE - one-liner permit signing with auto nonce/domain fetch
- **Log streaming with ABI decoding** (#39) - DONE - get_logs + event decoding in one call

## Speculative / future ideas

Not yet tracked as issues. May be worth pursuing based on user demand.

- **Simulation/dry-run** - `eth_call` with state overrides for simulating transactions
  before sending. Used by MEV bots and advanced dapps.
- **Event subscription helper** - higher-level than block polling. Filter for specific
  contract events, decode them automatically. "Watch for Transfer events on USDC."
- **EIP-4844 blob transactions** - Type 3 transactions for L2 data availability.
  Increasingly relevant as rollups adopt blobs.
