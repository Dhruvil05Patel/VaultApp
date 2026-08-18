import SwiftUI

struct OnboardingView: View {

    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var currentPage: Int = 0

    // Total number of onboarding pages
    private let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            // Page content — animated view switch
            Group {
                switch currentPage {
                case 0:
                    pageOne
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case 1:
                    pageTwo
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case 2:
                    pageThree
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                default:
                    EmptyView()
                }
            }
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: currentPage)
            .frame(minHeight: 360)

            Divider()

            // Navigation footer
            footer
        }
        .frame(width: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .interactiveDismissDisabled(true)
    }

    // MARK: - Page 1: Welcome

    @ViewBuilder
    private var pageOne: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, 8)

            Text("Welcome to VaultApp")
                .font(.system(size: 26, weight: .bold, design: .rounded))

            Text("A secure, offline-first password manager built for macOS. Your passwords never leave your Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            // Key points
            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "lock.fill", color: .blue,
                           title: "AES-256-GCM Encryption",
                           detail: "Military-grade encryption before anything touches disk")
                featureRow(icon: "icloud.slash.fill", color: .purple,
                           title: "100% Offline",
                           detail: "No cloud, no account, no servers — your data stays local")
                featureRow(icon: "eye.slash.fill", color: .green,
                           title: "Zero Knowledge",
                           detail: "Your master password is never stored, not even as a hash")
            }
            .padding(.horizontal, 40)
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }

    // MARK: - Page 2: How it works

    @ViewBuilder
    private var pageTwo: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "key.fill")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, 8)

            Text("How Your Vault is Protected")
                .font(.system(size: 26, weight: .bold, design: .rounded))

            Text("Understanding how VaultApp keeps your data safe.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Encryption flow diagram
            VStack(spacing: 0) {
                flowStep(number: "1", icon: "person.fill",
                         title: "You enter your master password",
                         detail: "Only you know it. It is never stored anywhere.")
                flowArrow
                flowStep(number: "2", icon: "function",
                         title: "PBKDF2 derives a 256-bit key",
                         detail: "200,000 iterations + random salt. Very slow to brute-force.")
                flowArrow
                flowStep(number: "3", icon: "lock.fill",
                         title: "AES-256-GCM encrypts everything",
                         detail: "All passwords are locked inside a single encrypted file.")
                flowArrow
                flowStep(number: "4", icon: "doc.fill",
                         title: "vault.enc is saved to disk",
                         detail: "Unreadable without your master password.")
            }
            .padding(.horizontal, 32)
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }

    // MARK: - Page 3: Master Password Advice

    @ViewBuilder
    private var pageThree: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .teal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, 8)

            Text("Choose a Strong Master Password")
                .font(.system(size: 26, weight: .bold, design: .rounded))

            Text("This is the only password you'll need to remember. Make it count.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            VStack(alignment: .leading, spacing: 12) {
                adviceRow(icon: "checkmark.circle.fill", color: .green,
                          text: "Use a passphrase: 4+ random words (e.g. correct-horse-battery-staple)")
                adviceRow(icon: "checkmark.circle.fill", color: .green,
                          text: "Make it at least 16 characters long")
                adviceRow(icon: "checkmark.circle.fill", color: .green,
                          text: "Don't reuse a password you've used elsewhere")
                adviceRow(icon: "exclamationmark.triangle.fill", color: .orange,
                          text: "If you forget it, your vault cannot be recovered — by design")
                adviceRow(icon: "exclamationmark.triangle.fill", color: .orange,
                          text: "Write it down and store it somewhere physically safe until memorised")
            }
            .padding(.horizontal, 40)
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        HStack {
            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Circle()
                        .fill(i == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                        .animation(reduceMotion ? .none : .easeInOut, value: currentPage)
                }
            }

            Spacer()

            // Back button (hidden on first page)
            if currentPage > 0 {
                Button("Back") {
                    withAnimation { currentPage -= 1 }
                }
                .buttonStyle(.bordered)
            }

            // Next / Get Started
            if currentPage < pageCount - 1 {
                Button("Next →") {
                    withAnimation { currentPage += 1 }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            } else {
                Button("Get Started") {
                    settings.hasCompletedOnboarding = true
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
    }

    // MARK: - Subview Helpers

    @ViewBuilder
    private func featureRow(icon: String, color: Color,
                            title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout).fontWeight(.semibold)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func flowStep(number: String, icon: String,
                          title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.caption).foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).fontWeight(.semibold)
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var flowArrow: some View {
        Image(systemName: "arrow.down")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.leading, 16)
    }

    @ViewBuilder
    private func adviceRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).font(.callout).frame(width: 20)
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
