import Foundation
import CryptoKit

// AttachmentService handles encryption/decryption and disk I/O for file attachments.
// All file content is encrypted with the vault's SymmetricKey before touching disk.
enum AttachmentService {

    // MARK: - Directory

    static var attachmentsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VaultApp/Attachments", isDirectory: true)
    }

    // MARK: - Errors

    enum AttachmentError: LocalizedError {
        case encryptionFailed
        case decryptionFailed
        case fileNotFound
        case writePermissionDenied
        case fileTooLarge

        var errorDescription: String? {
            switch self {
            case .encryptionFailed:      return "Failed to encrypt the attachment."
            case .decryptionFailed:      return "Failed to decrypt the attachment. The vault key may have changed."
            case .fileNotFound:          return "Attachment file not found on disk."
            case .writePermissionDenied: return "Cannot write to the attachments folder."
            case .fileTooLarge:          return "Attachment is too large. Maximum size is 50 MB."
            }
        }
    }

    // Maximum unencrypted file size: 50 MB
    static let maxFileSizeBytes = 50 * 1024 * 1024

    // MARK: - Save Attachment

    // Encrypts the file data and saves it to the attachments directory.
    // Returns a VaultAttachment metadata object for storing in the vault.
    static func save(
        data: Data,
        filename: String,
        key: SymmetricKey
    ) throws -> VaultAttachment {
        guard data.count <= maxFileSizeBytes else {
            throw AttachmentError.fileTooLarge
        }

        try ensureDirectoryExists()

        let mimeType   = VaultAttachment.mimeType(for: filename)
        let attachment = VaultAttachment(
            filename: filename,
            mimeType: mimeType,
            sizeBytes: data.count
        )

        // Encrypt with a fresh nonce (same pattern as vault.enc)
        guard let sealed = try? AES.GCM.seal(data, using: key).combined else {
            throw AttachmentError.encryptionFailed
        }

        let destURL = attachmentsDirectory.appendingPathComponent(attachment.encryptedFilename)
        do {
            try sealed.write(to: destURL, options: .atomic)
        } catch {
            throw AttachmentError.writePermissionDenied
        }

        return attachment
    }

    // MARK: - Load Attachment

    // Reads the encrypted blob from disk and decrypts it.
    // Returns the original unencrypted file data.
    static func load(
        attachment: VaultAttachment,
        key: SymmetricKey
    ) throws -> Data {
        let srcURL = attachmentsDirectory.appendingPathComponent(attachment.encryptedFilename)

        guard FileManager.default.fileExists(atPath: srcURL.path) else {
            throw AttachmentError.fileNotFound
        }

        let encryptedData = try Data(contentsOf: srcURL)

        guard let box  = try? AES.GCM.SealedBox(combined: encryptedData),
              let data = try? AES.GCM.open(box, using: key) else {
            throw AttachmentError.decryptionFailed
        }

        return data
    }

    // MARK: - Delete Attachment

    // Removes the encrypted blob from disk.
    // Call this before removing the VaultAttachment from the vault item.
    @discardableResult
    static func delete(attachment: VaultAttachment) -> Bool {
        let fileURL = attachmentsDirectory.appendingPathComponent(attachment.encryptedFilename)
        do {
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Orphan Cleanup

    // Removes encrypted attachment files that no longer have a matching VaultAttachment
    // in any vault item. Call this after deleting items or attachments.
    static func cleanupOrphans(knownAttachments: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: attachmentsDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files where !knownAttachments.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Helpers

    private static func ensureDirectoryExists() throws {
        if !FileManager.default.fileExists(atPath: attachmentsDirectory.path) {
            try FileManager.default.createDirectory(
                at: attachmentsDirectory,
                withIntermediateDirectories: true
            )
        }
    }
}
