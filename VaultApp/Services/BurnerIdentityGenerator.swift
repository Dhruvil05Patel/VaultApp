import Foundation

enum BurnerIdentityGenerator {

    // MARK: - Generated Identity

    struct BurnerIdentity {
        var firstName: String
        var lastName: String
        var email: String
        var phone: String
        var addressLine1: String
        var city: String
        var state: String
        var postalCode: String
        var country: String
        var dateOfBirth: String    // "YYYY-MM-DD"
        var password: String

        var fullName: String { "\(firstName) \(lastName)" }
    }

    // MARK: - Generate

    static func generate(
        emailDomain: String = "",
        phoneCountry: PhoneCountry = .us
    ) -> BurnerIdentity {
        let first    = firstNames.randomElement()!
        let last     = lastNames.randomElement()!
        let email    = generateEmail(firstName: first, lastName: last, domain: emailDomain)
        let address  = generateAddress(country: phoneCountry)
        let dob      = generateDOB()
        let password = PasswordGenerator.generate()

        return BurnerIdentity(
            firstName:   first,
            lastName:    last,
            email:       email,
            phone:       generatePhone(country: phoneCountry),
            addressLine1: address.line1,
            city:        address.city,
            state:       address.state,
            postalCode:  address.postal,
            country:     phoneCountry.countryName,
            dateOfBirth: dob,
            password:    password
        )
    }

    // MARK: - Phone Country

    enum PhoneCountry: String, CaseIterable, Identifiable {
        case us = "United States"
        case uk = "United Kingdom"
        case india = "India"
        case canada = "Canada"
        case australia = "Australia"

        var id: String { rawValue }
        var countryName: String { rawValue }
        var prefix: String {
            switch self {
            case .us:        return "+1"
            case .uk:        return "+44"
            case .india:     return "+91"
            case .canada:    return "+1"
            case .australia: return "+61"
            }
        }
    }

    // MARK: - Email Generation

    static func generateEmail(firstName: String, lastName: String, domain: String) -> String {
        let cleanDomain = domain.trimmingCharacters(in: .whitespaces)

        if !cleanDomain.isEmpty {
            // User-provided alias domain (e.g. user+[random]@icloud.com style)
            let tag = "\(firstName.lowercased()).\(Int.random(in: 100...999))"
            let domainPart = cleanDomain.hasPrefix("@") ? cleanDomain : "@\(cleanDomain)"
            return "\(tag)\(domainPart)"
        } else {
            // Generic plausible-looking email for a fake domain
            let domains = ["outlook.com", "yahoo.com", "proton.me", "tutanota.com", "fastmail.com"]
            let tag = "\(firstName.lowercased()).\(lastName.lowercased())\(Int.random(in: 1...99))"
            return "\(tag)@\(domains.randomElement()!)"
        }
    }

    // MARK: - Phone Generation

    static func generatePhone(country: PhoneCountry) -> String {
        switch country {
        case .us, .canada:
            // NANP format — area codes 200-999, avoid 911
            let area = Int.random(in: 200...999)
            let exch = Int.random(in: 200...999)
            let line = Int.random(in: 1000...9999)
            return "\(country.prefix) (\(area)) \(exch)-\(line)"
        case .uk:
            let local = (0..<8).map { _ in String(Int.random(in: 0...9)) }.joined()
            return "\(country.prefix) 7\(local)"
        case .india:
            let digits = (0..<9).map { _ in String(Int.random(in: 0...9)) }.joined()
            return "\(country.prefix) 9\(digits)"
        case .australia:
            let digits = (0..<8).map { _ in String(Int.random(in: 0...9)) }.joined()
            return "\(country.prefix) 4\(digits)"
        }
    }

    // MARK: - Address Generation

    struct AddressComponents {
        let line1: String
        let city: String
        let state: String
        let postal: String
    }

