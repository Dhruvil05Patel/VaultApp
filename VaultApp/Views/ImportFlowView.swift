import SwiftUI
import UniformTypeIdentifiers

struct ImportFlowView: View {

    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSource: ImportService.Source? = nil
    @State private var parsedItems: [VaultItem]? = nil
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var showFilePicker: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if selectedSource != nil && parsedItems == nil {
                    Button {
                        selectedSource = nil
                        errorMessage = nil
                    } label: {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
                Text("Import Passwords")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                Button("Cancel") { dismiss() }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            Group {
                // Navigate to preview once parsed
                if let items = parsedItems, let source = selectedSource {
                    ImportPreviewView(source: source, items: items)
                        .environmentObject(vaultManager)
                } else if let source = selectedSource {
                    // Source selected — show instructions + action
                    sourceDetailScreen(source: source)
                } else {
                    // No source selected — show picker grid
                    sourcePickerScreen
                }
            }
        }
        .frame(minWidth: 520, minHeight: 480)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleFilePick(result: result)
        }
    }

    // MARK: - Source Picker Grid

    @ViewBuilder
    private var sourcePickerScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose where to import from:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(ImportService.Source.allCases) { source in
                        Button {
                            selectedSource = source
                            errorMessage = nil
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: source.icon)
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                    .frame(width: 32)
                                Text(source.rawValue)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(16)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - Source Detail (instructions + action button)

    @ViewBuilder
    private func sourceDetailScreen(source: ImportService.Source) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Icon + name
                HStack(spacing: 12) {
                    Image(systemName: source.icon)
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    Text(source.rawValue)
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to export:")
                        .font(.callout)
                        .fontWeight(.medium)
                    Text(source.exportInstructions)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Error
                if let error = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Action button
                if source.requiresFile {
                    Button {
                        showFilePicker = true
                    } label: {
                        if isLoading {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Reading file…")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Label("Choose CSV File…", systemImage: "doc.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isLoading)
                } else {
                    // Keychain — live read
                    Button {
                        readKeychain()
                    } label: {
                        if isLoading {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Reading Keychain…")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Label("Read from Keychain", systemImage: "key.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isLoading)

                    Text("You may be prompted to allow access. Click 'Always Allow' for the best experience.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Handlers

    private func handleFilePick(result: Result<[URL], Error>) {
        guard let source = selectedSource else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let urls = try result.get()
                guard let url = urls.first else { return }

                // Security-scoped resource access (required for sandboxed apps)
                guard url.startAccessingSecurityScopedResource() else {
                    throw NSError(domain: "ImportError", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Could not access the selected file."])
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let data = try Data(contentsOf: url)
                let items = try ImportService.parse(csvData: data, source: source)

                await MainActor.run {
                    self.parsedItems = items
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func readKeychain() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let items = try KeychainImporter.importItems()
                await MainActor.run {
                    if items.isEmpty {
                        self.errorMessage = "No passwords found in Keychain, or access was denied."
                    } else {
                        self.parsedItems = items
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}