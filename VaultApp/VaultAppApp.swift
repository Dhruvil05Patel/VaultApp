import SwiftUI

@main
struct VaultAppApp: App {

    private let autoLockService = AutoLockService(vaultManager: VaultManager.shared)

    var body: some Scene {
        // MARK: Main Window
        WindowGroup {
            ContentView()
                .environmentObject(VaultManager.shared)
                .frame(minWidth: 720, minHeight: 520)
                .onAppear {
                    autoLockService.start()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            VaultCommands()
        }

        // MARK: Settings Window (⌘ + ,)
        Settings {
            SettingsView()
        }
    }
}