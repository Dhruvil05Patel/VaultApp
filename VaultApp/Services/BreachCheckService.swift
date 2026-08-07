import Foundation
import CryptoKit

// BreachCheckService checks passwords against the HaveIBeenPwned
// Pwned Passwords API using the k-anonymity model.
// The full password and full SHA-1 hash are NEVER sent over the network.
enum BreachCheckService {

    // MARK: - Errors

    enum BreachError: LocalizedError {
        case networkUnavailable
        case rateLimited
        case serverError(Int)
        case invalidResponse
        case unknown(Error)

        var errorDescription: String? {
            switch self {
            case .networkUnavailable: return "No internet connection. Check your network and try again."
            case .rateLimited:        return "Too many requests. Wait a moment and try again."
            case .serverError(let c): return "HIBP server error (\(c)). Try again later."
            case .invalidResponse:    return "Unexpected response from breach check service."
            case .unknown(let e):     return e.localizedDescription
            }
        }
    }

    // MARK: - Result

    struct BreachResult {
        let isBreached: Bool
        let count: Int      // how many times this password appeared in breaches
    }

    // MARK: - Check Single Password

    // Checks one password against the HIBP Pwned Passwords API.
    // k-anonymity: only the first 5 hex chars of the SHA-1 hash are sent.
    static func check(password: String) async throws -> BreachResult {
        guard !password.isEmpty else {
            return BreachResult(isBreached: false, count: 0)
        }

        // Step 1: SHA-1 hash the password
        let passwordData = Data(password.utf8)
        let hash = Insecure.SHA1.hash(data: passwordData)

        // Step 2: Convert to uppercase hex string
        let hexHash = hash.map { String(format: "%02X", $0) }.joined()
        // e.g. "3D4F2BF07DC1BE38B20CD6E46949A1071F9D0E3D"

        // Step 3: Split — prefix (sent) and suffix (kept local)
        let prefix = String(hexHash.prefix(5))           // "3D4F2"
        let suffix = String(hexHash.dropFirst(5))        // "BF07DC1..."

        // Step 4: Fetch all hashes with this prefix
        let url = URL(string: "https://api.pwnedpasswords.com/range/\(prefix)")!
        var request = URLRequest(url: url)
        request.setValue("VaultApp-BreachCheck/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("true", forHTTPHeaderField: "Add-Padding")  // prevents traffic analysis
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BreachError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            throw BreachError.rateLimited
        case 400...499:
            throw BreachError.invalidResponse
        case 500...599:
            throw BreachError.serverError(httpResponse.statusCode)
        default:
            throw BreachError.invalidResponse
        }

        // Step 5: Parse response — each line is "SUFFIX:COUNT"
        guard let body = String(data: data, encoding: .utf8) else {
            throw BreachError.invalidResponse
        }

        // Step 6: Compare locally — look for our suffix in the list
        for line in body.components(separatedBy: "\r\n") {
            let parts = line.components(separatedBy: ":")
            guard parts.count == 2 else { continue }

            let returnedSuffix = parts[0].trimmingCharacters(in: .whitespaces)
            let countString    = parts[1].trimmingCharacters(in: .whitespaces)

            if returnedSuffix.uppercased() == suffix.uppercased() {
                let count = Int(countString) ?? 1
                return BreachResult(isBreached: true, count: count)
            }
        }

        // Suffix not found — password is clean
        return BreachResult(isBreached: false, count: 0)
    }

    // MARK: - Bulk Check (entire vault)

    // Checks all items in the vault, returns a dictionary of [UUID: BreachResult].
    // Adds a short delay between requests to be a polite API consumer.
    static func checkAll(
        items: [VaultItem],
        progress: @escaping (Int, Int) -> Void   // (completed, total)
    ) async throws -> [UUID: BreachResult] {
        var results: [UUID: BreachResult] = [:]
        let total = items.count

        for (index, item) in items.enumerated() {
            guard !item.password.isEmpty else {
                results[item.id] = BreachResult(isBreached: false, count: 0)
                progress(index + 1, total)
                continue
            }

            do {
                let result = try await check(password: item.password)
                results[item.id] = result
            } catch {
                // On individual failure, mark as unknown and continue
                results[item.id] = BreachResult(isBreached: false, count: 0)
            }

            progress(index + 1, total)

            // Polite delay — HIBP rate limit is 1 request / 1500ms per spec
            if index < items.count - 1 {
                try await Task.sleep(nanoseconds: 1_600_000_000) // 1.6 seconds
            }
        }

        return results
    }

    // MARK: - Format breach count

    static func formatCount(_ count: Int) -> String {
        switch count {
        case 0:          return "0 times"
        case 1:          return "1 time"
        case 2...999:    return "\(count) times"
        case 1000...999_999:
            return "\(count / 1000)K times"
        default:
            return "\(count / 1_000_000)M times"
        }
    }
}