import Foundation
import LocalAuthentication
import Security

// BiometricService handles all Touch ID / Keychain interactions.
// It stores and retrieves the vault's SymmetricKey bytes in a
// biometric-protected Keychain item.
// The master password is NEVER stored here — only the derived key bytes.
enum BiometricService {

    // MARK: - Errors

    enum BiometricError: LocalizedError {
        case notAvailable
        case notEnrolled
        case keyNotFound
        case keychainWriteFailed(OSStatus)
        case keychainReadFailed(OSStatus)
        case keychainDeleteFailed(OSStatus)
        case authenticationFailed
        case unknown(Error)

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "Touch ID is not available on this Mac."
            case .notEnrolled:
                return "No fingerprints are enrolled. Set up Touch ID in System Settings first."
            case .keyNotFound:
                return "No biometric key found. Please unlock with your master password once to enable Touch ID."
            case .keychainWriteFailed(let status):
                return "Failed to save key to Keychain (OSStatus \(status))."
            case .keychainReadFailed(let status):
                return "Failed to read key from Keychain (OSStatus \(status))."
            case .keychainDeleteFailed(let status):
                return "Failed to remove key from Keychain (OSStatus \(status))."
            case .authenticationFailed:
                return "Touch ID authentication failed."
            case .unknown(let error):
                return error.localizedDescription
            }
        }
    }

    // MARK: - Constants

    // Service label used to identify the Keychain item — must be unique to your app
    private static let keychainService = "com.vaultapp.biometric-key"
    private static let keychainAccount = "vault-symmetric-key"

    // MARK: - Availability

    // Returns true if Touch ID or Apple Watch unlock is available and enrolled
    static func isAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    // Returns a human-readable name for the biometric type ("Touch ID" / "Apple Watch")
    static func biometricName() -> String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .touchID:   return "Touch ID"
        case .faceID:    return "Face ID"
        default:         return "Biometrics"
        }
    }

    // MARK: - Store Key (called when user enables Touch ID after a successful password unlock)

    // Saves raw SymmetricKey bytes to a biometric-protected Keychain item.
    // Calling this replaces any previously stored key.
    static func storeKey(_ keyData: Data) throws {
        // Delete any existing item first to avoid errSecDuplicateItem
        _ = deleteKey()

        // Create access control — requires biometric auth to read, bound to this device
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryAny,           // any enrolled finger / Apple Watch
            &error
        ) else {
            throw BiometricError.keychainWriteFailed(errSecParam)
        }

        let query: [String: Any] = [
            kSecClass as String:              kSecClassGenericPassword,
            kSecAttrService as String:        keychainService,
            kSecAttrAccount as String:        keychainAccount,
            kSecValueData as String:          keyData,
            kSecAttrAccessControl as String:  access,
            // Do NOT include kSecAttrSynchronizable — never sync biometric keys to iCloud
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BiometricError.keychainWriteFailed(status)
        }
    }

    // MARK: - Retrieve Key (called on biometric unlock)

    // Reads the stored SymmetricKey bytes from Keychain.
    // macOS presents exactly ONE biometric prompt (via kSecUseOperationPrompt),
    // then returns the data. We do NOT call evaluatePolicy separately — that
    // would cause a second prompt when SecItemCopyMatching re-evaluates the
    // access-control item.
    static func retrieveKey(reason: String = "Unlock VaultApp") async throws -> Data {
        print("[BIOMETRIC] retrieveKey() CALLED, reason = \(reason)")
        // The reason string appears in the Touch ID dialog
        let context = LAContext()
        context.localizedReason = reason
        let query: [String: Any] = [
            kSecClass as String:             kSecClassGenericPassword,
            kSecAttrService as String:       keychainService,
            kSecAttrAccount as String:       keychainAccount,
            kSecReturnData as String:        true,
            kSecMatchLimit as String:        kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        print("[BIOMETRIC] SecItemCopyMatching returned status = \(status)")

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw BiometricError.keyNotFound
            }
            if status == errSecUserCanceled || status == errSecAuthFailed {
                throw BiometricError.authenticationFailed
            }
            throw BiometricError.keychainReadFailed(status)
        }

        guard let keyData = result as? Data else {
            throw BiometricError.keychainReadFailed(errSecDecode)
        }

        return keyData
    }

    // MARK: - Delete Key (called when user disables Touch ID or resets vault)

    @discardableResult
    static func deleteKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Check if Key is Stored

    static func hasStoredKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecMatchLimit as String:  kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        // When skipping UI on an item that requires biometrics, it may return errSecInteractionNotAllowed or errSecAuthFailed
        return status == errSecSuccess || status == errSecInteractionNotAllowed || status == errSecAuthFailed
    }
}