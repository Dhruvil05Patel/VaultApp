import Foundation

// AntiPhishingService compares a stored URL against a detected URL
// and returns a suspicion assessment.
// All checks are purely local — no network calls.
enum AntiPhishingService {

    // MARK: - Check Result

    struct CheckResult {
        let isSuspicious: Bool
        let storedHost: String
        let detectedHost: String
        let reason: SuspicionReason?
        let confidence: Confidence

        enum SuspicionReason {
            case differentDomain    // github.com vs gitlab.com
            case typosquatting      // glthhub.com vs github.com (edit distance 1-2)
            case homoglyph          // gіthub.com (Cyrillic і) vs github.com
            case suspiciousSubdomain // login.paypal.com.evil.com vs paypal.com
            case ipAddress          // 192.168.1.1 vs github.com
            case portMismatch       // github.com:8080 vs github.com
            case schemeMismatch     // http vs https

            var title: String {
                switch self {
                case .differentDomain:      return "Different Domain"
                case .typosquatting:        return "Possible Typosquatting"
                case .homoglyph:            return "Homoglyph Attack Detected"
                case .suspiciousSubdomain:  return "Suspicious Subdomain"
                case .ipAddress:            return "IP Address Instead of Domain"
                case .portMismatch:         return "Unusual Port Number"
                case .schemeMismatch:       return "Insecure Connection"
                }
            }

            var description: String {
                switch self {
                case .differentDomain:
                    return "The domain in your clipboard is completely different from where this password is stored."
                case .typosquatting:
                    return "The domain is very similar to the stored URL with a small difference — this is a common phishing technique."
                case .homoglyph:
                    return "The URL contains characters that look like normal letters but are not standard ASCII. This is used to create convincing fake sites."
                case .suspiciousSubdomain:
                    return "The real domain appears as a subdomain of a different site — a trick to make fake URLs look legitimate."
                case .ipAddress:
                    return "The URL uses a raw IP address instead of a domain name, which is unusual for legitimate websites."
                case .portMismatch:
                    return "The URL uses a non-standard port which is uncommon for legitimate public websites."
                case .schemeMismatch:
                    return "The site in your clipboard uses HTTP (insecure) while the stored URL uses HTTPS."
                }
            }
        }

        enum Confidence {
            case high    // very likely phishing
            case medium  // possibly phishing — warn clearly
            case low     // minor difference — show as info
        }
    }

    // MARK: - Main Check

