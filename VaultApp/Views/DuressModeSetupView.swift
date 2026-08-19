import SwiftUI

struct DuressModeSetupView: View {

    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) private var dismiss

    @State private var duressPassword: String = ""
    @State private var confirmDuressPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var isCreating: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showDeleteConfirm: Bool = false

    private var passwordsMatch: Bool { duressPassword == confirmDuressPassword }
    private var isValid: Bool { duressPassword.count >= 8 && passwordsMatch }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if vaultManager.duressVaultExists {
                        existingDuressContent
                    } else {
                        setupContent
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 460, minHeight: 420)
        .confirmationDialog("Delete Decoy Vault?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) { vaultManager.deleteDuressVault() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The decoy vault and all its entries will be permanently deleted.")
        }
    }

    // MARK: - Header

    @ViewBuilder private var header: some View {
        HStack {
            Text("Decoy Vault")
                .font(.headline)
            Spacer()
            Button("Done") { dismiss() }
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
    }

    // MARK: - Setup (no duress vault yet)

    @ViewBuilder private var setupContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("How Decoy Vault Works", systemImage: "shield.lefthalf.filled")
                .font(.headline)

            Text("Set a second password. If you enter this password at the lock screen, a separate empty vault opens — not your real one. Add fake entries to make it convincing.")
                .font(.callout).foregroundStyle(.secondary)

            warningBox("Your real vault remains hidden and inaccessible when the decoy is open. There is no visual indicator that a decoy is active.")

            Divider()

            formField("Decoy Password", binding: $duressPassword)
            formField("Confirm Decoy Password", binding: $confirmDuressPassword)

            if !confirmDuressPassword.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(passwordsMatch ? .green : .red)
                    Text(passwordsMatch ? "Passwords match" : "Passwords do not match")
                        .font(.caption)
                        .foregroundStyle(passwordsMatch ? .green : .red)
                }
            }

            warningBox("⚠️  Choose a password that is different from your master password and is plausible if inspected. Do not use a password you use anywhere else.")

            if let error = errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            Button {
                createDecoyVault()
            } label: {
                Group {
                    if isCreating {
                        HStack { ProgressView().controlSize(.small); Text("Creating…") }
                    } else {
                        Text("Create Decoy Vault").frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValid || isCreating)
        }
    }

    // MARK: - Existing duress vault

    @ViewBuilder private var existingDuressContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill").foregroundStyle(.green).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Decoy Vault Active").font(.headline)
                    Text("A decoy vault is set up. Add fake entries to it by logging in with your decoy password.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(Color.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text("Tips for a convincing decoy vault:")
                .font(.callout).fontWeight(.medium)

            VStack(alignment: .leading, spacing: 8) {
                tipRow("Add 8–12 real-looking entries (Gmail, Netflix, a bank)")
                tipRow("Include entries you wouldn't mind being seen (Wi-Fi password, streaming services)")
                tipRow("Do NOT add your real financial or work credentials")
                tipRow("Use realistic-looking passwords — not just 'password123'")
                tipRow("Add a few old entries with outdated passwords to seem authentic")
            }

            Divider()

            Button("Delete Decoy Vault", role: .destructive) {
                showDeleteConfirm = true
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.red)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func formField(_ label: String, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Group {
                if showPassword {
                    TextField(label, text: binding)
                } else {
                    SecureField(label, text: binding)
                }
            }
            .textFieldStyle(.roundedBorder)
        }
    }

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

    @ViewBuilder
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(.secondary).padding(.top, 6)
            Text(text).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func createDecoyVault() {
        isCreating = true
        errorMessage = nil
        Task {
            do {
                try await vaultManager.createDuressVault(duressPassword: duressPassword)
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            await MainActor.run { isCreating = false }
        }
    }
}
