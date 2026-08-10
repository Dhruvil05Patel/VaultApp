import Foundation

// Structured fields for an identity / personal information entry.
struct IdentityFields: Codable, Hashable {

    // Name
    var firstName: String  = ""
    var lastName: String   = ""
    var middleName: String = ""
    var prefix: String     = ""   // Mr, Ms, Dr, etc.

    // Contact
    var email: String      = ""
    var phone: String      = ""
    var phoneWork: String  = ""

    // Address
    var address1: String   = ""
    var address2: String   = ""
    var city: String       = ""
    var state: String      = ""
    var postalCode: String = ""
    var country: String    = ""

    // Documents
    var passportNumber: String    = ""
    var passportExpiry: String    = ""   // "YYYY-MM-DD"
    var driverLicense: String     = ""
    var licenseExpiry: String     = ""
    var nationalID: String        = ""
    var taxID: String             = ""   // SSN, NI, TFN, etc.

    // Personal
    var dateOfBirth: String       = ""   // "YYYY-MM-DD"
    var nationality: String       = ""
    var gender: String            = ""
    var company: String           = ""
    var jobTitle: String          = ""
    var website: String           = ""

    // MARK: - Helpers

    var fullName: String {
        [prefix, firstName, middleName, lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var fullAddress: String {
        [address1, address2, city, state, postalCode, country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}