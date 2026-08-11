import Foundation

// The top-level container that holds all vault items.
// This struct is serialized to JSON and then encrypted before being saved to disk.
struct Vault: Codable {
    
    var items: [VaultItem]
    
    var folders: [VaultFolder] = []
    
    // MARK: - Codable

    // folders was added after the initial vault format; fall back to [] when missing
    private enum CodingKeys: String, CodingKey {
        case items, folders
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items   = try c.decodeIfPresent([VaultItem].self, forKey: .items) ?? []
        folders = try c.decodeIfPresent([VaultFolder].self, forKey: .folders) ?? []
    }

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
    
    // MARK: - Folder CRUD
    
    mutating func addFolder(_ folder: VaultFolder) {
        folders.append(folder)
    }
    
    mutating func updateFolder(_ folder: VaultFolder) {
        guard let i = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[i] = folder
    }
    
    mutating func deleteFolder(id: UUID) {
        folders.removeAll { $0.id == id }
        // Move orphaned items to root
        for i in items.indices where items[i].folderID == id {
            items[i].folderID = nil
        }
    }
    
    func folder(withID id: UUID) -> VaultFolder? {
        folders.first { $0.id == id }
    }
    
    // MARK: - Tag Helpers
    
    // All unique tags across all items, sorted alphabetically
    var allTags: [String] {
        Array(Set(items.flatMap { $0.tags })).sorted()
    }
    
    // Items in a specific folder (nil = root / unfiled)
    func items(inFolder folderID: UUID?) -> [VaultItem] {
        items.filter { $0.folderID == folderID }
    }
    
    // Items with a specific tag
    func items(withTag tag: String) -> [VaultItem] {
        items.filter { $0.tags.contains(tag) }
    }
}
