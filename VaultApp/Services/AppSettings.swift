import Foundation
import Combine

final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    // Auto-lock timeout in seconds. 0 = never.
    @Published var autoLockTimeout: Int {
        didSet { UserDefaults.standard.set(autoLockTimeout, forKey: "autoLockTimeout") }
    }

    // How long (seconds) before clipboard is cleared after a copy. 0 = never.
    @Published var clipboardClearDelay: Int {
        didSet { UserDefaults.standard.set(clipboardClearDelay, forKey: "clipboardClearDelay") }
    }

    // Whether to lock the vault when the screen is locked or the Mac sleeps.
    @Published var lockOnSleep: Bool {
        didSet { UserDefaults.standard.set(lockOnSleep, forKey: "lockOnSleep") }
    }

    // Whether to show passwords in the detail view by default (instead of masked).
    @Published var showPasswordsByDefault: Bool {
        didSet { UserDefaults.standard.set(showPasswordsByDefault, forKey: "showPasswordsByDefault") }
    }

    // Whether Touch ID / biometric unlock is enabled.
    @Published var isBiometricEnabled: Bool {
        didSet { UserDefaults.standard.set(isBiometricEnabled, forKey: "isBiometricEnabled") }
    }

    // Whether the user has explicitly answered the biometric setup prompt (either Enable or Not Now).
    @Published var hasAnsweredBiometricPrompt: Bool {
        didSet { UserDefaults.standard.set(hasAnsweredBiometricPrompt, forKey: "hasAnsweredBiometricPrompt") }
    }

    // Whether to sync the encrypted vault to iCloud Drive. Disabled by default.
    @Published var iCloudSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(iCloudSyncEnabled, forKey: "iCloudSyncEnabled") }
    }

    // Whether to show the persistent menu bar icon. Enabled by default.
    @Published var showMenuBarIcon: Bool {
        didSet { UserDefaults.standard.set(showMenuBarIcon, forKey: "showMenuBarIcon") }
    }

    @Published var isDuressModeEnabled: Bool {
        didSet { UserDefaults.standard.set(isDuressModeEnabled, forKey: "isDuressModeEnabled") }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    @Published var p2pSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(p2pSyncEnabled, forKey: "p2pSyncEnabled") }
    }

    @Published var p2pDeviceName: String {
        didSet { UserDefaults.standard.set(p2pDeviceName, forKey: "p2pDeviceName") }
    }

    @Published var aliasEmailDomain: String {
        didSet { UserDefaults.standard.set(aliasEmailDomain, forKey: "aliasEmailDomain") }
    }

    @Published var screenCaptureProtection: Bool {
        didSet { UserDefaults.standard.set(screenCaptureProtection, forKey: "screenCaptureProtection") }
    }

    @Published var lockOnScreenShare: Bool {
        didSet { UserDefaults.standard.set(lockOnScreenShare, forKey: "lockOnScreenShare") }
    }

    @Published var inheritanceEnabled: Bool {
        didSet { UserDefaults.standard.set(inheritanceEnabled, forKey: "inheritanceEnabled") }
    }

    @Published var inheritanceInactivityDays: Int {
        didSet { UserDefaults.standard.set(inheritanceInactivityDays, forKey: "inheritanceInactivityDays") }
    }

    @Published var inheritanceGraceDays: Int {
        didSet { UserDefaults.standard.set(inheritanceGraceDays, forKey: "inheritanceGraceDays") }
    }

    @Published var lastVaultActivityDate: Date? {
        didSet { UserDefaults.standard.set(lastVaultActivityDate, forKey: "lastVaultActivityDate") }
    }

    @Published var auditLogEnabled: Bool {
        didSet { UserDefaults.standard.set(auditLogEnabled, forKey: "auditLogEnabled") }
    }

    private init() {
        // Load persisted values, falling back to sensible defaults
        self.autoLockTimeout      = UserDefaults.standard.object(forKey: "autoLockTimeout") as? Int ?? 300  // 5 min
        self.clipboardClearDelay  = UserDefaults.standard.object(forKey: "clipboardClearDelay") as? Int ?? 30  // 30s
        self.lockOnSleep          = UserDefaults.standard.object(forKey: "lockOnSleep") as? Bool ?? true
        self.showPasswordsByDefault = UserDefaults.standard.object(forKey: "showPasswordsByDefault") as? Bool ?? false
        self.isBiometricEnabled   = UserDefaults.standard.object(forKey: "isBiometricEnabled") as? Bool ?? false
        self.hasAnsweredBiometricPrompt = UserDefaults.standard.object(forKey: "hasAnsweredBiometricPrompt") as? Bool ?? false
        self.iCloudSyncEnabled    = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? false
        self.showMenuBarIcon      = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true
        self.isDuressModeEnabled  = UserDefaults.standard.bool(forKey: "isDuressModeEnabled")
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.p2pSyncEnabled       = UserDefaults.standard.bool(forKey: "p2pSyncEnabled")
        self.p2pDeviceName        = UserDefaults.standard.string(forKey: "p2pDeviceName") ?? ""
        self.aliasEmailDomain     = UserDefaults.standard.string(forKey: "aliasEmailDomain") ?? ""
        self.screenCaptureProtection = UserDefaults.standard.object(forKey: "screenCaptureProtection") as? Bool ?? true
        self.lockOnScreenShare    = UserDefaults.standard.bool(forKey: "lockOnScreenShare")
        self.inheritanceEnabled       = UserDefaults.standard.bool(forKey: "inheritanceEnabled")
        self.inheritanceInactivityDays = UserDefaults.standard.object(forKey: "inheritanceInactivityDays") as? Int ?? 90
        self.inheritanceGraceDays     = UserDefaults.standard.object(forKey: "inheritanceGraceDays") as? Int ?? 14
        self.lastVaultActivityDate    = UserDefaults.standard.object(forKey: "lastVaultActivityDate") as? Date
        self.auditLogEnabled          = UserDefaults.standard.object(forKey: "auditLogEnabled") as? Bool ?? true
    }
}