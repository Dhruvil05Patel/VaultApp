import SwiftUI

struct InheritanceSetupView: View {

    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isCreatingPackage: Bool = false
    @State private var packageURL: URL? = nil
    @State private var packageError: String? = nil

    private let thresholdOptions = [30, 60, 90, 180]
    private let graceOptions = [7, 14, 30]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Emergency Access")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding(.horizontal, 24).padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    explanationSection
                    Divider()
                    configSection
                    Divider()
                    statusSection
                    Divider()
                    manualPackageSection
                }
                .padding(24)
            }
        }
        .frame(minWidth: 480, minHeight: 580)
    }

    // MARK: - Explanation

    @ViewBuilder
    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("How Emergency Access Works", systemImage: "person.2.badge.key.fill")
                .font(.headline)

            Text("If you don't open VaultApp for a set period, a reminder is shown. After a grace period, an encrypted backup is automatically saved to your iCloud Drive or Desktop so your trusted contact can access your accounts.")
                .font(.callout).foregroundStyle(.secondary)

            warningBox("You must share your master password with your trusted contact in advance — on paper, in a sealed envelope, or in a safety deposit box. Never store it digitally.")

            warningBox("The backup is fully encrypted. Without your master password it is unreadable, even for Apple.")
        }
    }

    // MARK: - Config

    @ViewBuilder
    private var configSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Enable Emergency Access", isOn: $settings.inheritanceEnabled)
                .toggleStyle(.switch).font(.callout)

            if settings.inheritanceEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trigger after inactivity of:")
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $settings.inheritanceInactivityDays) {
                        ForEach(thresholdOptions, id: \.self) { days in
                            Text("\(days) days").tag(days)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Grace period after reminder:")
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $settings.inheritanceGraceDays) {
                        ForEach(graceOptions, id: \.self) { days in
                            Text("\(days) days").tag(days)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Text("After the grace period expires, a backup is automatically saved. Simply opening VaultApp resets the timer.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusSection: some View {
        if settings.inheritanceEnabled {
            VStack(alignment: .leading, spacing: 8) {
                Text("Status").font(.callout).fontWeight(.medium)

                if let last = settings.lastVaultActivityDate {
                    let days = Calendar.current.dateComponents(
                        [.day], from: last, to: Date()).day ?? 0
                    let remaining = settings.inheritanceInactivityDays - days

                    HStack(spacing: 8) {
                        Image(systemName: remaining > 14 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(remaining > 14 ? .green : .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(remaining > 0
                                 ? "Emergency access triggers in \(remaining) days of inactivity"
                                 : "Inactivity threshold reached")
                                .font(.callout)
                            Text("Last active: \(last.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("No activity recorded yet. Open the app regularly to keep the timer reset.")
                        .font(.callout).foregroundStyle(.secondary)
                }

                if let lastExport = UserDefaults.standard.object(forKey: "lastEmergencyPackageDate") as? Date {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill").foregroundStyle(.blue)
                        Text("Last automatic backup: \(lastExport.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Manual Package

    @ViewBuilder
    private var manualPackageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual Emergency Package")
                .font(.callout).fontWeight(.medium)

            Text("Create an encrypted backup now to store in a location your trusted contact can find. Attach printed master-password instructions to it.")
                .font(.caption).foregroundStyle(.secondary)

            if let url = packageURL {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Package saved").font(.callout).fontWeight(.medium)
                        Text(url.path).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }

            if let error = packageError {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            Button {
                createManualPackage()
            } label: {
                if isCreatingPackage {
                    HStack { ProgressView().controlSize(.small); Text("Creating…") }
                } else {
                    Label("Create Emergency Package Now", systemImage: "shield.fill")
                }
            }
            .buttonStyle(.bordered)
            .disabled(!VaultManager.shared.isUnlocked || isCreatingPackage)

            if !VaultManager.shared.isUnlocked {
                Text("Unlock the vault first to create a manual backup.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func warningBox(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func createManualPackage() {
        isCreatingPackage = true
        packageError = nil
        packageURL = nil
        Task {
            do {
                packageURL = try await InheritanceService.shared.prepareEmergencyPackage()
            } catch {
                packageError = error.localizedDescription
            }
            isCreatingPackage = false
        }
    }
}
