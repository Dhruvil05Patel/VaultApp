import SwiftUI

struct ShareReceiveView: View {

    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) private var dismiss

    @State private var blob: String = ""
    @State private var key: String = ""
    @State private var isEncrypted: Bool = true
    @State private var preview: FieldSharingService.SharePayload? = nil
    @State private var errorMessage: String? = nil
    @State private var importDone: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Receive Share").font(.headline)
                    if let preview {
                        Text(preview.title).font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        Text("Import shared fields").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()

            if importDone {
                doneView
            } else if let preview {
                previewView(preview)
            } else {
                inputSection
            }
        }
        .frame(width: 500, height: 560)
    }

    // MARK: - Input

    @ViewBuilder
    private var inputSection: some View {
        Form {
            Section {
                Toggle(isOn: $isEncrypted) {
                    Text("This share is encrypted").fontWeight(.medium)
                }
                .toggleStyle(.switch)
                .padding(.vertical, 4)
            } header: {
                Text("Security")
            }

            Section {
                TextEditor(text: $blob)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 100)
            } header: {
                Text(isEncrypted ? "Encrypted Blob" : "Share Data")
            }

            if isEncrypted {
                Section {
                    SecureField("", text: $key, prompt: Text("Paste the one-time decryption key here"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.vertical, 4)
                } header: {
                    Text("Decryption Key")
                } footer: {
                    Text("Required to decrypt the secure blob.")
                }
            }
        }
        .formStyle(.grouped)

        Divider()

        VStack(spacing: 12) {
            if let error = errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            Button("Decrypt & Preview") { decodeShare() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(blob.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(20)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Preview

    @ViewBuilder
    private func previewView(_ payload: FieldSharingService.SharePayload) -> some View {
        Form {
            Section {
                ForEach(payload.fields) { field in
                    LabeledContent {
                        if field.isSensitive {
                            Text(String(repeating: "•", count: max(6, min(field.value.count, 16))))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(field.value)
                                .font(.callout)
                                .textSelection(.enabled)
                        }
                    } label: {
                        Text(field.label)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Fields to Import")
            } footer: {
                Text("Sensitive fields are masked for security but will be imported intact.")
            }
        }
        .formStyle(.grouped)

        Divider()

        HStack {
            Button("Back") { withAnimation { preview = nil } }
                .controlSize(.large)
            Spacer()
            Button("Add to Vault") { importShare(payload) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(20)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Done

    @ViewBuilder
    private var doneView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64)).foregroundStyle(.green)
            Text("Import Successful")
                .font(.title2).fontWeight(.semibold)
            Text("The fields were successfully added to your vault.")
                .foregroundStyle(.secondary)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 12)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Logic

    private func decodeShare() {
        errorMessage = nil
        do {
            let trimmedBlob = blob.trimmingCharacters(in: .whitespacesAndNewlines)
            if isEncrypted {
                let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                let decoded = try FieldSharingService.decodeEncryptedShare(
                    blob: trimmedBlob, key: trimmedKey)
                withAnimation { preview = decoded }
            } else {
                let decoded = try FieldSharingService.decodePlaintextShare(trimmedBlob)
                withAnimation { preview = decoded }
            }
        } catch {
            withAnimation { errorMessage = error.localizedDescription }
        }
    }

    private func importShare(_ payload: FieldSharingService.SharePayload) {
        let item = FieldSharingService.toVaultItem(payload)
        vaultManager.addItem(item)
        withAnimation { importDone = true }
    }
}
