import SwiftUI

struct AddItemView: View {

    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) private var dismiss

    // Optional: if set, we are editing; if nil, we are creating
    var existingItem: VaultItem? = nil

    // MARK: - Form State

    @State private var title: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var url: String = ""
    @State private var notes: String = ""
    @State private var category: VaultItem.Category = .login
    @State private var showPassword: Bool = false
    @State private var showGenerator: Bool = false
    @State private var totpSecret: String = ""
    @State private var totpError: String? = nil
    @State private var cardFields: CardFields = CardFields()
    @State private var identityFields: IdentityFields = IdentityFields()
    @State private var secureNoteBody: String = ""

    // Validation
    private var isFormValid: Bool {
        switch category {
        case .login:
            return !title.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
        case .creditCard:
            return !title.trimmingCharacters(in: .whitespaces).isEmpty && !cardFields.cardNumber.isEmpty
        case .secureNote:
            return !title.trimmingCharacters(in: .whitespaces).isEmpty && !secureNoteBody.isEmpty
        case .identity:
            return !title.trimmingCharacters(in: .whitespaces).isEmpty && !identityFields.firstName.isEmpty
        }
    }

    private var isEditing: Bool {
        existingItem != nil
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            sheetHeader

            Divider()

            // Form content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Category picker
                    categorySection

                    // Category-specific fields
                    categorySpecificForm
                }
                .padding(24)
            }

            Divider()

            // Bottom action buttons
            sheetFooter
        }
        .frame(minWidth: 440, minHeight: 520)
        .onAppear(perform: prefillIfEditing)
        .sheet(isPresented: $showGenerator) {
            GeneratorView { selectedPassword in
                password = selectedPassword
                showPassword = true
            }
        }
    }

    // MARK: - Sheet Header

    @ViewBuilder
    private var sheetHeader: some View {
        HStack {
            Text(isEditing ? "Edit Item" : "Add Item")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Category Section

    @ViewBuilder
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Category", systemImage: "folder")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)

            Picker("Category", selection: $category) {
                ForEach(VaultItem.Category.allCases, id: \.self) { cat in
                    Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Category-Specific Form Router

    @ViewBuilder
    private var categorySpecificForm: some View {
        switch category {
        case .login:
            coreFieldsSection       // existing login fields (title, username, password, TOTP)
            optionalFieldsSection   // existing URL + notes
        case .creditCard:
            titleSection
            CardFormSection(fields: $cardFields)
            optionalFieldsSection   // notes still apply
        case .secureNote:
            titleSection
            secureNoteEditor
        case .identity:
            titleSection
            IdentityFormSection(fields: $identityFields)
        }
    }

    // MARK: - Title Section (non-login categories)

    @ViewBuilder
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            formField(label: "Title", icon: "textformat") {
                TextField("e.g. Chase Sapphire, My Profile", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: - Secure Note Editor

    @ViewBuilder
    private var secureNoteEditor: some View {
        formField(label: "Note", icon: "note.text") {
            TextEditor(text: $secureNoteBody)
                .frame(minHeight: 200)
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1))
        }
    }

    // MARK: - Core Fields (title, username, password)

    @ViewBuilder
    private var coreFieldsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            formField(label: "Title", icon: "textformat") {
                TextField("e.g. GitHub, Netflix, Bank", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            // Username / Email
            formField(label: "Username / Email", icon: "person.fill") {
                TextField("username@example.com", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
            }

            // Password + Generator
            formField(label: "Password", icon: "key.fill") {
                HStack(spacing: 8) {
                    Group {
                        if showPassword {
                            TextField("Password", text: $password)
                        } else {
                            SecureField("Password", text: $password)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                    // Show / hide toggle
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(showPassword ? "Hide password" : "Show password")

                    // Generate button
                    Button {
                        password = PasswordGenerator.generate()
                        showPassword = true   // reveal so user can see what was generated
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Generate a strong password")

                    // Open full generator sheet
                    Button {
                        showGenerator = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Open password generator")
                }

                // Password strength bar
                if !password.isEmpty {
                    strengthBar
                }
            }

            // Two-Factor Secret
            formField(label: "Two-Factor Secret (optional)", icon: "shield.lefthalf.filled") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        TextField("e.g. JBSWY3DPEHPK3PXP", text: $totpSecret)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .autocorrectionDisabled()
                            .onChange(of: totpSecret) { _, newValue in
                                handleTOTPChange(newValue)
                            }

                        // Test live preview
                        if TOTPService.isValidSecret(totpSecret) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else if !totpSecret.isEmpty {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }

                    if let err = totpError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if !totpSecret.isEmpty && TOTPService.isValidSecret(totpSecret) {
                        // Show a live preview code while filling in the form
                        TOTPRowView(secret: totpSecret)
                    }

                    Text("Paste the secret key from your account's 2FA setup page. Usually shown as text or in a QR code.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Password Strength Bar

    @ViewBuilder
    private var strengthBar: some View {
        let strength = PasswordGenerator.strength(of: password)
        HStack(spacing: 6) {
            // 4 segment bar
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(segmentColor(index: index, strength: strength))
                    .frame(height: 4)
            }
            Text(strength.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
        .animation(.easeInOut, value: strength.rawValue)
    }

    private func segmentColor(index: Int, strength: PasswordGenerator.Strength) -> Color {
        let filled: Int
        switch strength {
        case .weak:       filled = 1
        case .fair:       filled = 2
        case .strong:     filled = 3
        case .veryStrong: filled = 4
        }
        guard index < filled else { return Color(.separatorColor) }
        switch strength {
        case .weak:       return .red
        case .fair:       return .orange
        case .strong:     return .yellow
        case .veryStrong: return .green
        }
    }

    // MARK: - Optional Fields (URL, notes)

    @ViewBuilder
    private var optionalFieldsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Website URL
            formField(label: "Website (optional)", icon: "globe") {
                TextField("https://github.com", text: $url)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.URL)
            }

            // Notes
            formField(label: "Notes (optional)", icon: "note.text") {
                TextEditor(text: $notes)
                    .frame(minHeight: 80, maxHeight: 160)
                    .font(.body)
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Sheet Footer

    @ViewBuilder
    private var sheetFooter: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            Button(isEditing ? "Save Changes" : "Add Item") {
                saveItem()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Form Field Layout Helper

    @ViewBuilder
    private func formField<Content: View>(
        label: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
            content()
        }
    }

    // MARK: - Logic

    private func prefillIfEditing() {
        guard let item = existingItem else { return }
        title    = item.title
        username = item.username
        password = item.password
        url      = item.url
        notes    = item.notes
        category = item.category
        totpSecret = item.totpSecret
        cardFields     = item.cardFields ?? CardFields()
        identityFields = item.identityFields ?? IdentityFields()
        secureNoteBody = item.secureNoteBody
    }

    private func saveItem() {
        guard isFormValid else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)

        if let existing = existingItem {
            // Build an updated copy preserving the original id and createdAt
            var updated = existing
            updated.title    = trimmedTitle
            updated.username = username
            updated.password = password
            updated.url      = url
            updated.notes    = notes
            updated.category = category
            updated.totpSecret = totpSecret.trimmingCharacters(in: .whitespaces)
            updated.cardFields     = category == .creditCard ? cardFields : nil
            updated.identityFields = category == .identity   ? identityFields : nil
            updated.secureNoteBody = category == .secureNote ? secureNoteBody : ""
            vaultManager.updateItem(updated)
        } else {
            var newItem = VaultItem(
                title:    trimmedTitle,
                username: username,
                password: password,
                url:      url,
                notes:    notes,
                category: category
            )
            newItem.totpSecret = totpSecret.trimmingCharacters(in: .whitespaces)
            newItem.cardFields     = category == .creditCard ? cardFields : nil
            newItem.identityFields = category == .identity   ? identityFields : nil
            newItem.secureNoteBody = category == .secureNote ? secureNoteBody : ""
            vaultManager.addItem(newItem)
        }

        dismiss()
    }

    // MARK: - TOTP Helpers

    private func handleTOTPChange(_ newValue: String) {
        // Detect otpauth:// URI paste
        if newValue.hasPrefix("otpauth://") {
            if let parsed = TOTPService.parseOTPAuthURI(newValue) {
                totpSecret = parsed.secret
                // Pre-fill title if empty
                if title.isEmpty { title = parsed.label }
                if username.isEmpty { username = parsed.issuer }
            }
        }
        validateTOTP()
    }

    private func validateTOTP() {
        let clean = totpSecret.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else {
            totpError = nil
            return
        }
        totpError = TOTPService.isValidSecret(clean) ? nil : "Invalid secret — must be valid Base32 (A–Z, 2–7)"
    }
}

// MARK: - Preview

#Preview("Add mode") {
    AddItemView()
        .environmentObject(VaultManager())
}

#Preview("Edit mode") {
    AddItemView(existingItem: VaultItem(
        title:    "GitHub",
        username: "dhruvil@example.com",
        password: "SuperSecret123!",
        url:      "https://github.com",
        notes:    "Work account",
        category: .login
    ))
    .environmentObject(VaultManager())
}
