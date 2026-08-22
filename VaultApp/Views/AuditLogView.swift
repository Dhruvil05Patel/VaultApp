import SwiftUI

struct AuditLogView: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    @State private var filterMode: FilterMode = .all
    @State private var searchQuery: String = ""
    @State private var showClearConfirm: Bool = false

    enum FilterMode: String, CaseIterable, Identifiable {
        case all            = "All Events"
        case security       = "Security"
        case items          = "Item Changes"
        var id: String { rawValue }
    }

    private var displayedEntries: [AuditLogService.LogEntry] {
        var base: [AuditLogService.LogEntry]
        switch filterMode {
        case .all:
            base = AuditLogService.shared.allEntries()
        case .security:
            base = AuditLogService.shared.securityEvents()
        case .items:
            base = AuditLogService.shared.allEntries().filter {
                [.itemAdded, .itemEdited, .itemDeleted,
                 .attachmentAdded, .attachmentDeleted].contains($0.eventType)
            }
        }

        if !searchQuery.isEmpty {
            base = base.filter {
                $0.eventType.rawValue.localizedCaseInsensitiveContains(searchQuery) ||
                ($0.itemTitle?.localizedCaseInsensitiveContains(searchQuery) ?? false) ||
                ($0.detail?.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }

        return base
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Activity Log")
                    .font(.headline)
                Spacer()
                Text("\(AuditLogService.shared.entryCount) events")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Done") { dismiss() }
            }
            .padding(.horizontal, 24).padding(.vertical, 16)

            Divider()

            // Filter + Search
            VStack(spacing: 10) {
                Picker("Filter", selection: $filterMode) {
                    ForEach(FilterMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                    TextField("Search events…", text: $searchQuery)
                        .textFieldStyle(.plain)
                    if !searchQuery.isEmpty {
                        Button { searchQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)

            Divider()

            // Log entries
            if displayedEntries.isEmpty {
                emptyState
            } else {
                List(displayedEntries) { entry in
                    LogEntryRow(entry: entry)
                }
                .listStyle(.plain)
            }

            Divider()

            // Footer
            HStack(spacing: 12) {
                Button {
                    let text = AuditLogService.shared.exportPlaintext()
                    ClipboardService.copy(text)
                } label: {
                    Label("Copy Log", systemImage: "doc.on.doc")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .help("Copy the full activity log as plain text")

                Spacer()

                Button("Clear Log…", role: .destructive) {
                    showClearConfirm = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .font(.callout)
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
        }
        .frame(minWidth: 560, minHeight: 560)
        .confirmationDialog(
            "Clear Activity Log?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear All Events", role: .destructive) {
                AuditLogService.shared.clearLog()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All \(AuditLogService.shared.entryCount) activity log entries will be permanently deleted.")
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40)).foregroundStyle(.tertiary)
            Text(searchQuery.isEmpty ? "No events recorded yet" : "No events match \"\(searchQuery)\"")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {

    let entry: AuditLogService.LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Event icon
            Image(systemName: entry.eventType.sfSymbol)
                .foregroundStyle(iconColor)
                .frame(width: 22, height: 22)
                .padding(.top, 1)

            // Content
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.eventType.rawValue)
                        .font(.callout).fontWeight(.medium)

                    if let title = entry.itemTitle {
                        Text("· \(title)")
                            .font(.callout).foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let field = entry.fieldLabel {
                        Text("(\(field))")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                }

                HStack(spacing: 8) {
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2).foregroundStyle(.tertiary)

                    if entry.deviceName != Host.current().localizedName {
                        Label(entry.deviceName, systemImage: "laptopcomputer")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }

                if let detail = entry.detail {
                    Text(detail)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Security badge
            if entry.eventType.isSecurityEvent {
                Image(systemName: "shield.fill")
                    .font(.caption2).foregroundStyle(.orange.opacity(0.7))
            }
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        switch entry.eventType {
        case .unlockFailed:                 return .red
        case .vaultExported, .vaultImported: return .orange
        case .itemDeleted, .attachmentDeleted: return .red.opacity(0.7)
        case .vaultUnlocked, .biometricUnlock: return .green
        case .itemAdded, .vaultCreated:     return .blue
        case .itemViewed, .fieldCopied:     return .secondary
        default:                            return .secondary
        }
    }
}
