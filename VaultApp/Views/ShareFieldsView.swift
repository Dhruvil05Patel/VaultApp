import SwiftUI

struct ShareFieldsView: View {

    let item: VaultItem
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFields: Set<FieldSharingService.ShareableField> = [.username, .password]
    @State private var useEncryption: Bool = true
    @State private var shareBlob: String? = nil
    @State private var shareKey: String? = nil
    @State private var errorMessage: String? = nil

    private var availableFields: [FieldSharingService.ShareableField] {
        FieldSharingService.ShareableField.allCases.filter { !$0.value(from: item).isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Share Fields").font(.headline)
                    Text(item.title).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if shareBlob != nil {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(20)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()

            if let blob = shareBlob {
                resultView(blob: blob, key: shareKey)
            } else {
                Form {
                    fieldSelectionSection
                    encryptionSection
                }
                .formStyle(.grouped)

                Divider()

                VStack(spacing: 12) {
                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                    Button("Generate Share Package") { generateShare() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(selectedFields.isEmpty)
                }
                .padding(20)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .frame(width: 500, height: 600)
    }

    // MARK: - Field Selection

    @ViewBuilder
    private var fieldSelectionSection: some View {
        Section {
            ForEach(availableFields) { field in
                Toggle(isOn: binding(for: field)) {
                    HStack {
                        Image(systemName: field.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(field.rawValue)
                        Spacer()
                        if field.isSensitive {
                            Text("Sensitive")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.red.opacity(0.8))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
                .toggleStyle(.switch)
                .padding(.vertical, 4)
            }
        } header: {
            Text("Select fields to share")
        } footer: {
            Text("Only non-empty fields for this item are shown.")
        }
    }

    private func binding(for field: FieldSharingService.ShareableField) -> Binding<Bool> {
        Binding(
            get: { selectedFields.contains(field) },
            set: { isSelected in
                if isSelected {
                    selectedFields.insert(field)
                } else {
                    selectedFields.remove(field)
                }
            }
        )
    }

    // MARK: - Encryption Toggle

    @ViewBuilder
    private var encryptionSection: some View {
        Section {
            Toggle(isOn: $useEncryption) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Use Encryption (Recommended)")
                        .fontWeight(.medium)
                    
                    if useEncryption {
                        Text("Generates an encrypted blob and a separate one-time decryption key.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Data will be exported in plaintext. Anyone who intercepts the blob can read your fields.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .toggleStyle(.switch)
            .padding(.vertical, 6)
        } header: {
            Text("Security")
        }
    }

    // MARK: - Result View

    @ViewBuilder
    private func resultView(blob: String, key: String?) -> some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(key != nil ? "Encrypted Blob" : "Share Data")
                        .font(.headline)
                    
                    Text(blob)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(4)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                    
                    Button {
                        ClipboardService.copy(blob)
                    } label: {
                        Label("Copy Blob", systemImage: "doc.on.doc")
                    }
                }
                .padding(.vertical, 8)
                
                if let key {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Decryption Key")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        
                        Text(key)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(2)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3)))
                        
                        Button {
                            ClipboardService.copy(key)
                        } label: {
                            Label("Copy Key", systemImage: "doc.on.doc")
                        }
                    }
                    .padding(.vertical, 8)
                }
            } header: {
                Text("Ready to Share")
            } footer: {
                if key != nil {
                    Text("Share the blob via messaging or AirDrop, and send the key through a different channel (e.g. verbally) for maximum security.")
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Logic

    private func generateShare() {
        errorMessage = nil
        do {
            if useEncryption {
                let (blob, key) = try FieldSharingService.createEncryptedShare(
                    from: item, fields: selectedFields)
                withAnimation {
                    shareBlob = blob
                    shareKey  = key
                }
            } else {
                let blob = try FieldSharingService.createPlaintextShare(
                    from: item, fields: selectedFields)
                withAnimation {
                    shareBlob = blob
                    shareKey  = nil
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
