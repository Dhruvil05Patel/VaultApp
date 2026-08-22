import SwiftUI

struct ItemDetailView: View {

    let item: VaultItem
    @EnvironmentObject var vaultManager: VaultManager

    @State private var showPassword: Bool = false
    @State private var showEditSheet: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var copiedField: String? = nil   // tracks which field was just copied
    @State private var isCheckingBreach: Bool = false
    @State private var breachError: String? = nil
    @State private var showPasswordChange: Bool = false
    @State private var showShareFields: Bool = false
    @State private var hideForCapture: Bool = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                headerSection
                    .padding(.bottom, 24)

                Divider()
                    .padding(.bottom, 24)

                // Fields
                VStack(alignment: .leading, spacing: 20) {
                    if item.category == .login {
                        fieldRow(
                            label: "Username",
                            value: item.username,
                            icon: "person.fill",
                            copyKey: "username",
                            isSecret: false
                        )

                        passwordRow

                        Button {
                            showPasswordChange = true
                        } label: {
                            Label("Change Password…", systemImage: "arrow.triangle.2.circlepath")
                                .font(.callout)
                        }
                        .buttonStyle(.bordered)
                        .disabled(item.url.isEmpty)
                        .help(item.url.isEmpty ? "Add a URL to this item to enable guided password change" : "Open the site and change this password")
                        
                        if let age = item.passwordAge {
                            Text("Password changed \(age) day\(age == 1 ? "" : "s") ago")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }

                        if item.hasTOTP {
                            TOTPRowView(secret: item.totpSecret)
                        }

                        breachSection

                        fieldRow(
                            label: "Website",
                            value: item.url,
                            icon: "globe",
                            copyKey: "url",
                            isSecret: false,
                            isURL: true
                        )
                    } else if item.category == .creditCard {
                        if let card = item.cardFields {
                            CardDetailSection(card: card)
                        } else {
                            Text("No card data saved.")
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                    } else if item.category == .secureNote {
                        SecureNoteDetailSection(noteBody: item.secureNoteBody)
                    } else if item.category == .identity {
                        if let identity = item.identityFields {
                            IdentityDetailSection(identity: identity)
                        } else {
                            Text("No identity data saved.")
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                    } else if item.category == .sshKey || item.category == .seedPhrase {
                        if let fields = item.sshKeyFields {
                            SSHKeyDetailSection(fields: fields)
                        } else {
                            Text("No key data saved.")
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                    }

                    if !item.notes.isEmpty {
                        notesRow
                    }

                    Divider().padding(.vertical, 8)

                    AttachmentsView(item: item)
                        .environmentObject(vaultManager)

                    metadataRow
                }

                Spacer(minLength: 32)

                // Delete button at bottom
                deleteSection
            }
            .padding(28)
        }
        .navigationTitle(item.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Button {
                        showShareFields = true
                    } label: {
                        Label("Share Fields…", systemImage: "square.and.arrow.up")
                    }
                    
                    Button("Edit") {
                        showEditSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("e", modifiers: .command)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddItemView(existingItem: item)   // Task 09 — edit mode
                .environmentObject(vaultManager)
        }
        .sheet(isPresented: $showShareFields) {
            ShareFieldsView(item: item)
        }
        .sheet(isPresented: $showPasswordChange) {
            PasswordChangeBrowserView(item: item)
                .environmentObject(vaultManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: .screenCaptureStarted)) { _ in
            withAnimation { hideForCapture = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .screenCaptureStopped)) { _ in
            withAnimation { hideForCapture = false }
        }
        .confirmationDialog(
            "Delete \"\(item.title)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                vaultManager.deleteItem(id: item.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .background {
            Button("") { copyToClipboard(item.password, key: "password") }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .opacity(0)
            
            Button("") { copyToClipboard(item.username, key: "username") }
                .keyboardShortcut("u", modifiers: [.command, .shift])
                .opacity(0)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(categoryColor)
                    .frame(width: 56, height: 56)
                Image(systemName: item.category.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(item.category.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(categoryColor.opacity(0.12))
                    .clipShape(Capsule())

                // Folder badge
                if let folderID = item.folderID,
                   let folder = vaultManager.vault.folder(withID: folderID) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill").foregroundStyle(folder.color)
                        Text(folder.name).font(.caption).foregroundStyle(.secondary)
                    }
                }

                // Tag chips
                if !item.tags.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.orange.opacity(0.10))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.category.rawValue)")
    }

    // MARK: - Standard Field Row

    @ViewBuilder
    private func fieldRow(
        label: String,
        value: String,
        icon: String,
        copyKey: String,
        isSecret: Bool,
        isURL: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)

