import SwiftUI

struct ContentView: View {

    @EnvironmentObject var vaultManager: VaultManager

    // These are triggered by menu bar commands via NotificationCenter
    @State private var showAddItem: Bool = false
    @State private var showGenerator: Bool = false
    @State private var showImport: Bool = false
    @State private var showEnableBiometricOffer: Bool = false
    @State private var biometricEnableError: String? = nil

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
        // Offer to enable Touch ID after a password unlock
        .onChange(of: vaultManager.isUnlocked) { unlocked in
            print("[CONTENT] onChange isUnlocked = \(unlocked)")
            if unlocked,
               BiometricService.isAvailable(),
               !AppSettings.shared.isBiometricEnabled {
                showEnableBiometricOffer = true
            }
        }
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
        // React to menu bar "Import Passwords…" command
        .onReceive(NotificationCenter.default.publisher(for: .openImport)) { _ in
            if vaultManager.isUnlocked {
                showImport = true
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddItemView()
                .environmentObject(vaultManager)
        }
        .sheet(isPresented: $showGenerator) {
            GeneratorView()
        }
        .sheet(isPresented: $showImport) {
            ImportFlowView()
                .environmentObject(vaultManager)
        }
        .alert("Enable \(BiometricService.biometricName())?", isPresented: $showEnableBiometricOffer) {
            Button("Enable") {
                Task {
                    do {
                        try await vaultManager.enableBiometric()
                    } catch {
                        biometricEnableError = error.localizedDescription
                    }
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            if let bioError = biometricEnableError {
                Text(bioError)
            } else {
                Text("Unlock future sessions with \(BiometricService.biometricName()) instead of typing your master password.")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(VaultManager.shared)
        .frame(width: 800, height: 600)
}