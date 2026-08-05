import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vaultManager: VaultManager

    var body: some View {
        Group {
            if vaultManager.isUnlocked {
                Text("Vault open — list view coming in Task 07")
            } else {
                Text("Lock screen coming in Task 06")
            }
        }
    }
}
