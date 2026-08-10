import Foundation

// Structured fields for a credit / debit card entry.
struct CardFields: Codable, Hashable {

    var cardholderName: String = ""
    var cardNumber: String     = ""   // stored as digits only, no spaces
    var expiryMonth: String    = ""   // "01"–"12"
    var expiryYear: String     = ""   // "2027"
    var cvv: String            = ""
    var cardType: CardType     = .unknown
    var bankName: String       = ""
    var billingAddress: String = ""
    var pin: String            = ""   // ATM PIN — optional

    enum CardType: String, Codable, CaseIterable {
        case visa       = "Visa"
        case mastercard = "Mastercard"
        case amex       = "Amex"
        case discover   = "Discover"
        case other      = "Other"
        case unknown    = "Unknown"

        var icon: String {
            switch self {
            case .visa:       return "creditcard"
            case .mastercard: return "creditcard.fill"
            case .amex:       return "creditcard.and.123"
            case .discover:   return "creditcard.trianglebadge.exclamationmark"
            case .other, .unknown: return "creditcard"
            }
        }

        // Detect type from card number prefix (first 1–2 digits)
        static func detect(from number: String) -> CardType {
            let digits = number.filter { $0.isNumber }
            guard !digits.isEmpty else { return .unknown }
            if digits.hasPrefix("4")                          { return .visa }
            if digits.hasPrefix("51") || digits.hasPrefix("52")
            || digits.hasPrefix("53") || digits.hasPrefix("54")
            || digits.hasPrefix("55")                         { return .mastercard }
            if digits.hasPrefix("34") || digits.hasPrefix("37") { return .amex }
            if digits.hasPrefix("6011") || digits.hasPrefix("65") { return .discover }
            return .other
        }
    }

    // MARK: - Helpers

    // Display format: "•••• •••• •••• 4242"
    var maskedNumber: String {
        let digits = cardNumber.filter { $0.isNumber }
        guard digits.count >= 4 else { return cardNumber }
        let last4 = String(digits.suffix(4))
        return "•••• •••• •••• \(last4)"
    }

    // Formatted: "04 / 2027"
    var formattedExpiry: String {
        guard !expiryMonth.isEmpty, !expiryYear.isEmpty else { return "" }
        return "\(expiryMonth) / \(expiryYear)"
    }

    // Luhn check — basic card number validation
    var isValidCardNumber: Bool {
        let digits = cardNumber.filter { $0.isNumber }.compactMap { $0.wholeNumberValue }
        guard digits.count >= 13 && digits.count <= 19 else { return false }
        var sum = 0
        for (i, digit) in digits.reversed().enumerated() {
            if i % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        return sum % 10 == 0
    }
}