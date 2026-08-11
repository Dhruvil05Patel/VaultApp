import SwiftUI

struct MenuBarQuickResultRow: View {

    let item: VaultItem

    @State private var copiedField: String? = nil
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row — click to expand
            HStack(spacing: 10) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(iconColor)
                        .frame(width: 28, height: 28)
                    Image(systemName: item.category.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }

                // Title + username
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.callout).fontWeight(.medium).lineLimit(1)
                    Text(item.username.isEmpty ? item.url : item.username)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }

                Spacer()

                // Quick copy password
                quickCopyButton(value: item.password, key: "password",
                                icon: "key.fill", help: "Copy password")

                // Expand for more actions
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }

            // Expanded actions
            if isExpanded {
                HStack(spacing: 8) {
                    actionButton("Copy Password", icon: "key.fill") {
                        ClipboardService.copy(item.password)
                        copiedField = "password"
                        autoClearCopied()
                    }
                    actionButton("Copy Username", icon: "person.fill") {
                        ClipboardService.copy(item.username)
                        copiedField = "username"
                        autoClearCopied()
                    }
                    if !item.url.isEmpty {
                        actionButton("Open URL", icon: "safari") {
                            if let url = URL(string: item.url.hasPrefix("http") ? item.url : "https://\(item.url)") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isExpanded ? Color.accentColor.opacity(0.05) : Color.clear)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func quickCopyButton(value: String, key: String,
                                 icon: String, help: String) -> some View {
        Button {
            ClipboardService.copy(value)
            withAnimation { copiedField = key }
            autoClearCopied()
        } label: {
            Image(systemName: copiedField == key ? "checkmark" : icon)
                .padding(4)
                .foregroundStyle(copiedField == key ? .green : .secondary)
                .font(.callout)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private func actionButton(_ label: String, icon: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func autoClearCopied() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copiedField = nil }
        }
    }

    private var iconColor: Color {
        switch item.category {
        case .login:      return .blue
        case .creditCard: return .purple
        case .secureNote: return .orange
        case .identity:   return .green
        }
    }
}