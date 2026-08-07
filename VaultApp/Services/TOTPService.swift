import Foundation
import CryptoKit
import CommonCrypto

// TOTPService generates Time-based One-Time Passwords per RFC 6238.
// Uses HMAC-SHA1 (the standard algorithm for TOTP/Google Authenticator compatibility).
// Pure stateless enum — no instances.
enum TOTPService {

    // MARK: - Errors

    enum TOTPError: LocalizedError {
        case invalidBase32
        case emptySecret
        case generationFailed

        var errorDescription: String? {
            switch self {
            case .invalidBase32:    return "Invalid TOTP secret. Make sure you copied it correctly."
            case .emptySecret:      return "No TOTP secret configured for this entry."
            case .generationFailed: return "Failed to generate TOTP code."
            }
        }
    }

    // MARK: - Generate Current Code

    // Returns the current 6-digit TOTP code and the seconds remaining until it changes.
    static func currentCode(secret: String) throws -> (code: String, secondsRemaining: Int) {
        guard !secret.isEmpty else { throw TOTPError.emptySecret }

        let keyBytes = try base32Decode(secret.trimmingCharacters(in: .whitespaces).uppercased())
        let timestamp = Date().timeIntervalSince1970
        let counter   = UInt64(timestamp / 30)
        let remaining = 30 - Int(timestamp.truncatingRemainder(dividingBy: 30))

        let code = try generateCode(keyBytes: keyBytes, counter: counter)
        return (code, remaining)
    }

    // Generate the TOTP code for a specific counter value (for ±1 window validation)
    static func generateCode(keyBytes: [UInt8], counter: UInt64) throws -> String {
        // Step 1: counter → 8-byte big-endian
        var counterBE = counter.bigEndian
        let counterData = withUnsafeBytes(of: &counterBE) { Data($0) }

        // Step 2: HMAC-SHA1(key, counter)
        let key  = SymmetricKey(data: Data(keyBytes))
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
        let hmacBytes = Array(hmac)

        // Step 3: Dynamic truncation
        let offset    = Int(hmacBytes[19] & 0x0F)
        let binCode   = (Int(hmacBytes[offset]     & 0x7F) << 24)
                      | (Int(hmacBytes[offset + 1] & 0xFF) << 16)
                      | (Int(hmacBytes[offset + 2] & 0xFF) <<  8)
                      | (Int(hmacBytes[offset + 3] & 0xFF))

        // Step 4: 6-digit code (zero-padded)
        let otp = binCode % 1_000_000
        return String(format: "%06d", otp)
    }

    // MARK: - Validate Secret

    // Returns true if the string is a valid Base32 TOTP secret
    static func isValidSecret(_ secret: String) -> Bool {
        let clean = secret.trimmingCharacters(in: .whitespaces)
                          .uppercased()
                          .replacingOccurrences(of: " ", with: "")
        guard !clean.isEmpty else { return false }
        return (try? base32Decode(clean)) != nil
    }

    // MARK: - Parse otpauth:// URI

    // Parses a standard otpauth:// URI (from QR codes) into its components.
    // Format: otpauth://totp/Label?secret=BASE32&issuer=NAME&digits=6&period=30
    struct OTPAuthURI {
        let label: String
        let secret: String
        let issuer: String
        let digits: Int
        let period: Int
    }

    static func parseOTPAuthURI(_ uri: String) -> OTPAuthURI? {
        guard let url = URL(string: uri),
              url.scheme == "otpauth",
              url.host == "totp" else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let params = Dictionary(
            (components?.queryItems ?? []).compactMap { item -> (String, String)? in
                guard let value = item.value else { return nil }
                return (item.name, value)
            },
            uniquingKeysWith: { first, _ in first }
        )

        guard let secret = params["secret"], !secret.isEmpty else { return nil }

        // Label: the path component (URL-decoded), strip leading slash
        let rawLabel = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
        let label = rawLabel.removingPercentEncoding ?? rawLabel

        return OTPAuthURI(
            label:  label,
            secret: secret,
            issuer: params["issuer"] ?? "",
            digits: Int(params["digits"] ?? "6") ?? 6,
            period: Int(params["period"] ?? "30") ?? 30
        )
    }

    // MARK: - Base32 Decoder (RFC 4648)

    static func base32Decode(_ input: String) throws -> [UInt8] {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        // Strip padding and whitespace
        let clean = input
            .uppercased()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard !clean.isEmpty else { throw TOTPError.invalidBase32 }

        var output: [UInt8] = []
        var buffer: UInt64  = 0
        var bitsLeft: Int   = 0

        for char in clean {
            guard let index = alphabet.firstIndex(of: char) else {
                throw TOTPError.invalidBase32
            }
            let value = alphabet.distance(from: alphabet.startIndex, to: index)
            buffer    = (buffer << 5) | UInt64(value)
            bitsLeft += 5
            if bitsLeft >= 8 {
                bitsLeft -= 8
                output.append(UInt8((buffer >> UInt64(bitsLeft)) & 0xFF))
            }
        }

        return output
    }

    // MARK: - Format Code for Display

    // "123456" → "123 456" (spaced for readability)
    static func formatCode(_ code: String) -> String {
        guard code.count == 6 else { return code }
        let mid = code.index(code.startIndex, offsetBy: 3)
        return String(code[..<mid]) + " " + String(code[mid...])
    }
}
