import SwiftUI

// Shows a compact breach status indicator.
// Used in VaultItemRow (small) and ItemDetailView (full).
struct BreachBadge: View {

    let status: VaultItem.BreachStatus
    let count: Int
    var style: Style = .compact

    enum Style { case compact, full }

    var body: some View {
        switch status {
        case .unknown:
            EmptyView()

        case .safe:
            badge(
                icon: "checkmark.shield.fill",
                text: style == .full ? "Not found in breaches" : "",
                color: .green
            )

        case .breached:
            badge(
                icon: "exclamationmark.shield.fill",
                text: style == .full
                    ? "Found in breaches \(BreachCheckService.formatCount(count))"
                    : BreachCheckService.formatCount(count),
                color: .red
            )
        }
    }

    @ViewBuilder
    private func badge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(style == .full ? .callout : .caption2)
            if !text.isEmpty {
                Text(text)
                    .font(style == .full ? .callout : .caption2)
                    .fontWeight(.medium)
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, style == .full ? 10 : 6)
        .padding(.vertical, style == .full ? 6 : 3)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}