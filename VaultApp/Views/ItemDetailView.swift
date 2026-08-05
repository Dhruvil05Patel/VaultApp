import SwiftUI

struct ItemDetailView: View {

    let item: VaultItem
    @EnvironmentObject var vaultManager: VaultManager

    @State private var showPassword: Bool = false
    @State private var showEditSheet: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var copiedField: String? = nil   // tracks which field was just copied

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
                    if !item.username.isEmpty {
                        fieldRow(
                            label: "Username",
                            value: item.username,
                            icon: "person.fill",
                            copyKey: "username",
                            isSecret: false
                        )
                    }

                    passwordRow

                    if !item.url.isEmpty {
                        fieldRow(
                            label: "Website",
                            value: item.url,
                            icon: "globe",
                            copyKey: "url",
                            isSecret: false,
                            isURL: true
                        )
                    }

                    if !item.notes.isEmpty {
                        notesRow
                    }

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
                Button("Edit") {
                    showEditSheet = true
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("e", modifiers: .command)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddItemView(existingItem: item)   // Task 09 — edit mode
                .environmentObject(vaultManager)
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
            }

            Spacer()
        }
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
                if isURL, let url = URL(string: value.hasPrefix("http") ? value : "https://\(value)") {
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

                copyButton(value: value, key: copyKey)
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
                if showPassword {
                    Text(item.password)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(1)
                } else {
                    Text(String(repeating: "●", count: min(item.password.count, 20)))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
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

                copyButton(value: item.password, key: "password")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
            ClipboardService.copy(value)
            withAnimation { copiedField = key }
            // Reset the checkmark icon after 2s
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { copiedField = nil }
            }
        } label: {
            Image(systemName: copiedField == key ? "checkmark" : "doc.on.doc")
                .foregroundStyle(copiedField == key ? .green : .secondary)
                .frame(width: 20)
        }
        .buttonStyle(.plain)
        .help("Copy to clipboard")
    }

    // MARK: - Helpers

    private var categoryColor: Color {
        switch item.category {
        case .login:      return .blue
        case .creditCard: return .purple
        case .secureNote: return .orange
        case .identity:   return .green
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
