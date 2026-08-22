import Foundation

// Represents a single entry in the vault (a login, card, note, etc.)
struct VaultItem: Codable, Identifiable, Hashable {
    
    // MARK: - Properties
    
    let id: UUID           // Unique ID — never changes after creation
    var title: String      // Display name e.g. "GitHub", "Netflix"
    var username: String   // The email or username for this entry
    var password: String   // The stored password
    var url: String        // Website URL — empty string if not applicable
    var notes: String      // Free-form notes — empty string if not applicable

    // Structured credit/debit card fields — only populated when category == .creditCard
    var cardFields: CardFields? = nil

    // Structured identity fields — only populated when category == .identity
    var identityFields: IdentityFields? = nil

    // SSH Key and API Token fields — only populated when category == .sshKey or .seedPhrase
    var sshKeyFields: SSHKeyFields? = nil

    // File attachments associated with this item
    var attachments: [VaultAttachment] = []

    // Convenience: true when there are attachments
    var hasAttachments: Bool { !attachments.isEmpty }

    // Full-text secure note body — only populated when category == .secureNote
    var secureNoteBody: String = ""

    // Base32-encoded TOTP secret (e.g. "JBSWY3DPEHPK3PXP").
    // Empty string means no TOTP is configured for this entry.
    var totpSecret: String = ""

    // Which folder this item lives in (nil = root)
    var folderID: UUID? = nil

    // List of tag strings, lowercase, no duplicates
    var tags: [String] = []

    // When the password was last changed
    var lastPasswordChangedAt: Date? = nil

    // Items can be individually geofenced regardless of folder
    var geofenceRestricted: Bool = false

    // Convenience: Days since the password was last changed
    var passwordAge: Int? {
        guard let date = lastPasswordChangedAt else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day
    }

    // Convenience — true when a non-empty TOTP secret is stored
    var hasTOTP: Bool { !totpSecret.trimmingCharacters(in: .whitespaces).isEmpty }

    // Convenience — true when the item has at least one tag
    var hasTags: Bool { !tags.isEmpty }

    // Convenience — true when the item belongs to a folder
    var isInFolder: Bool { folderID != nil }

    var createdAt: Date    // Set once at creation, never updated
    var updatedAt: Date    // Updated every time the item is edited
    var category: Category // What type of entry this is

    // MARK: - Breach Status (cached, not authoritative — re-check periodically)

    enum BreachStatus: String, Codable {
        case unknown      // never checked
        case safe         // checked and not found
        case breached     // found in breach database
    }

    var breachStatus: BreachStatus = .unknown
    var breachCount: Int = 0           // number of times seen in breaches (0 if safe/unknown)
    var breachCheckedAt: Date? = nil   // when the last check was performed

    // MARK: - Category

    enum Category: String, Codable, CaseIterable {
        case login      = "Login"
        case creditCard = "Credit Card"
        case secureNote = "Secure Note"
        case identity   = "Identity"
        case sshKey     = "SSH / API Key"
        case seedPhrase = "Seed Phrase"

        // SF Symbol icon name for each category
        var icon: String {
            switch self {
            case .login:      return "key.fill"
            case .creditCard: return "creditcard.fill"
            case .secureNote: return "note.text"
            case .identity:   return "person.fill"
            case .sshKey:     return "terminal.fill"
            case .seedPhrase: return "bitcoinsign.circle.fill"
            }
        }
    }

    // MARK: - Codable

    // Custom decoder so fields added after the vault format was created
    // (tags, folderID, breach status, …) fall back to their defaults instead
    // of making the whole vault undecodable.
    private enum CodingKeys: String, CodingKey {
        case id, title, username, password, url, notes
        case cardFields, identityFields, sshKeyFields, secureNoteBody, totpSecret
        case attachments
        case folderID, tags, lastPasswordChangedAt, geofenceRestricted
        case createdAt, updatedAt, category
        case breachStatus, breachCount, breachCheckedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id      = try c.decode(UUID.self,        forKey: .id)
        title   = try c.decode(String.self,      forKey: .title)
        username = try c.decode(String.self,     forKey: .username)
        password = try c.decode(String.self,     forKey: .password)
        url     = try c.decode(String.self,      forKey: .url)
        notes   = try c.decode(String.self,      forKey: .notes)
        cardFields     = try c.decodeIfPresent(CardFields.self,     forKey: .cardFields)
        identityFields = try c.decodeIfPresent(IdentityFields.self, forKey: .identityFields)
        sshKeyFields   = try c.decodeIfPresent(SSHKeyFields.self,   forKey: .sshKeyFields)
        attachments    = try c.decodeIfPresent([VaultAttachment].self, forKey: .attachments) ?? []
        secureNoteBody = try c.decodeIfPresent(String.self, forKey: .secureNoteBody) ?? ""
        totpSecret     = try c.decodeIfPresent(String.self, forKey: .totpSecret) ?? ""
        folderID = try c.decodeIfPresent(UUID.self, forKey: .folderID)
        tags     = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        lastPasswordChangedAt = try c.decodeIfPresent(Date.self, forKey: .lastPasswordChangedAt)
        geofenceRestricted = try c.decodeIfPresent(Bool.self, forKey: .geofenceRestricted) ?? false
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        category  = try c.decode(Category.self, forKey: .category)
        breachStatus    = try c.decodeIfPresent(BreachStatus.self, forKey: .breachStatus) ?? .unknown
        breachCount     = try c.decodeIfPresent(Int.self, forKey: .breachCount) ?? 0
        breachCheckedAt = try c.decodeIfPresent(Date.self, forKey: .breachCheckedAt)
    }

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        title: String,
        username: String,
        password: String,
        url: String = "",
        notes: String = "",
        category: Category = .login
    ) {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.url = url
        self.notes = notes
        self.category = category
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Helpers
    
    // Returns a copy of this item with updatedAt set to now
    func updatedNow() -> VaultItem {
        var copy = self
        copy.updatedAt = Date()
        return copy
    }

    // Normalise a tag: lowercase, trim, replace spaces with hyphens
    static func normaliseTag(_ tag: String) -> String {
        tag.lowercased()
           .trimmingCharacters(in: .whitespacesAndNewlines)
           .replacingOccurrences(of: " ", with: "-")
    }
}
