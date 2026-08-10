import SwiftUI

struct IdentityDetailSection: View {

    let identity: IdentityFields
    @State private var copiedKey: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            fieldGroup(header: "Personal") {
                row("Full Name",    identity.fullName,        "person.fill",   "fullName")
                row("Date of Birth", identity.dateOfBirth,   "calendar",      "dob")
                row("Nationality",  identity.nationality,     "globe",         "nationality")
                row("Gender",       identity.gender,          "person.2.fill", "gender")
            }
            fieldGroup(header: "Contact") {
                row("Email",        identity.email,           "envelope.fill", "email")
                row("Phone",        identity.phone,           "phone.fill",    "phone")
                row("Work Phone",   identity.phoneWork,       "phone.badge.waveform.fill", "phoneWork")
                row("Company",      identity.company,         "building.2.fill", "company")
                row("Job Title",    identity.jobTitle,        "briefcase.fill","jobTitle")
                row("Website",      identity.website,         "globe",         "website")
            }
            fieldGroup(header: "Address") {
                if !identity.fullAddress.isEmpty {
                    row("Address", identity.fullAddress, "house.fill", "address")
                }
            }
            fieldGroup(header: "Documents") {
                row("Passport",        identity.passportNumber, "doc.fill",      "passport")
                row("Passport Expiry", identity.passportExpiry, "calendar.badge.clock", "passportExp")
                row("Driver License",  identity.driverLicense,  "car.fill",      "license")
                row("License Expiry",  identity.licenseExpiry,  "calendar.badge.clock", "licenseExp")
                row("National ID",     identity.nationalID,     "creditcard.fill","nationalID")
                row("Tax / SSN",       identity.taxID,          "dollarsign.circle.fill", "taxID")
            }
        }
    }

    @ViewBuilder
    private func fieldGroup<Content: View>(header: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(header)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .padding(.bottom, 2)
            content()
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String, _ icon: String, _ key: String) -> some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Label(label, systemImage: icon)
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text(value).font(.body).textSelection(.enabled)
                    Spacer()
                    Button {
                        ClipboardService.copy(value)
                        withAnimation { copiedKey = key }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copiedKey = nil }
                        }
                    } label: {
                        Image(systemName: copiedKey == key ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(copiedKey == key ? .green : .secondary)
                    }.buttonStyle(.plain)
                }
                .padding(10).background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}