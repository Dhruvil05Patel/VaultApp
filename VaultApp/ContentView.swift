import SwiftUI

struct ContentView: View {
    @State private var masterPassword = ""
    @State private var isUnlocked = false

    var body: some View {
        if isUnlocked {
            Text("Vault is open! 🔓") // placeholder for now
        } else {
            VStack(spacing: 20) {
                Text("🔐 VaultApp")
                    .font(.largeTitle)
                    .bold()

                SecureField("Master Password", text: $masterPassword)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)

                Button("Unlock") {
                    if masterPassword == "test123" { // hardcoded for now
                        isUnlocked = true
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(40)
        }
    }
}
