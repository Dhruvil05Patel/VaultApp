import SwiftUI

// Shown inside ItemDetailView when category == .creditCard
struct CardDetailSection: View {

    let card: CardFields
    @State private var showCardNumber: Bool = false
    @State private var showCVV: Bool = false
    @State private var showPIN: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Card type badge
            HStack {
                Image(systemName: card.cardType.icon)
                    .font(.title2)
                    .foregroundStyle(.purple)
                Text(card.cardType.rawValue)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if !card.bankName.isEmpty {
                    Text("· \(card.bankName)")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }

            if !card.cardholderName.isEmpty {
                detailRow(label: "Cardholder", value: card.cardholderName,
                          icon: "person.fill", copyKey: "cardholder", reveal: false)
            }

            if !card.cardNumber.isEmpty {
                secretRow(
                    label: "Card Number",
                    icon: "creditcard",
                    visibleValue: card.groupedNumber,
                    maskedValue: card.maskedNumber,
                    isRevealed: $showCardNumber,
                    copyKey: "cardNumber",
                    copyValue: card.cardNumber.filter { $0.isNumber }
                )
            }

            if !card.expiryMonth.isEmpty {
                detailRow(label: "Expiry", value: card.formattedExpiry,
                          icon: "calendar", copyKey: "expiry", reveal: false)
            }

            if !card.cvv.isEmpty {
                secretRow(label: "CVV", icon: "lock.shield",
                          visibleValue: card.cvv,
                          maskedValue: String(repeating: "•", count: card.cvv.count),
                          isRevealed: $showCVV,
                          copyKey: "cvv", copyValue: card.cvv)
            }

            if !card.pin.isEmpty {
                secretRow(label: "PIN", icon: "pin.fill",
                          visibleValue: card.pin,
                          maskedValue: String(repeating: "•", count: card.pin.count),
                          isRevealed: $showPIN,
                          copyKey: "pin", copyValue: card.pin)
            }

            if !card.billingAddress.isEmpty {
                detailRow(label: "Billing Address", value: card.billingAddress,
                          icon: "house.fill", copyKey: "address", reveal: false)
            }

            // Luhn validity indicator
            if !card.cardNumber.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: card.isValidCardNumber ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(card.isValidCardNumber ? .green : .red)
                    Text(card.isValidCardNumber ? "Valid card number (Luhn check passed)" : "Invalid card number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Row helpers

    @State private var copiedKey: String? = nil

    @ViewBuilder
    private func detailRow(label: String, value: String, icon: String,
                           copyKey: String, reveal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption).foregroundStyle(.secondary).fontWeight(.medium)
            HStack {
                Text(value).font(.body).textSelection(.enabled).lineLimit(2)
                Spacer()
                copyBtn(value: value, key: copyKey)
            }
            .padding(10).background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func secretRow(label: String, icon: String,
                           visibleValue: String, maskedValue: String,
                           isRevealed: Binding<Bool>,
                           copyKey: String, copyValue: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption).foregroundStyle(.secondary).fontWeight(.medium)
            HStack {
                Text(isRevealed.wrappedValue ? visibleValue : maskedValue)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                Spacer()
                Button { isRevealed.wrappedValue.toggle() } label: {
                    Image(systemName: isRevealed.wrappedValue ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.secondary)
                }.buttonStyle(.plain)
                copyBtn(value: copyValue, key: copyKey)
            }
            .padding(10).background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func copyBtn(value: String, key: String) -> some View {
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