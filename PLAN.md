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
- 170 tests, zero warnings (including Foundry-verified signing vectors and anvil integration)

### What doesn't work

- ABI only handles uint256, address, bool, bytes32
- CI workflow fails (outdated Gleam version, missing Elixir)

## Phase 1: Foundation fixes

### 1.1 Fix CI workflow

- Update `.github/workflows/test.yml`:
  - Gleam version: 1.10.0 -> 1.14.0
  - OTP version: 27.1.2 -> 28
  - Add Elixir installation (needed for ex_keccak/ex_secp256k1 NIF compilation)
  - Add `mix local.hex --force` step before `gleam deps download`

### 1.2 Clean up project docs

- Delete `PROJECT_STATUS.md` (stale, references 33 tests and outdated feature status)
- Delete `PHASE_1_2_1_SUMMARY.md` (historical, no longer actionable)
- This file (`PLAN.md`) replaces both

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

## Phase 4: ABI system

### 4.1 Complete parameter encoding

- Add support for: int types (int8-int256), bytes (dynamic), string, arrays (fixed and dynamic), tuples
- Implement ABI head/tail encoding for dynamic types

### 4.2 JSON ABI parsing

- Parse standard Solidity JSON ABI files
- Generate function selectors from parsed ABI
- Type-safe call data building from ABI definitions

### 4.3 Event log decoding

- Decode indexed parameters from log topics
- Decode non-indexed parameters from log data
- Match logs to ABI event definitions

## Phase 5: Provider abstraction

### 5.1 Provider type

- Replace raw `rpc_url: String` threading with a `Provider` type
- Provider holds: URL, chain ID, middleware configuration
- All RPC methods take `Provider` instead of string

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
