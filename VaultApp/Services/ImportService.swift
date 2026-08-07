import Foundation

// ImportService parses CSV/text data from various password managers
// into an array of VaultItem objects ready to be reviewed and imported.
enum ImportService {

    // MARK: - Source Types

    enum Source: String, CaseIterable, Identifiable {
        case onePassword = "1Password"
        case bitwarden   = "Bitwarden"
        case safari      = "Safari"
        case chrome      = "Chrome"
        case firefox     = "Firefox"
        case edge        = "Microsoft Edge"
        case keychain    = "macOS Keychain"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .onePassword: return "lock.shield.fill"
            case .bitwarden:   return "shield.fill"
            case .safari:      return "safari.fill"
            case .chrome:      return "globe.americas.fill"
            case .firefox:     return "flame.fill"
            case .edge:        return "e.circle.fill"
            case .keychain:    return "key.fill"
            }
        }

        // Whether this source requires a file picker or reads live data
        var requiresFile: Bool { self != .keychain }

        // Accepted file extensions for the open panel
        var fileExtensions: [String] {
            switch self {
            case .keychain: return []
            default:        return ["csv"]
            }
        }

        var exportInstructions: String {
            switch self {
            case .onePassword:
                return "1. Open 1Password → File → Export → All Items\n2. Choose CSV format\n3. Save and select the file below"
            case .bitwarden:
                return "1. Open Bitwarden web vault → Tools → Export Vault\n2. Choose File Format: .csv\n3. Save and select the file below"
            case .safari:
                return "1. Open Safari → File → Export → Passwords…\n2. Authenticate with your Mac password\n3. Save the CSV and select it below"
            case .chrome:
                return "1. Open Chrome → Settings → Autofill → Password Manager\n2. Click the ⋮ menu → Export passwords\n3. Save the CSV and select it below"
            case .firefox:
                return "1. Open Firefox → Passwords (about:logins)\n2. Click the ⋮ menu → Export Logins\n3. Save the CSV and select it below"
            case .edge:
                return "1. Open Edge → Settings → Passwords\n2. Click ⋮ → Export passwords\n3. Save the CSV and select it below"
            case .keychain:
                return "VaultApp will read directly from your macOS Keychain.\nYou'll be prompted to allow access for each entry or grant bulk access."
            }
        }
    }

    // MARK: - Errors

    enum ImportError: LocalizedError {
        case emptyFile
        case unrecognisedFormat
        case noValidRows
        case unknown(Error)

        var errorDescription: String? {
            switch self {
            case .emptyFile:           return "The selected file is empty."
            case .unrecognisedFormat:  return "Could not recognise the file format. Make sure you exported from the correct app."
            case .noValidRows:         return "No valid password entries were found in the file."
            case .unknown(let e):      return e.localizedDescription
            }
        }
    }

    // MARK: - Parse Dispatch

    static func parse(csvData: Data, source: Source) throws -> [VaultItem] {
        guard !csvData.isEmpty else { throw ImportError.emptyFile }
        guard let text = String(data: csvData, encoding: .utf8) ??
                         String(data: csvData, encoding: .isoLatin1) else {
            throw ImportError.unrecognisedFormat
        }
        let rows = parseCSV(text)
        guard rows.count > 1 else { throw ImportError.noValidRows }  // at least header + one row

        let items: [VaultItem]
        switch source {
        case .onePassword: items = parseOnePassword(rows: rows)
        case .bitwarden:   items = parseBitwarden(rows: rows)
        case .safari:      items = parseSafari(rows: rows)
        case .chrome:      items = parseChrome(rows: rows)
        case .firefox:     items = parseFirefox(rows: rows)
        case .edge:        items = parseChrome(rows: rows)  // Edge uses Chrome format
        case .keychain:    items = []  // handled by KeychainImporter, not CSV
        }

        guard !items.isEmpty else { throw ImportError.noValidRows }
        return items
    }

    // MARK: - CSV Parser (RFC 4180-compliant)

    // Returns array of rows, each row is an array of field strings.
    // Handles quoted fields, commas inside quotes, escaped quotes ("").
    static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false
        var i = text.startIndex

        while i < text.endIndex {
            let char = text[i]

            if insideQuotes {
                if char == "\"" {
                    let next = text.index(after: i)
                    if next < text.endIndex && text[next] == "\"" {
                        // Escaped quote — two double-quotes inside a quoted field = one literal "
                        currentField.append("\"")
                        i = text.index(after: next)
                        continue
                    } else {
                        // End of quoted field
                        insideQuotes = false
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                if char == "\"" {
                    insideQuotes = true
                } else if char == "," {
                    currentRow.append(currentField)
                    currentField = ""
                } else if char == "\n" || char == "\r" {
                    currentRow.append(currentField)
                    currentField = ""
                    if !currentRow.isEmpty {
                        rows.append(currentRow)
                    }
                    currentRow = []
                    // Skip \n after \r
                    if char == "\r" {
                        let next = text.index(after: i)
                        if next < text.endIndex && text[next] == "\n" {
                            i = next
                        }
                    }
                } else {
                    currentField.append(char)
                }
            }
            i = text.index(after: i)
        }

        // Flush last row
        currentRow.append(currentField)
        if !currentRow.allSatisfy({ $0.isEmpty }) {
            rows.append(currentRow)
        }

        return rows
    }

    // MARK: - Source-Specific Parsers

    // 1Password CSV: Title,Username,Password,URL,Notes,OTPAuth
    private static func parseOnePassword(rows: [[String]]) -> [VaultItem] {
        guard let header = rows.first else { return [] }
        let col = columnMap(header)
        return rows.dropFirst().compactMap { row in
            guard row.count == header.count else { return nil }
            let password = field(row, col["password"] ?? col["Password"])
            guard !password.isEmpty else { return nil }
            return VaultItem(
                title:    field(row, col["title"] ?? col["Title"]),
                username: field(row, col["username"] ?? col["Username"]),
                password: password,
                url:      field(row, col["url"] ?? col["URL"]),
                notes:    field(row, col["notes"] ?? col["Notes"]),
                category: .login
            )
        }
    }

    // Bitwarden CSV: folder,favorite,type,name,notes,fields,reprompt,login_uri,login_username,login_password,login_totp
    private static func parseBitwarden(rows: [[String]]) -> [VaultItem] {
        guard let header = rows.first else { return [] }
        let col = columnMap(header)
        return rows.dropFirst().compactMap { row in
            guard row.count == header.count else { return nil }
            // Only import login items
            let type = field(row, col["type"])
            guard type == "login" || type.isEmpty else { return nil }
            let password = field(row, col["login_password"])
            guard !password.isEmpty else { return nil }
            return VaultItem(
                title:    field(row, col["name"]),
                username: field(row, col["login_username"]),
                password: password,
                url:      field(row, col["login_uri"]),
                notes:    field(row, col["notes"]),
                category: .login
            )
        }
    }

    // Safari CSV: Title,URL,Username,Password,Notes,OTPAuth (same columns as 1Password)
    private static func parseSafari(rows: [[String]]) -> [VaultItem] {
        return parseOnePassword(rows: rows)  // Identical column structure
    }

    // Chrome / Edge CSV: name,url,username,password
    private static func parseChrome(rows: [[String]]) -> [VaultItem] {
        guard let header = rows.first else { return [] }
        let col = columnMap(header)
        return rows.dropFirst().compactMap { row in
            guard row.count == header.count else { return nil }
            let password = field(row, col["password"])
            guard !password.isEmpty else { return nil }
            let urlStr = field(row, col["url"])
            // Chrome uses the full URL for the title if name is empty
            let title = field(row, col["name"]).isEmpty
                ? (URL(string: urlStr)?.host ?? urlStr)
                : field(row, col["name"])
            return VaultItem(
                title:    title,
                username: field(row, col["username"]),
                password: password,
                url:      urlStr,
                notes:    "",
                category: .login
            )
        }
    }

    // Firefox CSV: url,username,password,httpRealm,formActionOrigin,guid,timeCreated,timeLastUsed,timePasswordChanged
    private static func parseFirefox(rows: [[String]]) -> [VaultItem] {
        guard let header = rows.first else { return [] }
        let col = columnMap(header)
        return rows.dropFirst().compactMap { row in
            guard row.count == header.count else { return nil }
            let password = field(row, col["password"])
            guard !password.isEmpty else { return nil }
            let urlStr = field(row, col["url"])
            let title = URL(string: urlStr)?.host ?? urlStr
            return VaultItem(
                title:    title.isEmpty ? urlStr : title,
                username: field(row, col["username"]),
                password: password,
                url:      urlStr,
                notes:    "",
                category: .login
            )
        }
    }

    // MARK: - Helpers

    // Build a lowercase column-name → index map from the header row
    private static func columnMap(_ header: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (index, name) in header.enumerated() {
            map[name.trimmingCharacters(in: .whitespaces).lowercased()] = index
            map[name.trimmingCharacters(in: .whitespaces)] = index  // also keep original case
        }
        return map
    }

    private static func field(_ row: [String], _ index: Int?) -> String {
        guard let index, index < row.count else { return "" }
        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}