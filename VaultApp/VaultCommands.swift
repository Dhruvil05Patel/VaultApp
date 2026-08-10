import SwiftUI

struct VaultCommands: Commands {
    var body: some Commands {

        // MARK: File Menu additions
        CommandGroup(after: .newItem) {
            Button("New Password Entry") {
                NotificationCenter.default.post(name: .addNewItem, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        // MARK: View Menu
        CommandMenu("Vault") {
            Button("Lock Vault") {
                VaultManager.shared.lock()
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .disabled(!VaultManager.shared.isUnlocked)

            Divider()

            Button("Password Generator") {
                NotificationCenter.default.post(name: .openGenerator, object: nil)
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])

            Button("Import Passwords…") {
                NotificationCenter.default.post(name: .openImport, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            Button("Export / Backup Vault…") {
                NotificationCenter.default.post(name: .openExport, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Divider()

            Button("Lock and Quit") {
                VaultManager.shared.lock()
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command, .shift])
        }
    }
}

// MARK: Notification Names

extension Notification.Name {
    static let addNewItem    = Notification.Name("VaultApp.addNewItem")
    static let openGenerator = Notification.Name("VaultApp.openGenerator")
    static let openImport    = Notification.Name("VaultApp.openImport")
    static let openExport    = Notification.Name("VaultApp.openExport")
}