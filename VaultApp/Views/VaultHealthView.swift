import SwiftUI

struct VaultHealthView: View {

    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) private var dismiss

    private var report: VaultHealthService.HealthReport {
        VaultHealthService.analyse(vault: vaultManager.vault)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Security Report")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    scoreSection
                    issueSection("Breached Passwords", icon: "exclamationmark.shield.fill",
                                 color: .red, items: report.breachedItems,
                                 description: "Found in data breaches. Change immediately.")
                    issueSection("Weak Passwords", icon: "lock.open.fill",
                                 color: .orange, items: report.weakPasswords,
                                 description: "Too short or too simple to resist cracking.")
                    reusedSection
                    issueSection("Old Passwords", icon: "clock.fill",
                                 color: .yellow, items: report.oldPasswords,
                                 description: "Not changed in over 6 months.")
                    issueSection("No 2FA Set Up", icon: "shield",
                                 color: .blue, items: report.missingTOTP,
                                 description: "These logins have no two-factor authentication stored.")
                }
                .padding(24)
            }
        }
        .frame(minWidth: 520, minHeight: 580)
    }

    // MARK: - Score Section

    @ViewBuilder
    private var scoreSection: some View {
        HStack(spacing: 24) {
            // Grade circle
            ZStack {
                Circle()
                    .stroke(Color(report.grade.color == "green" ? .systemGreen
                                  : report.grade.color == "blue" ? .systemBlue
                                  : report.grade.color == "yellow" ? .systemYellow
                                  : report.grade.color == "orange" ? .systemOrange
                                  : .systemRed),
                            lineWidth: 6)
                    .frame(width: 80, height: 80)
                Text(report.grade.rawValue)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Security Score: \(report.score)/100")
                    .font(.title3).fontWeight(.semibold)
                Text("\(report.totalItems) passwords analysed")
                    .font(.callout).foregroundStyle(.secondary)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2))
                            .frame(height: 8)
                        Capsule()
                            .fill(scoreColor)
                            .frame(width: geo.size.width * CGFloat(report.score) / 100, height: 8)
                    }
                }.frame(height: 8)
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var scoreColor: Color {
        switch report.score {
        case 85...100: return .green
        case 70...84:  return .blue
        case 55...69:  return .yellow
        case 40...54:  return .orange
        default:       return .red
        }
    }

    // MARK: - Issue Section

    @ViewBuilder
    private func issueSection(_ title: String, icon: String, color: Color,
                               items: [VaultItem], description: String) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: icon).foregroundStyle(color)
                    Text(title).font(.callout).fontWeight(.semibold)
                    Spacer()
                    Text("\(items.count)").font(.callout).foregroundStyle(color)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(color.opacity(0.12)).clipShape(Capsule())
                }
                Text(description).font(.caption).foregroundStyle(.secondary)
                ForEach(items) { item in
                    HStack {
                        Image(systemName: item.category.icon).foregroundStyle(color).frame(width: 20)
                        Text(item.title).font(.callout).lineLimit(1)
                        Text(item.username).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(color.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Reused Section

    @ViewBuilder
    private var reusedSection: some View {
        if !report.reusedPasswords.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc.fill").foregroundStyle(.purple)
                    Text("Reused Passwords").font(.callout).fontWeight(.semibold)
                    Spacer()
                    Text("\(report.reusedPasswords.flatMap { $0.items }.count)")
                        .font(.callout).foregroundStyle(.purple)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.purple.opacity(0.12)).clipShape(Capsule())
                }
                Text("The same password used on multiple sites. If one is breached, all are compromised.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(report.reusedPasswords, id: \.password) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Same password used on \(group.items.count) sites:")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(group.items) { item in
                            HStack {
                                Image(systemName: item.category.icon).foregroundStyle(.purple).frame(width: 20)
                                Text(item.title).font(.callout)
                                Spacer()
                            }
                            .padding(.horizontal, 10).padding(.vertical, 4)
                        }
                    }
                    .padding(10)
                    .background(Color.purple.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
