import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vaultManager: VaultManager

    var body: some View {
        Group {
            if vaultManager.isUnlocked {
                // VaultListView will go here in Task 07
                Text("✅ Vault is unlocked — list coming in Task 07")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LockView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vaultManager.isUnlocked)
    }
}
