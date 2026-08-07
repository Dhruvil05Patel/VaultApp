import SwiftUI

struct ImportPreviewView: View {

    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) private var dismiss

    let source: ImportService.Source
    let items: [VaultItem]

    @State private var selectedIDs: Set<UUID>
    @State private var searchQuery: String = ""
    @State private var isImporting: Bool = false
    @State private var importDone: Bool = false
    @State private var importedCount: Int = 0

    init(source: ImportService.Source, items: [VaultItem]) {
        self.source = source
        self.items = items
        // Start with all items selected
        self._selectedIDs = State(initialValue: Set(items.map { $0.id }))
    }

    private var filteredItems: [VaultItem] {
        if searchQuery.isEmpty { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery) ||
            $0.username.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private var duplicates: Set<UUID> {
        let existingKeys = Set(vaultManager.vault.items.map { "\($0.username.lowercased()):\($0.password)" })
        return Set(items.filter { item in
            existingKeys.contains("\(item.username.lowercased()):\(item.password)")
        }.map { $0.id })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Import from \(source.rawValue)", systemImage: source.icon)
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            if importDone {
                doneScreen
            } else {
                previewContent
            }
        }
        .frame(minWidth: 560, minHeight: 500)
    }

    // MARK: - Preview Content

    @ViewBuilder
    private var previewContent: some View {
        // Stats bar
        HStack(spacing: 16) {
            statChip(label: "Found", count: items.count, color: .blue)
            statChip(label: "Selected", count: selectedIDs.count, color: .green)
            if !duplicates.isEmpty {
                statChip(label: "Duplicates", count: duplicates.count, color: .orange)
            }
            Spacer()
            // Select all / none
            Button(selectedIDs.count == items.count ? "Deselect All" : "Select All") {
                if selectedIDs.count == items.count {
                    selectedIDs.removeAll()
                } else {
                    selectedIDs = Set(items.map { $0.id })
                }
            }
            .buttonStyle(.link)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))

        Divider()

        // Search
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
            TextField("Search…", text: $searchQuery)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))

        Divider()

        // List
        List(filteredItems, id: \.id) { item in
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: selectedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedIDs.contains(item.id) ? Color.blue : Color(nsColor: .tertiaryLabelColor))
                    .font(.title3)
                    .onTapGesture {
                        if selectedIDs.contains(item.id) {
                            selectedIDs.remove(item.id)
                        } else {
                            selectedIDs.insert(item.id)
                        }
                    }

                // Item info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.title.isEmpty ? "(No title)" : item.title)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        if duplicates.contains(item.id) {
                            Text("Duplicate")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                    }
                    Text(item.username.isEmpty ? item.url : item.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Masked password preview
                Text(String(repeating: "●", count: min(item.password.count, 12)))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .listStyle(.plain)

        Divider()

        // Footer
        HStack {
            if !duplicates.isEmpty {
                Image(systemName: "info.circle")
                    .foregroundStyle(.orange)
                Text("\(duplicates.count) entries already exist in your vault")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Import \(selectedIDs.count) Passwords") {
                performImport()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedIDs.isEmpty || isImporting)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Done Screen

    @ViewBuilder
    private var doneScreen: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Import Complete")
                .font(.title2)
                .fontWeight(.semibold)
            Text("\(importedCount) password\(importedCount == 1 ? "" : "s") imported successfully.")
                .foregroundStyle(.secondary)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statChip(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }

    private func performImport() {
        isImporting = true
        let toImport = items.filter { selectedIDs.contains($0.id) }
        for item in toImport {
            vaultManager.addItem(item)
        }
        importedCount = toImport.count
        isImporting = false
        importDone = true
    }
}