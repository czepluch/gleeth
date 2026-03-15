# Gleeth Development Plan

Gleeth aims to be the Gleam equivalent of alloy.rs / ethers.js - a complete Ethereum library targeting the Erlang/BEAM runtime.

## Current State (March 2026)

### What works
- Read-only JSON-RPC calls: block number, balance, call, code, estimate gas, storage, logs, transaction
- CLI interface for all read operations + wallet subcommand
- Crypto: keccak256 (via ex_keccak NIF), secp256k1 signing/verification/recovery (via ex_secp256k1 NIF)
- Wallet: creation from private key, random generation, message signing, signature recovery
- Proper JSON decoding with gleam_json decoders (replaced manual string parsing)
- Concurrent balance checking with BEAM process batching
- GLEETH_RPC_URL environment variable support
- 84 tests, zero warnings

### What doesn't work
- Transaction signing produces placeholder output (no RLP encoding)
- ABI only handles uint256, address, bool, bytes32
- No transaction broadcasting
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

## Phase 2: RLP encoding

RLP (Recursive Length Prefix) is Ethereum's serialization format. Without it, transactions cannot be signed or broadcast. No Gleam RLP library exists, so we need to implement one.

### RLP specification
- Single byte 0x00-0x7f: encoded as itself
- String 0-55 bytes: 0x80 + length, then data
- String > 55 bytes: 0xb7 + length-of-length, then length, then data
- List 0-55 bytes total: 0xc0 + total length, then concatenated items
- List > 55 bytes total: 0xf7 + length-of-length, then total length, then items

### Implementation plan
- Create `src/gleeth/encoding/rlp.gleam`
- Define `RlpItem` type: `RlpBytes(BitArray)` | `RlpList(List(RlpItem))`
- Implement `encode(RlpItem) -> BitArray`
- Implement `decode(BitArray) -> Result(RlpItem, RlpError)`
- Add comprehensive tests with known Ethereum test vectors from the yellow paper

### Dependencies
- None - pure Gleam/BitArray operations

## Phase 3: Transaction signing and broadcasting

With RLP encoding available, implement real transaction signing.

### 3.1 Fix legacy transaction signing
- Update `crypto/transaction.gleam`:
  - `create_signing_hash`: RLP-encode `[nonce, gasPrice, gasLimit, to, value, data, chainId, 0, 0]` then keccak256
  - `sign_transaction`: produce valid RLP-encoded signed transaction `[nonce, gasPrice, gasLimit, to, value, data, v, r, s]`
  - Remove placeholder raw transaction creation
  - Fix EIP-155 v value calculation: `v = recovery_id + 2 * chain_id + 35`

### 3.2 Add EIP-1559 (Type 2) transaction signing
- Signing payload: `0x02 || RLP([chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, value, data, accessList])`
- Signed form: `0x02 || RLP([chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, value, data, accessList, v, r, s])`

### 3.3 Add broadcasting support
- Add `eth_sendRawTransaction` to `rpc/methods.gleam`
- Add `eth_getTransactionCount` for nonce queries
- Add `eth_gasPrice` and `eth_feeHistory` for fee estimation
- Add `eth_getTransactionReceipt` polling for confirmation

### 3.4 Tests
- Unit tests with known signed transaction test vectors (can use ethers.js to generate reference data)
- Test RLP encoding matches expected output for known transactions
- Test signing produces the correct transaction hash

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

## Phase 6: Advanced features (future)

- ENS name resolution
- EIP-55 checksummed addresses
- HD wallets / BIP39 mnemonics
- Multi-chain configuration (chain registry)
- Contract deployment
- Multicall batching
