# Changelog

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
