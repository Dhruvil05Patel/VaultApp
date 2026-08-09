import SwiftUI

struct VaultListView: View {

    @EnvironmentObject var vaultManager: VaultManager

    // Search and filter state
    @State private var searchQuery: String = ""
    @State private var selectedCategory: VaultItem.Category? = nil
    @State private var selectedItemID: UUID? = nil

    // Sheet presentation state
    @State private var showAddItem: Bool = false
    @State private var showGenerator: Bool = false
    @State private var showBulkBreachCheck: Bool = false
    @State private var showImport: Bool = false

    // MARK: - Filtered Items

    private var filteredItems: [VaultItem] {
        var items = vaultManager.vault.search(query: searchQuery)
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }
        return items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .searchable(text: $searchQuery, prompt: "Search passwords…")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showAddItem) {
            AddItemView()  // Built in Task 09
                .environmentObject(vaultManager)
        }
        .sheet(isPresented: $showGenerator) {
            GeneratorView()  // Built in Task 10
        }
        .sheet(isPresented: $showBulkBreachCheck) {
            BulkBreachCheckView()
                .environmentObject(vaultManager)
        }
        .sheet(isPresented: $showImport) {
            ImportFlowView()
                .environmentObject(vaultManager)
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebarContent: some View {
        List(selection: $selectedItemID) {
            // Category filter buttons
            categoryFilterSection

            // Vault items
            Section {
                if filteredItems.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredItems) { item in
                        VaultItemRow(item: item)
                            .tag(item.id)
                            .contextMenu {
                                Button("Copy Password") {
                                    copyToClipboard(item.password)
                                }
                                Button("Copy Username") {
                                    copyToClipboard(item.username)
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    vaultManager.deleteItem(id: item.id)
                                    if selectedItemID == item.id {
                                        selectedItemID = nil
                                    }
                                }
                            }
                    }
                }
            } header: {
                Text("Passwords (\(filteredItems.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 240)
    }

    // MARK: - Category Filter Section

    @ViewBuilder
    private var categoryFilterSection: some View {
        Section {
            // "All" button
            Label("All Items", systemImage: "square.grid.2x2.fill")
                .foregroundStyle(selectedCategory == nil ? .blue : .primary)
                .onTapGesture { selectedCategory = nil }

            ForEach(VaultItem.Category.allCases, id: \.self) { category in
                Label(category.rawValue, systemImage: category.icon)
                    .foregroundStyle(selectedCategory == category ? .blue : .primary)
                    .onTapGesture {
                        selectedCategory = selectedCategory == category ? category : nil
                    }
            }
        } header: {
            Text("Categories")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Detail Panel

    @ViewBuilder
    private var detailContent: some View {
        if let id = selectedItemID,
           let item = vaultManager.vault.item(withId: id) {
            ItemDetailView(item: item)   // Built in Task 08
                .environmentObject(vaultManager)
                .id(id)  // force re-render when selection changes
        } else {
            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("Select an item to view")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(searchQuery.isEmpty ? "No passwords saved yet" : "No results for \"\(searchQuery)\"")
                .font(.callout)
                .foregroundStyle(.secondary)
            if searchQuery.isEmpty {
                Button("Add your first password") {
                    showAddItem = true
                }
                .buttonStyle(.link)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Left side — lock button
        ToolbarItem(placement: .automatic) {
            Button {
                vaultManager.lock()
            } label: {
                Label("Lock Vault", systemImage: "lock.fill")
            }
            .help("Lock the vault and return to the lock screen")
        }

        // Right side — add + generator
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showImport = true
            } label: {
                Label("Import Passwords", systemImage: "square.and.arrow.down")
            }
            .help("Import passwords from another app or the Keychain")

            Button {
                showBulkBreachCheck = true
            } label: {
                Label("Check All for Breaches", systemImage: "shield.lefthalf.filled")
            }
            .help("Check all passwords against the HaveIBeenPwned database")

            Button {
                showGenerator = true
            } label: {
                Label("Password Generator", systemImage: "dice.fill")
            }
            .help("Open the password generator")

            Button {
                showAddItem = true
            } label: {
                Label("Add Password", systemImage: "plus")
            }
            .help("Add a new password entry")
            .keyboardShortcut("n", modifiers: .command)
        }
    }

    // MARK: - Helpers

    private func copyToClipboard(_ string: String) {
        ClipboardService.copy(string)
    }
}

// MARK: - Vault Item Row

struct VaultItemRow: View {
    let item: VaultItem

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBackground)
                    .frame(width: 36, height: 36)
                Image(systemName: item.category.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }

            // Title and username
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    // Small breach indicator
                    if item.breachStatus == .breached {
                        BreachBadge(status: .breached, count: item.breachCount, style: .compact)
                    }
                }
                Text(item.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var iconBackground: Color {
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
    let manager = VaultManager()
    // Add sample items for preview
    return VaultListView()
        .environmentObject(manager)
        .frame(width: 800, height: 600)
}
