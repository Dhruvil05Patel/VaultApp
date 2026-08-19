import SwiftUI

struct VaultListView: View {

    @EnvironmentObject var vaultManager: VaultManager

    // Sidebar filter — drives the filtered items list
    enum SidebarFilter: Equatable {
        case all
        case category(VaultItem.Category)
        case folder(UUID)
        case tag(String)
    }

    // Search and filter state
    @State private var searchQuery: String = ""
    @State private var sidebarFilter: SidebarFilter = .all
    @State private var selectedItemID: UUID? = nil

    // Folder / tag management state
    @State private var showFolderManager: Bool = false
    @State private var folderToEdit: VaultFolder? = nil
    @State private var tagToManage: String? = nil
    @State private var showTagRename: Bool = false

    // Sheet presentation state
    @State private var showAddItem: Bool = false
    @State private var addCategory: VaultItem.Category = .login
    @State private var showGenerator: Bool = false
    @State private var showBulkBreachCheck: Bool = false
    @State private var showImport: Bool = false
    @State private var showExport: Bool = false
    @State private var showDeleteConfirmForID: UUID? = nil

    @FocusState private var searchFocused: Bool
    @FocusState private var listFocused: Bool

    // MARK: - Filtered Items

    private var filteredItems: [VaultItem] {
        var base: [VaultItem]
        switch sidebarFilter {
        case .all:              base = vaultManager.vault.items
        case .category(let c):  base = vaultManager.vault.items.filter { $0.category == c }
        case .folder(let id):   base = vaultManager.vault.items(inFolder: id)
        case .tag(let t):       base = vaultManager.vault.items(withTag: t)
        }
        if !searchQuery.isEmpty {
            base = base.filter {
                $0.title.localizedCaseInsensitiveContains(searchQuery) ||
                $0.username.localizedCaseInsensitiveContains(searchQuery) ||
                $0.url.localizedCaseInsensitiveContains(searchQuery) ||
                $0.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchQuery)
            }
        }
        return base.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private var geoFilteredItems: [VaultItem] {
        let items = filteredItems
        return items.filter { item in
            // If item is in a geofenced folder and we're outside that zone, hide it
            if let folderID = item.folderID,
               let folder = vaultManager.vault.folder(withID: folderID),
               let geofence = folder.geofence {
                return GeofenceService.shared.isInside(geofence)
            }
            return true  // no geofence = always visible
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .searchable(text: $searchQuery, prompt: "Search passwords…")
        .onChange(of: vaultManager.isUnlocked) { _, isUnlocked in
            if isUnlocked {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    searchFocused = true
                }
            }
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: $showAddItem) {
            AddItemView(initialCategory: addCategory)  // Built in Task 09
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
        .sheet(isPresented: $showExport) {
            ExportView()
                .environmentObject(vaultManager)
        }
        .sheet(isPresented: $showFolderManager) {
            FolderManageView(folder: folderToEdit)
                .environmentObject(vaultManager)
                .id(folderToEdit?.id)
        }
        .sheet(isPresented: $showTagRename) {
            if let tag = tagToManage {
                TagRenameView(oldTag: tag)
                    .environmentObject(vaultManager)
            }
        }
        .onKeyPress(.delete) {
            guard let id = selectedItemID else { return .ignored }
            showDeleteConfirmForID = id
            return .handled
        }
        .confirmationDialog(
            "Delete this item?",
            isPresented: Binding(get: { showDeleteConfirmForID != nil },
                                 set: { if !$0 { showDeleteConfirmForID = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = showDeleteConfirmForID {
                    vaultManager.deleteItem(id: id)
                    selectedItemID = nil
                    listFocused = true
                }
            }
            Button("Cancel", role: .cancel) { showDeleteConfirmForID = nil }
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebarContent: some View {
        List(selection: $selectedItemID) {
            // ── Section 1: All Items + Categories ──
            Section("Library") {
                sidebarRow(label: "All Items", icon: "tray.full.fill",
                           isSelected: sidebarFilter == .all) {
                    sidebarFilter = .all
                }
                ForEach(VaultItem.Category.allCases, id: \.self) { cat in
                    sidebarRow(label: cat.rawValue, icon: cat.icon,
                               count: vaultManager.vault.items.filter { $0.category == cat }.count,
                               isSelected: sidebarFilter == .category(cat)) {
                        sidebarFilter = .category(cat)
                    }
                }
            }

            // ── Section 2: Folders ──
            Section {
                ForEach(vaultManager.vault.folders.sorted(by: { $0.name < $1.name })) { folder in
                    sidebarRow(
                        label: folder.name,
                        icon: "folder.fill",
                        iconColor: folder.color,
                        count: vaultManager.vault.items(inFolder: folder.id).count,
                        isSelected: sidebarFilter == .folder(folder.id),
                        folder: folder
                    ) {
                        sidebarFilter = .folder(folder.id)
                    }
                    .contextMenu {
                        Button("Edit Folder…") { 
                            folderToEdit = folder
                            DispatchQueue.main.async { showFolderManager = true }
                        }
                        Button("Delete", role: .destructive) {
                            vaultManager.deleteFolder(id: folder.id)
                            if sidebarFilter == .folder(folder.id) { sidebarFilter = .all }
                        }
                    }
                }
                Button {
                    folderToEdit = nil
                    DispatchQueue.main.async { showFolderManager = true }
                } label: {
                    Label("New Folder…", systemImage: "folder.badge.plus")
                        .foregroundStyle(.blue)
                }.buttonStyle(.plain)
            } header: {
                Text("Folders")
            }

            // ── Section 3: Tags ──
            Section {
                ForEach(vaultManager.vault.allTags, id: \.self) { tag in
                    sidebarRow(
                        label: "#\(tag)",
                        icon: "tag.fill",
                        iconColor: .orange,
                        count: vaultManager.vault.items(withTag: tag).count,
                        isSelected: sidebarFilter == .tag(tag)
                    ) {
                        sidebarFilter = .tag(tag)
                    }
                    .contextMenu {
                        Button("Rename Tag…") { tagToManage = tag; showTagRename = true }
                        Button("Delete Tag", role: .destructive) {
                            vaultManager.deleteTag(tag)
                            if sidebarFilter == .tag(tag) { sidebarFilter = .all }
                        }
                    }
                }
            } header: {
                Text("Tags")
            }

            // Vault items
            Section {
                if geoFilteredItems.isEmpty {
                    emptyState
                } else {
                    ForEach(geoFilteredItems) { item in
                        VaultItemRow(item: item)
                            .tag(item.id)
                            .contextMenu {
                                switch item.category {
                                case .login:
                                    Button("Copy Password") {
                                        copyToClipboard(item.password)
                                    }
                                    Button("Copy Username") {
                                        copyToClipboard(item.username)
                                    }
                                case .creditCard:
                                    if let card = item.cardFields {
                                        Button("Copy Card Number") {
                                            copyToClipboard(card.cardNumber)
                                        }
                                        Button("Copy CVV") {
                                            copyToClipboard(card.cvv)
                                        }
                                    }
                                case .identity:
                                    if let identity = item.identityFields, !identity.fullName.isEmpty {
                                        Button("Copy Full Name") {
                                            copyToClipboard(identity.fullName)
                                        }
                                    }
                                case .secureNote:
                                    if !item.secureNoteBody.isEmpty {
                                        Button("Copy Note") {
                                            copyToClipboard(item.secureNoteBody)
                                        }
                                    }
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
                Text("Items (\(geoFilteredItems.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 240)
        .focused($listFocused)
    }

    // MARK: - Sidebar Row

    @ViewBuilder
    private func sidebarRow(label: String, icon: String,
                            iconColor: Color = .accentColor,
                            count: Int? = nil,
                            isSelected: Bool,
                            folder: VaultFolder? = nil,
                            action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(iconColor).frame(width: 20)
            Text(label).lineLimit(1)
            
            if let folder = folder, let geofence = folder.geofence {
                let inside = GeofenceService.shared.isInside(geofence)
                Image(systemName: inside ? "location.fill" : "location.slash.fill")
                    .font(.caption2)
                    .foregroundStyle(inside ? .green : .red)
            }
            
            Spacer()
            if let count { Text("\(count)").foregroundStyle(.tertiary).font(.caption) }
        }
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture { action() }
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
        switch sidebarFilter {

        case .all where vaultManager.vault.items.isEmpty:
            // First time — no passwords at all
            EmptyStateView(
                icon: "lock.open.fill",
                iconColor: .blue,
                title: "Your vault is empty",
                message: "Add your first password to get started. VaultApp will keep it safe.",
                actionLabel: "Add Password",
                action: { 
                    addCategory = .login
                    showAddItem = true 
                }
            )

        case .all:
            // Search returned nothing
            EmptyStateView(
                icon: "magnifyingglass",
                iconColor: .secondary,
                title: "No results for \"\(searchQuery)\"",
                message: "Try a different search term, or check a specific category.",
                actionLabel: nil,
                action: nil
            )

        case .category(let cat) where geoFilteredItems.isEmpty && searchQuery.isEmpty:
            // Category has no items
            EmptyStateView(
                icon: cat.icon,
                iconColor: .blue,
                title: "No \(cat.rawValue) items",
                message: "You haven't added any \(cat.rawValue.lowercased()) entries yet.",
                actionLabel: "Add \(cat.rawValue)",
                action: { 
                    addCategory = cat
                    showAddItem = true 
                }
            )

        case .folder(let id) where geoFilteredItems.isEmpty && searchQuery.isEmpty:
            let folderName = vaultManager.vault.folder(withID: id)?.name ?? "this folder"
            EmptyStateView(
                icon: "folder",
                iconColor: .blue,
                title: "\(folderName) is empty",
                message: "Move items here from the All Items view, or add a new password directly to this folder.",
                actionLabel: "Add Password",
                action: { 
                    addCategory = .login
                    showAddItem = true 
                }
            )

        case .tag(let tag) where geoFilteredItems.isEmpty && searchQuery.isEmpty:
            EmptyStateView(
                icon: "tag",
                iconColor: .orange,
                title: "No items tagged \"\(tag)\"",
                message: "Assign this tag to items from their edit form.",
                actionLabel: nil,
                action: nil
            )

        default:
            // Generic search-within-filter empty
            EmptyStateView(
                icon: "magnifyingglass",
                iconColor: .secondary,
                title: "No results for \"\(searchQuery)\"",
                message: "Try a broader search term.",
                actionLabel: nil,
                action: nil
            )
        }
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
            .accessibilityHint("Returns to the password entry screen")
        }

        // Right side — add + generator
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showExport = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export or backup vault")

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
            .accessibilityHint("Checks all passwords against the HaveIBeenPwned database using an anonymous hash")

            Button {
                showGenerator = true
            } label: {
                Label("Password Generator", systemImage: "dice.fill")
            }
            .help("Open the password generator")

            Button {
                addCategory = .login
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
                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.category.rawValue), \(item.username)")
        .accessibilityHint("Double-tap to view details")
    }

    private var subtitleText: String {
        switch item.category {
        case .login:
            return item.username.isEmpty ? item.url : item.username
        case .creditCard:
            return item.cardFields?.maskedNumber ?? ""
        case .secureNote:
            return item.secureNoteBody.isEmpty ? "Secure note" : item.secureNoteBody
        case .identity:
            return item.identityFields?.fullName ?? ""
        }
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
