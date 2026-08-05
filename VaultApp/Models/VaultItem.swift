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
    var createdAt: Date    // Set once at creation, never updated
    var updatedAt: Date    // Updated every time the item is edited
    var category: Category // What type of entry this is

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
