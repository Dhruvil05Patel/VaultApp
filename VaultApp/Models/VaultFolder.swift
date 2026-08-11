import Foundation
import SwiftUI

struct VaultFolder: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var parentID: UUID?       // nil = root; reserved for future nesting
    var colorHex: String      // e.g. "#4A90D9"
    var createdAt: Date

    init(id: UUID = UUID(), name: String, parentID: UUID? = nil, colorHex: String = "#4A90D9") {
        self.id        = id
        self.name      = name
        self.parentID  = parentID
        self.colorHex  = colorHex
        self.createdAt = Date()
    }

    // Resolved SwiftUI Color from the stored hex string
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}

// MARK: - Color from hex (extension)

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int), hex.count == 6 else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}