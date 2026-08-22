import SwiftUI

struct SSHKeyFormSection: View {

    @Binding var fields: SSHKeyFields

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Key type picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Key / Secret Type").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $fields.keyType) {
                    ForEach(SSHKeyFields.KeyType.allCases) { type in
                        Label(type.rawValue, systemImage: type.icon).tag(type)
                    }
                }.pickerStyle(.menu)
            }

            // Host / service
            formRow("Host / Service", placeholder: "github.com, api.stripe.com", binding: $fields.hostname)

            // Type-specific fields
            switch fields.keyType {
            case .ed25519, .rsa, .ecdsa:
                sshFields
            case .apiToken, .other:
                tokenField
            case .envVar:
                envVarFields
            case .seedPhrase:
                seedPhraseFields
            }
        }
    }

    // MARK: - SSH-Specific

    @ViewBuilder private var sshFields: some View {
        formRow("Public Key", placeholder: "ssh-ed25519 AAAA...", binding: $fields.publicKey, multiline: true)
        formRow("Private Key", placeholder: "-----BEGIN OPENSSH PRIVATE KEY-----", binding: $fields.privateKey, multiline: true, sensitive: true)
        formRow("Passphrase (optional)", placeholder: "Key passphrase", binding: $fields.passphrase, sensitive: true)
        formRow("Fingerprint (optional)", placeholder: "SHA256:xxxx", binding: $fields.fingerprint)
        formRow("Comment (optional)", placeholder: "user@machine", binding: $fields.keyComment)
    }

    // MARK: - API Token

    @ViewBuilder private var tokenField: some View {
        formRow("Token / Secret Value", placeholder: "sk_live_xxxx...", binding: $fields.tokenValue, sensitive: true)
        formRow("Expires (optional)", placeholder: "2025-12-31", binding: $fields.expiresAt)
    }

    // MARK: - Env Var

    @ViewBuilder private var envVarFields: some View {
        formRow("Variable Name", placeholder: "STRIPE_API_KEY", binding: $fields.envVarName)
        formRow("Value", placeholder: "secret value", binding: $fields.tokenValue, sensitive: true)
    }

    // MARK: - Seed Phrase

    @ViewBuilder private var seedPhraseFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Seed Phrase").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !fields.seedPhrase.isEmpty {
                    Text("\(fields.seedPhrase.split(separator: " ").count) words")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            TextEditor(text: $fields.seedPhrase)
                .font(.system(.callout, design: .monospaced))
                .frame(minHeight: 80)
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1))
            Text("Enter the words separated by spaces. Standard BIP-39 phrases are 12 or 24 words.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        formRow("Network", placeholder: "Ethereum, Bitcoin, Solana", binding: $fields.network)
        formRow("Wallet Address (optional)", placeholder: "0x...", binding: $fields.walletAddress)
        formRow("Derivation Path (optional)", placeholder: "m/44'/60'/0'/0/0", binding: $fields.derivationPath)
    }

    // MARK: - Generic Row Helper

    @ViewBuilder
    private func formRow(_ label: String, placeholder: String,
                          binding: Binding<String>,
                          multiline: Bool = false,
                          sensitive: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            if multiline {
                TextEditor(text: binding)
                    .font(.system(.callout, design: .monospaced))
                    .frame(minHeight: 70)
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1))
            } else if sensitive {
                SecureField(placeholder, text: binding)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.callout, design: .monospaced))
            } else {
                TextField(placeholder, text: binding)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
            }
        }
    }
}
