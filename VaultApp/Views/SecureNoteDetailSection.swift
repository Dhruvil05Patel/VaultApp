import SwiftUI

struct SecureNoteDetailSection: View {
    var noteBody: String

    var bodyView: some View {
        ScrollView {
            Text(noteBody.isEmpty ? "No content." : noteBody)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(minHeight: 120)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Note", systemImage: "note.text")
                .font(.caption).foregroundStyle(.secondary).fontWeight(.medium)
            bodyView
        }
    }
}