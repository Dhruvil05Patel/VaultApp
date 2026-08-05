import AppKit
import Foundation

enum ClipboardService {

    // Copy a string to the clipboard.
    // Automatically schedules a clear after AppSettings.shared.clipboardClearDelay seconds.
    static func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)

        let delay = AppSettings.shared.clipboardClearDelay
        guard delay > 0 else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + Double(delay)) {
            // Only clear if our value is still on the clipboard
            // (don't erase something the user copied afterwards)
            if NSPasteboard.general.string(forType: .string) == string {
                NSPasteboard.general.clearContents()
            }
        }
    }
}