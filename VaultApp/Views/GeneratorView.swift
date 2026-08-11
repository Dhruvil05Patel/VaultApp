import SwiftUI

struct GeneratorView: View {

    @Environment(\.dismiss) private var dismiss

    // Optional callback — when opened from AddItemView,
    // this lets the sheet pass the password back instead of just copying it
    var onUse: ((String) -> Void)? = nil

    // MARK: - Generator Options State

    @State private var mode: GeneratorMode = .password
    @State private var length: Double = 20
    @State private var includeUppercase: Bool = true
    @State private var includeNumbers: Bool = true
    @State private var includeSymbols: Bool = true
    @State private var excludeAmbiguous: Bool = false

    // Passphrase options
    @State private var wordCount: Double = 4
    @State private var separator: String = "-"

    // Output state
    @State private var generatedValue: String = ""
    @State private var copied: Bool = false

    // MARK: - Mode Enum

    enum GeneratorMode: String, CaseIterable {
        case password   = "Password"
        case passphrase = "Passphrase"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Password Generator")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // Mode toggle
                    modePicker

                    // Generated output
                    outputSection

                    // Options
                    if mode == .password {
                        passwordOptions
                    } else {
                        passphraseOptions
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer actions
            footerButtons
        }
        .frame(minWidth: 420, minHeight: 460)
        .onAppear { regenerate() }
        .onChange(of: mode)            { regenerate() }
        .onChange(of: length)          { regenerate() }
        .onChange(of: includeUppercase){ regenerate() }
        .onChange(of: includeNumbers)  { regenerate() }
        .onChange(of: includeSymbols)  { regenerate() }
        .onChange(of: excludeAmbiguous){ regenerate() }
        .onChange(of: wordCount)       { regenerate() }
        .onChange(of: separator)       { regenerate() }
    }

    // MARK: - Mode Picker

    @ViewBuilder
    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(GeneratorMode.allCases, id: \.self) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Generated Output

    @ViewBuilder
    private var outputSection: some View {
        VStack(spacing: 10) {
            // The generated value — shown in a monospaced box
            Text(generatedValue)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 70)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .textSelection(.enabled)

            // Strength indicator (passwords only)
            if mode == .password {
                let strength = PasswordGenerator.strength(of: generatedValue)
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        Capsule()
                            .fill(segmentColor(index: i, strength: strength))
                            .frame(height: 5)
                    }
                    Text(strength.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 64, alignment: .trailing)
                }
            }

            // Regenerate button
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    regenerate()
                }
            } label: {
                Label("Regenerate", systemImage: "arrow.clockwise")
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("r", modifiers: .command)
        }
    }

    // MARK: - Password Options

    @ViewBuilder
    private var passwordOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Options")
                .font(.headline)

            // Length slider
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Length")
                        .font(.callout)
                    Spacer()
                    Text("\(Int(length)) characters")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $length, in: 8...64, step: 1)
                    .tint(.blue)
            }

            Divider()

            // Character type toggles
            VStack(alignment: .leading, spacing: 10) {
                toggleRow("Uppercase letters (A-Z)", binding: $includeUppercase)
                toggleRow("Numbers (0-9)", binding: $includeNumbers)
                toggleRow("Symbols (!@#$...)", binding: $includeSymbols)
                toggleRow("Exclude ambiguous characters (0/O, l/I/1)", binding: $excludeAmbiguous)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Passphrase Options

    @ViewBuilder
    private var passphraseOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Options")
                .font(.headline)

            // Word count
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Number of words")
                        .font(.callout)
                    Spacer()
                    Text("\(Int(wordCount)) words")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $wordCount, in: 3...8, step: 1)
                    .tint(.blue)
            }

            Divider()

            // Separator
            HStack {
                Text("Separator")
                    .font(.callout)
                Spacer()
                Picker("Separator", selection: $separator) {
                    Text("Hyphen (-)").tag("-")
                    Text("Dot (.)").tag(".")
                    Text("Underscore (_)").tag("_")
                    Text("Space ( )").tag(" ")
                    Text("None").tag("")
                }
                .pickerStyle(.menu)
                .frame(width: 160)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerButtons: some View {
        HStack(spacing: 12) {
            // Copy button
            Button {
                ClipboardService.copy(generatedValue)
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { copied = false }
                }
            } label: {
                Label(
                    copied ? "Copied!" : "Copy",
                    systemImage: copied ? "checkmark" : "doc.on.doc"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(copied ? .green : .primary)

            // "Use this password" — only shown when opened from AddItemView
            if let onUse {
                Button {
                    onUse(generatedValue)
                    dismiss()
                } label: {
                    Label("Use This Password", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Toggle Row Helper

    @ViewBuilder
    private func toggleRow(_ label: String, binding: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.callout)
            Spacer()
            Toggle("", isOn: binding)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    // MARK: - Logic

    private func regenerate() {
        if mode == .password {
            let options = PasswordGenerator.Options(
                length: Int(length),
                includeUppercase: includeUppercase,
                includeNumbers: includeNumbers,
                includeSymbols: includeSymbols,
                excludeAmbiguous: excludeAmbiguous
            )
            generatedValue = PasswordGenerator.generate(options: options)
        } else {
            generatedValue = PasswordGenerator.generatePassphrase(
                wordCount: Int(wordCount),
                separator: separator
            )
        }
        copied = false
    }

    // MARK: - Strength Bar Helper

    private func segmentColor(index: Int, strength: PasswordGenerator.Strength) -> Color {
        let filled: Int
        switch strength {
        case .weak:       filled = 1
        case .fair:       filled = 2
        case .strong:     filled = 3
        case .veryStrong: filled = 4
        }
        guard index < filled else { return Color(.separatorColor) }
        switch strength {
        case .weak:       return .red
        case .fair:       return .orange
        case .strong:     return .yellow
        case .veryStrong: return .green
        }
    }
}

// MARK: - Preview

#Preview {
    GeneratorView()
}

#Preview("With onUse callback") {
    GeneratorView { password in
        print("Selected: \(password)")
    }
}
