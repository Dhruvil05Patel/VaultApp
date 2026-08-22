import SwiftUI

struct SettingsView: View {

    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var syncService = SyncService.shared

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
            // MARK: iCloud Sync Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync with iCloud")
                        Text("Your encrypted vault is synced across your Macs. Apple cannot read it.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.iCloudSyncEnabled)
                        .toggleStyle(.switch).labelsHidden()
                        .onChange(of: settings.iCloudSyncEnabled) { _, enabled in
                            if enabled {
                                SyncService.shared.start()
                                Task { await SyncService.shared.uploadVault() }
                            } else {
                                SyncService.shared.stop()
                            }
                        }
                }

                // Sync status display
                if settings.iCloudSyncEnabled {
                    if case .error(let message) = syncService.syncStatus {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.icloud.fill")
                                .foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(message)
                                    .font(.caption).foregroundStyle(.red)
                                if message.contains("iCloud") || message.contains("sign in") {
                                    Text("Go to System Settings → Apple ID → iCloud to fix this.")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: syncService.syncStatus.icon)
                                .foregroundStyle(.secondary)
                            Text(syncService.syncStatus.description)
                                .font(.callout).foregroundStyle(.secondary)
                            Spacer()
                            if let date = syncService.lastSyncDate {
                                Text("Last synced \(date.formatted(.relative(presentation: .named)))")
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            } header: {
                Text("iCloud Sync")
            } footer: {
                Text("Requires iCloud Drive to be enabled in System Settings → Apple ID.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // MARK: Local Network Sync Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync over Local Wi-Fi")
                        Text("Sync vaults directly with another Mac on your network without internet.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.p2pSyncEnabled)
                        .toggleStyle(.switch).labelsHidden()
                }

                if settings.p2pSyncEnabled {
                    TextField("Device Name", text: $settings.p2pDeviceName)
                        .textFieldStyle(.roundedBorder)

                    Button("Sync with Nearby Mac…") {
                        showP2PDiscovery = true
                    }
                }
            } header: {
                Text("Local Network Sync")
            } footer: {
                Text("Your vault is sent fully encrypted. You must use the same master password on both Macs.")
                    .font(.caption).foregroundStyle(.secondary)
            }

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

            // MARK: Activity Log Section
            Section {
                Toggle("Enable Activity Log", isOn: $settings.auditLogEnabled)
                
                if settings.auditLogEnabled {
                    Button("View Activity Log…") {
                        showAuditLog = true
                    }
                    
                    HStack {
                        Image(systemName: "info.circle").foregroundStyle(.secondary)
                        Text("The log is encrypted with your vault key and stores the last 1,000 events.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Activity Log")
            } footer: {
                Text("Records vault operations (unlocks, copies, changes) to help you detect unexpected access.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // MARK: Screen Protection Section
            Section {
                Toggle("Hide passwords during screen capture", isOn: $settings.screenCaptureProtection)
                Toggle("Lock vault when screen sharing starts", isOn: $settings.lockOnScreenShare)
                    .disabled(!settings.screenCaptureProtection)
            } header: {
                Text("Screen Protection")
            } footer: {
                Text("When enabled, password fields are hidden if a screen recording or screen share is detected. Locking provides maximum protection.")
                    .font(.caption).foregroundStyle(.secondary)
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

            // MARK: Menu Bar Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show menu bar icon")
                        Text("Quick access to your passwords from the menu bar.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.showMenuBarIcon)
                        .toggleStyle(.switch).labelsHidden()
                        .onChange(of: settings.showMenuBarIcon) { _, enabled in
                            if enabled {
                                MenuBarManager.shared.setup()
                            } else {
                                MenuBarManager.shared.teardown()
                            }
                        }
                }
            } header: {
                Text("Menu Bar")
            }

            // MARK: Emergency Access Section
            if VaultManager.shared.isUnlocked {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Emergency Access")
                            Text(settings.inheritanceEnabled
                                 ? "Active — backup after \(settings.inheritanceInactivityDays) days inactive"
                                 : "Not configured")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: settings.inheritanceEnabled ? "checkmark.shield.fill" : "shield")
                            .foregroundStyle(settings.inheritanceEnabled ? .green : .secondary)
                    }
                    Button("Configure Emergency Access…") {
                        showInheritanceSetup = true
                    }
                } header: {
                    Text("Emergency Access")
                }
            }

            // MARK: Advanced Security Section
            if VaultManager.shared.isUnlocked && !VaultManager.shared.isDuressMode {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Decoy Vault")
                            Text(VaultManager.shared.duressVaultExists
                                 ? "Active — a secondary vault opens with your decoy password"
                                 : "Set up a secondary vault that opens with a different password")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: VaultManager.shared.duressVaultExists
                              ? "checkmark.shield.fill" : "shield")
                            .foregroundStyle(VaultManager.shared.duressVaultExists ? .green : .secondary)
                    }
                    Button("Configure Decoy Vault…") {
                        showDuressSetup = true
                    }
                } header: {
                    Text("Advanced Security")
                }
            }

            // MARK: Developer Section
            #if DEBUG
            Section("Developer") {
                Button("Reset Onboarding") {
                    AppSettings.shared.hasCompletedOnboarding = false
                }
                .foregroundStyle(.red)
            }
            #endif

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
        .sheet(isPresented: $showDuressSetup) {
            DuressModeSetupView().environmentObject(VaultManager.shared)
        }
        .sheet(isPresented: $showP2PDiscovery) {
            P2PDiscoveryView()
        }
        .sheet(isPresented: $showInheritanceSetup) {
            InheritanceSetupView()
        }
        .sheet(isPresented: $showAuditLog) {
            AuditLogView()
        }
    }

    // MARK: - Helpers

    @State private var showUnlockRequiredAlert: Bool = false
    @State private var biometricError: String? = nil
    @State private var showDuressSetup: Bool = false
    @State private var showP2PDiscovery: Bool = false
    @State private var showInheritanceSetup: Bool = false
    @State private var showAuditLog: Bool = false

    private var biometricBinding: Binding<Bool> {
        Binding(
            get: { AppSettings.shared.isBiometricEnabled },
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