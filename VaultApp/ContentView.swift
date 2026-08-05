import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vaultManager: VaultManager

    var body: some View {
        Group {
            if vaultManager.isUnlocked {
                VaultListView()
            } else {
                LockView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vaultManager.isUnlocked)
    }
}
