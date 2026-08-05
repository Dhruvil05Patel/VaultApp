import SwiftUI

@main
struct VaultAppApp: App {

    @StateObject private var vaultManager = VaultManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vaultManager)
                .frame(minWidth: 700, minHeight: 500)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
