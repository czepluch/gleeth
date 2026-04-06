# Changelog

## 1.5.0 - 2026-04-07

### Features

- **Contract type** - `contract.at(provider, address, abi)` binds provider, address, and ABI together for simplified interaction
- **String-coerced calls** - `contract.call_raw` and `contract.send_raw` accept plain strings, auto-coerced to ABI types
- **Event streaming** - `events.get_events` combines getLogs + ABI event decoding in one call; `get_events_by_name` filters by event name
- **EIP-2612 permits** - `permit.sign` for one-liner permit signing with auto domain/nonce fetch
- **Multicall3** - `multicall.new() |> multicall.add(...) |> multicall.execute(provider)` batches contract reads at the EVM level

## 1.4.0 - 2026-04-06

### Features

- **EIP-712 typed data signing** - `eip712.sign_typed_data` for permits, order books, and meta-transactions. Full spec implementation with domain separation, recursive struct hashing, and Solidity-verified output.
- **Batch JSON-RPC** - `batch.new() |> batch.add(...) |> batch.execute_strings(provider)` sends multiple RPC calls in a single HTTP request
- **Contract deployment** - `deploy.deploy` and `deploy.deploy_with_args` handle signing, broadcasting, and receipt polling, returning the contract address
- **Retry middleware** - `provider.with_retry(provider, default_retry())` adds automatic retry with exponential backoff on HTTP 429/503 and connection failures
- **Block queries** - `get_block_by_number` and `get_block_by_hash` with full Block type decoding

## 1.3.0 - 2026-03-28

### Changes

- **Library-only package** - CLI commands moved to separate [gleeth-cli](https://github.com/czepluch/gleeth-cli) package. `argv` and `simplifile` dependencies removed. gleeth is now a pure library with no IO or argument parsing.
- **ABI fuzz tests** - random encode/decode roundtrips for uint, int, bool, address, string, bytes, tuples, and arrays
- **Sign/recover fuzz tests** - random key generation, signing, and address recovery cycles
- **ERC-20 integration test** - full deploy, approve, transferFrom, balanceOf flow against anvil

## 1.2.0 - 2026-03-25

### Features

- **Transaction builder** - pipeline API: `build_legacy() |> legacy_to("0x...") |> legacy_value_ether("1.5") |> sign_legacy(wallet)`. Accepts human-readable values (ether, gwei) or raw hex.
- **Gas estimation** - `gas.estimate_legacy` and `gas.estimate_eip1559` combine multiple RPC calls into a single function returning gas_price/fees + gas_limit
- **Receipt polling** - `methods.wait_for_receipt` with exponential backoff (1s, 2s, 4s...) and configurable timeout
- **Nonce manager** - `nonce.new`, `nonce.next`, `nonce.reset` for local nonce tracking across multi-transaction sequences
- **Sender recovery** - `transaction.recover_sender` and `transaction.recover_sender_eip1559` to cryptographically recover the signer address from signed transactions
- **ABI output decoding** - `decode.decode_outputs` takes a parsed ABI function entry and decodes return values

### Cleanup

- Removed legacy `ParamType` shim from `contract.gleam` - uses ABI types directly
- Removed unreachable `Wallet`/`Help` branches in `execute_command`
- Replaced mock wallet with real wallet module in random tests
- Updated `actions/checkout` to v6 for Node.js 24 compatibility

## 1.1.0 - 2026-03-23

### Features

- **Transaction decoder** - decode raw legacy and EIP-1559 transactions back into typed structs, with auto-detection from the type prefix
- **Calldata decoding** - decode calldata back to function name and typed arguments given an ABI or function signature
- **Revert reason decoding** - decode `Error(string)`, `Panic(uint256)`, and custom error selectors
- **EIP-191 personal message recovery** - `recover_personal_message` and `verify_personal_message` for Sign-In with Ethereum and off-chain signature verification
- **Signature parsing** - `signature_from_hex` parses 65-byte hex signatures with v=0/1/27/28 normalization
- **Function output decoding** - `decode_function_output` for decoding `eth_call` return values
- **Wei conversion module** - `wei.from_ether`, `wei.to_ether`, `wei.from_gwei`, `wei.to_gwei`, `wei.from_int`, `wei.to_int` for converting between human-readable amounts and hex strings
- **EIP-55 checksummed addresses** - `address.checksum` and `address.is_valid_checksum` per the EIP-55 specification

### Testing

- 18 edge case signing tests verified against Foundry `cast mktx` (zero value, contract creation, large chain IDs, multi-entry access lists)
- 22 transaction decoder round-trip tests
- Property-based fuzz testing with `qcheck` (800+ random transactions per run)
- 18 cross-implementation tests comparing gleeth output byte-for-byte against Foundry `cast`
- 8 integration tests against anvil (contract deployment, state changes, error paths, multi-tx sequences)
- 19 RPC response edge case tests (malformed JSON, null fields, type mismatches)

## 1.0.0 - 2026-03-19

Initial release.

### Features

- **JSON-RPC client** - block number, balance, call, code, estimate gas, storage, logs, transactions, receipts, fee history
- **Provider abstraction** - opaque type with URL validation and chain ID caching; convenience constructors for mainnet and Sepolia
- **Transaction signing** - Legacy (Type 0) with EIP-155 replay protection, EIP-1559 (Type 2) with access list support
- **Transaction broadcasting** - `eth_sendRawTransaction`, nonce queries, gas price and priority fee estimation
- **ABI system** - full encoding/decoding for all Solidity types (uint/int 8-256, address, bool, bytesN, bytes, string, dynamic arrays, fixed arrays, tuples), JSON ABI parsing, event log decoding
- **Wallet management** - creation from private key, random generation, message signing, signature recovery
- **Crypto primitives** - keccak256 (via ex_keccak NIF), secp256k1 signing/verification/recovery (via ex_secp256k1 NIF)
- **RLP encoding/decoding** - per Ethereum Yellow Paper spec
- **CLI** - commands for all read operations, transaction sending, wallet management
- **Unified error type** - `GleethError` with domain-specific wrapper variants for ABI, wallet, and transaction errors
