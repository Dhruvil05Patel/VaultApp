import Foundation
import UserNotifications

// InheritanceService checks vault inactivity on every launch
// and prepares an emergency backup when the threshold is exceeded.
@MainActor
final class InheritanceService {

    static let shared = InheritanceService()
    private init() {}

    // MARK: - Record Activity

    // Call this every time the vault is successfully unlocked.
    func recordActivity() {
        AppSettings.shared.lastVaultActivityDate = Date()
    }

    // MARK: - Check Inactivity (called on app launch before unlock)

    func checkInactivity() {
        guard AppSettings.shared.inheritanceEnabled else { return }

        // First launch — no activity recorded yet
        guard let lastActive = AppSettings.shared.lastVaultActivityDate else {
            recordActivity()
            return
        }

        let daysSince = Calendar.current.dateComponents(
            [.day], from: lastActive, to: Date()
        ).day ?? 0

        let threshold  = AppSettings.shared.inheritanceInactivityDays
        let graceDays  = AppSettings.shared.inheritanceGraceDays

        if daysSince >= threshold + graceDays {
            // Grace period exceeded — prepare emergency package automatically
            Task { await prepareEmergencyPackageAutomatically() }
        } else if daysSince >= threshold {
            // Past threshold but within grace — show reminder
            scheduleLocalNotification(daysSince: daysSince, daysRemaining: graceDays - (daysSince - threshold))
            NotificationCenter.default.post(
                name: .inheritanceWarning,
                object: ["daysSince": daysSince, "graceDays": graceDays]
            )
        } else if daysSince >= threshold - 7 {
            // Within 7 days of threshold — show gentle warning in app
            NotificationCenter.default.post(
                name: .inheritanceApproaching,
                object: ["daysUntilWarning": threshold - daysSince]
            )
        }
    }

    // MARK: - Prepare Emergency Package

    // Triggered manually by user for testing, or automatically after grace period.
    func prepareEmergencyPackage() async throws -> URL {
        guard VaultManager.shared.isUnlocked else {
            throw NSError(domain: "Inheritance", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Vault must be unlocked to create a backup."])
        }

        let backupData = try VaultManager.shared.exportEncryptedBackup()
        let destination = resolveDestinationURL()

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try backupData.write(to: destination)

        // Record that we made the backup
        UserDefaults.standard.set(Date(), forKey: "lastEmergencyPackageDate")
        return destination
    }

    private func prepareEmergencyPackageAutomatically() async {
        // Only auto-export if vault is NOT currently unlocked (user is absent)
        // and we haven't exported in the last 24 hours
        guard !VaultManager.shared.isUnlocked else { return }

        let lastExport = UserDefaults.standard.object(forKey: "lastEmergencyPackageDate") as? Date
        if let last = lastExport, Date().timeIntervalSince(last) < 86400 { return }

        // We can only export if we have the vault file — copy the encrypted blob directly
        let src = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VaultApp/vault.enc")
        let salt = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VaultApp/vault.salt")

        guard FileManager.default.fileExists(atPath: src.path),
              FileManager.default.fileExists(atPath: salt.path),
              let saltData = try? Data(contentsOf: salt),
              let vaultData = try? Data(contentsOf: src) else { return }

        // Build a BackupEnvelope from the raw files (same format as Task 18)
        let envelope = ExportService.BackupEnvelope(
            version: 1,
            createdAt: Date(),
            salt: saltData.base64EncodedString(),
            encryptedVault: vaultData.base64EncodedString()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let envelopeData = try? encoder.encode(envelope) else { return }

        let destination = resolveDestinationURL()
        try? FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? envelopeData.write(to: destination)
        UserDefaults.standard.set(Date(), forKey: "lastEmergencyPackageDate")

        // Post a notification about the automatic export
        NotificationCenter.default.post(name: .inheritancePackageCreated, object: destination)
    }

    // MARK: - Resolve Destination

    private func resolveDestinationURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "VaultApp-Emergency-\(formatter.string(from: Date())).vaultbackup"

        // Prefer iCloud Drive
        if let iCloud = FileManager.default
            .url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents/VaultApp Emergency") {
            return iCloud.appendingPathComponent(filename)
        }

        // Fall back to Desktop
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/\(filename)")
    }

    // MARK: - Local Notification

    private func scheduleLocalNotification(daysSince: Int, daysRemaining: Int) {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "VaultApp Emergency Access"
            content.body = "You haven't opened VaultApp in \(daysSince) days. "
                + "Your emergency contact will receive access in \(daysRemaining) days "
                + "unless you open the app."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "inheritance-warning",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let inheritanceWarning      = Notification.Name("VaultApp.inheritanceWarning")
    static let inheritanceApproaching  = Notification.Name("VaultApp.inheritanceApproaching")
    static let inheritancePackageCreated = Notification.Name("VaultApp.inheritancePackageCreated")
}
