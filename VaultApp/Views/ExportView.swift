import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {

    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ExportService.Format = .encryptedBackup
    @State private var showWarningConfirm: Bool = false
    @State private var showFileSaver: Bool = false
    @State private var exportData: Data? = nil
    @State private var errorMessage: String? = nil
    @State private var exportSuccess: Bool = false

    // For restore
    @State private var showRestorePicker: Bool = false
    @State private var pendingRestoreURL: URL? = nil
    @State private var restorePassword: String = ""
    @State private var showRestoreSheet: Bool = false
    @State private var restoreMerge: Bool = false
    @State private var isRestoring: Bool = false
    @State private var restoreError: String? = nil
    @State private var restoreSuccess: Bool = false

    private var suggestedFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: Date())
        return "VaultApp-\(date).\(selectedFormat.fileExtension)"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Export & Backup")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    exportSection
                    Divider()
                    restoreSection
                }
                .padding(24)
            }
        }
        .frame(minWidth: 480, minHeight: 520)
        // Export file saver
        .fileExporter(
            isPresented: $showFileSaver,
            document: ExportDocument(data: exportData ?? Data()),
            contentType: contentType(for: selectedFormat),
            defaultFilename: suggestedFileName
        ) { result in
            switch result {
            case .success:
                exportSuccess = true
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        // Restore file picker
        .fileImporter(
            isPresented: $showRestorePicker,
            allowedContentTypes: [UTType(filenameExtension: "vaultbackup") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            handleRestorePick(url: url)
        }
        // Restore password sheet
        .sheet(isPresented: $showRestoreSheet) {
            restorePasswordSheet
        }
        .confirmationDialog(
            "Export Without Encryption?",
            isPresented: $showWarningConfirm,
            titleVisibility: .visible
        ) {
            Button("Export Anyway", role: .destructive) {
                performExport()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(selectedFormat.warningMessage ?? "")
        }
    }

    // MARK: - Export Section

    @ViewBuilder
    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Vault")
                .font(.title3)
                .fontWeight(.semibold)

            Text("\(vaultManager.vault.items.count) passwords will be exported.")
                .foregroundStyle(.secondary)

            // Format picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Format")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)

                ForEach(ExportService.Format.allCases) { format in
                    formatRow(format: format)
                }
            }

            // Warning banner for plaintext formats
            if let warning = selectedFormat.warningMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Success message
            if exportSuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Export saved successfully.")
                        .foregroundStyle(.green)
                }
                .font(.callout)
            }

            // Error
            if let error = errorMessage {
                ErrorBannerView(message: error) {
                    errorMessage = nil
                }
            }

            // Export button
            Button {
                exportSuccess = false
                errorMessage = nil
                if selectedFormat.warningMessage != nil {
                    showWarningConfirm = true
                } else {
                    performExport()
                }
            } label: {
                Label("Export…", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Format Row

    @ViewBuilder
    private func formatRow(format: ExportService.Format) -> some View {
        Button {
            selectedFormat = format
            exportSuccess = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: format.icon)
                    .font(.title3)
                    .foregroundStyle(format.isEncrypted ? .blue : .orange)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(format.rawValue)
                        .fontWeight(.medium)
                    Text(".\(format.fileExtension)"
                         + (format.isEncrypted ? " · Encrypted" : " · Plaintext"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selectedFormat == format {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(12)
            .background(
                selectedFormat == format
                ? Color.blue.opacity(0.07)
                : Color(NSColor.controlBackgroundColor)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Restore Section

    @ViewBuilder
    private var restoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Restore from Backup")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Restore a `.vaultbackup` file. You can replace your current vault or merge new items into it.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Toggle("Merge with current vault", isOn: $restoreMerge)
                    .toggleStyle(.checkbox)
                Spacer()
            }

            if restoreSuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(restoreMerge ? "Items merged successfully." : "Vault restored successfully.")
                        .foregroundStyle(.green)
                }
                .font(.callout)
            }

            if let err = restoreError {
                ErrorBannerView(message: err) {
                    restoreError = nil
                }
            }

            Button {
                restoreSuccess = false
                restoreError = nil
                showRestorePicker = true
            } label: {
                Label("Choose Backup File…", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    // MARK: - Restore Password Sheet

    @ViewBuilder
    private var restorePasswordSheet: some View {
        VStack(spacing: 20) {
            Text("Enter Backup Password")
                .font(.headline)

            Text("Enter the master password that was used when this backup was created.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            SecureField("Master Password", text: $restorePassword)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)

            if let err = restoreError {
                ErrorBannerView(message: err) {
                    restoreError = nil
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    showRestoreSheet = false
                    restorePassword = ""
                    pendingRestoreURL = nil
                }
                .buttonStyle(.bordered)

                Button("Restore") {
                    performRestore()
                }
                .buttonStyle(.borderedProminent)
                .disabled(restorePassword.isEmpty || isRestoring)
            }
        }
        .padding(32)
        .frame(width: 360)
    }

    // MARK: - Logic

    private func performExport() {
        do {
            switch selectedFormat {
            case .encryptedBackup:
                exportData = try vaultManager.exportEncryptedBackup()
            case .csv:
                exportData = try vaultManager.exportCSV()
            case .json:
                exportData = try vaultManager.exportJSON()
            }
            showFileSaver = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleRestorePick(url: URL) {
        pendingRestoreURL = url
        restorePassword = ""
        restoreError = nil
        showRestoreSheet = true
    }

    private func performRestore() {
        guard let url = pendingRestoreURL else {
            restoreError = "No backup file selected."
            return
        }

        isRestoring = true
        restoreError = nil

        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        Task {
            do {
                let data = try Data(contentsOf: url)
                try await vaultManager.restoreFromBackup(
                    data: data,
                    masterPassword: restorePassword,
                    merge: restoreMerge
                )
                await MainActor.run {
                    restoreSuccess = true
                    showRestoreSheet = false
                    restorePassword = ""
                    pendingRestoreURL = nil
                    isRestoring = false
                }
            } catch {
                await MainActor.run {
                    restoreError = error.localizedDescription
                    isRestoring = false
                }
            }
        }
    }

    private func contentType(for format: ExportService.Format) -> UTType {
        switch format {
        case .encryptedBackup:
            return UTType(filenameExtension: "vaultbackup") ?? .data
        case .csv:
            return .commaSeparatedText
        case .json:
            return .json
        }
    }
}

// MARK: - FileDocument wrapper for fileExporter

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data, .commaSeparatedText, .json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}