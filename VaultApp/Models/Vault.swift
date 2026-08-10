import Foundation

// The top-level container that holds all vault items.
// This struct is serialized to JSON and then encrypted before being saved to disk.
struct Vault: Codable {
    
    var items: [VaultItem]
    
    // MARK: - Initializer
    
    init(items: [VaultItem] = []) {
        self.items = items
    }
    
    // MARK: - Helpers
    
    // Find an item by its id
    func item(withId id: UUID) -> VaultItem? {
        items.first { $0.id == id }
    }
    
    // Add a new item
    mutating func add(_ item: VaultItem) {
        items.append(item)
    }
    
    // Update an existing item (match by id)
    mutating func update(_ item: VaultItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item.updatedNow()
    }
    
    // Delete an item by id
    mutating func delete(id: UUID) {
        items.removeAll { $0.id == id }
    }
    
    // Search items by title or any searchable field
    func search(query: String) -> [VaultItem] {
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.username.localizedCaseInsensitiveContains(query) ||
            $0.url.localizedCaseInsensitiveContains(query) ||
            ($0.cardFields?.cardNumber.localizedCaseInsensitiveContains(query) ?? false) ||
            ($0.cardFields?.cardholderName.localizedCaseInsensitiveContains(query) ?? false) ||
            ($0.cardFields?.bankName.localizedCaseInsensitiveContains(query) ?? false) ||
            ($0.identityFields?.fullName.localizedCaseInsensitiveContains(query) ?? false) ||
            ($0.identityFields?.email.localizedCaseInsensitiveContains(query) ?? false) ||
            $0.secureNoteBody.localizedCaseInsensitiveContains(query)
        }
    }
    
    // Filter items by category
    func filtered(by category: VaultItem.Category) -> [VaultItem] {
        items.filter { $0.category == category }
    }
}
