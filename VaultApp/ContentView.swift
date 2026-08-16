import SwiftUI

struct ContentView: View {

    @EnvironmentObject var vaultManager: VaultManager

    // These are triggered by menu bar commands via NotificationCenter
    @State private var showAddItem: Bool = false
    @State private var showGenerator: Bool = false
    @State private var showImport: Bool = false
    @State private var showExport: Bool = false
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
        .onChange(of: vaultManager.isUnlocked) { _, unlocked in
            print("[CONTENT] onChange isUnlocked = \(unlocked)")
            if unlocked,
               BiometricService.isAvailable(),
               !AppSettings.shared.hasAnsweredBiometricPrompt {
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
        // React to menu bar "Export / Backup Vault…" command
        .onReceive(NotificationCenter.default.publisher(for: .openExport)) { _ in
            if vaultManager.isUnlocked {
                showExport = true
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
        .sheet(isPresented: $showExport) {
            ExportView()
                .environmentObject(vaultManager)
        }
        .alert("Enable \(BiometricService.biometricName())?", isPresented: $showEnableBiometricOffer) {
            Button("Enable") {
                Task {
                    do {
                        print("[BIOMETRIC-SETUP] ENABLE BUTTON PRESSED")
                        print("[BIOMETRIC-SETUP] value BEFORE SAVE = \(UserDefaults.standard.bool(forKey: "hasAnsweredBiometricPrompt"))")
                        
                        try await vaultManager.enableBiometric()
                        
                        print("[BIOMETRIC-SETUP] SAVING ENABLED STATE")
                        AppSettings.shared.hasAnsweredBiometricPrompt = true
                        
                        // Force UserDefaults synchronization for debugging
                        UserDefaults.standard.synchronize()
                        
                        print("[BIOMETRIC-SETUP] value AFTER SAVE = \(AppSettings.shared.hasAnsweredBiometricPrompt)")
                        print("[BIOMETRIC-SETUP] READ-BACK VALUE = \(UserDefaults.standard.bool(forKey: "hasAnsweredBiometricPrompt"))")
                    } catch {
                        biometricEnableError = error.localizedDescription
                    }
                }
            }
            Button("Not Now", role: .cancel) {
                AppSettings.shared.hasAnsweredBiometricPrompt = true
            }
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