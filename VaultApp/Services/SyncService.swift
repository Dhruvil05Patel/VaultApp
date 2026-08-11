import Foundation
import Combine

// SyncService manages bidirectional sync of the encrypted vault file
// between the local Application Support directory and iCloud Drive.
//
// Security: vault.enc is AES-256-GCM encrypted — Apple cannot read it.
// Conflict resolution: last-write-wins based on file modification date.
@MainActor
final class SyncService: ObservableObject {

    // MARK: - State

    @Published var syncStatus: SyncStatus = .disabled
    @Published var lastSyncDate: Date? = nil
    @Published var conflictResolved: Bool = false

    enum SyncStatus: Equatable {
        case disabled
        case idle
        case uploading
        case downloading
        case conflict
        case error(String)

        var description: String {
            switch self {
            case .disabled:     return "Sync disabled"
            case .idle:         return "Up to date"
            case .uploading:    return "Uploading…"
            case .downloading:  return "Downloading…"
            case .conflict:     return "Conflict resolved"
            case .error(let e): return "Error: \(e)"
            }
        }

        var icon: String {
            switch self {
            case .disabled:    return "icloud.slash"
            case .idle:        return "checkmark.icloud"
            case .uploading:   return "icloud.and.arrow.up"
            case .downloading: return "icloud.and.arrow.down"
            case .conflict:    return "exclamationmark.icloud"
            case .error:       return "xcloud.fill"
            }
        }
    }

    // MARK: - Singleton

    static let shared = SyncService(vaultManager: VaultManager.shared, settings: .shared)

    // MARK: - Dependencies

    private let vaultManager: VaultManager
    private let settings: AppSettings

    // MARK: - iCloud Paths

    /// The container identifier must match the one added in VaultApp.entitlements.
    private static let containerIdentifier = "iCloud.dhruvil-patel.VaultApp"

    // The iCloud container URL for this app
    private var iCloudContainerURL: URL? {
        FileManager.default.url(
            forUbiquityContainerIdentifier: Self.containerIdentifier
        )?.appendingPathComponent("Documents", isDirectory: true)
    }

    private var iCloudVaultURL: URL? {
        iCloudContainerURL?.appendingPathComponent("vault.enc")
    }

    private var iCloudSaltURL: URL? {
        iCloudContainerURL?.appendingPathComponent("vault.salt")
    }

    // Local vault paths — read from VaultManager's app support directory
    private var localVaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VaultApp/vault.enc")
    }

    private var localSaltURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VaultApp/vault.salt")
    }

    // MARK: - Metadata Query (watches for remote iCloud changes)

    private var metadataQuery: NSMetadataQuery? = nil
    private var queryObserver: NSObjectProtocol? = nil
    private var isDownloading: Bool = false

    // MARK: - Init

    init(vaultManager: VaultManager, settings: AppSettings) {
        self.vaultManager = vaultManager
        self.settings = settings
    }

    // MARK: - Start / Stop

    func start() {
        guard settings.iCloudSyncEnabled else {
            syncStatus = .disabled
            return
        }
        guard FileManager.default.ubiquityIdentityToken != nil else {
            syncStatus = .error("iCloud is not available. Sign in to iCloud in System Settings.")
            return
        }
        syncStatus = .idle
        ensureICloudDirectoryExists()
        startMetadataQuery()
    }

    func stop() {
        metadataQuery?.stop()
        if let observer = queryObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        metadataQuery = nil
        queryObserver = nil
        syncStatus = .disabled
    }

    // MARK: - Upload (called by VaultManager after every save)

    // Copies local vault.enc + vault.salt to the iCloud container.
    func uploadVault() async {
        guard settings.iCloudSyncEnabled,
              let iCloudVault = iCloudVaultURL,
              let iCloudSalt  = iCloudSaltURL else { return }

        syncStatus = .uploading

        do {
            ensureICloudDirectoryExists()
            let fm = FileManager.default

            // Copy vault file (overwrite if exists)
            if fm.fileExists(atPath: iCloudVault.path) {
                try fm.removeItem(at: iCloudVault)
            }
            try fm.copyItem(at: localVaultURL, to: iCloudVault)

            // Copy salt file
            if fm.fileExists(atPath: iCloudSalt.path) {
                try fm.removeItem(at: iCloudSalt)
            }
            try fm.copyItem(at: localSaltURL, to: iCloudSalt)

            lastSyncDate = Date()
            syncStatus = .idle
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - Download (triggered by metadata query on remote change)

    // Downloads the iCloud vault and merges or replaces based on modification date.
    func downloadAndMerge() async {
        guard settings.iCloudSyncEnabled,
              let iCloudVault = iCloudVaultURL,
              let iCloudSalt  = iCloudSaltURL else { return }

        guard FileManager.default.fileExists(atPath: iCloudVault.path) else { return }
        guard !isDownloading else { return }

        isDownloading = true
        syncStatus = .downloading

        defer { isDownloading = false }

        do {
            // Trigger download of the iCloud item if it's not local yet
            try FileManager.default.startDownloadingUbiquitousItem(at: iCloudVault)
            try FileManager.default.startDownloadingUbiquitousItem(at: iCloudSalt)

            // Compare modification dates — keep the newer one
            let localMod  = modDate(localVaultURL)
            let remoteMod = await awaitDownloadModDate(iCloudVault)

            guard let remote = remoteMod else {
                syncStatus = .idle
                return
            }

            // Short-circuit: if the iCloud file already matches our local copy,
            // this didUpdate was caused by our own upload — nothing to do.
            // Without this check the service would oscillate upload → download → upload…
            if let localData = try? Data(contentsOf: localVaultURL),
               let remoteData = try? Data(contentsOf: iCloudVault),
               localData == remoteData {
                lastSyncDate = Date()
                syncStatus = .idle
                return
            }

            if let local = localMod, local >= remote {
                // Local is newer — upload ours instead
                isDownloading = false
                await uploadVault()
                return
            }

            // Remote is newer — replace local files
            let fm = FileManager.default

            if fm.fileExists(atPath: localVaultURL.path) {
                try fm.removeItem(at: localVaultURL)
            }
            try fm.copyItem(at: iCloudVault, to: localVaultURL)

            if fm.fileExists(atPath: localSaltURL.path) {
                try fm.removeItem(at: localSaltURL)
            }
            try fm.copyItem(at: iCloudSalt, to: localSaltURL)

            lastSyncDate = Date()
            syncStatus = .idle

            // If vault is currently unlocked, reload it in memory
            if vaultManager.isUnlocked {
                await vaultManager.reloadFromDisk()
            }

        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - NSMetadataQuery — watches iCloud for remote file changes

    private func startMetadataQuery() {
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(
            format: "%K LIKE %@",
            NSMetadataItemFSNameKey, "vault.enc"
        )
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        // Observe results when the query finishes or updates
        let center = NotificationCenter.default
        queryObserver = center.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.downloadAndMerge()
            }
        }

        query.start()
        metadataQuery = query
    }

    // MARK: - Helpers

    @discardableResult
    private func ensureICloudDirectoryExists() -> Bool {
        guard let dir = iCloudContainerURL else { return false }
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return true
    }

    private func modDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    // startDownloadingUbiquitousItem is NOT synchronous — the file may not be
    // materialised immediately. Poll for the modification date briefly.
    private func awaitDownloadModDate(_ url: URL) async -> Date? {
        for _ in 0..<10 {
            if let date = modDate(url) { return date }
            try? await Task.sleep(nanoseconds: 500_000_000)   // 0.5s, up to 5s total
        }
        return modDate(url)
    }
}