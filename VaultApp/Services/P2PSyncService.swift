import Foundation
import Network
import Combine

// P2PSyncService manages Bonjour advertisement + browsing and TCP socket transfer.
// Uses NWListener (server) and NWBrowser (discovery) from the Network framework.
@MainActor
final class P2PSyncService: ObservableObject {

    static let shared = P2PSyncService()

    // MARK: - State

    @Published var discoveredPeers: [Peer] = []
    @Published var syncStatus: SyncState = .idle
    @Published var pairingCode: String? = nil
    @Published var incomingRequest: Peer? = nil  // peer requesting to sync with us

    enum SyncState: Equatable {
        case idle
        case advertising
        case browsing
        case pairing(Peer)
        case syncing(Peer)
        case success(Peer)
        case error(String)
    }

    struct Peer: Identifiable, Equatable {
        let id: UUID
        let name: String         // device display name
        let endpoint: NWEndpoint
    }

    // MARK: - Constants

    private let serviceType  = "_vaultapp._tcp"
    private let port: NWEndpoint.Port = 52741
    private let serviceName: String

    // MARK: - Network Objects

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var activeConnection: NWConnection?

    // MARK: - Init

    private init() {
        self.serviceName = AppSettings.shared.p2pDeviceName.isEmpty
            ? Host.current().localizedName ?? "VaultApp"
            : AppSettings.shared.p2pDeviceName
    }

    // MARK: - Start Advertising (be discoverable)

    func startAdvertising() {
        guard AppSettings.shared.p2pSyncEnabled else { return }

        do {
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true

            listener = try NWListener(using: parameters, on: port)
            listener?.service = NWListener.Service(name: serviceName, type: serviceType)

            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    if state == .ready { self?.syncStatus = .advertising }
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.handleIncomingConnection(connection)
                }
            }

