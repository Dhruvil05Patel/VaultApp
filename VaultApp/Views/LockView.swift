import SwiftUI

struct LockView: View {

    @EnvironmentObject var vaultManager: VaultManager

    // Local form state
    @State private var masterPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    @FocusState private var passwordFieldFocused: Bool
    @State private var biometricError: String? = nil
    @State private var allowBiometric: Bool = false  // prevents auto-trigger on launch
    @State private var hasAutoPrompted: Bool = false

    // Computed: are we creating a new vault or unlocking an existing one?
    private var isCreatingVault: Bool {
        !vaultManager.vaultExists
    }

    private var canUseBiometrics: Bool {
        allowBiometric && !isCreatingVault && BiometricService.isAvailable() && AppSettings.shared.isBiometricEnabled
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
                        if isAuthenticating {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.regular)
                                Text("Authenticating with \(biometricName)…")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: 360)
                        } else {
                            Button(action: unlockWithBiometrics) {
                                Label(
                                    "Unlock with \(biometricName)",
                                    systemImage: "touchid"
                                )
                                .font(.callout)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .frame(maxWidth: 360)
                            .disabled(vaultManager.isLoading)
                        }

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
            print("[LOCKVIEW] onAppear, isCreatingVault = \(isCreatingVault), authenticationState = \(vaultManager.authenticationState)")
            vaultManager.clearError()
            passwordFieldFocused = true
            biometricError = nil
            // Enable biometric after brief delay to prevent Xcode/debugger auto-trigger on launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                allowBiometric = true
                
                if canUseBiometrics && !hasAutoPrompted {
                    hasAutoPrompted = true
                    unlockWithBiometrics()
                }
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
        print("[LOCKVIEW] unlockWithBiometrics() button tapped")
        biometricError = nil
        Task {
            await vaultManager.authenticateWithBiometrics()
            // Error is now handled by VaultManager and shown via vaultManager.errorMessage
            // but we can also show it locally if needed
            await MainActor.run {
                if let error = vaultManager.errorMessage,
                   vaultManager.authenticationState == .locked {
                    biometricError = error
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
