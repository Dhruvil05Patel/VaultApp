import Foundation
import CryptoKit

// AuditLogService maintains an encrypted, in-memory log of vault operations.
// The log is loaded on vault unlock and saved on every new entry.
// It is cleared from memory when the vault locks.
@MainActor
final class AuditLogService {

    static let shared = AuditLogService()
    private init() {}

    // MARK: - Log Entry Model

    struct LogEntry: Codable, Identifiable {
        let id: UUID
        let timestamp: Date
        let eventType: EventType
        let itemTitle: String?     // name of the affected item (nil for vault-level events)
        let fieldLabel: String?    // which field was copied (for .fieldCopied events)
        let detail: String?        // additional context (e.g. error message for failed unlocks)
        let deviceName: String     // hostname at time of event

        enum EventType: String, Codable, CaseIterable {
            case vaultUnlocked      = "Vault Unlocked"
            case vaultCreated       = "Vault Created"
            case vaultLocked        = "Vault Locked"
            case unlockFailed       = "Unlock Failed"
            case biometricUnlock    = "Biometric Unlock"
            case itemViewed         = "Item Viewed"
            case fieldCopied        = "Field Copied"
            case itemAdded          = "Item Added"
            case itemEdited         = "Item Edited"
            case itemDeleted        = "Item Deleted"
            case vaultExported      = "Vault Exported"
            case vaultImported      = "Vault Imported"
            case settingsChanged    = "Settings Changed"
            case attachmentAdded    = "Attachment Added"
            case attachmentDeleted  = "Attachment Deleted"

            var sfSymbol: String {
                switch self {
                case .vaultUnlocked:    return "lock.open.fill"
                case .vaultCreated:     return "sparkles"
                case .vaultLocked:      return "lock.fill"
                case .unlockFailed:     return "exclamationmark.lock.fill"
                case .biometricUnlock:  return "touchid"
                case .itemViewed:       return "eye.fill"
                case .fieldCopied:      return "doc.on.doc.fill"
                case .itemAdded:        return "plus.circle.fill"
                case .itemEdited:       return "pencil.circle.fill"
                case .itemDeleted:      return "trash.fill"
                case .vaultExported:    return "square.and.arrow.up.fill"
                case .vaultImported:    return "square.and.arrow.down.fill"
                case .settingsChanged:  return "gear.badge"
                case .attachmentAdded:  return "paperclip.circle.fill"
                case .attachmentDeleted: return "paperclip.badge.ellipsis"
                }
            }

            // Events that represent potential security concerns
            var isSecurityEvent: Bool {
                switch self {
                case .unlockFailed, .biometricUnlock, .vaultExported,
                     .vaultUnlocked, .vaultCreated:
                    return true
                default:
                    return false
                }
            }
        }
    }

    // MARK: - State

    private var entries: [LogEntry] = []
    private var encryptionKey: SymmetricKey? = nil
    private let maxEntries = 1000

    // MARK: - File Path

    private var logFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VaultApp/audit.log.enc")
    }

    // MARK: - Load (called on unlock)

    func load(using key: SymmetricKey) {
        encryptionKey = key

        guard FileManager.default.fileExists(atPath: logFileURL.path),
              let encryptedData = try? Data(contentsOf: logFileURL),
              let box  = try? AES.GCM.SealedBox(combined: encryptedData),
              let json = try? AES.GCM.open(box, using: key) else {
            entries = []
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([LogEntry].self, from: json)) ?? []
    }

    // MARK: - Unload (called on lock)

    func unload() {
        entries = []
        encryptionKey = nil
    }

    // MARK: - Append Entry

    func log(
        _ eventType: LogEntry.EventType,
        itemTitle: String? = nil,
        fieldLabel: String? = nil,
        detail: String? = nil
    ) {
        guard AppSettings.shared.auditLogEnabled else { return }

        let entry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            eventType: eventType,
            itemTitle: itemTitle,
            fieldLabel: fieldLabel,
            detail: detail,
            deviceName: Host.current().localizedName ?? "Unknown"
        )

        entries.append(entry)

        // Cap at maxEntries — drop oldest
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }

        persist()
    }

    // MARK: - Read

    func allEntries() -> [LogEntry] {
        entries.reversed()
    }

    func securityEvents() -> [LogEntry] {
        entries.filter { $0.eventType.isSecurityEvent }.reversed()
    }

    func recentEntries(limit: Int = 50) -> [LogEntry] {
        Array(entries.suffix(limit).reversed())
    }

    var entryCount: Int { entries.count }

    // MARK: - Persist (async, fire-and-forget)

    private func persist() {
        guard let key = encryptionKey else { return }
        let entriesToSave = entries
        let fileURL = logFileURL

        Task.detached(priority: .background) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            guard let json = try? encoder.encode(entriesToSave),
                  let sealed = try? AES.GCM.seal(json, using: key).combined else { return }

            let directory = fileURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? sealed.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: - Export as Plain Text

    func exportPlaintext() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .current

        let header = "VaultApp Activity Log — Exported \(formatter.string(from: Date()))\n"
            + String(repeating: "─", count: 60) + "\n\n"

        let lines = entries.reversed().map { entry in
            var line = "[\(formatter.string(from: entry.timestamp))] \(entry.eventType.rawValue)"
            if let title = entry.itemTitle { line += " · \(title)" }
            if let field = entry.fieldLabel { line += " · \(field)" }
            if let detail = entry.detail { line += " — \(detail)" }
            line += " [\(entry.deviceName)]"
            return line
        }

        return header + lines.joined(separator: "\n")
    }

    // MARK: - Clear Log (user-initiated only)

    func clearLog() {
        entries = []
        try? FileManager.default.removeItem(at: logFileURL)
    }
}
