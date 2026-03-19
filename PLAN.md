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
- 285 tests, zero warnings (including Foundry-verified signing vectors and anvil integration)
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

- Retry with exponential backoff on transient errors (429, 503, connection reset)
- Rate limiting (respect provider rate limits)
- Request logging (debug-level, opt-in)

### 5.3 WebSocket support

- WebSocket provider for subscriptions (eth_subscribe)
- Event streaming for new blocks, pending transactions, logs
- Leverages BEAM's strength in concurrent connections

## Phase 6: Code cleanup

Small items that should be addressed to keep the codebase clean.

### 6.1 Remove legacy contract.gleam ParamType shim

`contract.gleam` still has its own `ParamType` enum (UInt256, Address, String,
Bool, Bytes32) that just wraps the ABI type system. It predates the ABI module.
The CLI `call` command should use ABI types directly, then the legacy types can
be deleted.

### 6.2 Remove unreachable cases in execute_command

`gleeth.gleam` `execute_command` has `Wallet` and `Help` branches that are
unreachable because both are handled before the function is called.

### 6.3 Reduce public API surface

- `cli.gleam` exports internal helpers (`get_env_rpc_url`, `extract_rpc_url`)
  that should be private
- Some functions in `abi/encode.gleam` are public but are implementation details

### 6.4 Fix mock wallet in random_test.gleam

The "integration" test uses a mock that returns hardcoded values, so it doesn't
actually test wallet integration. Either use the real wallet module or delete it.

### 6.5 CI Node.js deprecation

Update `actions/checkout` and `erlef/setup-beam` to versions that support
Node.js 24. GitHub deadline is June 2026.

## Phase 7: Architecture decisions

### 7.1 Library vs CLI split

Gleeth should be a library for Gleam projects to interact with Ethereum. The CLI
currently lives in the same package (`src/gleeth.gleam` + `src/gleeth/commands/`).

- **Option A: Split into two packages** - `gleeth` (library only) and
  `gleeth_cli` (depends on gleeth). Cleaner separation, library consumers don't
  pull in CLI dependencies (`argv`, `simplifile`, all command modules). Standard
  approach in the Gleam/Rust ecosystem.
- **Option B: Keep as one package** - simpler to maintain, fewer repos. The CLI
  entrypoint is just one file and the commands are thin wrappers.
- **Current status**: published as one package (v1.0.0). Should split before
  library gets more users - consumers currently pull in CLI deps they don't need.

## Phase 8: Ergonomics and developer experience

### 8.1 Value conversion helpers

Currently all numeric values (wei, gas, nonce) are `0x`-prefixed hex strings
matching the JSON-RPC wire format. This is efficient internally but confusing
for users who think in ETH or decimal. Add a `wei` module:

- `wei.from_ether("1.5")` -> `"0x14d1120d7b160000"`
- `wei.from_gwei(20)` -> `"0x4a817c800"`
- `wei.to_ether("0xde0b6b3a7640000")` -> `"1.0"`
- `wei.to_gwei("0x3b9aca00")` -> `"1.0"`
- Decimal string to/from hex: `hex.from_int(21000)` -> `"0x5208"`

### 8.2 EIP-55 checksummed addresses

Validate and produce mixed-case checksummed addresses. Trivial to implement
since keccak256 is already available. ~30 lines.

### 8.3 Type-safe transaction builders

Builder pattern that accepts human-readable values:

```
transaction.build()
|> transaction.to("0x...")
|> transaction.value_ether("1.5")
|> transaction.gas_limit(21000)
|> transaction.sign(wallet)
```

### 8.4 Gas estimation helpers

Auto-populate gas limit, priority fee, and max fee from the network. Currently
users must make 3 separate RPC calls and wire them together manually.

### 8.5 Receipt polling

`methods.wait_for_receipt(provider, tx_hash, timeout_ms)` that polls with
backoff. Currently users have to loop manually.

### 8.6 Nonce manager

Track pending nonces locally so multiple transactions can be sent without
waiting for each to be mined. Critical for any app sending more than one tx.

## Phase 9: Comprehensive testing (pre-audit)

Before recommending gleeth for mainnet use, the test suite needs significant
expansion to build confidence that funds are safe.

### 9.1 Transaction signing edge cases

- Zero-value fields (nonce 0, value 0, empty data)
- Max-size calldata, multiple access list entries
- Unusual chain IDs (very large, 0, 1)
- Contract creation (empty `to` field)
- Cross-client verification: compare output against ethers.js, web3.py, alloy

### 9.2 Fuzz testing

- Random transaction parameters signed by gleeth and verified by Foundry `cast`
- Random ABI encode/decode roundtrips with property-based testing
- Random private keys: sign -> recover -> verify address matches

### 9.3 Integration test expansion

- Full ERC-20 transfer flow against anvil (deploy, approve, transferFrom)
- Contract deployment and interaction end-to-end
- Error paths: reverts, out-of-gas, invalid nonce, insufficient balance
- Multi-transaction sequences (nonce management)

### 9.4 RPC edge cases

- Handling of null/missing fields in RPC responses
- Large block ranges in getLogs
- Pending transaction queries
- Chain reorganization handling (removed logs)

### 9.5 Crypto primitives

- NIST/Wycheproof test vectors for secp256k1
- Known-answer tests for keccak256 against NIST test vectors
- Signature malleability checks (s-value normalization)

## Phase 10: Advanced features (future)

### 10.1 Typed contract bindings

Generate Gleam modules from ABI JSON files (like alloy's `sol!` macro or
ethers' `abigen`). Type-safe function calls instead of raw calldata construction.

### 10.2 EIP-712 typed data signing

`signTypedData` for permit signatures, off-chain order books, meta-transactions.
Increasingly common in DeFi protocols.

### 10.3 Batch JSON-RPC

Send multiple RPC calls in a single HTTP request per the JSON-RPC batch spec.
Different from Multicall - this is at the transport level, works for any RPC
method, not just contract reads.

### 10.4 Block subscription via polling

For HTTP providers that don't support WebSocket, poll `eth_blockNumber` and emit
new blocks. BEAM makes this trivial with a GenServer/process.

### 10.5 ENS name resolution

Resolve `.eth` names to addresses via the ENS registry contracts.

### 10.6 HD wallets / BIP39 mnemonics

Generate wallets from seed phrases, derivation paths (m/44'/60'/0'/0/n).

### 10.7 Multi-chain configuration

Chain registry with RPC URLs, block explorers, native currency info.

### 10.8 Contract deployment

Build and send contract creation transactions.

### 10.9 Multicall batching

Batch multiple contract read calls into a single RPC request via Multicall3.
