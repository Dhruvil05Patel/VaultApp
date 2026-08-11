import SwiftUI

// Reusable tag input — shows existing tags as chips and lets you add/remove
struct TagInputView: View {

    @Binding var tags: [String]
    let allVaultTags: [String]  // for autocomplete suggestions

    @State private var newTag: String = ""
    @State private var showSuggestions: Bool = false

    private var suggestions: [String] {
        guard !newTag.isEmpty else { return [] }
        let normalised = VaultItem.normaliseTag(newTag)
        return allVaultTags
            .filter { $0.hasPrefix(normalised) && !tags.contains($0) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tag chips
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text("#\(tag)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }.buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }

            // New tag input
            HStack(spacing: 6) {
                Image(systemName: "tag").foregroundStyle(.secondary).font(.caption)
                TextField("Add tag…", text: $newTag)
                    .font(.callout)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onSubmit { addTag() }
                    .onChange(of: newTag) { _, _ in showSuggestions = !suggestions.isEmpty }
                if !newTag.isEmpty {
                    Button { addTag() } label: {
                        Image(systemName: "return").foregroundStyle(.blue)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Autocomplete suggestions
            if showSuggestions {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            tags.append(suggestion)
                            newTag = ""
                            showSuggestions = false
                        } label: {
                            HStack {
                                Image(systemName: "tag").foregroundStyle(.orange)
                                Text("#\(suggestion)")
                                Spacer()
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4)
            }
        }
    }

    private func addTag() {
        let normalised = VaultItem.normaliseTag(newTag)
        guard !normalised.isEmpty, !tags.contains(normalised) else {
            newTag = ""; return
        }
        tags.append(normalised)
        newTag = ""
        showSuggestions = false
    }
}

// MARK: - Tag Rename Sheet

// Small sheet to rename an existing tag across all items
struct TagRenameView: View {

    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) private var dismiss

    let oldTag: String

    @State private var newName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Rename Tag")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Rename \"#\(oldTag)\" to:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("#\(oldTag)", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .onSubmit { save() }
            }
            .padding(24)

            Divider()

            HStack {
                Spacer()
                Button("Rename") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(width: 340)
        .onAppear { newName = oldTag }
    }

    private func save() {
        guard !oldTag.isEmpty else { dismiss(); return }
        vaultManager.renameTag(from: oldTag, to: newName)
        dismiss()
    }
}

// Simple flow layout for tag chips (wraps to next line)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.height }.max() ?? 0 }.reduce(0) { $0 + $1 + spacing }
        return CGSize(width: proposal.width ?? 0, height: max(0, height - spacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.height }.max() ?? 0
            for item in row {
                item.view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private struct RowItem { let view: LayoutSubview; let size: CGSize; var width: CGFloat { size.width }; var height: CGFloat { size.height } }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[RowItem]] {
        var rows: [[RowItem]] = [[]]
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(RowItem(view: view, size: size))
            x += size.width + spacing
        }
        return rows.filter { !$0.isEmpty }
    }
}