            HStack {
                if value.isEmpty {
                    Text("Not set")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .italic()
                } else if isURL, let url = URL(string: value.hasPrefix("http") ? value : "https://\(value)") {
                    Link(value, destination: url)
                        .font(.body)
                        .lineLimit(1)
                } else {
                    Text(value)
                        .font(.body)
                        .textSelection(.enabled)
                        .lineLimit(1)
                }

                Spacer()

                if !value.isEmpty {
                    copyButton(value: value, key: copyKey)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Password Row (special: masked + toggle)

    @ViewBuilder
    private var passwordRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Password", systemImage: "key.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)

            HStack {
                Group {
                    if hideForCapture {
                        HStack {
                            Image(systemName: "eye.slash.fill").foregroundStyle(.secondary)
                            Text("Hidden during screen capture")
                                .font(.callout).foregroundStyle(.secondary).italic()
                        }
                    } else if showPassword {
                        SecureDisplayField(text: item.password, isRevealed: true,
                                          font: .monospacedSystemFont(ofSize: 14, weight: .regular))
                            .frame(height: 20)
                    } else {
                        Text(String(repeating: "●", count: min(item.password.count, 20)))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Show/hide toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showPassword.toggle()
                    }
                } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(showPassword ? "Hide password" : "Show password")
                .accessibilityLabel(showPassword ? "Hide password" : "Show password")

                copyButton(value: item.password, key: "password")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Breach Section

    @ViewBuilder
    private var breachSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Show cached result if available
            if item.breachStatus != .unknown {
                BreachBadge(status: item.breachStatus, count: item.breachCount, style: .full)
                if let checkedAt = item.breachCheckedAt {
                    Text("Last checked \(checkedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Error
            if let error = breachError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Check button
            Button {
                checkBreach()
            } label: {
                if isCheckingBreach {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Checking…")
                    }
                } else {
                    Label(
                        item.breachStatus == .unknown ? "Check for Breaches" : "Re-check",
                        systemImage: "shield.lefthalf.filled"
                    )
                }
            }
            .buttonStyle(.bordered)
            .disabled(isCheckingBreach)
            .accessibilityHint("Checks this password against the HaveIBeenPwned database using an anonymous hash")

            Text("Checks against the HaveIBeenPwned database. Only an anonymous partial hash is sent — your password never leaves this device.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Notes Row

    @ViewBuilder
    private var notesRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Notes", systemImage: "note.text")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)

            Text(item.notes)
                .font(.body)
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Metadata Row

    @ViewBuilder
    private var metadataRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
                .padding(.vertical, 8)
            HStack {
                Text("Created: \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
                Spacer()
                Text("Modified: \(item.updatedAt.formatted(date: .abbreviated, time: .shortened))")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Delete Section

    @ViewBuilder
    private var deleteSection: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label("Delete \"\(item.title)\"", systemImage: "trash")
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Copy Button

    @ViewBuilder
    private func copyButton(value: String, key: String) -> some View {
        Button {
            copyToClipboard(value, key: key)
        } label: {
            Image(systemName: copiedField == key ? "checkmark" : "doc.on.doc")
                .foregroundStyle(copiedField == key ? .green : .secondary)
                .frame(width: 20)
        }
        .buttonStyle(.plain)
        .help("Copy to clipboard")
        .accessibilityLabel("Copy \(key)")
    }

    // MARK: - Helpers

    private func copyToClipboard(_ value: String, key: String) {
        ClipboardService.copy(value)
        withAnimation { copiedField = key }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copiedField = nil }
        }
    }

    private func checkBreach() {
        isCheckingBreach = true
        breachError = nil

        Task {
            do {
                let result = try await BreachCheckService.check(password: item.password)

                // Update the item in the vault with the result
                var updated = item
                updated.breachStatus    = result.isBreached ? .breached : .safe
                updated.breachCount     = result.count
                updated.breachCheckedAt = Date()
                vaultManager.updateItem(updated)
            } catch {
                breachError = error.localizedDescription
            }
            isCheckingBreach = false
        }
    }

    private var categoryColor: Color {
        switch item.category {
        case .login:      return .blue
        case .creditCard: return .purple
        case .secureNote: return .orange
        case .identity:   return .green
        case .sshKey:     return .teal
        case .seedPhrase: return .indigo
        }
    }
}

// MARK: - Preview

#Preview {
    ItemDetailView(item: VaultItem(
        title: "GitHub",
        username: "dhruvil@example.com",
        password: "SuperSecret123!",
        url: "https://github.com",
        notes: "Work account — 2FA enabled",
        category: .login
    ))
    .environmentObject(VaultManager())
    .frame(width: 480, height: 600)
}
