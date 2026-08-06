import SwiftUI

struct LockView: View {

    @EnvironmentObject var vaultManager: VaultManager

    // Local form state
    @State private var masterPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    @FocusState private var passwordFieldFocused: Bool
    @State private var biometricError: String? = nil

    // Computed: are we creating a new vault or unlocking an existing one?
    private var isCreatingVault: Bool {
        !vaultManager.vaultExists
    }

    private var showBiometricButton: Bool {
        !isCreatingVault &&
        BiometricService.isAvailable() &&
        BiometricService.hasStoredKey()
    }

    // Validation for the create flow
    private var passwordsMatch: Bool {
        masterPassword == confirmPassword
    }

    private var isFormValid: Bool {
        if isCreatingVault {
            return masterPassword.count >= 8 && passwordsMatch
        } else {
            return !masterPassword.isEmpty
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App icon + title
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .foregroundStyle(.blue)

                    Text("VaultApp")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text(isCreatingVault ? "Create your master password" : "Enter your master password")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 32)

                // Form card
                VStack(spacing: 16) {
                    passwordField(
                        label: "Master Password",
                        text: $masterPassword,
                        show: showPassword
                    )

                    if isCreatingVault {
                        passwordField(
                            label: "Confirm Password",
                            text: $confirmPassword,
                            show: showPassword
                        )

                        // Password match feedback
                        if !confirmPassword.isEmpty {
                            HStack {
                                Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(passwordsMatch ? .green : .red)
                                Text(passwordsMatch ? "Passwords match" : "Passwords do not match")
                                    .font(.caption)
                                    .foregroundStyle(passwordsMatch ? .green : .red)
                                Spacer()
                            }
                        }

                        // Minimum length hint
                        if masterPassword.count < 8 && !masterPassword.isEmpty {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.orange)
                                Text("Must be at least 8 characters (\(masterPassword.count)/8)")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Spacer()
                            }
                        }
                    }

                    // Toggle show/hide password
                    Toggle(isOn: $showPassword) {
                        Label("Show password", systemImage: showPassword ? "eye.slash" : "eye")
                            .font(.caption)
                    }
                    .toggleStyle(.checkbox)
                    .padding(.top, 4)

                    // Error message from VaultManager
                    if let error = vaultManager.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .padding(10)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Primary action button
                    Button(action: primaryAction) {
                        Group {
                            if vaultManager.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text(isCreatingVault ? "Create Vault" : "Unlock")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!isFormValid || vaultManager.isLoading)
                    .keyboardShortcut(.return, modifiers: [])
                }
                .padding(24)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                .frame(maxWidth: 360)

                // Biometric unlock button
                if showBiometricButton {
                    VStack(spacing: 8) {
                        Button(action: unlockWithBiometrics) {
                            Label(
                                "Unlock with \(BiometricService.biometricName())",
                                systemImage: "touchid"
                            )
                            .font(.callout)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: 360)

                        if let bioError = biometricError {
                            Text(bioError)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding()
        }
        .onAppear {
            vaultManager.clearError()
            passwordFieldFocused = true
            // Auto-prompt Touch ID if available and enabled
            if showBiometricButton {
                unlockWithBiometrics()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func passwordField(label: String, text: Binding<String>, show: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Group {
                if show {
                    TextField(label, text: text)
                } else {
                    SecureField(label, text: text)
                }
            }
            .textFieldStyle(.roundedBorder)
            .focused($passwordFieldFocused)
        }
    }

    // MARK: - Actions

    private func primaryAction() {
        if isCreatingVault {
            vaultManager.createVault(masterPassword: masterPassword)
        } else {
            vaultManager.unlock(masterPassword: masterPassword)
        }
    }

    private func unlockWithBiometrics() {
        biometricError = nil
        Task {
            do {
                let keyData = try await BiometricService.retrieveKey(reason: "Unlock VaultApp")
                await MainActor.run {
                    vaultManager.unlockWithBiometricKey(keyData)
                }
            } catch {
                await MainActor.run {
                    biometricError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LockView()
        .environmentObject(VaultManager())
        .frame(width: 500, height: 500)
}
