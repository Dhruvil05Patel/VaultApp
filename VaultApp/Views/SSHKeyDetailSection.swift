import SwiftUI

struct SSHKeyDetailSection: View {

    let fields: SSHKeyFields
    @State private var showPrivateKey: Bool = false
    @State private var showPassphrase: Bool = false
    @State private var showSeed: Bool = false
    @State private var copiedKey: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Type + host header
            HStack(spacing: 10) {
                Image(systemName: fields.keyType.icon)
                    .font(.title3).foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(fields.keyType.rawValue)
                        .font(.callout).fontWeight(.semibold)
                    if !fields.hostname.isEmpty {
                        Text(fields.hostname)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            // Route to sub-section
            switch fields.keyType {
            case .ed25519, .rsa, .ecdsa:
                sshKeySection
            case .apiToken, .other:
                apiTokenSection
            case .envVar:
                envVarSection
            case .seedPhrase:
                seedPhraseSection
            }
        }
    }

    // MARK: - SSH Key Section

    @ViewBuilder
    private var sshKeySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !fields.publicKey.isEmpty {
                codeBlock(
                    label: "Public Key",
                    value: fields.publicKey,
                    icon: "key",
                    copyKey: "pubkey",
                    isSecret: false,
                    isRevealed: .constant(true)
                )
            }

            if !fields.privateKey.isEmpty {
                codeBlock(
                    label: "Private Key",
                    value: fields.privateKey,
                    icon: "key.fill",
                    copyKey: "privkey",
                    isSecret: true,
                    isRevealed: $showPrivateKey
                )
            }

            if !fields.passphrase.isEmpty {
                secretRow(
                    label: "Passphrase",
                    value: fields.passphrase,
                    icon: "lock.fill",
                    copyKey: "passphrase",
                    isRevealed: $showPassphrase
                )
            }

            if !fields.fingerprint.isEmpty {
                plainRow("Fingerprint", fields.fingerprint, "number", "fp")
            }

            if !fields.keyComment.isEmpty {
                plainRow("Comment", fields.keyComment, "text.bubble", "comment")
            }

            if !fields.hostname.isEmpty {
                plainRow("Host", fields.hostname, "server.rack", "host")
            }
        }
    }

    // MARK: - API Token Section

    @ViewBuilder
    private var apiTokenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            secretRow(
                label: "Token Value",
                value: fields.tokenValue,
                icon: "lock.doc.fill",
                copyKey: "token",
                isRevealed: $showPrivateKey
            )

            if !fields.hostname.isEmpty {
                plainRow("API Endpoint / Service", fields.hostname, "globe", "host")
            }

            if !fields.expiresAt.isEmpty {
                plainRow("Expires", fields.expiresAt, "calendar.badge.clock", "expires")
            }
        }
    }

    // MARK: - Environment Variable Section

    @ViewBuilder
    private var envVarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !fields.envVarName.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Variable Name", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text(fields.envVarName)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer()
                        copyButton(value: fields.envVarName, key: "varname")
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.85))
                    .foregroundColor(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            secretRow(
                label: "Value",
                value: fields.tokenValue,
                icon: "lock.fill",
                copyKey: "value",
                isRevealed: $showPrivateKey
            )

            // Export hint
            if !fields.envVarName.isEmpty && !fields.tokenValue.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shell export command:").font(.caption2).foregroundStyle(.tertiary)
                    Text("export \(fields.envVarName)=\"\(showPrivateKey ? fields.tokenValue : "***")\"")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    copyButton(value: "export \(fields.envVarName)=\"\(fields.tokenValue)\"",
                               key: "export")
                }
                .padding(10)
                .background(Color.black.opacity(0.85))
                .foregroundColor(.green)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Seed Phrase Section

    @ViewBuilder
    private var seedPhraseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Warning banner
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text("Never share your seed phrase. Anyone with it has full control of your wallet.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color.red.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Seed phrase grid
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("\(fields.wordCount)-Word Seed Phrase", systemImage: "bitcoinsign.circle.fill")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        withAnimation { showSeed.toggle() }
                    } label: {
                        Label(showSeed ? "Hide" : "Reveal",
                              systemImage: showSeed ? "eye.slash" : "eye")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                }

                if showSeed {
                    let words = fields.seedPhrase.split(separator: " ")
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 4),
                        spacing: 8
                    ) {
                        ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                            HStack(spacing: 4) {
                                Text("\(i+1).")
                                    .font(.caption2).foregroundStyle(.tertiary).frame(width: 22, alignment: .trailing)
                                Text(String(word))
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 6).padding(.horizontal, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    copyButton(value: fields.seedPhrase, key: "seed")
                        .padding(.top, 4)
                } else {
                    // Blurred placeholder grid
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 4),
                        spacing: 8
                    ) {
                        ForEach(0..<min(fields.wordCount, 24), id: \.self) { i in
                            Text("● ● ●")
                                .font(.caption2).foregroundStyle(.tertiary)
                                .padding(.vertical, 6).padding(.horizontal, 8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }

            if !fields.walletAddress.isEmpty {
                plainRow("Wallet Address", fields.walletAddress, "creditcard.fill", "address")
            }
            if !fields.network.isEmpty {
                plainRow("Network", fields.network, "network", "network")
            }
            if !fields.derivationPath.isEmpty {
                plainRow("Derivation Path", fields.derivationPath, "arrow.triangle.branch", "path")
            }
        }
    }

    // MARK: - Reusable Row Components

    @ViewBuilder
    private func codeBlock(label: String, value: String, icon: String,
                            copyKey: String, isSecret: Bool,
                            isRevealed: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.caption).foregroundStyle(.secondary).fontWeight(.medium)
                Spacer()
                if isSecret {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isRevealed.wrappedValue.toggle()
                        }
                    } label: {
                        Image(systemName: isRevealed.wrappedValue ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary).font(.caption)
                    }.buttonStyle(.plain)
                }
            }

            if isSecret && !isRevealed.wrappedValue {
                Button { isRevealed.wrappedValue = true } label: {
                    Label("Reveal \(label)", systemImage: "eye.fill").font(.callout)
                }.buttonStyle(.bordered)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(value)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                        .foregroundColor(.green)
                }
                .background(Color.black.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxHeight: 140)

                copyButton(value: value, key: copyKey)
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private func secretRow(label: String, value: String, icon: String,
                            copyKey: String, isRevealed: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption).foregroundStyle(.secondary).fontWeight(.medium)
            HStack {
                Text(isRevealed.wrappedValue
                     ? value
                     : String(repeating: "●", count: min(value.count, 20)))
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(1)
                Spacer()
                Button { isRevealed.wrappedValue.toggle() } label: {
                    Image(systemName: isRevealed.wrappedValue ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.secondary)
                }.buttonStyle(.plain)
                copyButton(value: value, key: copyKey)
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func plainRow(_ label: String, _ value: String,
                           _ icon: String, _ copyKey: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Text(value).font(.callout).textSelection(.enabled).lineLimit(2)
                Spacer()
                copyButton(value: value, key: copyKey)
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func copyButton(value: String, key: String) -> some View {
        Button {
            ClipboardService.copy(value)
            withAnimation { copiedKey = key }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { copiedKey = nil }
            }
        } label: {
            Image(systemName: copiedKey == key ? "checkmark" : "doc.on.doc")
                .foregroundStyle(copiedKey == key ? .green : .secondary)
        }.buttonStyle(.plain)
    }
}
