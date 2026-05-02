/**
 * ABDM M3 Security Utilities - Doctor Side
 * Implements ECDH (X25519) and AES-GCM decryption
 */

const CryptoUtils = {
    // Generate a fresh X25519 keypair for the session
    generateKeyPair: () => {
        const keyPair = nacl.box.keyPair();
        return {
            publicKey: keyPair.publicKey, // Uint8Array
            privateKey: keyPair.secretKey // Uint8Array
        };
    },

    // Convert Uint8Array to Base64
    toBase64: (uint8Array) => {
        return nacl.util.encodeBase64(uint8Array);
    },

    // Convert Base64 or Base64Url to Uint8Array
    fromBase64: (base64String) => {
        let sanitized = base64String.replace(/-/g, '+').replace(/_/g, '/');
        while (sanitized.length % 4) {
            sanitized += '=';
        }
        return nacl.util.decodeBase64(sanitized);
    },

    // Derive Shared Secret using ECDH (X25519)
    deriveSharedSecret: (doctorPrivateKey, patientPublicKey) => {
        try {
            // nacl.scalarMult(n, p) - n is secret, p is public
            return nacl.scalarMult(doctorPrivateKey, patientPublicKey);
        } catch (e) {
            console.error("ECDH Derivation failed:", e);
            return null;
        }
    },

    /**
     * Derive a strong session key using HKDF-SHA256
     * This MUST match the Flutter implementation
     */
    deriveSessionKey: async (sharedSecret) => {
        const info = new TextEncoder().encode('ABDM_M3_E2EE');
        
        // Import raw shared secret as a key for HMAC
        const baseKey = await window.crypto.subtle.importKey(
            "raw", sharedSecret, { name: "HKDF" }, false, ["deriveKey"]
        );

        // Derive AES-GCM key using HKDF
        return await window.crypto.subtle.deriveKey(
            {
                name: "HKDF",
                hash: "SHA-256",
                salt: new Uint8Array(), // Empty salt
                info: new TextEncoder().encode("ABDM_M3_E2EE") // Move constant to info
            },
            baseKey,
            { name: "AES-GCM", length: 256 },
            false,
            ["decrypt", "encrypt"]
        );
    },

    /**
     * Decrypt data using AES-256-GCM
     */
    decryptData: async (encryptedDataB64, sessionKey, nonceB64) => {
        try {
            const encryptedBuffer = CryptoUtils.fromBase64(encryptedDataB64);
            const iv = CryptoUtils.fromBase64(nonceB64);

            const decrypted = await window.crypto.subtle.decrypt(
                {
                    name: "AES-GCM",
                    iv: iv,
                    tagLength: 128
                },
                sessionKey,
                encryptedBuffer
            );

            return new TextDecoder().decode(decrypted);
        } catch (e) {
            console.error("AES-GCM Decryption failed:", e);
            throw new Error("Decryption failed: Key mismatch or integrity violation.");
        }
    },

    // Helper for hex conversion
    bufToHex: (buffer) => {
        return Array.from(new Uint8Array(buffer))
            .map(b => b.toString(16).padStart(2, '0'))
            .join('');
    }
};

// Polyfill for padLeft if needed
if (!String.prototype.padLeft) {
    String.prototype.padLeft = function(length, character) {
        return new Array(length - this.length + 1).join(character || ' ') + this;
    };
}
