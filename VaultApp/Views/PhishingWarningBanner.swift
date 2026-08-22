import SwiftUI

struct PhishingWarningBanner: View {

    let result: AntiPhishingService.CheckResult
    let onOpenCorrectSite: () -> Void
    let onDismiss: () -> Void

    private var bannerColor: Color {
        switch result.confidence {
        case .high:   return .red
        case .medium: return .orange
        case .low:    return .yellow
        }
    }

    private var bannerIcon: String {
        switch result.confidence {
        case .high:   return "exclamationmark.shield.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .low:    return "info.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: bannerIcon)
                    .foregroundStyle(bannerColor)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.reason?.title ?? "Domain Mismatch")
                        .font(.callout).fontWeight(.semibold)
                        .foregroundStyle(bannerColor)

                    // Domain comparison
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clipboard").font(.caption2).foregroundStyle(.secondary)
                            Text(result.detectedHost)
                                .font(.system(.callout, design: .monospaced))
                                .foregroundStyle(bannerColor)
                        }

                        Image(systemName: "arrow.right")
                            .font(.caption).foregroundStyle(.tertiary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Stored").font(.caption2).foregroundStyle(.secondary)
                            Text(result.storedHost)
                                .font(.system(.callout, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                    }
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }

            // Description
            if let reason = result.reason {
                Text(reason.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Action buttons
            HStack(spacing: 10) {
                Button("Open Correct Site") {
                    onOpenCorrectSite()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Navigate to the correct site in your browser")

                Button("Ignore This Warning") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(bannerColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(bannerColor.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    PhishingWarningBanner(
        result: AntiPhishingService.CheckResult(
            isSuspicious: true,
            storedHost: "paypal.com",
            detectedHost: "paypa1.com",
            reason: .typosquatting,
            confidence: .high
        ),
        onOpenCorrectSite: {},
        onDismiss: {}
    )
    .frame(width: 440)
    .padding()
}
