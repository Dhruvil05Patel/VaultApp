import SwiftUI

struct FolderManageView: View {

    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) private var dismiss

    var folder: VaultFolder? // nil = create new

    @State private var name: String = ""
    @State private var colorHex: String = "#4A90D9"
    @State private var showGeofenceSetup: Bool = false

    private let presetColors: [String] = [
        "#4A90D9", "#E74C3C", "#2ECC71", "#F39C12",
        "#9B59B6", "#1ABC9C", "#E67E22", "#34495E"
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(folder == nil ? "New Folder" : "Edit Folder")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
            Divider()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name").font(.caption).foregroundStyle(.secondary)
                    TextField("e.g. Work, Finance, Personal", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Color").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        ForEach(presetColors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .blue)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle().stroke(Color.white, lineWidth: colorHex == hex ? 3 : 0)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 2)
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }

                // Preview
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color(hex: colorHex) ?? .blue)
                    Text(name.isEmpty ? "Folder Name" : name)
                        .foregroundStyle(name.isEmpty ? .tertiary : .primary)
                }
                .font(.callout)

                if let existingFolder = folder {
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Location Lock")
                            Text(existingFolder.isGeofenced ? "Active" : "Not configured")
                                .font(.caption)
                                .foregroundStyle(existingFolder.isGeofenced ? .green : .secondary)
                        }
                        Spacer()
                        Button(existingFolder.isGeofenced ? "Edit…" : "Set Up…") {
                            showGeofenceSetup = true
                        }
                    }
                }
            }
            .padding(24)

            Divider()

            HStack {
                Spacer()
                Button(folder == nil ? "Create Folder" : "Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(width: 360)
        .onAppear {
            if let f = folder { name = f.name; colorHex = f.colorHex }
        }
        .sheet(isPresented: $showGeofenceSetup) {
            if let existingFolder = folder {
                GeofenceSetupView(folder: existingFolder)
                    .environmentObject(vaultManager)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if var existing = folder {
            existing.name     = trimmed
            existing.colorHex = colorHex
            vaultManager.updateFolder(existing)
        } else {
            vaultManager.addFolder(VaultFolder(name: trimmed, colorHex: colorHex))
        }
        dismiss()
    }
}