            listener?.start(queue: .main)
        } catch {
            syncStatus = .error("Failed to start advertising: \(error.localizedDescription)")
        }
    }

    // MARK: - Start Browsing (find peers)

    func startBrowsing() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: .bonjourWithTXTRecord(type: serviceType, domain: nil),
                            using: parameters)

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor [weak self] in
                self?.discoveredPeers = results.compactMap { result in
                    guard case .service(let name, _, _, _) = result.endpoint else { return nil }
                    return Peer(id: UUID(), name: name, endpoint: result.endpoint)
                }
            }
        }

        browser?.start(queue: .main)
    }

    // MARK: - Initiate Sync with Peer

    func connect(to peer: Peer) {
        syncStatus = .pairing(peer)
        pairingCode = generatePairingCode()

        let connection = NWConnection(to: peer.endpoint, using: .tcp)
        activeConnection = connection

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                if state == .ready {
                    self?.sendPairingCode(connection: connection, peer: peer)
                } else if case .failed(let error) = state {
                    self?.syncStatus = .error(error.localizedDescription)
                }
            }
        }
        connection.start(queue: .main)
    }

    // MARK: - Pairing Code Exchange

    private func generatePairingCode() -> String {
        String(format: "%06d", Int.random(in: 0..<1_000_000))
    }

    private func sendPairingCode(connection: NWConnection, peer: Peer) {
        guard let code = pairingCode?.data(using: .utf8) else { return }
        connection.send(content: code, completion: .contentProcessed { [weak self] error in
            if error == nil {
                Task { @MainActor [weak self] in
                    self?.waitForPairingConfirmation(connection: connection, peer: peer)
                }
            }
        })
    }

    private func waitForPairingConfirmation(connection: NWConnection, peer: Peer) {
        connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { [weak self] data, _, _, _ in
            Task { @MainActor [weak self] in
                guard let data, let response = String(data: data, encoding: .utf8) else { return }
                if response == "OK" {
                    self?.performSync(connection: connection, peer: peer)
                } else {
                    self?.syncStatus = .error("Peer declined the pairing code.")
                    connection.cancel()
                }
            }
        }
    }

    // MARK: - Sync Protocol

    private func performSync(connection: NWConnection, peer: Peer) {
        syncStatus = .syncing(peer)

        guard let vault = VaultManager.shared.exportEncryptedBlobForP2P() else {
            syncStatus = .error("Vault is locked. Unlock before syncing.")
            connection.cancel()
            return
        }

        // Send our modification timestamp
        var ourTimestamp = UInt64(Date().timeIntervalSince1970).bigEndian
        let timestampData = withUnsafeBytes(of: &ourTimestamp) { Data($0) }

        connection.send(content: timestampData, completion: .contentProcessed { _ in })

        // Receive their timestamp
        connection.receive(minimumIncompleteLength: 8, maximumLength: 8) { [weak self] data, _, _, _ in
            Task { @MainActor [weak self] in
                guard let data, data.count == 8 else { return }
                let theirTimestamp = data.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
                let ourTime = UInt64(Date().timeIntervalSince1970)

                if ourTime >= theirTimestamp {
                    // We're newer — send our vault
                    self?.sendVault(vault, connection: connection, peer: peer)
                } else {
                    // They're newer — receive their vault
                    self?.receiveVault(connection: connection, peer: peer)
                }
            }
        }
    }

    private func sendVault(_ vault: Data, connection: NWConnection, peer: Peer) {
        var size = UInt32(vault.count).bigEndian
        let sizeData = withUnsafeBytes(of: &size) { Data($0) }
        let payload = sizeData + vault
        connection.send(content: payload, completion: .contentProcessed { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncStatus = .success(peer)
                connection.cancel()
            }
        })
    }

    private func receiveVault(connection: NWConnection, peer: Peer) {
        // Read 4-byte size header
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] sizeData, _, _, _ in
            guard let sizeData else { return }
            let size = sizeData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            // Read vault blob
            connection.receive(minimumIncompleteLength: Int(size), maximumLength: Int(size)) { [weak self] vaultData, _, _, _ in
                Task { @MainActor [weak self] in
                    guard let vaultData else { return }
                    do {
                        try VaultManager.shared.importEncryptedBlobFromP2P(vaultData)
                        self?.syncStatus = .success(peer)
                    } catch {
                        self?.syncStatus = .error("Failed to import vault: \(error.localizedDescription)")
                    }
                    connection.cancel()
                }
            }
        }
    }

    // MARK: - Handle Incoming Connection

    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 6, maximumLength: 6) { [weak self] data, _, _, _ in
            Task { @MainActor [weak self] in
                guard let data, let code = String(data: data, encoding: .utf8) else { return }
                self?.pairingCode = code
                // Get the peer's name from the connection endpoint if possible
                let peerName: String
                if case .service(let name, _, _, _) = connection.endpoint {
                    peerName = name
                } else {
                    peerName = "Unknown Device"
                }
                
                let peer = Peer(id: UUID(), name: peerName, endpoint: connection.endpoint)
                self?.incomingRequest = peer
                self?.activeConnection = connection
                self?.syncStatus = .pairing(peer)
            }
        }
        connection.start(queue: .main)
    }
    
    // MARK: - Confirm/Decline Pairing (for incoming)

    func confirmPairing() {
        guard let connection = activeConnection, let peer = incomingRequest else { return }
        let okData = "OK".data(using: .utf8)!
        connection.send(content: okData, completion: .contentProcessed { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.incomingRequest = nil
                self?.performSync(connection: connection, peer: peer)
            }
        })
    }

    func declinePairing() {
        guard let connection = activeConnection else { return }
        let noData = "NO".data(using: .utf8)!
        connection.send(content: noData, completion: .contentProcessed { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.incomingRequest = nil
                self?.stop()
            }
        })
    }

    // MARK: - Stop

    func stop() {
        listener?.cancel(); listener = nil
        browser?.cancel(); browser = nil
        activeConnection?.cancel(); activeConnection = nil
        syncStatus = .idle
        discoveredPeers = []
        pairingCode = nil
        incomingRequest = nil
    }
}
