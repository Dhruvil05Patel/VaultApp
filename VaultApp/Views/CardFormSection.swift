import SwiftUI

// Embedded inside AddItemView when category == .creditCard
struct CardFormSection: View {

    @Binding var fields: CardFields

    // Format card number with spaces every 4 digits while typing
    private var formattedCardNumber: Binding<String> {
        Binding(
            get: {
                let digits = fields.cardNumber.filter { $0.isNumber }
                return stride(from: 0, to: digits.count, by: 4).map { i -> String in
                    let start = digits.index(digits.startIndex, offsetBy: i)
                    let end   = digits.index(start, offsetBy: min(4, digits.count - i))
                    return String(digits[start..<end])
                }.joined(separator: " ")
            },
            set: { newValue in
                fields.cardNumber = newValue.filter { $0.isNumber }
                fields.cardType   = CardFields.CardType.detect(from: fields.cardNumber)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            formField("Cardholder Name", icon: "person.fill") {
                TextField("Full name as on card", text: $fields.cardholderName)
                    .textFieldStyle(.roundedBorder)
            }

            formField("Card Number", icon: "creditcard") {
                HStack {
                    TextField("0000 0000 0000 0000", text: formattedCardNumber)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    if !fields.cardNumber.isEmpty {
                        Image(systemName: fields.cardType.icon)
                            .foregroundStyle(.purple)
                    }
                }
                if !fields.cardNumber.isEmpty {
                    Text(fields.isValidCardNumber ? "✓ Valid number" : "✗ Invalid number")
                        .font(.caption2)
                        .foregroundStyle(fields.isValidCardNumber ? .green : .red)
                }
            }

            HStack(spacing: 12) {
                formField("Expiry Month", icon: "calendar") {
                    TextField("MM", text: $fields.expiryMonth)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                }
                formField("Year", icon: "calendar") {
                    TextField("YYYY", text: $fields.expiryYear)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                formField("CVV", icon: "lock.shield") {
                    SecureField("•••", text: $fields.cvv)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                }
            }

            formField("Bank Name (optional)", icon: "building.columns.fill") {
                TextField("e.g. Chase, Barclays", text: $fields.bankName)
                    .textFieldStyle(.roundedBorder)
            }

            formField("Card Type", icon: "creditcard.trianglebadge.exclamationmark") {
                Picker("", selection: $fields.cardType) {
                    ForEach(CardFields.CardType.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }.pickerStyle(.menu)
            }

            formField("PIN (optional)", icon: "pin.fill") {
                SecureField("ATM PIN", text: $fields.pin)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
            }

            formField("Billing Address (optional)", icon: "house.fill") {
                TextEditor(text: $fields.billingAddress)
                    .frame(minHeight: 60)
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func formField<Content: View>(_ label: String, icon: String,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption).foregroundStyle(.secondary).fontWeight(.medium)
            content()
        }
    }
}