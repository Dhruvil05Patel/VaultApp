import Foundation
import CryptoKit
import CommonCrypto

// EncryptionService handles all cryptographic operations.
// It is a stateless enum — no instances, just static functions.
enum EncryptionService {

    // MARK: - Errors

    enum CryptoError: LocalizedError {
        case keyDerivationFailed
        case encryptionFailed
        case decryptionFailed
        case invalidData

        var errorDescription: String? {
            switch self {
            case .keyDerivationFailed: return "Failed to derive encryption key from master password."
            case .encryptionFailed:    return "Failed to encrypt vault data."
            case .decryptionFailed:    return "Failed to decrypt vault. Wrong password or corrupted file."
            case .invalidData:         return "Vault file is corrupted or unreadable."
            }
        }
    }

    // MARK: - Salt

    // Generate a new random 16-byte salt.
    // Call this ONCE when the vault is first created. Store the result alongside the vault file.
    static func generateSalt() -> Data {
        var salt = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, salt.count, &salt)
        return Data(salt)
    }

    // MARK: - Key Derivation

    // Derive a 256-bit AES symmetric key from the master password + salt.
    // Uses PBKDF2-SHA256 with 200,000 iterations.
    // This is intentionally slow to make brute-force attacks expensive.
    static func deriveKey(from password: String, salt: Data) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw CryptoError.keyDerivationFailed
        }

        var derivedKeyBytes = [UInt8](repeating: 0, count: 32) // 256-bit output

        let result = passwordData.withUnsafeBytes { passwordPtr in
            salt.withUnsafeBytes { saltPtr in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordPtr.baseAddress?.assumingMemoryBound(to: Int8.self),
                    passwordData.count,
                    saltPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    200_000,            // iterations — do not lower this
                    &derivedKeyBytes,
                    derivedKeyBytes.count
                )
            }
        }

        guard result == kCCSuccess else {
            throw CryptoError.keyDerivationFailed
        }

        return SymmetricKey(data: Data(derivedKeyBytes))
    }

    // MARK: - Encrypt

    // Encrypt arbitrary Data using AES-256-GCM.
    // A fresh random nonce is generated on every call — this is correct and required.
    // Output format: nonce (12 bytes) + ciphertext + auth tag — all combined by CryptoKit.
    static func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        do {
            let sealed = try AES.GCM.seal(data, using: key)
            guard let combined = sealed.combined else {
                throw CryptoError.encryptionFailed
            }
            return combined
        } catch {
            throw CryptoError.encryptionFailed
        }
    }

    // MARK: - Decrypt

    // Decrypt data that was previously encrypted with encrypt(_:using:).
    // Throws CryptoError.decryptionFailed if the key is wrong or the data is tampered.
    // The authentication tag is verified automatically by AES-GCM — no extra step needed.
    static func decrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        do {
            let box = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw CryptoError.decryptionFailed
        }
    }

    // MARK: - Vault Serialize + Encrypt

    // Convenience: encode a Vault to JSON then encrypt it in one step.
    static func encryptVault(_ vault: Vault, using key: SymmetricKey) throws -> Data {
        let jsonData = try JSONEncoder().encode(vault)
        return try encrypt(jsonData, using: key)
    }

    // MARK: - Decrypt + Deserialize Vault

    // Convenience: decrypt raw bytes then decode the JSON Vault in one step.
    static func decryptVault(_ data: Data, using key: SymmetricKey) throws -> Vault {
        let jsonData = try decrypt(data, using: key)
        return try JSONDecoder().decode(Vault.self, from: jsonData)
    }
}
