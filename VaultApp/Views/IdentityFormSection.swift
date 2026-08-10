import SwiftUI

struct IdentityFormSection: View {
    @Binding var fields: IdentityFields

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            group("Personal") {
                row("Prefix",        "Mr / Ms / Dr",     $fields.prefix)
                row("First Name",    "First",             $fields.firstName)
                row("Middle Name",   "Middle (optional)", $fields.middleName)
                row("Last Name",     "Last",              $fields.lastName)
                row("Date of Birth", "YYYY-MM-DD",        $fields.dateOfBirth)
                row("Nationality",   "e.g. Indian",       $fields.nationality)
                row("Gender",        "optional",          $fields.gender)
            }
            group("Contact") {
                row("Email",       "email@example.com",   $fields.email)
                row("Phone",       "+1 555 000 0000",     $fields.phone)
                row("Work Phone",  "optional",            $fields.phoneWork)
                row("Company",     "optional",            $fields.company)
                row("Job Title",   "optional",            $fields.jobTitle)
                row("Website",     "https://",            $fields.website)
            }
            group("Address") {
                row("Address Line 1", "Street",           $fields.address1)
                row("Address Line 2", "Apt / Suite",      $fields.address2)
                row("City",           "City",              $fields.city)
                row("State / Region", "State",            $fields.state)
                row("Postal Code",    "ZIP / Postcode",   $fields.postalCode)
                row("Country",        "Country",          $fields.country)
            }
            group("Documents") {
                row("Passport Number", "optional",        $fields.passportNumber)
                row("Passport Expiry", "YYYY-MM-DD",      $fields.passportExpiry)
                row("Driver License",  "optional",        $fields.driverLicense)
                row("License Expiry",  "YYYY-MM-DD",      $fields.licenseExpiry)
                row("National ID",     "optional",        $fields.nationalID)
                row("Tax ID / SSN",    "optional",        $fields.taxID)
            }
        }
    }

    @ViewBuilder
    private func group<Content: View>(_ header: String,
                                       @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(header).font(.caption).foregroundStyle(.secondary)
                .fontWeight(.semibold).textCase(.uppercase)
            content()
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ placeholder: String,
                     _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: binding).textFieldStyle(.roundedBorder)
        }
    }
}