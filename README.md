# 🔐 VaultApp — macOS Password Manager

> A local-first, end-to-end encrypted password manager for macOS, built with Swift and SwiftUI. Inspired by 1Password, designed to be private, fast, and fully yours.

---

## Table of Contents

- [Overview](#overview)
- [Goals & Philosophy](#goals--philosophy)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Security Model](#security-model)
- [Project Structure](#project-structure)
- [Screens & User Flow](#screens--user-flow)
- [Data Model](#data-model)
- [Encryption Design](#encryption-design)
- [Roadmap](#roadmap)
- [Development Setup](#development-setup)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

VaultApp is a native macOS password manager that stores all your credentials locally in an AES-256-GCM encrypted vault. There is no cloud backend, no account required, and no data ever leaves your machine unless you explicitly export it.

The app is designed as a learning project and personal tool — something you build yourself, understand fully, and trust completely.

---

## Goals & Philosophy

| Principle | What it means in practice |
|---|---|
| **Local-first** | All data lives on your Mac. No servers, no accounts, no sync unless you add it |
| **Zero-knowledge** | Your master password is never stored — not even a hash. It is only used to derive a key at unlock time |
| **Native feel** | Built with SwiftUI so it looks and behaves like a real macOS app — not an Electron wrapper |
| **Auditable** | Small codebase you can read top to bottom and understand every security decision |
| **No telemetry** | No analytics, no crash reporting, no network calls unless you opt in |

---

## Features

### Implemented
- [ ] Lock screen with master password entry
- [ ] AES-256-GCM encrypted vault file
- [ ] Key derivation from master password using PBKDF2-SHA256
- [ ] List of all saved passwords
- [ ] Add / Edit / Delete vault entries
- [ ] Copy username and password to clipboard
- [ ] Auto-clear clipboard after 30 seconds
- [ ] Password generator (length, symbols, numbers)
- [ ] Auto-lock on screen sleep or inactivity

### Planned
- [ ] Touch ID / Face ID (Biometric unlock)
- [ ] Browser autofill via `ASCredentialProviderExtension`
- [ ] TOTP / 2FA code generator (RFC 6238)
- [ ] Secure notes category
- [ ] Credit card and identity templates
- [ ] Import from 1Password / Bitwarden (CSV)
- [ ] iCloud Sync with client-side encryption
- [ ] Tags and folders for organization
- [ ] Password strength indicator
- [ ] Breach detection via HaveIBeenPwned API (k-anonymity model)
- [ ] Menu bar quick-access widget

---

## Tech Stack

| Layer | Technology | Why |
|---|---|---|
| **Language** | Swift 5.9+ | Native macOS, type-safe, fast |
| **UI Framework** | SwiftUI | Declarative, minimal boilerplate, native macOS components |
| **Encryption** | Apple CryptoKit | System-level AES-256-GCM, no third-party crypto deps |
| **Key Derivation** | CommonCrypto (PBKDF2-SHA256) | Proven KDF built into macOS, 200,000+ iterations |
| **Storage** | JSON + File System | Simple, auditable, no database overhead |
| **Biometrics** | LocalAuthentication framework | Touch ID / Apple Watch unlock |
| **Autofill** | ASCredentialProviderExtension | Browser and app autofill integration (planned) |
| **IDE** | Xcode 15+ | Required for SwiftUI development on macOS |
| **Target OS** | macOS 13 Ventura and above | Required for latest SwiftUI APIs |

---

## Architecture

VaultApp follows a simple layered architecture:

```
┌─────────────────────────────────────────────┐
│                   SwiftUI Views              │  ← What the user sees
│   LockView · VaultListView · AddItemView     │
└────────────────────┬────────────────────────┘
                     │
┌────────────────────▼────────────────────────┐
│               VaultManager                   │  ← Business logic
│   unlock() · addItem() · deleteItem()        │
│   generatePassword() · lockVault()           │
└────────────────────┬────────────────────────┘
                     │
┌────────────────────▼────────────────────────┐
│              EncryptionService               │  ← Security layer
│   deriveKey() · encrypt() · decrypt()        │
└────────────────────┬────────────────────────┘
                     │
┌────────────────────▼────────────────────────┐
│               File System                    │  ← Persistence
│   ~/Library/Application Support/VaultApp/   │
│   vault.enc  ·  vault.salt                  │
└─────────────────────────────────────────────┘
```

**Key design decisions:**
- The `SymmetricKey` lives only in memory and is cleared when the vault locks
- Views never touch encryption — they only talk to `VaultManager`
- `VaultManager` is an `ObservableObject` injected via SwiftUI's environment

---

## Security Model

### How the master password works

```
Master Password (never stored)
         │
         ▼
  PBKDF2-SHA256
  200,000 iterations
  + Random 16-byte Salt (stored in vault.salt)
         │
         ▼
  256-bit Symmetric Key (lives in memory only)
         │
         ▼
  AES-256-GCM encrypt/decrypt
  Random nonce per write operation
         │
         ▼
  vault.enc  (stored on disk)
```

### What is stored on disk

| File | Contents | Sensitive? |
|---|---|---|
| `vault.enc` | AES-GCM encrypted JSON blob | Safe — useless without the key |
| `vault.salt` | 16 random bytes | Not secret — needed to re-derive the key |

### What is NEVER stored

- Master password
- Derived key
- Any plaintext credentials

### Threat model

VaultApp protects against:
- ✅ Someone accessing your Mac files without your password
- ✅ Disk theft or cloning
- ✅ Accidental cloud backup exposure (vault.enc is useless without master password)

VaultApp does NOT protect against:
- ❌ Someone who already has your master password
- ❌ Malware running on your Mac with your user permissions
- ❌ Keyloggers capturing your master password at entry

---

## Project Structure

```
VaultApp/
├── VaultApp/
│   ├── VaultAppApp.swift          ← App entry point
│   │
│   ├── Views/
│   │   ├── ContentView.swift      ← Root view, routes locked/unlocked state
│   │   ├── LockView.swift         ← Master password entry screen
│   │   ├── VaultListView.swift    ← Searchable list of all items
│   │   ├── ItemDetailView.swift   ← View and copy a single entry
│   │   ├── AddItemView.swift      ← Form to add/edit a vault entry
│   │   ├── GeneratorView.swift    ← Password generator
│   │   └── SettingsView.swift     ← App preferences
│   │
│   ├── Models/
│   │   ├── VaultItem.swift        ← Data model for a password entry
│   │   └── Vault.swift            ← Wrapper for the full list of items
│   │
│   ├── Services/
│   │   ├── VaultManager.swift     ← ObservableObject — app state and logic
│   │   ├── EncryptionService.swift ← AES-GCM encrypt/decrypt, key derivation
│   │   └── PasswordGenerator.swift ← Password generation logic
│   │
│   └── Assets.xcassets            ← App icon and image assets
│
├── VaultApp.xcodeproj             ← Xcode project file
└── README.md                      ← This file
```

---

## Screens & User Flow

```
App Launch
    │
    ▼
[Lock Screen]
    │ Enter master password
    ▼
[Vault List] ←──────────────────────┐
    │ Tap an item                    │
    ▼                                │
[Item Detail]                        │
    │ Edit button                    │
    ▼                                │
[Edit Item Form] ──── Save ──────────┘
    
[Vault List]
    │ "+" button
    ▼
[Add Item Form] ──── Save ──────────→ [Vault List]

[Vault List]
    │ Generator icon
    ▼
[Password Generator]

[Vault List]
    │ Settings icon
    ▼
[Settings] → Auto-lock timeout, export, about
```

---

## Data Model

### VaultItem

```swift
struct VaultItem: Codable, Identifiable {
    let id: UUID           // Unique identifier
    var title: String      // e.g. "GitHub", "Netflix"
    var username: String   // Email or username
    var password: String   // The stored password
    var url: String?       // Website URL (optional)
    var notes: String?     // Extra notes (optional)
    var createdAt: Date    // When the entry was created
    var updatedAt: Date    // Last modified time
    var category: Category // Login, Card, Note, Identity

    enum Category: String, Codable {
        case login
        case creditCard
        case secureNote
        case identity
    }
}
```

### Vault (top-level container)

```swift
struct Vault: Codable {
    var items: [VaultItem] = []
}
```

The `Vault` struct is serialised to JSON, then that JSON is encrypted and written to `vault.enc`.

---

## Encryption Design

### Encrypting the vault

1. Serialize `Vault` → JSON `Data`
2. Generate a random 12-byte nonce (fresh every save)
3. Encrypt with AES-256-GCM using the in-memory `SymmetricKey`
4. Write `nonce + ciphertext + auth_tag` to `vault.enc`

### Decrypting the vault

1. Read `vault.enc` from disk
2. Read `vault.salt` from disk
3. Prompt user for master password
4. Derive `SymmetricKey` using PBKDF2 + salt
5. Decrypt the file → JSON `Data`
6. Deserialise JSON → `Vault`
7. Store `SymmetricKey` in memory; clear it on lock

### Key derivation parameters

| Parameter | Value |
|---|---|
| Algorithm | PBKDF2-SHA256 |
| Iterations | 200,000 |
| Output length | 32 bytes (256-bit) |
| Salt length | 16 bytes (random, generated once) |

---

## Roadmap

### v0.1 — Core (current)
- Lock screen
- Add / view / delete passwords
- AES-GCM encrypted vault file
- Password generator

### v0.2 — Polish
- Touch ID unlock
- Search and filter
- Password strength meter
- Auto-lock timeout settings
- Clipboard auto-clear

### v0.3 — Power Features
- TOTP/2FA code generator
- Secure notes and credit card templates
- Import from 1Password / Bitwarden CSV
- Menu bar quick access

### v1.0 — Production Ready
- Browser autofill extension
- iCloud Sync (client-side encrypted)
- Breach detection (HaveIBeenPwned)
- App Store distribution

---

## Development Setup

### Prerequisites

| Tool | Version | Install |
|---|---|---|
| macOS | 13 Ventura or later | System update |
| Xcode | 15.0 or later | Mac App Store |
| Swift | 5.9+ | Bundled with Xcode |

### Running the project

```bash
# 1. Open the project
open VaultApp.xcodeproj

# 2. Select target: My Mac (top toolbar in Xcode)

# 3. Build and run
# Press ⌘ + R  or  Product → Run

# 4. Default test password (remove before shipping)
# Master password: test123
```

### Useful Xcode shortcuts

| Shortcut | Action |
|---|---|
| `⌘ + R` | Build and Run |
| `⌘ + B` | Build only (check for errors) |
| `⌘ + .` | Stop the running app |
| `⌘ + /` | Comment / uncomment selected code |
| `⌘ + Shift + K` | Clean build folder |
| `⌘ + 0` | Show/hide the file sidebar |
| `Option + Click` | See quick documentation for any symbol |

---

## Security Checklist

Before distributing or using this with real passwords, verify:

- [ ] PBKDF2 iteration count is ≥ 200,000
- [ ] AES-256-GCM is used (authenticated encryption)
- [ ] A fresh random nonce is generated on every vault write
- [ ] Salt is randomly generated once and never reused
- [ ] Master password is never stored anywhere on disk
- [ ] `SymmetricKey` is cleared from memory on lock
- [ ] Clipboard is auto-cleared after 30 seconds
- [ ] Hardened Runtime is enabled in Xcode signing settings
- [ ] App does not make any outbound network requests without user consent
- [ ] Test password (`test123`) is removed before real use

---

## Contributing

This is currently a solo learning project. If you want to contribute:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/totp-generator`
3. Make your changes with clear commit messages
4. Open a pull request with a description of what you changed and why

For security-related issues, please do not open a public issue — contact the maintainer directly.

---

## License

MIT License — do whatever you want with it, but no warranty is provided. Do not ship this as a production product without a full security audit.

---

> Built by Dhruvil · Shipwright Agency · DA-IICT
> 
> *"The best password manager is the one you built yourself and actually understand."*
