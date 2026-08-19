import Foundation

enum PasswordChangeService {

    // MARK: - Known Change-Password URLs

    // Sites that support the W3C .well-known/change-password standard
    // Add more as they become known
    static let wellKnownPath = "/.well-known/change-password"

    // Fallback: common change-password page paths for popular sites
    // Used when .well-known is not supported
    static let knownPaths: [String: String] = [
        "github.com":       "https://github.com/settings/security",
        "google.com":       "https://myaccount.google.com/signinoptions/password",
        "facebook.com":     "https://www.facebook.com/settings?tab=security",
        "twitter.com":      "https://twitter.com/settings/password",
        "x.com":            "https://twitter.com/settings/password",
        "instagram.com":    "https://www.instagram.com/accounts/password/change/",
        "reddit.com":       "https://www.reddit.com/prefs/update/",
        "amazon.com":       "https://www.amazon.com/ap/cnep",
        "apple.com":        "https://appleid.apple.com/account/manage",
        "microsoft.com":    "https://account.live.com/password/Change",
        "dropbox.com":      "https://www.dropbox.com/account/security",
        "netflix.com":      "https://www.netflix.com/YourAccount",
        "linkedin.com":     "https://www.linkedin.com/psettings/change-password",
        "paypal.com":       "https://www.paypal.com/myaccount/security/password/change",
    ]

    // MARK: - Resolve change-password URL for a vault item

    struct ChangePasswordTarget {
        let url: URL
        let method: Method
        enum Method {
            case wellKnown      // W3C standard
            case knownPath      // Hardcoded path from our database
            case searchFallback // User must find the page manually
        }
    }

    static func resolveTarget(for item: VaultItem) async -> ChangePasswordTarget? {
        guard !item.url.isEmpty,
              let baseURL = URL(string: item.url.hasPrefix("http") ? item.url : "https://\(item.url)"),
              let host = baseURL.host else { return nil }

        // 1. Try .well-known/change-password
        if let wellKnown = URL(string: "https://\(host)\(wellKnownPath)") {
            if await isReachable(wellKnown) {
                return ChangePasswordTarget(url: wellKnown, method: .wellKnown)
            }
        }

        // 2. Try known paths database (strip www.)
        let cleanHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        if let knownURL = knownPaths[cleanHost].flatMap({ URL(string: $0) }) {
            return ChangePasswordTarget(url: knownURL, method: .knownPath)
        }

        // 3. Fall back to the site's root — user navigates themselves
        if let root = URL(string: "https://\(host)") {
            return ChangePasswordTarget(url: root, method: .searchFallback)
        }

        return nil
    }

    // HEAD request to check if the .well-known URL exists
    private static func isReachable(_ url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        return (try? await URLSession.shared.data(for: request)) != nil
    }
}
