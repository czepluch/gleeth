# Gleeth Development Plan

Gleeth aims to be the Gleam equivalent of alloy.rs / ethers.js - a complete Ethereum library targeting the Erlang/BEAM runtime.

## Current State (March 2026)

### What works

- Read-only JSON-RPC calls: block number, balance, call, code, estimate gas, storage, logs, transaction
- CLI interface for all read operations + wallet subcommand
- Crypto: keccak256 (via ex_keccak NIF), secp256k1 signing/verification/recovery (via ex_secp256k1 NIF)
- Wallet: creation from private key, random generation, message signing, signature recovery
- RLP encoding/decoding per Ethereum Yellow Paper spec (`encoding/rlp.gleam`)
- Legacy (Type 0) and EIP-1559 (Type 2) transaction signing
- Transaction broadcasting via `eth_sendRawTransaction`
- Fee estimation: `eth_gasPrice`, `eth_maxPriorityFeePerGas`, `eth_feeHistory`
- Nonce queries via `eth_getTransactionCount`
- Proper JSON decoding with gleam_json decoders (replaced manual string parsing)
- Concurrent balance checking with BEAM process batching
- GLEETH_RPC_URL environment variable support
- Full ABI encoding/decoding (all Solidity types, head/tail, JSON ABI parsing, event log decoding)
- 292 tests, zero warnings (including Foundry-verified signing vectors and anvil integration)
- CI workflow: Gleam 1.14.0, OTP 28, Elixir 1.19

## Phase 1: Foundation fixes - DONE

CI workflow fixed (Gleam 1.14.0, OTP 28, Elixir 1.19, mix local.hex). Stale docs cleaned up.

## Phase 2: RLP encoding - DONE

RLP encoder/decoder implemented in `encoding/rlp.gleam` with 47 tests covering the full Yellow Paper spec.

## Phase 3: Transaction signing and broadcasting

### 3.1 Legacy (Type 0) transaction signing - DONE

- RLP-encoded signing hash: `keccak256(RLP([nonce, gasPrice, gasLimit, to, value, data, chainId, 0, 0]))`
- RLP-encoded signed transaction: `[nonce, gasPrice, gasLimit, to, value, data, v, r, s]`
- EIP-155 replay protection: `v = recovery_id + 2 * chain_id + 35`
- Verified byte-identical to Foundry `cast mktx --legacy` across mainnet, Sepolia, and anvil
- Verified end-to-end: signed tx accepted and mined by anvil

### 3.2 EIP-1559 (Type 2) transaction signing - DONE

- Envelope format: `0x02 || RLP([chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, value, data, accessList, v, r, s])`
- v = raw recovery_id (0 or 1), no chain ID encoding
- Access list support: `List(#(address, List(storage_key)))`
- Verified byte-identical to Foundry `cast mktx` across 4 vectors including access lists

EIP-2930 (Type 1, access list only) is rarely used standalone and can be deferred.

### 3.3 Broadcasting support - DONE

- `eth_sendRawTransaction` - broadcast signed transactions
- `eth_getTransactionCount` - nonce queries (defaults to "pending" block)
- `eth_gasPrice` - legacy gas price estimation
- `eth_maxPriorityFeePerGas` - EIP-1559 priority fee suggestion
- `eth_feeHistory` - historical fee data with percentile rewards
- `eth_getTransactionReceipt` was already implemented (used for receipt polling)

### 3.4 Tests - DONE

- 14 legacy transaction signing tests including 3 Foundry-verified vectors
- 12 EIP-1559 transaction signing tests including 4 Foundry-verified vectors (with access list coverage)
- 7 RPC decoder tests for broadcasting/fee methods
- 3 anvil integration tests: legacy broadcast, EIP-1559 broadcast, fee history query
- All integration tests query nonce + fees from anvil, sign, broadcast, and verify receipt

Future: expand signing test coverage significantly - more edge cases (zero-value fields, max-size calldata, multiple access list entries, unusual chain IDs, contract creation with empty `to`), fuzz testing with random transaction parameters verified against Foundry, and cross-client verification (e.g. comparing against ethers.js or web3.py output). Low priority but valuable for long-term confidence.

## Phase 4: ABI system - DONE

Full ABI encoder/decoder implemented in `ethereum/abi/` with 108 tests covering encoding, decoding, roundtrips, type parsing, JSON ABI, and function selectors.

### 4.1 Complete parameter encoding - DONE

- Type system: all Solidity ABI types (uint/int 8-256, address, bool, bytesN, bytes, string, T[], T[k], tuples)
- Full head/tail encoding per Solidity ABI spec
- Two's complement for signed integers, proper left/right padding
- Function selector computation (keccak256 of canonical signature)
- `contract.gleam` refactored to delegate to `abi/encode.gleam`

### 4.2 JSON ABI parsing - DONE

- Parse standard Solidity JSON ABI files into typed entries (functions, events)
- Generate function selectors from parsed ABI
- `call` command accepts `--abi <file>` for typed response decoding
- Recursive type string parser handles nested arrays and tuples

### 4.3 Event log decoding - DONE

- Decode indexed parameters from log topics (static types decoded, dynamic types returned as hash)
- Decode non-indexed parameters from log data via ABI decoder
- Match logs to ABI event definitions by topic0 hash

## Phase 5: Provider abstraction

### 5.1 Provider type - DONE

- Opaque `Provider` type in `provider.gleam` replaces raw `rpc_url: String` threading
- Provider holds: validated URL, optional chain_id (populated lazily)
- All RPC methods take `Provider` instead of string
- Boundary at `methods.gleam` - layers below (`response_utils`, `client`) unchanged
- `config.gleam` deleted (absorbed into `provider.gleam`)
- Convenience constructors: `mainnet()`, `sepolia()`
- `send` command uses `provider.chain_id()` caching for library use

### 5.1.1 Error type consolidation - DONE

- `GleethError` now wraps domain error types: `WalletErr(WalletError)`, `TransactionErr(TransactionError)`, `AbiErr(AbiError)`
- Library consumers handle one `Result` type in mixed wallet+RPC+tx pipelines
- Domain error types (`WalletError`, `TransactionError`, `AbiError`) unchanged - kept where they belong
- Bridge points (`send.gleam`, `contract.gleam`) use proper wrappers instead of string-flattening

### 5.2 Middleware

- Retry with backoff on transient errors
- Rate limiting
- Request logging

### 5.3 WebSocket support

- WebSocket provider for subscriptions (eth_subscribe)
- Event streaming for new blocks, pending transactions, logs

## Phase 6: Architecture decisions

### 6.1 Library vs CLI split

Gleeth should be a library for Gleam projects to interact with Ethereum. The CLI currently lives in the same package (`src/gleeth.gleam` + `src/gleeth/commands/`). This needs a decision:

- **Option A: Split into two packages** - `gleeth` (library only) and `gleeth_cli` (depends on gleeth). Cleaner separation, library consumers don't pull in CLI dependencies. Standard approach in the Gleam/Rust ecosystem.
- **Option B: Keep as one package** - simpler to maintain, fewer repos. The CLI entrypoint is just one file and the commands are thin wrappers around library functions.
- **Current status**: the CLI is useful for manual testing and verification (e.g. `gleeth send` against anvil). No need to split immediately, but should decide before publishing to Hex.

## Phase 7: Advanced features (future)

- ENS name resolution
- EIP-55 checksummed addresses
- HD wallets / BIP39 mnemonics
- Multi-chain configuration (chain registry)
- Contract deployment
- Multicall batching
