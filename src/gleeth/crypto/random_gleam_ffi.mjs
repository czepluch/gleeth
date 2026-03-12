/**
 * JavaScript FFI module for cryptographically secure random number generation
 *
 * This module provides secure random byte generation for both Node.js and
 * browser environments using the Web Crypto API, which is available in:
 * - Node.js 15.0+ (stable)
 * - All modern browsers
 * - Web Workers
 *
 * The implementation uses crypto.getRandomValues() which provides
 * cryptographically secure pseudorandom numbers suitable for
 * cryptographic key generation.
 */

/**
 * Generate cryptographically secure random bytes
 *
 * @param {number} length - Number of bytes to generate (must be positive integer)
 * @returns {Object} Result object with either Ok(Uint8Array) or Error(string)
 */
export function generateSecureBytes(length) {
  try {
    // Validate input
    if (!Number.isInteger(length) || length <= 0) {
      return {
        type: "error",
        value: `Invalid length: must be positive integer, got ${length}`
      };
    }

    // Check if length is within reasonable bounds
    // crypto.getRandomValues() has implementation-specific limits
    if (length > 65536) { // 64KB limit for safety
      return {
        type: "error",
        value: `Length too large: ${length} bytes exceeds maximum of 65536`
      };
    }

    // Check if crypto is available
    const crypto = getCrypto();
    if (!crypto) {
      return {
        type: "error",
        value: "Web Crypto API not available in this environment"
      };
    }

    // Generate random bytes
    const randomBytes = new Uint8Array(length);
    crypto.getRandomValues(randomBytes);

    // Verify we got the expected number of bytes
    if (randomBytes.length !== length) {
      return {
        type: "error",
        value: `Expected ${length} bytes, got ${randomBytes.length}`
      };
    }

    // Convert to the format expected by Gleam BitArray
    return {
      type: "ok",
      value: randomBytes
    };

  } catch (error) {
    return {
      type: "error",
      value: `Random generation failed: ${error.message}`
    };
  }
}

/**
 * Get the crypto object for the current environment
 *
 * @returns {Crypto|null} The crypto object or null if not available
 */
function getCrypto() {
  // Browser environment
  if (typeof window !== 'undefined' && window.crypto) {
    return window.crypto;
  }

  // Web Worker environment
  if (typeof self !== 'undefined' && self.crypto) {
    return self.crypto;
  }

  // Node.js environment
  if (typeof globalThis !== 'undefined' && globalThis.crypto) {
    return globalThis.crypto;
  }

  // Try to import Node.js crypto module
  try {
    const { webcrypto } = eval('require')('crypto');
    return webcrypto;
  } catch (e) {
    // Node.js crypto not available or too old
  }

  return null;
}

/**
 * Test if secure random generation is available
 * This function can be used to check system capabilities
 *
 * @returns {Object} Result object indicating availability
 */
export function testRandomAvailability() {
  try {
    const crypto = getCrypto();
    if (!crypto) {
      return {
        type: "error",
        value: "Web Crypto API not available"
      };
    }

    // Test with minimal generation
    const testBytes = new Uint8Array(1);
    crypto.getRandomValues(testBytes);

    return {
      type: "ok",
      value: null
    };

  } catch (error) {
    return {
      type: "error",
      value: `Random test failed: ${error.message}`
    };
  }
}

/**
 * Get information about the current crypto environment
 * Useful for debugging and diagnostics
 *
 * @returns {Object} Environment information
 */
export function getCryptoEnvironmentInfo() {
  const info = {
    environment: "unknown",
    cryptoAvailable: false,
    cryptoSource: "none",
    userAgent: typeof navigator !== 'undefined' ? navigator.userAgent : 'N/A'
  };

  // Detect environment
  if (typeof window !== 'undefined') {
    info.environment = "browser";
    info.cryptoAvailable = !!window.crypto;
    info.cryptoSource = window.crypto ? "window.crypto" : "none";
  } else if (typeof self !== 'undefined') {
    info.environment = "webworker";
    info.cryptoAvailable = !!self.crypto;
    info.cryptoSource = self.crypto ? "self.crypto" : "none";
  } else if (typeof globalThis !== 'undefined') {
    info.environment = "nodejs";
    try {
      const { webcrypto } = eval('require')('crypto');
      info.cryptoAvailable = !!webcrypto;
      info.cryptoSource = webcrypto ? "require('crypto').webcrypto" : "none";
    } catch (e) {
      info.cryptoAvailable = false;
    }
  }

  return info;
}

/**
 * Generate multiple random samples for testing
 * This is useful for randomness quality testing
 *
 * @param {number} sampleCount - Number of samples to generate
 * @param {number} byteLength - Length of each sample in bytes
 * @returns {Object} Result with array of samples or error
 */
export function generateRandomSamples(sampleCount, byteLength) {
  try {
    if (!Number.isInteger(sampleCount) || sampleCount <= 0) {
      return {
        type: "error",
        value: `Invalid sample count: ${sampleCount}`
      };
    }

    if (!Number.isInteger(byteLength) || byteLength <= 0) {
      return {
        type: "error",
        value: `Invalid byte length: ${byteLength}`
      };
    }

    const samples = [];

    for (let i = 0; i < sampleCount; i++) {
      const result = generateSecureBytes(byteLength);
      if (result.type === "error") {
        return result;
      }
      samples.push(result.value);
    }

    return {
      type: "ok",
      value: samples
    };

  } catch (error) {
    return {
      type: "error",
      value: `Sample generation failed: ${error.message}`
    };
  }
}
