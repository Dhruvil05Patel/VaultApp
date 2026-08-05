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
    }

    // MARK: - Helpers

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