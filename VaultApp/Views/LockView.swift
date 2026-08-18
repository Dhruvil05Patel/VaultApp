import SwiftUI

struct LockView: View {

    @EnvironmentObject var vaultManager: VaultManager

    // Local form state
    @State private var masterPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var hasFailedOnce: Bool = false
    enum LockField: Hashable { case password, confirm }
    @FocusState private var focusedField: LockField?

    // Computed: are we creating a new vault or unlocking an existing one?
    private var isCreatingVault: Bool {
        !vaultManager.vaultExists
    }

    private var canUseBiometrics: Bool {
        !isCreatingVault && BiometricService.isAvailable() && AppSettings.shared.isBiometricEnabled
    }

    private var biometricName: String {
        BiometricService.biometricName()
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

    private var isAuthenticating: Bool {
        vaultManager.authenticationState == .authenticating
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
                        show: showPassword,
                        field: .password
                    )

                    if isCreatingVault {
                        passwordField(
                            label: "Confirm Password",
                            text: $confirmPassword,
                            show: showPassword,
                            field: .confirm
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
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(error)
                                    .font(.callout)
                                    .foregroundStyle(.red)
                                // Show "Forgot password?" hint after a failed attempt
                                if !isCreatingVault && hasFailedOnce {
                                    Text("Forgot your master password? VaultApp cannot recover it, but you can restore from a backup.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                vaultManager.clearError()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
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
                    .disabled(!isFormValid || vaultManager.isLoading || isAuthenticating)
                    .keyboardShortcut(.return, modifiers: [])
                }
                .padding(24)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                .frame(maxWidth: 360)

                // Biometric unlock button / authenticating state
                if canUseBiometrics && !isCreatingVault {
                    VStack(spacing: 8) {
                        Button(action: unlockWithBiometrics) {
                            Label(
                                isAuthenticating ? "Authenticating…" : "Unlock with \(biometricName)",
                                systemImage: "touchid"
                            )
                            .font(.callout)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: 360)
                        .disabled(vaultManager.isLoading || isAuthenticating)
                        .accessibilityHint("Uses your fingerprint to unlock the vault without entering your password")
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding()
        }
        .onAppear {
            print("[LOCKVIEW] onAppear, isCreatingVault = \(isCreatingVault), authenticationState = \(vaultManager.authenticationState)")
            vaultManager.clearError()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .password
            }
        }
        .onChange(of: vaultManager.errorMessage) { _, newError in
            if newError != nil {
                hasFailedOnce = true
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func passwordField(label: String, text: Binding<String>, show: Bool, field: LockField) -> some View {
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
            .focused($focusedField, equals: field)
            .onSubmit {
                if isCreatingVault && field == .password {
                    focusedField = .confirm
                } else {
                    primaryAction()
                }
            }
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
        print("[LOCKVIEW] unlockWithBiometrics() button tapped")
        vaultManager.authenticateForUnlock()
    }
}

// MARK: - Preview

#Preview {
    LockView()
        .environmentObject(VaultManager())
        .frame(width: 500, height: 500)
}
