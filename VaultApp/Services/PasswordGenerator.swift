import Foundation

// PasswordGenerator is a stateless enum — no instances, just static functions.
// Uses Swift's SystemRandomNumberGenerator which is cryptographically secure on Apple platforms.
enum PasswordGenerator {

    // MARK: - Character Sets

    private static let lowercase  = "abcdefghijklmnopqrstuvwxyz"
    private static let uppercase  = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    private static let digits     = "0123456789"
    private static let symbols    = "!@#$%^&*()-_=+[]{}|;:,.<>?"

    // Characters that look too similar — excluded when ambiguous chars are disabled
    private static let ambiguous  = "0O1lI"

    // MARK: - Options

    struct Options {
        var length: Int          = 20
        var includeUppercase: Bool = true
        var includeLowercase: Bool = true
        var includeNumbers: Bool   = true
        var includeSymbols: Bool   = true
        var excludeAmbiguous: Bool = false

        // Default strong password options
        static let strong = Options()

        // PIN — digits only
        static func pin(digits: Int = 6) -> Options {
            Options(
                length: digits,
                includeUppercase: false,
                includeLowercase: false,
                includeNumbers: true,
                includeSymbols: false,
                excludeAmbiguous: false
            )
        }
    }

    // MARK: - Generate

    // Returns a random password string based on the provided Options.
    // Guarantees at least one character from each enabled category
    // (so the password always satisfies common site requirements).
    static func generate(options: Options = .strong) -> String {
        var pool = options.includeLowercase ? lowercase : ""
        var required: [Character] = []

        // Build the character pool and collect one guaranteed char per category
        if options.includeUppercase {
            pool += uppercase
            required.append(randomChar(from: uppercase))
        }

        if options.includeNumbers {
            pool += digits
            required.append(randomChar(from: digits))
        }

        if options.includeSymbols {
            pool += symbols
            required.append(randomChar(from: symbols))
        }

        // Always guarantee one lowercase character
        if options.includeLowercase {
            pool += lowercase
            required.append(randomChar(from: lowercase))
        }

        // Remove ambiguous characters from pool if requested
        if options.excludeAmbiguous {
            pool = pool.filter { !ambiguous.contains($0) }
        }

        // Guard: pool must not be empty
        guard !pool.isEmpty, options.length > 0 else { return "" }

        // Fill remaining slots with random characters from the pool
        let remainingLength = max(0, options.length - required.count)
        var result: [Character] = required + (0..<remainingLength).map { _ in randomChar(from: pool) }

        // Shuffle so the guaranteed characters are not always at the start
        result.shuffle()

        return String(result.prefix(options.length))
    }

    // MARK: - Passphrase (word-based, easier to remember)

    // Generates a passphrase like "correct-horse-battery-staple"
    // using a built-in short word list. For a production app, use the EFF large wordlist.
    static func generatePassphrase(wordCount: Int = 4, separator: String = "-") -> String {
        let words = [
            "apple", "bridge", "cloud", "dragon", "ember", "forest", "glass", "harbor",
            "island", "jungle", "knight", "lemon", "marble", "noble", "ocean", "pepper",
            "quartz", "river", "silver", "tiger", "umbrella", "violet", "whisper", "xenon",
            "yellow", "zenith", "anchor", "breeze", "crater", "dagger", "echo", "flint",
            "gravel", "hollow", "ivory", "jasper", "lantern", "mosaic", "nectar", "onyx",
            "prism", "raven", "storm", "tundra", "vapor", "walnut", "xylem", "yonder", "zinc"
        ]
        let selected = (0..<wordCount).map { _ in words.randomElement()! }
        return selected.joined(separator: separator)
    }

    // MARK: - Password Strength

    enum Strength: String {
        case weak    = "Weak"
        case fair    = "Fair"
        case strong  = "Strong"
        case veryStrong = "Very Strong"

        var color: String {   // return a semantic color name for SwiftUI
            switch self {
            case .weak:       return "red"
            case .fair:       return "orange"
            case .strong:     return "yellow"
            case .veryStrong: return "green"
            }
        }
    }

    // Estimate the strength of a given password string.
    // This is a heuristic — not an entropy calculation.
    static func strength(of password: String) -> Strength {
        let length = password.count
        let hasUpper    = password.contains(where: { $0.isUppercase })
        let hasLower    = password.contains(where: { $0.isLowercase })
        let hasDigit    = password.contains(where: { $0.isNumber })
        let hasSymbol   = password.contains(where: { !$0.isLetter && !$0.isNumber })

        let variety = [hasUpper, hasLower, hasDigit, hasSymbol].filter { $0 }.count

        switch (length, variety) {
        case (..<8,  _):          return .weak
        case (8..<12, 1...2):    return .fair
        case (8..<12, 3...):     return .strong
        case (12..<20, 1...2):   return .fair
        case (12..<20, 3...):    return .strong
        case (20..., 3...):      return .veryStrong
        default:                  return .fair
        }
    }

    // MARK: - Private Helpers

    private static func randomChar(from string: String) -> Character {
        string.randomElement()!
    }
}
