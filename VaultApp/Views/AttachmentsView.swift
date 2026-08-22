import SwiftUI
import UniformTypeIdentifiers

struct AttachmentsView: View {

    let item: VaultItem
    @EnvironmentObject var vaultManager: VaultManager
    @State private var showFilePicker: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack {
                Label("Attachments (\(item.attachments.count))", systemImage: "paperclip")
                    .font(.caption).foregroundStyle(.secondary).fontWeight(.medium)
                Spacer()
                Button {
                    showFilePicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }.buttonStyle(.plain).help("Add attachment")
            }

            // Attachment list
            if item.attachments.isEmpty {
                Text("No attachments")
                    .font(.caption).foregroundStyle(.tertiary).italic()
                    .padding(.vertical, 4)
            } else {
                ForEach(item.attachments) { attachment in
                    AttachmentRow(
                        attachment: attachment,
                        onOpen:   { openAttachment(attachment) },
                        onDelete: { deleteAttachment(attachment) }
                    )
                }
            }

            // Error
            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(error).font(.caption).foregroundStyle(.secondary)
                }
            }

            // Loading indicator
            if isLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Processing attachment…").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.data, .image, .pdf, .plainText, .folder],
            allowsMultipleSelection: false
        ) { result in
            handleFilePick(result: result)
        }
    }

    // MARK: - Add

    private func handleFilePick(result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        isLoading = true
        errorMessage = nil

        Task {
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                guard let key = vaultManager.symmetricKey else {
                    await MainActor.run { errorMessage = "Vault must be unlocked to add attachments." }
                    return
                }
                let attachment = try AttachmentService.save(
                    data: data,
                    filename: url.lastPathComponent,
                    key: key
                )
                await MainActor.run {
                    var updated = item
                    updated.attachments.append(attachment)
                    vaultManager.updateItem(updated)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Open

    private func openAttachment(_ attachment: VaultAttachment) {
        guard let key = vaultManager.symmetricKey else {
            errorMessage = "Vault must be unlocked to open attachments."
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let data = try AttachmentService.load(attachment: attachment, key: key)
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(attachment.filename)
                try data.write(to: tempURL)
                await MainActor.run {
                    NSWorkspace.shared.open(tempURL)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Delete

    private func deleteAttachment(_ attachment: VaultAttachment) {
        AttachmentService.delete(attachment: attachment)
        var updated = item
        updated.attachments.removeAll { $0.id == attachment.id }
        vaultManager.updateItem(updated)
    }
}

// MARK: - Attachment Row

struct AttachmentRow: View {

    let attachment: VaultAttachment
    let onOpen: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 10) {
            // File icon
            Image(systemName: attachment.sfSymbolIcon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            // Name + size
            VStack(alignment: .leading, spacing: 1) {
                Text(attachment.filename)
                    .font(.callout).lineLimit(1)
                HStack(spacing: 6) {
                    Text(attachment.displaySize)
                        .font(.caption2).foregroundStyle(.tertiary)
                    Text("·")
                        .font(.caption2).foregroundStyle(.tertiary)
                    Text(attachment.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Open button
            Button(action: onOpen) {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open \(attachment.filename)")

            // Delete button
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Delete attachment")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .confirmationDialog(
            "Delete \"\(attachment.filename)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the file from your vault. This action cannot be undone.")
        }
    }
}
