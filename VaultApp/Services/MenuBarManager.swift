import AppKit
import SwiftUI
import Combine

// MenuBarManager owns the NSStatusItem and NSPopover.
// It is created once at app launch and lives for the app's lifetime.
@MainActor
final class MenuBarManager: NSObject {

    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?   // for click-outside-to-close
    private var stateCancellable: AnyCancellable?
    private var phishingCancellable: AnyCancellable?

    // MARK: - Setup

    func setup() {
        guard AppSettings.shared.showMenuBarIcon else { return }

        // Create the status bar item
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "lock.shield.fill",
            accessibilityDescription: "VaultApp"
        )
        item.button?.image?.isTemplate = true  // adapts to dark/light menu bar
        item.button?.action = #selector(togglePopover)
        item.button?.target = self
        statusItem = item

        // Create the SwiftUI popover
        let contentView = MenuBarView()
            .environmentObject(VaultManager.shared)
        let hostingController = NSHostingController(rootView: contentView)

        let popover = NSPopover()
        popover.contentSize    = NSSize(width: 320, height: 440)
        popover.behavior       = .transient  // closes when user clicks outside
        popover.animates       = true
        popover.contentViewController = hostingController
        self.popover = popover

        // Keep the icon in sync with the vault lock state even while the
        // popover/window is closed (observes the shared VaultManager).
        stateCancellable = VaultManager.shared.$authenticationState
            .sink { [weak self] state in
                Task { @MainActor in
                    self?.updateIcon(isLocked: state != .unlocked)
                }
            }

        phishingCancellable = ClipboardPhishingMonitor.shared.$currentThreat
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateIcon(isLocked: VaultManager.shared.authenticationState != .unlocked)
                }
            }
    }

    func teardown() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        popover = nil
        stateCancellable?.cancel()
        stateCancellable = nil
        phishingCancellable?.cancel()
        phishingCancellable = nil
    }

    // MARK: - Toggle

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()

            // Watch for click outside the popover to close it
            eventMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    func closePopover() {
        popover?.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Update icon to reflect lock state

    func updateIcon(isLocked: Bool) {
        let hasThreat = ClipboardPhishingMonitor.shared.currentThreat != nil

        if hasThreat {
            statusItem?.button?.image = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: "VaultApp (Phishing Warning)"
            )
            // Turn off template to allow red coloring (if supported by OS), otherwise fallback to template
            statusItem?.button?.image?.isTemplate = true
        } else {
            let symbolName = isLocked ? "lock.shield.fill" : "lock.open.fill"
            statusItem?.button?.image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: isLocked ? "VaultApp (Locked)" : "VaultApp"
            )
            statusItem?.button?.image?.isTemplate = true
        }
    }
}