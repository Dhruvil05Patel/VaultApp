import SwiftUI

struct ContentView: View {

    @EnvironmentObject var vaultManager: VaultManager

    // These are triggered by menu bar commands via NotificationCenter
    @State private var showAddItem: Bool = false
    @State private var showGenerator: Bool = false

    var body: some View {
        ZStack {
            if vaultManager.isUnlocked {
                VaultListView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            } else {
                LockView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .trailing)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vaultManager.isUnlocked)
        // React to menu bar "New Password Entry" command
        .onReceive(NotificationCenter.default.publisher(for: .addNewItem)) { _ in
            if vaultManager.isUnlocked {
                showAddItem = true
            }
        }
        // React to menu bar "Password Generator" command
        .onReceive(NotificationCenter.default.publisher(for: .openGenerator)) { _ in
            showGenerator = true
        }
        .sheet(isPresented: $showAddItem) {
            AddItemView()
                .environmentObject(vaultManager)
        }
        .sheet(isPresented: $showGenerator) {
            GeneratorView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(VaultManager.shared)
        .frame(width: 800, height: 600)
}