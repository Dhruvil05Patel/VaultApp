import SwiftUI

// Placeholder — replaced by Task 08
struct ItemDetailView: View {
    let item: VaultItem

    @EnvironmentObject var vaultManager: VaultManager

    var body: some View {
        Text("Detail view for \(item.title) — coming in Task 08")
    }
}
