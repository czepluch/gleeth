import { keccak_256 } from "@noble/hashes/sha3";

export function hash(message) {
  // Convert BitArray to Uint8Array
  const bytes = new Uint8Array(message);

  // Compute keccak256 hash
  const hash = keccak_256(bytes);

  // Return as BitArray (Uint8Array is compatible)
  return hash;
}
