import Foundation
import Combine
import CryptoKit
import SwiftUI

@MainActor
final class VaultManager: ObservableObject {

    // MARK: - Published State (drives all SwiftUI views)

    @Published var isUnlocked: Bool = false
    @Published var vault: Vault = Vault()
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false

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
                self.isUnlocked = true
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
                self.isUnlocked = true
            } catch {
                // Show a generic error — don't reveal whether the file or the password is wrong
                self.errorMessage = "Incorrect password or corrupted vault."
            }
            self.isLoading = false
        }
    }

    // MARK: - Lock Vault

    // Clears the key and vault from memory. The encrypted file on disk is untouched.
    func lock() {
        symmetricKey = nil
        vault = Vault()
        isUnlocked = false
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
}
