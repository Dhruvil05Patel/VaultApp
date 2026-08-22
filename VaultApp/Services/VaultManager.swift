import Foundation
import Combine
import CryptoKit
import SwiftUI

@MainActor
final class VaultManager: ObservableObject {

    // Shared singleton so services (e.g. AutoLockService) can reference it
    // before SwiftUI instantiates the view.
    static let shared = VaultManager()

    // Optional sync service that uploads vault.enc to iCloud after every save.
    var syncService: SyncService? = nil

    // MARK: - Authentication State Machine

    enum AuthenticationState: Equatable {
        case locked
        case authenticating
        case unlocked
    }

    // MARK: - Published State (drives all SwiftUI views)

    @Published private(set) var authenticationState: AuthenticationState = .locked
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
    internal var symmetricKey: SymmetricKey? = nil

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

    // MARK: - Duress Vault Paths

    private var duressVaultURL: URL {
        appSupportURL.appendingPathComponent("duress.enc")
    }

    private var duressSaltURL: URL {
        appSupportURL.appendingPathComponent("duress.salt")
    }

    // MARK: - Duress State

    // Never expose this publicly — the UI should never branch on isDuressMode
    // except for the Settings duress setup screen (only accessible from the real vault)
    private(set) var isDuressMode: Bool = false

