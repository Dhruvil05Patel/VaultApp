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

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
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
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
}