import SwiftUI

struct P2PDiscoveryView: View {

    @StateObject private var service = P2PSyncService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showPairing: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sync with Nearby Mac")
                    .font(.headline)
                Spacer()
                Button("Done") { service.stop(); dismiss() }
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
            Divider()

            VStack(spacing: 20) {
                // Status
                statusSection

                Divider()

                // Discovered peers
                if service.discoveredPeers.isEmpty {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Looking for VaultApp on your network…")
                            .font(.callout).foregroundStyle(.secondary)
                        Text("Make sure both Macs are on the same Wi-Fi network and VaultApp is open.")
                            .font(.caption).foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(32)
                } else {
                    List(service.discoveredPeers) { peer in
                        HStack {
                            Image(systemName: "laptopcomputer")
                                .foregroundStyle(.blue)
                            Text(peer.name)
                                .font(.callout).fontWeight(.medium)
                            Spacer()
                            Button("Sync") {
                                service.connect(to: peer)
                                showPairing = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .padding(.horizontal, 24).padding(.top, 16)
        }
        .frame(minWidth: 420, minHeight: 380)
        .onAppear { service.startAdvertising(); service.startBrowsing() }
        .onChange(of: service.incomingRequest) { newValue in
            if newValue != nil {
                showPairing = true
            }
        }
        .sheet(isPresented: $showPairing) {
            P2PPairingView().environmentObject(service)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(service.syncStatus == .advertising ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(service.syncStatus == .advertising
                 ? "This Mac is visible to other VaultApp devices"
                 : "Starting…")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
