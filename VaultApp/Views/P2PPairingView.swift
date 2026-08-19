import SwiftUI

struct P2PPairingView: View {

    @EnvironmentObject var service: P2PSyncService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "network")
                .font(.system(size: 48)).foregroundStyle(.blue)

            Text("Verify Pairing Code")
                .font(.title2).fontWeight(.semibold)

            Text("Make sure this code matches the one shown on the other Mac:")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // 6-digit code display
            if let code = service.pairingCode {
                Text(code)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .tracking(12)
                    .foregroundStyle(.primary)
            } else {
                ProgressView()
            }

            // Accept/Decline if incoming
            if service.incomingRequest != nil {
                HStack(spacing: 20) {
                    Button("Decline") {
                        service.declinePairing()
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Accept Sync") {
                        service.confirmPairing()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            } else {
                switch service.syncStatus {
                case .pairing:
                    Text("Waiting for the other Mac to confirm…")
                        .font(.caption).foregroundStyle(.secondary)
                case .syncing:
                    HStack { ProgressView().controlSize(.small); Text("Syncing vault…") }
                case .success:
                    Label("Sync complete!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green).font(.headline)
                case .error(let msg):
                    Text(msg).font(.caption).foregroundStyle(.red)
                default:
                    EmptyView()
                }
            }

            if case .success = service.syncStatus {
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding(32)
        .frame(width: 380, height: 360)
    }
}
