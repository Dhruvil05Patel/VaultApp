import SwiftUI

struct SettingsView: View {

    @ObservedObject private var settings = AppSettings.shared

    // Timeout options (label, value in seconds)
    private let timeoutOptions: [(label: String, seconds: Int)] = [
        ("Never",    0),
        ("1 minute", 60),
        ("5 minutes", 300),
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("1 hour", 3600)
    ]

    // Clipboard clear options
    private let clipboardOptions: [(label: String, seconds: Int)] = [
        ("Never",     0),
        ("15 seconds", 15),
        ("30 seconds", 30),
        ("1 minute",  60),
        ("2 minutes", 120)
    ]

    var body: some View {
        Form {
            // MARK: Security Section
            Section {
                // Auto-lock timeout picker
                Picker("Auto-lock after", selection: $settings.autoLockTimeout) {
                    ForEach(timeoutOptions, id: \.seconds) { option in
                        Text(option.label).tag(option.seconds)
                    }
                }
                .pickerStyle(.menu)

                // Lock on sleep
                Toggle("Lock vault when Mac sleeps or screen locks", isOn: $settings.lockOnSleep)
            } header: {
                Text("Security")
            } footer: {
                Text("The vault will be locked automatically and require your master password to re-open.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: Biometric Section
            if BiometricService.isAvailable() {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unlock with \(BiometricService.biometricName())")
                            Text("Use \(BiometricService.biometricName()) instead of typing your master password each time.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: biometricBinding)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                } header: {
                    Text(BiometricService.biometricName())
                } footer: {
                    if AppSettings.shared.isBiometricEnabled {
                        Text("Your vault key is stored in the Keychain, protected by \(BiometricService.biometricName()). Your master password is never stored.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: Clipboard Section
            Section {
                Picker("Clear clipboard after", selection: $settings.clipboardClearDelay) {
                    ForEach(clipboardOptions, id: \.seconds) { option in
                        Text(option.label).tag(option.seconds)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Clipboard")
            } footer: {
                Text("Copied passwords and usernames are automatically removed from the clipboard after this delay.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: Display Section
            Section {
                Toggle("Show passwords in detail view by default", isOn: $settings.showPasswordsByDefault)
            } header: {
                Text("Display")
            } footer: {
                Text("When enabled, passwords will be visible rather than masked when you open an item.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: About Section
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Build")
                    Spacer()
                    Text(appBuild)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .padding()
        .alert("Unlock Vault First", isPresented: $showUnlockRequiredAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Unlock the vault with your master password before enabling \(BiometricService.biometricName()).")
        }
        .alert("Enable \(BiometricService.biometricName()) Failed", isPresented: Binding(
            get: { biometricError != nil },
            set: { if !$0 { biometricError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(biometricError ?? "Unknown error")
        }
    }

    // MARK: - Helpers

    @State private var showUnlockRequiredAlert: Bool = false
    @State private var biometricError: String? = nil

    private var biometricBinding: Binding<Bool> {
        Binding(
            get: { AppSettings.shared.isBiometricEnabled && BiometricService.hasStoredKey() },
            set: { enabled in
                if enabled {
                    // Vault must be unlocked to enable — check first
                    guard VaultManager.shared.isUnlocked else {
                        showUnlockRequiredAlert = true
                        return
                    }
                    Task {
                        do {
                            try await VaultManager.shared.enableBiometric()
                        } catch {
                            biometricError = error.localizedDescription
                        }
                    }
                } else {
                    VaultManager.shared.disableBiometric()
                }
            }
        )
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    SettingsView()
}