    static func generateAddress(country: PhoneCountry) -> AddressComponents {
        let number    = Int.random(in: 1...9999)
        let street    = streetNames.randomElement()!
        let streetType = streetTypes.randomElement()!

        switch country {
        case .us, .canada:
            let city   = usCities.randomElement()!
            let state  = usStates.randomElement()!
            let zip    = String(format: "%05d", Int.random(in: 10000...99999))
            return AddressComponents(
                line1:  "\(number) \(street) \(streetType)",
                city:   city.0,
                state:  city.1,
                postal: zip
            )
        case .uk:
            let city   = ukCities.randomElement()!
            let area   = String((65...90).map { Character(UnicodeScalar($0)!) }.randomElement()!)
            let postal = "\(area)\(area)\(Int.random(in: 1...9)) \(Int.random(in: 1...9))\(area)\(area)"
            return AddressComponents(line1: "\(number) \(street) \(streetType)", city: city, state: "", postal: postal)
        default:
            return AddressComponents(line1: "\(number) \(street) \(streetType)", city: "Springfield", state: "", postal: "00000")
        }
    }

    // MARK: - Date of Birth (makes person appear 22-50 years old)

    static func generateDOB() -> String {
        let year  = Calendar.current.component(.year, from: Date()) - Int.random(in: 22...50)
        let month = Int.random(in: 1...12)
        let day   = Int.random(in: 1...28)  // 28 is safe for all months
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    // MARK: - Word Lists

    static let firstNames = [
        "Alex", "Jordan", "Casey", "Morgan", "Riley", "Taylor", "Quinn",
        "Avery", "Dakota", "Reese", "Blake", "Cameron", "Drew", "Finley",
        "Harper", "Jamie", "Kendall", "Logan", "Marcus", "Noel", "Parker",
        "Rowan", "Sage", "Skyler", "Toby", "Emery", "Hadley", "Peyton"
    ]

    static let lastNames = [
        "Anderson", "Bailey", "Brooks", "Chen", "Clark", "Davis", "Evans",
        "Foster", "Garcia", "Harris", "Hughes", "Jackson", "Johnson", "Kim",
        "Lee", "Martin", "Miller", "Moore", "Murphy", "Nelson", "Parker",
        "Patel", "Roberts", "Scott", "Singh", "Smith", "Taylor", "Thomas",
        "Turner", "Walker", "White", "Williams", "Wilson", "Wright", "Young"
    ]

    static let streetNames = [
        "Maple", "Oak", "Cedar", "Pine", "Elm", "Birch", "Willow",
        "Cherry", "Walnut", "Ash", "Spruce", "Aspen", "Magnolia", "Ivy",
        "Rose", "Daisy", "Sunset", "Sunrise", "Hillside", "Lakewood",
        "Riverside", "Meadow", "Valley", "Ridge", "Highland", "Greenwood"
    ]

    static let streetTypes = [
        "Street", "Avenue", "Boulevard", "Drive", "Lane", "Court",
        "Place", "Way", "Road", "Circle", "Trail", "Terrace"
    ]

    // (city, state abbreviation)
    static let usCities: [(String, String)] = [
        ("Portland", "OR"), ("Austin", "TX"), ("Denver", "CO"), ("Nashville", "TN"),
        ("Minneapolis", "MN"), ("Charlotte", "NC"), ("Indianapolis", "IN"),
        ("Columbus", "OH"), ("Salt Lake City", "UT"), ("Raleigh", "NC"),
        ("Richmond", "VA"), ("Louisville", "KY"), ("Hartford", "CT"),
        ("Albany", "NY"), ("Boise", "ID"), ("Tucson", "AZ"), ("Omaha", "NE")
    ]

    static let usStates = [
        "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA",
        "HI","ID","IL","IN","IA","KS","KY","LA","ME","MD"
    ]

    static let ukCities = [
        "Manchester", "Birmingham", "Leeds", "Sheffield", "Liverpool",
        "Bristol", "Edinburgh", "Cardiff", "Belfast", "Newcastle",
        "Nottingham", "Leicester", "Southampton", "Portsmouth", "Brighton"
    ]
}
