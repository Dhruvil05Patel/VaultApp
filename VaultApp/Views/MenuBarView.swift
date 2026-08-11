import SwiftUI

struct MenuBarView: View {

    @EnvironmentObject var vaultManager: VaultManager
    @State private var searchQuery: String = ""
    @State private var masterPassword: String = ""
    @FocusState private var searchFieldFocused: Bool

    private var filteredItems: [VaultItem] {
        guard !searchQuery.isEmpty else {
            // Show 5 most recently updated items when no query
            return Array(
                vaultManager.vault.items
                    .sorted { $0.updatedAt > $1.updatedAt }
                    .prefix(5)
            )
        }
        return vaultManager.vault.search(query: searchQuery)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            if vaultManager.isUnlocked {
                unlockedContent
            } else {
                lockedContent
            }

            Divider()

            // Footer actions
            footer
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if vaultManager.isUnlocked { searchFieldFocused = true }
        }
        .onChange(of: vaultManager.isUnlocked) { _, unlocked in
            searchQuery = ""
            masterPassword = ""
            if unlocked { searchFieldFocused = true }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: vaultManager.isUnlocked ? "lock.open.fill" : "lock.shield.fill")
                .foregroundStyle(vaultManager.isUnlocked ? .green : .secondary)
            Text("VaultApp")
                .font(.headline)
            Spacer()
            // Open main window
            Button {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
                MenuBarManager.shared.closePopover()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open VaultApp window")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Locked Content

    @ViewBuilder
    private var lockedContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
                .padding(.top, 12)

            Text("Vault is locked")
                .font(.callout)
                .foregroundStyle(.secondary)

            SecureField("Master password", text: $masterPassword)
                .textFieldStyle(.roundedBorder)
                .onSubmit { quickUnlock() }
                .padding(.horizontal, 14)

            if let error = vaultManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
            }

            Button("Unlock") { quickUnlock() }
                .buttonStyle(.borderedProminent)
                .disabled(masterPassword.isEmpty || vaultManager.isLoading)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Unlocked Content

    @ViewBuilder
    private var unlockedContent: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.tertiary).font(.callout)
                TextField(
                    searchQuery.isEmpty ? "Search or type to filter…" : "",
                    text: $searchQuery
                )
                .textFieldStyle(.plain)
                .font(.callout)
                .focused($searchFieldFocused)
                if !searchQuery.isEmpty {
                    Button { searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Results list
            if filteredItems.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                    Text(searchQuery.isEmpty ? "No passwords saved yet" : "No results")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Section header when showing recents
                        if searchQuery.isEmpty && !vaultManager.vault.items.isEmpty {
                            HStack {
                                Text("Recent")
                                    .font(.caption2).foregroundStyle(.tertiary)
                                    .textCase(.uppercase).padding(.leading, 14)
                                Spacer()
                            }.padding(.top, 6)
                        }

                        ForEach(filteredItems) { item in
                            MenuBarQuickResultRow(item: item)
                            if item.id != filteredItems.last?.id {
                                Divider().padding(.leading, 46)
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 0) {
            // Lock button
            footerButton(
                label: "Lock",
                icon: "lock.fill",
                color: .secondary
            ) {
                vaultManager.lock()
            }
            .disabled(!vaultManager.isUnlocked)

            Divider().frame(height: 20)

            // Generator
            footerButton(
                label: "Generate",
                icon: "dice.fill",
                color: .blue
            ) {
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: .openGenerator, object: nil)
                MenuBarManager.shared.closePopover()
            }

            Divider().frame(height: 20)

            // Quit
            footerButton(
                label: "Quit",
                icon: "power",
                color: .secondary
            ) {
                vaultManager.lock()
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func footerButton(label: String, icon: String,
                              color: Color,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.callout).foregroundStyle(color)
                Text(label).font(.caption2).foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Unlock

    private func quickUnlock() {
        vaultManager.unlock(masterPassword: masterPassword)
    }
}