import Foundation
import UniformTypeIdentifiers

struct VaultAttachment: Codable, Identifiable, Hashable {

    let id: UUID
    var filename: String            // original filename e.g. "passport.pdf"
    var mimeType: String            // IANA media type e.g. "application/pdf"
    var sizeBytes: Int              // original (unencrypted) file size in bytes
    var encryptedFilename: String   // "{id.uuidString}.enc" — stored in Attachments/
    var createdAt: Date

    // MARK: - Init

    init(
        id: UUID = UUID(),
        filename: String,
        mimeType: String,
        sizeBytes: Int
    ) {
        self.id                = id
        self.filename          = filename
        self.mimeType          = mimeType
        self.sizeBytes         = sizeBytes
        self.encryptedFilename = "\(id.uuidString).enc"
        self.createdAt         = Date()
    }

    // MARK: - Display Helpers

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }

    var sfSymbolIcon: String {
        switch mimeType {
        case _ where mimeType.hasPrefix("image/"): return "photo.fill"
        case "application/pdf":                    return "doc.richtext.fill"
        case "text/plain":                         return "doc.text.fill"
        case _ where mimeType.contains("word"):    return "doc.fill"
        case _ where mimeType.contains("sheet"):   return "tablecells.fill"
        case _ where mimeType.contains("zip"):     return "archivebox.fill"
        default:                                   return "paperclip"
        }
    }

    // MARK: - MIME Type Detection

    static func mimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        if let utType = UTType(filenameExtension: ext) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }
        switch ext {
        case "pdf":       return "application/pdf"
        case "jpg","jpeg":return "image/jpeg"
        case "png":       return "image/png"
        case "gif":       return "image/gif"
        case "webp":      return "image/webp"
        case "txt":       return "text/plain"
        case "md":        return "text/markdown"
        case "doc","docx":return "application/msword"
        case "xls","xlsx":return "application/vnd.ms-excel"
        case "zip":       return "application/zip"
        case "key":       return "application/x-iwork-keynote-sffkey"
        default:          return "application/octet-stream"
        }
    }
}
