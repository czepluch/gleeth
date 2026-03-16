# Gleeth Development Plan

Gleeth aims to be the Gleam equivalent of alloy.rs / ethers.js - a complete Ethereum library targeting the Erlang/BEAM runtime.

## Current State (March 2026)

### What works

- Read-only JSON-RPC calls: block number, balance, call, code, estimate gas, storage, logs, transaction
- CLI interface for all read operations + wallet subcommand
- Crypto: keccak256 (via ex_keccak NIF), secp256k1 signing/verification/recovery (via ex_secp256k1 NIF)
- Wallet: creation from private key, random generation, message signing, signature recovery
- RLP encoding/decoding per Ethereum Yellow Paper spec (`encoding/rlp.gleam`)
- Legacy (Type 0) transaction signing with proper EIP-155 replay protection
- Proper JSON decoding with gleam_json decoders (replaced manual string parsing)
- Concurrent balance checking with BEAM process batching
- GLEETH_RPC_URL environment variable support
- 150 tests, zero warnings (including Foundry-verified transaction signing vectors)

### What doesn't work

- EIP-1559 (Type 2) transaction signing - types defined, no encoding/signing logic
- ABI only handles uint256, address, bool, bytes32
- No transaction broadcasting (no eth_sendRawTransaction RPC method)
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

### 3.2 EIP-1559 (Type 2) transaction signing

EIP-1559 is the default transaction type since the London hard fork (August 2021). Almost all mainnet transactions use it. Key differences from legacy:

- Envelope format: type byte prefix `0x02` before the RLP payload
- Two gas fields: `maxPriorityFeePerGas` (tip) and `maxFeePerGas` (total cap) replace single `gasPrice`
- Simpler v value: just the raw recovery_id (0 or 1), no chain ID encoding
- Access lists: optional `List(#(address, List(storage_key)))` for gas discounts

Implementation:
- Signing payload: `keccak256(0x02 || RLP([chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, value, data, accessList]))`
- Signed form: `0x02 || RLP([chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, value, data, accessList, v, r, s])`
- Add `sign_eip1559_transaction` to `crypto/transaction.gleam`
- Reuse existing `Eip1559Transaction` and `AccessListEntry` types
- Tests with Foundry-generated vectors (`cast mktx` without `--legacy`)

EIP-2930 (Type 1, access list only) is rarely used standalone and can be deferred.

### 3.3 Add broadcasting support

- Add `eth_sendRawTransaction` to `rpc/methods.gleam`
- Add `eth_getTransactionCount` for nonce queries
- Add `eth_gasPrice` and `eth_feeHistory` for fee estimation
- Add `eth_getTransactionReceipt` polling for confirmation

### 3.4 Tests - DONE (for legacy and EIP-1559)

- 14 legacy transaction signing tests including 3 Foundry-verified vectors
- 12 EIP-1559 transaction signing tests including 4 Foundry-verified vectors (with access list coverage)
- Anvil integration test (sends signed tx, verifies acceptance)

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

## Phase 6: Advanced features (future)

- ENS name resolution
- EIP-55 checksummed addresses
- HD wallets / BIP39 mnemonics
- Multi-chain configuration (chain registry)
- Contract deployment
- Multicall batching
