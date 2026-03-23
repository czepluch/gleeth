# Changelog

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
