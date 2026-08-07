import SwiftUI
import Combine

// Displays a live TOTP code with a countdown ring.
// Self-contained — takes a Base32 secret and manages its own timer.
struct TOTPRowView: View {

    let secret: String

    @State private var code: String = "------"
    @State private var secondsRemaining: Int = 30
    @State private var copied: Bool = false
    @State private var error: String? = nil

    // Refresh every second
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Two-Factor Code", systemImage: "shield.lefthalf.filled")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                // Countdown ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: CGFloat(secondsRemaining) / 30.0)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: secondsRemaining)
                    Text("\(secondsRemaining)")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ringColor)
                }
                .frame(width: 30, height: 30)

                // Code display
                if let err = error {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text(TOTPService.formatCode(code))
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(secondsRemaining <= 5 ? .red : .primary)
                }

                Spacer()

                // Copy button
                Button {
                    ClipboardService.copy(code)
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(error != nil)
                .help("Copy 2FA code")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .onAppear { refresh() }
        .onReceive(timer) { _ in refresh() }
    }

    // MARK: - Helpers

    private func refresh() {
        do {
            let result = try TOTPService.currentCode(secret: secret)
            code = result.code
            secondsRemaining = result.secondsRemaining
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private var ringColor: Color {
        switch secondsRemaining {
        case 0...5:  return .red
        case 6...10: return .orange
        default:     return .blue
        }
    }
}

// MARK: - Preview

#Preview {
    TOTPRowView(secret: "JBSWY3DPEHPK3PXP")
        .frame(width: 360)
        .padding()
}
