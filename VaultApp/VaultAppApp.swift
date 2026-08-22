import SwiftUI

// Keeps the app alive in the menu bar when the main window is closed.
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Return false to keep running in the menu bar when main window is closed
        return !AppSettings.shared.showMenuBarIcon
    }
}

@main
struct VaultAppApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let autoLockService = AutoLockService(vaultManager: VaultManager.shared)

    var body: some Scene {
        // MARK: Main Window
        WindowGroup {
            ContentView()
                .environmentObject(VaultManager.shared)
                .frame(minWidth: 720, minHeight: 520)
                .onAppear {
                    // Apply window screenshot protection
                    if let window = NSApp.windows.first {
                        window.enableScreenshotProtection()
                    }
                    ScreenProtectionService.shared.start()

                    autoLockService.start()
                    VaultManager.shared.syncService = SyncService.shared
                    if AppSettings.shared.iCloudSyncEnabled {
                        SyncService.shared.start()
                    }
                    MenuBarManager.shared.setup()
                    InheritanceService.shared.checkInactivity()
                    GeofenceService.shared.startMonitoring()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .onChange(of: VaultManager.shared.isUnlocked) { _, isUnlocked in
            if isUnlocked {
                InheritanceService.shared.recordActivity()
            }
            MenuBarManager.shared.updateIcon(isLocked: !isUnlocked)
        }
        .commands {
            VaultCommands()
        }

        // MARK: Settings Window (⌘ + ,)
        Settings {
            SettingsView()
        }
    }
}