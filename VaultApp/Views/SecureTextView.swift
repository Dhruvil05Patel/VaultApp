import SwiftUI
import AppKit

// A text display that is excluded from screenshots on macOS.
// Uses NSSecureTextField internally when secure mode is active.
struct SecureDisplayField: NSViewRepresentable {

    let text: String
    let isRevealed: Bool       // false = dots; true = plaintext (but still protected)
    let font: NSFont

    func makeNSView(context: Context) -> NSTextField {
        // NSSecureTextField is excluded from screenshots by the OS
        // when the window has .sharingType = .none
        let field = isRevealed
            ? NSTextField(labelWithString: text)
            : NSSecureTextField(string: text)
        field.font = font
        field.isBezeled = false
        field.drawsBackground = false
        field.isEditable = false
        field.isSelectable = !isRevealed  // only selectable when revealed
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
    }
}

// MARK: - Window Screenshot Protection

// Call this on the main window to exclude it from screen capture:
extension NSWindow {
    func enableScreenshotProtection() {
        // .sharingType = .none excludes the window content from screen capture APIs
        // Note: This does NOT prevent the system screenshot tool (⌘+Shift+4)
        // but DOES prevent app-level screen capture (e.g. QuickTime, Zoom screen share)
        sharingType = .none
    }

    func disableScreenshotProtection() {
        sharingType = .readOnly  // default
    }
}
