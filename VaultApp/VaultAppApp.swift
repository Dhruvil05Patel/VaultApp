import SwiftUI

@main
struct VaultAppApp: App {

    private let autoLockService = AutoLockService(vaultManager: VaultManager.shared)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(VaultManager.shared)
                .frame(minWidth: 700, minHeight: 500)
                .onAppear {
                    autoLockService.start()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView()
        }
    }
}