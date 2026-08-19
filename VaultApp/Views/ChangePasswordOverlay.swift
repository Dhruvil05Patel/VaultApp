import SwiftUI

struct ChangePasswordOverlay: View {

    let item: VaultItem
    @Binding var newPassword: String
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    @State private var copied: Bool = false
    @State private var showPassword: Bool = true
    @State private var showGenerator: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("New Password for \(item.title)", systemImage: "key.fill")
                    .font(.callout).fontWeight(.semibold)
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }

            // Steps
            HStack(alignment: .top, spacing: 12) {
                stepBadge("1")
                Text("Find the **Change Password** field on the page above")
                    .font(.callout)
            }
            HStack(alignment: .top, spacing: 12) {
                stepBadge("2")
                Text("Enter your current password: ")
                    .font(.callout)
                + Text(item.password)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.orange)
            }
            HStack(alignment: .top, spacing: 12) {
                stepBadge("3")
                VStack(alignment: .leading, spacing: 6) {
                    Text("Copy and paste this new password:").font(.callout)
                    HStack(spacing: 8) {
                        Text(showPassword ? newPassword : String(repeating: "•", count: 16))
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(1)
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }.buttonStyle(.plain)
                        Button {
                            ClipboardService.copy(newPassword)
                            withAnimation { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { copied = false }
                            }
                        } label: {
                            Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .tint(copied ? .green : .accentColor)
                        Button { showGenerator = true } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Generate a different password")
                    }
                }
            }

            Divider()

            HStack {
                Text("After the site accepts the new password, click:")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("✓ I Changed It — Update Vault") { onConfirm() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(Material.regular)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
        .sheet(isPresented: $showGenerator) {
            GeneratorView { generated in newPassword = generated }
        }
    }

    @ViewBuilder
    private func stepBadge(_ number: String) -> some View {
        ZStack {
            Circle().fill(Color.accentColor).frame(width: 22, height: 22)
            Text(number).font(.caption.bold()).foregroundStyle(.white)
        }
    }
}
