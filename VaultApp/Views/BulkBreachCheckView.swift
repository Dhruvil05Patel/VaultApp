import SwiftUI

struct BulkBreachCheckView: View {

    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) private var dismiss

    @State private var isRunning: Bool = false
    @State private var progress: Int = 0
    @State private var total: Int = 0
    @State private var results: [UUID: BreachCheckService.BreachResult] = [:]
    @State private var error: String? = nil
    @State private var isDone: Bool = false

    // Only login items have passwords worth checking — skip cards, notes, identity.
    private var checkableItems: [VaultItem] {
        vaultManager.vault.items.filter { $0.category == .login }
    }

    private var breachedItems: [VaultItem] {
        vaultManager.vault.items.filter { results[$0.id]?.isBreached == true }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Breach Check")
                    .font(.headline)
                Spacer()
                if isDone || !isRunning {
                    Button("Done") { dismiss() }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    if !isRunning && !isDone {
                        // Start screen
                        startScreen
                    } else if isRunning {
                        // Progress screen
                        progressScreen
                    } else {
                        // Results screen
                        resultsScreen
                    }

                    if let error {
                        VStack(spacing: 10) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 32))
                                .foregroundStyle(.orange)
                            Text("Breach check interrupted")
                                .font(.headline)
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Text("Partial results above may be incomplete. Run the check again when your connection is stable.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                runBulkCheck()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 440, minHeight: 400)
    }

    // MARK: - Start Screen

    @ViewBuilder
    private var startScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 52))
                .foregroundStyle(.blue)

            Text("Check \(checkableItems.count) passwords")
                .font(.title3)
                .fontWeight(.semibold)

            Text("This will check each password against the HaveIBeenPwned database using the k-anonymity model. Only an anonymous partial hash is sent — your passwords never leave this device.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("⏱ This takes about \(estimatedTime) due to rate limiting.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Start Check") {
                runBulkCheck()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Progress Screen

    @ViewBuilder
    private var progressScreen: some View {
        VStack(spacing: 16) {
            ProgressView(value: Double(progress), total: Double(max(total, 1)))
                .progressViewStyle(.linear)
                .tint(.blue)

            Text("Checking \(progress) of \(total)…")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("Do not close this window.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Results Screen

    @ViewBuilder
    private var resultsScreen: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Summary
            HStack(spacing: 16) {
                summaryCard(
                    icon: "checkmark.shield.fill",
                    color: .green,
                    count: results.values.filter { !$0.isBreached }.count,
                    label: "Safe"
                )
                summaryCard(
                    icon: "exclamationmark.shield.fill",
                    color: .red,
                    count: breachedItems.count,
                    label: "Breached"
                )
            }

            if breachedItems.isEmpty {
                Label("No breached passwords found.", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            } else {
                Text("Breached Passwords")
                    .font(.headline)

                ForEach(breachedItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .fontWeight(.medium)
                            Text(item.username)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let result = results[item.id] {
                            BreachBadge(status: .breached, count: result.count, style: .compact)
                        }
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Text("Change these passwords immediately. Use the Password Generator to create strong replacements.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func summaryCard(icon: String, color: Color, count: Int, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Logic

    private var estimatedTime: String {
        let seconds = checkableItems.count * 2
        if seconds < 60 { return "\(seconds) seconds" }
        return "\(seconds / 60) minutes"
    }

    private func runBulkCheck() {
        isRunning = true
        error = nil
        let items = checkableItems
        total = items.count
        progress = 0
        results = [:]

        Task {
            do {
                let checkResults = try await BreachCheckService.checkAll(
                    items: items,
                    progress: { completed, total in
                        Task { @MainActor in
                            self.progress = completed
                            self.total = total
                        }
                    }
                )

                await MainActor.run {
                    self.results = checkResults
                    // Update breach status on all vault items
                    for item in items {
                        if let result = checkResults[item.id] {
                            var updated = item
                            updated.breachStatus    = result.isBreached ? .breached : .safe
                            updated.breachCount     = result.count
                            updated.breachCheckedAt = Date()
                            vaultManager.updateItem(updated)
                        }
                    }
                    self.isRunning = false
                    self.isDone = true
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isRunning = false
                }
            }
        }
    }
}