    static func check(storedURLString: String, detectedURLString: String) -> CheckResult {
        let stored   = storedURLString.trimmingCharacters(in: .whitespaces)
        let detected = detectedURLString.trimmingCharacters(in: .whitespaces)

        guard !stored.isEmpty, !detected.isEmpty else {
            return safe(stored: "", detected: "")
        }

        guard let storedURL   = normaliseURL(stored),
              let detectedURL = normaliseURL(detected) else {
            return safe(stored: stored, detected: detected)
        }

        let storedHost   = storedURL.host?.lowercased() ?? ""
        let detectedHost = detectedURL.host?.lowercased() ?? ""

        // Strip www. for comparison
        let storedBase   = stripWWW(storedHost)
        let detectedBase = stripWWW(detectedHost)

        // 1. Exact match — safe
        if storedBase == detectedBase {
            return safe(stored: storedHost, detected: detectedHost)
        }

        // 2. Homoglyph detection — check for non-ASCII characters
        if containsNonASCII(detectedBase) {
            return CheckResult(
                isSuspicious: true,
                storedHost: storedHost,
                detectedHost: detectedHost,
                reason: .homoglyph,
                confidence: .high
            )
        }

        // 3. IP address check
        if isIPAddress(detectedBase) {
            return CheckResult(
                isSuspicious: true,
                storedHost: storedHost,
                detectedHost: detectedHost,
                reason: .ipAddress,
                confidence: .high
            )
        }

        // 4. Suspicious subdomain: storedBase appears inside detectedBase as a subdomain trick
        // e.g. detected = "paypal.com.evil.com" and stored = "paypal.com"
        if detectedBase.contains(storedBase + ".") && !detectedBase.hasSuffix(".\(storedBase)") {
            return CheckResult(
                isSuspicious: true,
                storedHost: storedHost,
                detectedHost: detectedHost,
                reason: .suspiciousSubdomain,
                confidence: .high
            )
        }

        // 5. Legitimate subdomain: detected ends with .storedBase (e.g. app.github.com)
        if detectedBase.hasSuffix(".\(storedBase)") {
            // This might be a legitimate subdomain — show as low confidence warning
            return CheckResult(
                isSuspicious: true,
                storedHost: storedHost,
                detectedHost: detectedHost,
                reason: .suspiciousSubdomain,
                confidence: .low
            )
        }

        // 6. Scheme mismatch (http vs https)
        let storedScheme   = storedURL.scheme?.lowercased() ?? "https"
        let detectedScheme = detectedURL.scheme?.lowercased() ?? "https"
        if storedScheme == "https" && detectedScheme == "http" {
            return CheckResult(
                isSuspicious: true,
                storedHost: storedHost,
                detectedHost: detectedHost,
                reason: .schemeMismatch,
                confidence: .medium
            )
        }

        // 7. Port mismatch
        if let detectedPort = detectedURL.port, detectedPort != 80, detectedPort != 443 {
            return CheckResult(
                isSuspicious: true,
                storedHost: storedHost,
                detectedHost: detectedHost,
                reason: .portMismatch,
                confidence: .medium
            )
        }

        // 8. Typosquatting — Levenshtein distance 1-2
        let distance = levenshtein(storedBase, detectedBase)
        if distance == 1 {
            return CheckResult(
                isSuspicious: true,
                storedHost: storedHost,
                detectedHost: detectedHost,
                reason: .typosquatting,
                confidence: .high
            )
        } else if distance == 2 {
            return CheckResult(
                isSuspicious: true,
                storedHost: storedHost,
                detectedHost: detectedHost,
                reason: .typosquatting,
                confidence: .medium
            )
        }

        // 9. Different domain entirely
        return CheckResult(
            isSuspicious: true,
            storedHost: storedHost,
            detectedHost: detectedHost,
            reason: .differentDomain,
            confidence: .medium
        )
    }

    // MARK: - Helpers

    private static func safe(stored: String, detected: String) -> CheckResult {
        CheckResult(
            isSuspicious: false,
            storedHost: stored,
            detectedHost: detected,
            reason: nil,
            confidence: .low
        )
    }

    private static func normaliseURL(_ string: String) -> URL? {
        let withScheme = string.hasPrefix("http") ? string : "https://\(string)"
        return URL(string: withScheme)
    }

    private static func stripWWW(_ host: String) -> String {
        host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private static func containsNonASCII(_ string: String) -> Bool {
        string.unicodeScalars.contains { $0.value > 127 }
    }

    private static func isIPAddress(_ host: String) -> Bool {
        // Simple IPv4 check
        let parts = host.components(separatedBy: ".")
        if parts.count == 4 && parts.allSatisfy({ Int($0) != nil && Int($0)! <= 255 }) {
            return true
        }
        // IPv6: contains colons
        return host.contains(":")
    }

    // Standard Levenshtein edit distance
    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        let m = a.count
        let n = b.count

        guard m > 0 else { return n }
        guard n > 0 else { return m }

        var dp = (0...n).map { $0 }

        for i in 1...m {
            var prev = i
            for j in 1...n {
                let curr: Int
                if a[i-1] == b[j-1] {
                    curr = dp[j-1]
                } else {
                    curr = 1 + min(dp[j], min(dp[j-1], prev))
                }
                dp[j-1] = prev
                prev = curr
            }
            dp[n] = prev
        }

        return dp[n]
    }
}
