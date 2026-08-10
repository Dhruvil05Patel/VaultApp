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

    // Full-text secure note body — only populated when category == .secureNote
    var secureNoteBody: String = ""

    // Base32-encoded TOTP secret (e.g. "JBSWY3DPEHPK3PXP").
    // Empty string means no TOTP is configured for this entry.
    var totpSecret: String = ""

    // Convenience — true when a non-empty TOTP secret is stored
    var hasTOTP: Bool { !totpSecret.trimmingCharacters(in: .whitespaces).isEmpty }

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

        // SF Symbol icon name for each category
        var icon: String {
            switch self {
            case .login:      return "key.fill"
            case .creditCard: return "creditcard.fill"
            case .secureNote: return "note.text"
            case .identity:   return "person.fill"
            }
        }
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
}
