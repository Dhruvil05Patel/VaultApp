import Foundation
import CryptoKit

// ExportService serialises the vault into various export formats.
// It does not touch the file system — it returns Data that the caller saves.
enum ExportService {

    // MARK: - Format

    enum Format: String, CaseIterable, Identifiable {
        case encryptedBackup = "VaultApp Backup"
        case csv             = "CSV (Plaintext)"
        case json            = "JSON (Plaintext)"

        var id: String { rawValue }

        var fileExtension: String {
            switch self {
            case .encryptedBackup: return "vaultbackup"
            case .csv:             return "csv"
            case .json:            return "json"
            }
        }

        var isEncrypted: Bool { self == .encryptedBackup }

        var icon: String {
            switch self {
            case .encryptedBackup: return "lock.doc.fill"
            case .csv:             return "tablecells"
            case .json:            return "curlybraces"
            }
        }

        var warningMessage: String? {
            switch self {
            case .encryptedBackup:
                return nil
            case .csv, .json:
                return "⚠️ This export contains ALL your passwords in plaintext. Anyone who can read this file can access your accounts. Store it securely and delete it after use."
            }
        }
    }

    // MARK: - Errors

    enum ExportError: LocalizedError {
        case vaultLocked
        case noKeyAvailable
        case encodingFailed
        case encryptionFailed
        case decryptionFailed

        var errorDescription: String? {
            switch self {
            case .vaultLocked:       return "Vault must be unlocked to export."
            case .noKeyAvailable:    return "Encryption key not available. Unlock the vault first."
            case .encodingFailed:    return "Failed to encode vault data."
            case .encryptionFailed:  return "Failed to encrypt backup file."
            case .decryptionFailed:  return "Failed to decrypt backup file."
            }
        }
    }

    // MARK: - Encrypted Backup (.vaultbackup)

    // The .vaultbackup format is a JSON envelope containing:
    // - the base64-encoded salt
    // - the base64-encoded AES-GCM sealed vault
    // This lets the file be self-contained — you only need the master password to restore it.
    struct BackupEnvelope: Codable {
        let version: Int          // format version — currently 1
        let createdAt: Date
        let salt: String          // base64
        let encryptedVault: String // base64 of the AES-GCM combined blob
    }

    static func exportEncryptedBackup(
        vault: Vault,
        key: SymmetricKey,
        saltData: Data
    ) throws -> Data {
        let encryptedVaultData = try EncryptionService.encryptVault(vault, using: key)

        let envelope = BackupEnvelope(
            version: 1,
            createdAt: Date(),
            salt: saltData.base64EncodedString(),
            encryptedVault: encryptedVaultData.base64EncodedString()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(envelope) else {
            throw ExportError.encodingFailed
        }
        return data
    }

    // MARK: - CSV Export

    // Column order: Title, Username, Password, URL, Notes, Category, CreatedAt, UpdatedAt, TOTP
    static func exportCSV(vault: Vault) throws -> Data {
        var lines: [String] = []

        // Header
        lines.append(csvRow([
            "Title", "Username", "Password", "URL",
            "Notes", "Category", "CreatedAt", "UpdatedAt", "TOTPSecret"
        ]))

        let formatter = ISO8601DateFormatter()

        for item in vault.items {
            lines.append(csvRow([
                item.title,
                item.username,
                item.password,
                item.url,
                item.notes,
                item.category.rawValue,
                formatter.string(from: item.createdAt),
                formatter.string(from: item.updatedAt),
                item.totpSecret
            ]))
        }

        let csv = lines.joined(separator: "\r\n")
        guard let data = csv.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }

    // CSV-escape a single field: wrap in quotes, escape internal quotes as ""
    private static func csvField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static func csvRow(_ fields: [String]) -> String {
        fields.map { csvField($0) }.joined(separator: ",")
    }

    // MARK: - JSON Export

    static func exportJSON(vault: Vault) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(vault) else {
            throw ExportError.encodingFailed
        }
        return data
    }
}