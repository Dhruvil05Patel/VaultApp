import Foundation
import Combine
import CryptoKit
import SwiftUI

@MainActor
final class VaultManager: ObservableObject {

    // Shared singleton so services (e.g. AutoLockService) can reference it
    // before SwiftUI instantiates the view.
    static let shared = VaultManager()

    // MARK: - Authentication State Machine

    enum AuthenticationState: Equatable {
        case locked
        case authenticating
        case unlocked
    }

    // MARK: - Published State (drives all SwiftUI views)

    @Published var authenticationState: AuthenticationState = .locked
    @Published var vault: Vault = Vault()
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false

    // Backward compatibility - derive from authenticationState
    var isUnlocked: Bool {
        authenticationState == .unlocked
    }

    // MARK: - Private State

    // The derived symmetric key — lives in memory only.
    // Cleared to nil when the vault is locked.
    private var symmetricKey: SymmetricKey? = nil

    // MARK: - File System Paths

    private var appSupportURL: URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appDir = urls[0].appendingPathComponent("VaultApp", isDirectory: true)
        return appDir
    }

    private var vaultFileURL: URL {
        appSupportURL.appendingPathComponent("vault.enc")
    }

    private var saltFileURL: URL {
        appSupportURL.appendingPathComponent("vault.salt")
    }

    // MARK: - Vault Existence Check

    // True if a vault file already exists on disk (i.e. user has set a master password before)
    var vaultExists: Bool {
        FileManager.default.fileExists(atPath: vaultFileURL.path)
    }

    // MARK: - Setup

    private func ensureAppDirectoryExists() throws {
        if !FileManager.default.fileExists(atPath: appSupportURL.path) {
            try FileManager.default.createDirectory(
                at: appSupportURL,
                withIntermediateDirectories: true
            )
        }
    }

    // MARK: - Create New Vault

    // Called when the user sets their master password for the first time.
    // Generates a fresh salt, derives the key, creates an empty vault, and saves it.
    func createVault(masterPassword: String) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try ensureAppDirectoryExists()

                let salt = EncryptionService.generateSalt()
                let key = try EncryptionService.deriveKey(from: masterPassword, salt: salt)
                let emptyVault = Vault()

                let encryptedData = try EncryptionService.encryptVault(emptyVault, using: key)

                try salt.write(to: saltFileURL)
                try encryptedData.write(to: vaultFileURL)

                self.symmetricKey = key
                self.vault = emptyVault
                self.authenticationState = .unlocked
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    // MARK: - Unlock Vault

    // Called when the user enters their master password on the lock screen.
    // Derives the key from the password + stored salt, then decrypts the vault file.
    func unlock(masterPassword: String) {
        print("[UNLOCK] unlock(password) CALLED, authenticationState = \(authenticationState)")
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let salt = try Data(contentsOf: saltFileURL)
                let key = try EncryptionService.deriveKey(from: masterPassword, salt: salt)
                let encryptedData = try Data(contentsOf: vaultFileURL)
                let decryptedVault = try EncryptionService.decryptVault(encryptedData, using: key)

                self.symmetricKey = key
                self.vault = decryptedVault
                self.authenticationState = .unlocked
                print("[UNLOCK] authenticationState -> unlocked")
            } catch {
                // Show a generic error — don't reveal whether the file or the password is wrong
                self.errorMessage = "Incorrect password or corrupted vault."
                print("[UNLOCK] ERROR: \(error)")
            }
            self.isLoading = false
        }
    }

    // MARK: - Lock Vault

    // Clears the key and vault from memory. The encrypted file on disk is untouched.
    // NEVER invokes biometric authentication - locking must be immediate and silent.
    func lock() {
        print("[LOCK] lock() CALLED")
        print(Thread.callStackSymbols.joined(separator: "\n"))
        print("[LOCK] authenticationState BEFORE = \(authenticationState)")
        symmetricKey = nil
        vault = Vault()
        authenticationState = .locked
        errorMessage = nil
        print("[LOCK] authenticationState AFTER = \(authenticationState)")
    }

    // MARK: - Save Vault to Disk

    // Re-encrypts the in-memory vault and writes it to disk.
    // Called internally after every mutation (add, update, delete).
    private func saveVault() throws {
        guard let key = symmetricKey else {
            throw NSError(domain: "VaultManager", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Vault is locked — cannot save."])
        }
        let encryptedData = try EncryptionService.encryptVault(vault, using: key)
        try encryptedData.write(to: vaultFileURL)
    }

    // MARK: - CRUD Operations

    func addItem(_ item: VaultItem) {
        vault.add(item)
        do {
            try saveVault()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    func updateItem(_ item: VaultItem) {
        vault.update(item)
        do {
            try saveVault()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    func deleteItem(id: UUID) {
        vault.delete(id: id)
        do {
            try saveVault()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    // MARK: - Error Dismissal

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Biometric Support

    // Expose raw key bytes so BiometricService can store them in Keychain.
    // Only callable while the vault is unlocked.
    func rawKeyDataForBiometricStorage() -> Data? {
        guard let key = symmetricKey else { return nil }
        return key.withUnsafeBytes { Data($0) }
    }

    // Unlock the vault using a raw key Data retrieved from Keychain (biometric path).
    // This bypasses PBKDF2 — the key bytes are used directly.
    func unlockWithBiometricKey(_ keyData: Data) {
        print("[UNLOCK_BIOMETRIC] unlockWithBiometricKey() CALLED, authenticationState = \(authenticationState)")
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let key = SymmetricKey(data: keyData)
                let encryptedData = try Data(contentsOf: vaultFileURL)
                let decryptedVault = try EncryptionService.decryptVault(encryptedData, using: key)

                self.symmetricKey = key
                self.vault = decryptedVault
                self.authenticationState = .unlocked
                print("[UNLOCK_BIOMETRIC] authenticationState -> unlocked")
            } catch {
                self.errorMessage = "Biometric unlock failed. Use your master password."
                print("[UNLOCK_BIOMETRIC] ERROR: \(error)")
            }
            self.isLoading = false
        }
    }

    // Enable Touch ID: store the current in-memory key in Keychain.
    // Must be called while the vault is unlocked.
    func enableBiometric() async throws {
        guard let keyData = rawKeyDataForBiometricStorage() else {
            throw NSError(domain: "VaultManager", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Vault must be unlocked to enable Touch ID."])
        }
        try BiometricService.storeKey(keyData)
        AppSettings.shared.isBiometricEnabled = true
    }

    // Single entry point for biometric authentication.
    // Only allowed when state is .locked. Transitions to .authenticating during the attempt.
    func authenticateWithBiometrics() async {
        print("[AUTH] authenticateWithBiometrics() CALLED, authenticationState = \(authenticationState)")
        // Guard: only allow authentication when locked, prevent multiple simultaneous attempts
        guard authenticationState == .locked else {
            print("[AUTH] GUARD: authenticationState != .locked, returning early")
            return
        }
        
        print("[AUTH] Setting authenticationState = .authenticating")
        authenticationState = .authenticating
        isLoading = true
        errorMessage = nil
        
        do {
            let keyData = try await BiometricService.retrieveKey(reason: "Unlock VaultApp")
            let key = SymmetricKey(data: keyData)
            let encryptedData = try Data(contentsOf: vaultFileURL)
            let decryptedVault = try EncryptionService.decryptVault(encryptedData, using: key)

            self.symmetricKey = key
            self.vault = decryptedVault
            self.authenticationState = .unlocked
            print("[AUTH] SUCCESS: authenticationState -> unlocked")
        } catch {
            // On any failure (cancel, error, lockout), return to locked state
            self.authenticationState = .locked
            self.errorMessage = error.localizedDescription
            print("[AUTH] FAILURE: authenticationState -> locked, error = \(error)")
        }
        self.isLoading = false
    }

    // Disable Touch ID: remove the Keychain item.
    func disableBiometric() {
        BiometricService.deleteKey()
        AppSettings.shared.isBiometricEnabled = false
    }

    // MARK: - Export

    // Read the stored salt from disk — needed for encrypted backup export
    func loadSaltForExport() -> Data? {
        try? Data(contentsOf: saltFileURL)
    }

    // Export the vault in the requested format. Throws if the vault is locked.
    func exportEncryptedBackup() throws -> Data {
        guard isUnlocked, let key = symmetricKey else {
            throw ExportService.ExportError.vaultLocked
        }
        guard let salt = loadSaltForExport() else {
            throw ExportService.ExportError.noKeyAvailable
        }
        return try ExportService.exportEncryptedBackup(vault: vault, key: key, saltData: salt)
    }

    func exportCSV() throws -> Data {
        guard isUnlocked else { throw ExportService.ExportError.vaultLocked }
        return try ExportService.exportCSV(vault: vault)
    }

    func exportJSON() throws -> Data {
        guard isUnlocked else { throw ExportService.ExportError.vaultLocked }
        return try ExportService.exportJSON(vault: vault)
    }

    // MARK: - Restore from Backup

    // Restores a vault from a .vaultbackup file using the given master password.
    // With merge=false the vault is replaced; with merge=true items whose UUID is
    // not already present are added to the current vault.
    func restoreFromBackup(data: Data, masterPassword: String, merge: Bool = false) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let envelope = try decoder.decode(ExportService.BackupEnvelope.self, from: data)

        guard envelope.version == 1 else {
            throw NSError(domain: "VaultManager", code: 10,
                          userInfo: [NSLocalizedDescriptionKey: "Unsupported backup version \(envelope.version)."])
        }

        guard let saltData = Data(base64Encoded: envelope.salt),
              let encryptedData = Data(base64Encoded: envelope.encryptedVault) else {
            throw NSError(domain: "VaultManager", code: 11,
                          userInfo: [NSLocalizedDescriptionKey: "Backup file is corrupted."])
        }

        let key = try EncryptionService.deriveKey(from: masterPassword, salt: saltData)
        let restoredVault = try EncryptionService.decryptVault(encryptedData, using: key)

        if merge, isUnlocked {
            // Merge: add only items whose UUID doesn't already exist in the current vault
            let existingIDs = Set(vault.items.map { $0.id })
            let newItems = restoredVault.items.filter { !existingIDs.contains($0.id) }
            for item in newItems { vault.add(item) }
            try saveVault()
        } else {
            // Replace: overwrite with the backup
            self.symmetricKey = key
            self.vault = restoredVault
            self.authenticationState = .unlocked
            // Write the restored salt + vault to disk
            try ensureAppDirectoryExists()
            try saltData.write(to: saltFileURL)
            try EncryptionService.encryptVault(restoredVault, using: key)
                .write(to: vaultFileURL)
        }
    }
}
