import SwiftUI

struct EmptyStateView: View {

    let icon: String
    var iconColor: Color = .secondary
    let title: String
    let message: String
    var actionLabel: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(iconColor.opacity(0.5))

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            if let label = actionLabel, let action {
                Button(label, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preview

#Preview {
    EmptyStateView(
        icon: "lock.open.fill",
        iconColor: .blue,
        title: "Your vault is empty",
        message: "Add your first password to get started.",
        actionLabel: "Add Password",
        action: {}
    )
    .frame(width: 400, height: 300)
}
