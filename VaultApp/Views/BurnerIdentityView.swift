import SwiftUI

struct BurnerIdentityView: View {

    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    @State private var identity: BurnerIdentityGenerator.BurnerIdentity
    @State private var phoneCountry: BurnerIdentityGenerator.PhoneCountry = .us
    @State private var itemTitle: String = ""
    @State private var saved: Bool = false

    init() {
        let generated = BurnerIdentityGenerator.generate()
        self._identity = State(initialValue: generated)
        self._itemTitle = State(initialValue: "Burner — \(generated.fullName)")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Burner Identity Generator")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding(.horizontal, 24).padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if saved {
                        doneView
                    } else {
                        controlsSection
                        previewSection
                        saveSection
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 480, minHeight: 560)
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Phone country:")
                    .font(.callout)
                Picker("", selection: $phoneCountry) {
                    ForEach(BurnerIdentityGenerator.PhoneCountry.allCases) { c in
                        Text(c.rawValue).tag(c)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)
                Spacer()
                Button {
                    identity = BurnerIdentityGenerator.generate(
                        emailDomain: settings.aliasEmailDomain,
                        phoneCountry: phoneCountry
                    )
                    itemTitle = "Burner — \(identity.fullName)"
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Email alias domain (optional):")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                TextField("e.g. yourdomain.com or leave blank", text: $settings.aliasEmailDomain)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: settings.aliasEmailDomain) { _, newDomain in
                        identity.email = BurnerIdentityGenerator.generateEmail(
                            firstName: identity.firstName,
                            lastName: identity.lastName,
                            domain: newDomain
                        )
                    }
                Text("If set, emails are generated as firstname.123@yourdomain.com — you forward this to your real inbox.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Generated Identity")
                .font(.callout).fontWeight(.semibold)
                .padding(.bottom, 10)

            identityRow("Name",        identity.fullName,       "person.fill",       sensitive: false)
            identityRow("Email",       identity.email,          "envelope.fill",     sensitive: false)
            identityRow("Phone",       identity.phone,          "phone.fill",        sensitive: false)
            identityRow("Address",     "\(identity.addressLine1), \(identity.city), \(identity.state) \(identity.postalCode)", "house.fill", sensitive: false)
            identityRow("Country",     identity.country,        "globe",             sensitive: false)
            identityRow("Date of Birth", identity.dateOfBirth,  "calendar",         sensitive: false)
            identityRow("Password",    identity.password,       "key.fill",          sensitive: true)
        }
    }

    @ViewBuilder
    private func identityRow(_ label: String, _ value: String, _ icon: String, sensitive: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption2).foregroundStyle(.tertiary)
                if sensitive {
                    Text(String(repeating: "•", count: 16))
                        .font(.callout)
                } else {
                    Text(value)
                        .font(.callout)
                        .textSelection(.enabled)
                }
            }
            Spacer()
            Button {
                ClipboardService.copy(value)
            } label: {
                Image(systemName: "doc.on.doc").foregroundStyle(.secondary).font(.caption)
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        Divider()
    }

    // MARK: - Save Section

    @ViewBuilder
    private var saveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Save as vault item:").font(.caption).foregroundStyle(.secondary)
                TextField("Title", text: $itemTitle)
                    .textFieldStyle(.roundedBorder)
            }
            Button("Save to Vault") {
                saveToVault()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(itemTitle.isEmpty)
        }
    }

    // MARK: - Done

    @ViewBuilder
    private var doneView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.badge.shield.checkmark.fill")
                .font(.system(size: 52)).foregroundStyle(.green)
            Text("Burner Identity Saved").font(.title2).fontWeight(.semibold)
            Text("Find it in your vault under Identity items.")
                .font(.callout).foregroundStyle(.secondary)
            Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Save Logic

    private func saveToVault() {
        var item = VaultItem(
            title:    itemTitle,
            username: identity.email,
            password: identity.password,
            category: .identity
        )
        var fields = IdentityFields()
        fields.firstName  = identity.firstName
        fields.lastName   = identity.lastName
        fields.email      = identity.email
        fields.phone      = identity.phone
        fields.address1   = identity.addressLine1
        fields.city       = identity.city
        fields.state      = identity.state
        fields.postalCode = identity.postalCode
        fields.country    = identity.country
        fields.dateOfBirth = identity.dateOfBirth
        item.identityFields = fields
        item.notes = "⚠️ This is a burner identity. Do not use for financial or legal purposes."
        vaultManager.addItem(item)
        saved = true
    }
}
