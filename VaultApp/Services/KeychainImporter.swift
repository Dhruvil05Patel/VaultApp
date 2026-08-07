import Foundation
import Security

// KeychainImporter reads internet passwords and generic passwords
// directly from the user's macOS Keychain.
// Each Keychain item that has a matching account + password is converted to a VaultItem.
enum KeychainImporter {

    // MARK: - Import

    static func importItems() throws -> [VaultItem] {
        var items: [VaultItem] = []
        items += try fetchInternetPasswords()
        items += try fetchGenericPasswords()
        // De-duplicate by (username, password) pair
        return deduplicate(items)
    }

    // MARK: - Internet Passwords (websites, servers)

    private static func fetchInternetPasswords() throws -> [VaultItem] {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassInternetPassword,
            kSecMatchLimit as String:       kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecReturnData as String:       true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        // errSecItemNotFound just means no items — not an error
        guard status == errSecSuccess || status == errSecItemNotFound else {
            // If denied, return empty — don't throw; let the UI show 0 items
            return []
        }

        guard let entries = result as? [[String: Any]] else { return [] }

        return entries.compactMap { entry -> VaultItem? in
            guard let passwordData = entry[kSecValueData as String] as? Data,
                  let password = String(data: passwordData, encoding: .utf8),
                  !password.isEmpty else { return nil }

            let account = entry[kSecAttrAccount as String] as? String ?? ""
            let server  = entry[kSecAttrServer as String]  as? String ?? ""
            let label   = entry[kSecAttrLabel as String]   as? String ?? server
            let comment = entry[kSecAttrComment as String] as? String ?? ""
            let proto   = entry[kSecAttrProtocol as String] as? String

            // Build URL from server + protocol
            var urlStr = ""
            if !server.isEmpty {
                let scheme = (proto == (kSecAttrProtocolHTTPS as String)) ? "https" : "http"
                urlStr = "\(scheme)://\(server)"
            }

            return VaultItem(
                title:    label.isEmpty ? server : label,
                username: account,
                password: password,
                url:      urlStr,
                notes:    comment,
                category: .login
            )
        }
    }

    // MARK: - Generic Passwords (app credentials, Wi-Fi, etc.)

    private static func fetchGenericPasswords() throws -> [VaultItem] {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecMatchLimit as String:       kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecReturnData as String:       true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess || status == errSecItemNotFound else { return [] }
        guard let entries = result as? [[String: Any]] else { return [] }

        return entries.compactMap { entry -> VaultItem? in
            guard let passwordData = entry[kSecValueData as String] as? Data,
                  let password = String(data: passwordData, encoding: .utf8),
                  !password.isEmpty else { return nil }

            let account = entry[kSecAttrAccount as String] as? String ?? ""
            let service = entry[kSecAttrService as String] as? String ?? ""
            let label   = entry[kSecAttrLabel as String]   as? String ?? service
            let comment = entry[kSecAttrComment as String] as? String ?? ""

            // Skip VaultApp's own Keychain items
            if service == "com.vaultapp.biometric-key" { return nil }

            // Skip Apple system entries (not useful as vault items)
            if service.hasPrefix("com.apple.") { return nil }

            // Skip empty labels (system internals)
            guard !label.isEmpty && !account.isEmpty else { return nil }

            return VaultItem(
                title:    label,
                username: account,
                password: password,
                url:      "",
                notes:    comment,
                category: .login
            )
        }
    }

    // MARK: - De-duplicate

    private static func deduplicate(_ items: [VaultItem]) -> [VaultItem] {
        var seen = Set<String>()
        return items.filter { item in
            let key = "\(item.username.lowercased()):\(item.password)"
            return seen.insert(key).inserted
        }
    }
}