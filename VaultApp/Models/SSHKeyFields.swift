import Foundation

struct SSHKeyFields: Codable, Hashable {

    // MARK: - Key Type

    enum KeyType: String, Codable, CaseIterable, Identifiable {
        case ed25519    = "Ed25519 (SSH)"
        case rsa        = "RSA (SSH)"
        case ecdsa      = "ECDSA (SSH)"
        case apiToken   = "API Token / Bearer"
        case envVar     = "Environment Variable"
        case seedPhrase = "Wallet Seed Phrase"
        case other      = "Other Secret"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .ed25519, .rsa, .ecdsa: return "terminal.fill"
            case .apiToken:              return "lock.doc.fill"
            case .envVar:                return "chevron.left.forwardslash.chevron.right"
            case .seedPhrase:            return "bitcoinsign.circle.fill"
            case .other:                 return "key.fill"
            }
        }

        var isSSHKeyType: Bool {
            [.ed25519, .rsa, .ecdsa].contains(self)
        }
    }

    // MARK: - Common Fields

    var keyType: KeyType = .ed25519
    var hostname: String = ""        // e.g. github.com, api.stripe.com

    // MARK: - SSH Key Fields

    var publicKey: String  = ""      // ssh-ed25519 AAAA...
    var privateKey: String = ""      // -----BEGIN OPENSSH PRIVATE KEY-----
    var passphrase: String = ""      // key passphrase
    var fingerprint: String = ""     // SHA256:xxxx (for verification)
    var keyComment: String = ""      // user@machine — the key comment

    // MARK: - API Token / Env Var Fields

    var tokenValue: String = ""      // the actual token / secret value
    var envVarName: String = ""      // e.g. STRIPE_API_KEY
    var expiresAt: String  = ""      // optional expiry date string

    // MARK: - Seed Phrase Fields

    var seedPhrase: String = ""      // space-separated 12/24 word BIP-39 mnemonic
    var derivationPath: String = ""  // e.g. m/44'/60'/0'/0/0
    var walletAddress: String  = ""  // the public wallet address (not secret)
    var network: String        = ""  // e.g. Ethereum, Solana, Bitcoin

    // MARK: - Helpers

    var wordCount: Int {
        seedPhrase.split(separator: " ").count
    }

    var maskedSeedPhrase: String {
        let words = seedPhrase.split(separator: " ")
        return words.enumerated().map { i, _ in "word\(i+1)" }.joined(separator: " ")
    }

    var primarySecret: String {
        switch keyType {
        case .ed25519, .rsa, .ecdsa: return privateKey
        case .apiToken, .other:      return tokenValue
        case .envVar:                return tokenValue
        case .seedPhrase:            return seedPhrase
        }
    }
}
