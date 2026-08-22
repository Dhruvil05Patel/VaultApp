import Foundation
import AppKit
import Combine

@MainActor
final class ClipboardPhishingMonitor: ObservableObject {
    static let shared = ClipboardPhishingMonitor()

    @Published var currentThreat: AntiPhishingService.CheckResult? = nil
    @Published var threatenedItemID: UUID? = nil

    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.checkClipboard()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        // Vault must be unlocked to compare against entries
        guard VaultManager.shared.isUnlocked else { return }

        let newCount = NSPasteboard.general.changeCount
        guard newCount != lastChangeCount else { return }
        lastChangeCount = newCount

        guard let clipboardContent = NSPasteboard.general.string(forType: .string),
              !clipboardContent.isEmpty else {
            clearThreat()
            return
        }

        let trimmed = clipboardContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("http") || (trimmed.contains(".") && !trimmed.contains(" ")) else {
            clearThreat()
            return
        }

        // Compare against unlocked vault items
        let items = VaultManager.shared.vault.items
        var foundThreat: AntiPhishingService.CheckResult? = nil
        var foundID: UUID? = nil

        for item in items {
            guard !item.url.isEmpty else { continue }
            let result = AntiPhishingService.check(
                storedURLString: item.url,
                detectedURLString: trimmed
            )
            if result.isSuspicious {
                foundThreat = result
                foundID = item.id
                break
            }
        }

        if let threat = foundThreat, let id = foundID {
            self.currentThreat = threat
            self.threatenedItemID = id
        } else {
            clearThreat()
        }
    }
    
    func clearThreat() {
        self.currentThreat = nil
        self.threatenedItemID = nil
    }
}
