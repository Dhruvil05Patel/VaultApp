import Foundation
import AppKit
import Combine

// Detects screen recording / sharing and responds per user settings.
@MainActor
final class ScreenProtectionService: ObservableObject {

    static let shared = ScreenProtectionService()

    @Published var isScreenBeingCaptured: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var captureTimer: Timer?

    private init() {}

    // MARK: - Start Monitoring

    func start() {
        // Poll every 2 seconds — macOS does not have a push notification for this
        captureTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkCaptureStatus()
            }
        }

        // Also observe display mirroring changes
        NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification
        )
        .sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkCaptureStatus()
            }
        }
        .store(in: &cancellables)
    }

    func stop() {
        captureTimer?.invalidate()
        captureTimer = nil
        cancellables.removeAll()
    }

    // MARK: - Check

    private func checkCaptureStatus() {
        // CGDisplayStreamCreate indicates an active screen recording session
        // The most reliable detection on macOS is checking NSScreen.screens for capture state
        let wasCaptured = isScreenBeingCaptured
        isScreenBeingCaptured = NSScreen.screens.contains { screen in
            // `displaysReconfigured` notification fires, but actual capture check:
            screen.safeAreaInsets.top != 0 || screen.safeAreaInsets.bottom != 0 || screen.safeAreaInsets.left != 0 || screen.safeAreaInsets.right != 0
        }

        // More reliable: check CGSessionCopyCurrentDictionary for screen lock state
        // For screen RECORDING detection, use:
        isScreenBeingCaptured = CGDisplayIsInMirrorSet(CGMainDisplayID()) != 0

        // On macOS 12.3+, check the capture indicator
        if #available(macOS 12.3, *) {
            isScreenBeingCaptured = NSScreen.screens.contains {
                $0.safeAreaInsets.top > 0  // menu bar camera indicator active
            }
        }

        // React to change
        if isScreenBeingCaptured && !wasCaptured {
            handleCaptureStarted()
        } else if !isScreenBeingCaptured && wasCaptured {
            NotificationCenter.default.post(name: .screenCaptureStopped, object: nil)
        }
    }

    // MARK: - Handle Capture Start

    private func handleCaptureStarted() {
        guard AppSettings.shared.screenCaptureProtection else { return }

        if AppSettings.shared.lockOnScreenShare {
            VaultManager.shared.lock()
        } else {
            // Post notification for views to hide sensitive fields
            NotificationCenter.default.post(name: .screenCaptureStarted, object: nil)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let screenCaptureStarted = Notification.Name("VaultApp.screenCaptureStarted")
    static let screenCaptureStopped = Notification.Name("VaultApp.screenCaptureStopped")
}