    var duressVaultExists: Bool {
        FileManager.default.fileExists(atPath: duressVaultURL.path)
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
                self.errorMessage = userFacingError(error)
            }
            self.isLoading = false
        }
    }

    // MARK: - Unlock Vault

    func unlock(masterPassword: String) {
        isLoading = true
        errorMessage = nil

        Task {
            // Try real vault first
            if let result = try? await attemptUnlock(
                password: masterPassword,
                vaultURL: vaultFileURL,
                saltURL: saltFileURL
            ) {
                self.symmetricKey = result.key
                self.vault = result.vault
                self.isDuressMode = false
                self.authenticationState = .unlocked
                
                Task {
                    await self.syncService?.downloadAndMerge()
                }
                self.isLoading = false
                return
            }

            // Try duress vault if it exists
            if duressVaultExists,
               let result = try? await attemptUnlock(
                password: masterPassword,
                vaultURL: duressVaultURL,
                saltURL: duressSaltURL
               ) {
                self.symmetricKey = result.key
                self.vault = result.vault
                self.isDuressMode = true
                self.authenticationState = .unlocked
                self.isLoading = false
                return
            }

            // Neither matched
            self.errorMessage = "Incorrect password. Try again, or restore from a backup if you think the vault is corrupted."
            self.isLoading = false
        }
    }

    // Shared unlock attempt helper
    private struct UnlockResult { let key: SymmetricKey; let vault: Vault }

    private func attemptUnlock(password: String, vaultURL: URL, saltURL: URL) async throws -> UnlockResult {
        let salt          = try Data(contentsOf: saltURL)
        let key           = try EncryptionService.deriveKey(from: password, salt: salt)
        let encryptedData = try Data(contentsOf: vaultURL)
        let vault         = try EncryptionService.decryptVault(encryptedData, using: key)
        return UnlockResult(key: key, vault: vault)
    }

    // MARK: - Lock Vault

    // Clears the key and vault from memory. The encrypted file on disk is untouched.
    // NEVER invokes biometric authentication - locking must be immediate and silent.
    func lock() {
        symmetricKey = nil
        vault = Vault()
        authenticationState = .locked
        isDuressMode = false
        errorMessage = nil
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
        let targetURL = isDuressMode ? duressVaultURL : vaultFileURL
        try encryptedData.write(to: targetURL)

        if !isDuressMode {
            // Upload to iCloud after local save (only for real vault)
            Task {
                await syncService?.uploadVault()
            }
        }
    }

    // MARK: - Reload from Disk

    // Re-decrypts the vault file using the key already in memory (no re-auth).
    // Called by SyncService after a remote iCloud change downloads a newer vault.
    func reloadFromDisk() async {
        guard let key = symmetricKey else { return }
        let targetURL = isDuressMode ? duressVaultURL : vaultFileURL
        guard let encryptedData = try? Data(contentsOf: targetURL) else { return }
        if let updated = try? EncryptionService.decryptVault(encryptedData, using: key) {
            vault = updated
        }
    }

    // MARK: - CRUD Operations

    func addItem(_ item: VaultItem) {
        vault.add(item)
        do {
            try saveVault()
        } catch {
            errorMessage = userFacingError(error)
        }
    }

    func updateItem(_ item: VaultItem) {
        vault.update(item)
        do {
            try saveVault()
        } catch {
            errorMessage = userFacingError(error)
        }
    }

    func deleteItem(id: UUID) {
        // Clean up attachment files before deleting the item
        if let item = vault.item(withId: id) {
            for attachment in item.attachments {
                AttachmentService.delete(attachment: attachment)
            }
        }
        vault.delete(id: id)
        do {
            try saveVault()
        } catch {
            errorMessage = userFacingError(error)
        }
    }

    // MARK: - Folder Management

    func addFolder(_ folder: VaultFolder) {
        vault.addFolder(folder)
        try? saveVault()
    }

    func updateFolder(_ folder: VaultFolder) {
        vault.updateFolder(folder)
        try? saveVault()
    }

    func deleteFolder(id: UUID) {
        vault.deleteFolder(id: id)
        try? saveVault()
    }

    // MARK: - Tag Management

    // Rename a tag across all vault items
    func renameTag(from old: String, to new: String) {
        let normalised = VaultItem.normaliseTag(new)
        guard !normalised.isEmpty else { return }
        for i in vault.items.indices where vault.items[i].tags.contains(old) {
            vault.items[i].tags = vault.items[i].tags.map { $0 == old ? normalised : $0 }
        }
        try? saveVault()
    }

    // Delete a tag from all vault items
    func deleteTag(_ tag: String) {
        for i in vault.items.indices {
            vault.items[i].tags.removeAll { $0 == tag }
        }
        try? saveVault()
    }

    // MARK: - Error Dismissal

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Create Duress Vault

    func createDuressVault(duressPassword: String) async throws {
        guard !isDuressMode else {
            throw NSError(domain: "VaultManager", code: 20,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot create duress vault from duress mode."])
        }
        try ensureAppDirectoryExists()
        let salt = EncryptionService.generateSalt()
        let key  = try EncryptionService.deriveKey(from: duressPassword, salt: salt)
        let emptyVault = Vault()
        let encrypted  = try EncryptionService.encryptVault(emptyVault, using: key)
        try salt.write(to: duressSaltURL)
        try encrypted.write(to: duressVaultURL)
        AppSettings.shared.isDuressModeEnabled = true
    }

    // MARK: - Delete Duress Vault

    func deleteDuressVault() {
        try? FileManager.default.removeItem(at: duressVaultURL)
        try? FileManager.default.removeItem(at: duressSaltURL)
        AppSettings.shared.isDuressModeEnabled = false
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

                // Pull any newer vault synced from another Mac
                Task {
                    await self.syncService?.downloadAndMerge()
                }
            } catch {
                self.errorMessage = "Biometric unlock failed. Use your master password."
                self.authenticationState = .locked
                print("[UNLOCK_BIOMETRIC] ERROR: \(error)")
            }
            self.isLoading = false
        }
    }

    // Attempt Touch ID authentication to unlock the vault.
    func authenticateForUnlock() {
        guard authenticationState == .locked else { return }
        authenticationState = .authenticating
        errorMessage = nil
        
        Task {
            do {
                let keyData = try await BiometricService.retrieveKey(reason: "Unlock VaultApp")
                await MainActor.run {
                    self.unlockWithBiometricKey(keyData)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = userFacingError(error)
                    self.authenticationState = .locked
                    
                    if let bioError = error as? BiometricService.BiometricError {
                        switch bioError {
                        case .keyNotFound, .keychainReadFailed:
                            // The credential is fundamentally missing or corrupted.
                            // Reset the preference so the user can be prompted to set it up again.
                            self.disableBiometric()
                        default:
                            break
                        }
                    }
                }
            }
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

            // Pull any newer vault synced from another Mac
            Task {
                await self.syncService?.downloadAndMerge()
            }
        } catch {
            // On any failure (cancel, error, lockout), return to locked state
            self.authenticationState = .locked
            self.errorMessage = userFacingError(error)
            print("[AUTH] FAILURE: authenticationState -> locked, error = \(error)")
        }
        self.isLoading = false
    }

    // Disable Touch ID: remove the Keychain item.
    func disableBiometric() {
        BiometricService.deleteKey()
        AppSettings.shared.isBiometricEnabled = false
        AppSettings.shared.hasAnsweredBiometricPrompt = false
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

            // Propagate the restored vault to iCloud
            Task {
                await syncService?.uploadVault()
            }
        }
    }

    // MARK: - P2P Sync

    // Export the current encrypted vault blob for P2P transfer.
    // Returns nil if vault is locked.
    func exportEncryptedBlobForP2P() -> Data? {
        guard let key = symmetricKey,
              let data = try? EncryptionService.encryptVault(vault, using: key) else { return nil }
        return data
    }

    // Import an encrypted vault blob received from a P2P peer.
    // Uses the current in-memory key (same master password assumption).
    func importEncryptedBlobFromP2P(_ data: Data) throws {
        guard let key = symmetricKey else {
            throw NSError(domain: "VaultManager", code: 30,
                          userInfo: [NSLocalizedDescriptionKey: "Vault must be unlocked to import."])
        }
        let received = try EncryptionService.decryptVault(data, using: key)
        // Merge: keep items from both, newest updatedAt wins per UUID
        for item in received.items {
            if let existing = vault.item(withId: item.id) {
                if item.updatedAt > existing.updatedAt {
                    vault.update(item)
                }
            } else {
                vault.add(item)
            }
        }
        try saveVault()
    }

    private func userFacingError(_ error: Error) -> String {
        // Map known error types to friendly messages
        if let cryptoError = error as? EncryptionService.CryptoError {
            switch cryptoError {
            case .decryptionFailed:
                return "Incorrect password or corrupted file."
            case .encryptionFailed:
                return "Failed to encrypt data. Try again."
            case .keyDerivationFailed:
                return "Could not derive encryption key. Check available memory."
            case .invalidData:
                return "Vault file appears corrupted. Restore from a backup."
            }
        }
        // File system errors
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case 4:   return "Vault file not found. It may have been moved or deleted."
            case 257:  return "Permission denied. Check that the app can access Application Support."
            case 516:  return "Not enough disk space to save the vault."
            default:  break
            }
        }
        return "An unexpected error occurred. Please try again."
    }
}
