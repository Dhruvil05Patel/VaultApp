import Foundation
import AppKit
import Combine

// AutoLockService observes system events and inactivity timers,
// then calls vaultManager.lock() when appropriate.
// It is started once at app launch and runs for the app's lifetime.
final class AutoLockService {

    private let vaultManager: VaultManager
    private let settings: AppSettings

    private var inactivityTimer: Timer? = nil
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Init

    init(vaultManager: VaultManager, settings: AppSettings = .shared) {
        self.vaultManager = vaultManager
        self.settings = settings
    }

    // MARK: - Start

    func start() {
        observeScreenLockAndSleep()
        observeUserActivity()
        observeSettingsChanges()
        resetInactivityTimer()
    }

    // MARK: - Screen Lock & Sleep

    private func observeScreenLockAndSleep() {
        let notificationCenter = NSWorkspace.shared.notificationCenter

        // Mac going to sleep
        notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.lockIfNeeded(reason: "sleep")
        }

        // Screen saver activated
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screensaver.didstart"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.lockIfNeeded(reason: "screensaver")
        }

        // Screen locked (Fast User Switching or manual lock)
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.lockIfNeeded(reason: "screenLock")
        }
    }

    private func lockIfNeeded(reason: String) {
        guard settings.lockOnSleep else { return }
        guard vaultManager.isUnlocked else { return }
        Task { @MainActor in
            vaultManager.lock()
        }
    }

    // MARK: - Inactivity Timer

    // Reset the inactivity timer every time user activity is detected.
    // When the timer fires (no activity for `autoLockTimeout` seconds), the vault locks.

    private func observeUserActivity() {
        // Monitor mouse and keyboard events globally
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .keyDown]) { [weak self] _ in
            self?.resetInactivityTimer()
        }

        // Also monitor events inside the app
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .keyDown]) { [weak self] event in
            self?.resetInactivityTimer()
            return event
        }
    }

    func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        let timeout = settings.autoLockTimeout
        guard timeout > 0 else { return }  // 0 = never auto-lock

        inactivityTimer = Timer.scheduledTimer(withTimeInterval: Double(timeout), repeats: false) { [weak self] _ in
            guard let self, self.vaultManager.isUnlocked else { return }
            Task { @MainActor in
                self.vaultManager.lock()
            }
        }
    }

    // MARK: - React to Settings Changes

    // If the user changes the auto-lock timeout in settings, restart the timer immediately.
    private func observeSettingsChanges() {
        settings.$autoLockTimeout
            .dropFirst()
            .sink { [weak self] _ in
                self?.resetInactivityTimer()
            }
            .store(in: &cancellables)
    }

    // MARK: - Stop

    func stop() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        cancellables.removeAll()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
}