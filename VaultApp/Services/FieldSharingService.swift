import Foundation
import CryptoKit

enum FieldSharingService {

    // MARK: - Data Model

    struct SharePayload: Codable {
        let version: Int                    // 1
        let title: String
        let fields: [SharedField]
        let createdAt: Date
        let expiresAt: Date?

        struct SharedField: Codable, Hashable, Identifiable {
            let label: String              // "Username", "Password" etc.
            let value: String
            let isSensitive: Bool
            var id: String { label }
        }
    }

    // MARK: - Shareable Field Enum

    enum ShareableField: String, CaseIterable, Identifiable, Hashable {
        case title    = "Title"
        case username = "Username"
        case password = "Password"
        case url      = "URL"
        case notes    = "Notes"
        case totp     = "2FA Secret"

        var id: String { rawValue }

        var isSensitive: Bool { self == .password || self == .totp }

        var icon: String {
            switch self {
            case .title:    return "textformat"
            case .username: return "person.fill"
            case .password: return "key.fill"
            case .url:      return "globe"
            case .notes:    return "note.text"
            case .totp:     return "shield.lefthalf.filled"
            }
        }

        // Extract the value from a VaultItem for this field
        func value(from item: VaultItem) -> String {
            switch self {
            case .title:    return item.title
            case .username: return item.username
            case .password: return item.password
            case .url:      return item.url
            case .notes:    return item.notes
            case .totp:     return item.totpSecret
            }
        }
    }

    // MARK: - Errors

    enum ShareError: LocalizedError {
        case encodingFailed
        case decodingFailed
        case invalidKey
        case decryptionFailed

        var errorDescription: String? {
            switch self {
            case .encodingFailed:   return "Failed to create share package."
            case .decodingFailed:   return "Could not read share data. Make sure you pasted it correctly."
            case .invalidKey:       return "Invalid decryption key."
            case .decryptionFailed: return "Could not decrypt share. Check that the key is correct."
            }
        }
    }

    // MARK: - Create Encrypted Share

    // Returns a tuple: (blob: base64 encrypted data, key: base64 one-time key)
    // The key is NOT included in the blob — it must be shared separately.
    static func createEncryptedShare(
        from item: VaultItem,
        fields: Set<ShareableField>,
        expiresAt: Date? = nil
    ) throws -> (blob: String, key: String) {
        let payload  = buildPayload(from: item, fields: fields, expiresAt: expiresAt)
        let json     = try encode(payload)

        // Generate a fresh one-time key — never the vault master key
        let shareKey = SymmetricKey(size: .bits256)
        guard let combined = try? AES.GCM.seal(json, using: shareKey).combined else {
            throw ShareError.encodingFailed
        }

        let keyBytes = shareKey.withUnsafeBytes { Data($0) }
        return (
            blob: combined.base64EncodedString(),
            key:  keyBytes.base64EncodedString()
        )
    }

    // MARK: - Create Plaintext Share

    static func createPlaintextShare(
        from item: VaultItem,
        fields: Set<ShareableField>,
        expiresAt: Date? = nil
    ) throws -> String {
        let payload = buildPayload(from: item, fields: fields, expiresAt: expiresAt)
        let json    = try encode(payload)
        return json.base64EncodedString()
    }

    // MARK: - Decode Encrypted Share

    static func decodeEncryptedShare(blob: String, key: String) throws -> SharePayload {
        guard let blobData = Data(base64Encoded: blob) else { throw ShareError.decodingFailed }
        guard let keyData  = Data(base64Encoded: key)  else { throw ShareError.invalidKey }

        let shareKey = SymmetricKey(data: keyData)
        guard let box  = try? AES.GCM.SealedBox(combined: blobData),
              let json = try? AES.GCM.open(box, using: shareKey) else {
            throw ShareError.decryptionFailed
        }

        return try decode(json)
    }

    // MARK: - Decode Plaintext Share

    static func decodePlaintextShare(_ base64: String) throws -> SharePayload {
        guard let data = Data(base64Encoded: base64) else { throw ShareError.decodingFailed }
        return try decode(data)
    }

    // MARK: - Convert payload to VaultItem

    static func toVaultItem(_ payload: SharePayload) -> VaultItem {
        var item = VaultItem(title: payload.title, username: "", password: "")
        for field in payload.fields {
            switch field.label {
            case "Username": item.username    = field.value
            case "Password": item.password    = field.value
            case "URL":      item.url         = field.value
            case "Notes":    item.notes       = field.value
            case "2FA Secret": item.totpSecret = field.value
            default: break
            }
        }
        return item
    }

    // MARK: - Helpers

    private static func buildPayload(
        from item: VaultItem,
        fields: Set<ShareableField>,
        expiresAt: Date?
    ) -> SharePayload {
        let sharedFields: [SharePayload.SharedField] = ShareableField.allCases
            .filter { fields.contains($0) }
            .compactMap { field in
                let value = field.value(from: item)
                guard !value.isEmpty else { return nil }
                return SharePayload.SharedField(
                    label:       field.rawValue,
                    value:       value,
                    isSensitive: field.isSensitive
                )
            }

        return SharePayload(
            version:   1,
            title:     item.title,
            fields:    sharedFields,
            createdAt: Date(),
            expiresAt: expiresAt
        )
    }

    private static func encode(_ payload: SharePayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { throw ShareError.encodingFailed }
        return data
    }

    private static func decode(_ data: Data) throws -> SharePayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(SharePayload.self, from: data) else {
            throw ShareError.decodingFailed
        }
        // Check expiry
        if let exp = payload.expiresAt, exp < Date() {
            throw NSError(domain: "FieldSharing", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "This share link has expired."])
        }
        return payload
    }
}
