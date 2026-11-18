import SwiftUI

/// Adresseingabe: PLZ → Ort wird automatisch ergänzt (offline), Straßen werden vorgeschlagen.
struct AddressInputView: View {
    @Binding var address: AddressValue

    @StateObject private var completer = AddressCompleter()
    @State private var cityAutoFilled = false
    @State private var cityChoices: [String] = []
    @State private var lastPickedStreet: String? = nil
    @FocusState private var focusedField: Field?

    private enum Field { case postalCode, city, street }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("PLZ", text: $address.postalCode, prompt: Text("PLZ"))
                    .focused($focusedField, equals: .postalCode)
                    .frame(width: 90)
                TextField("Ort", text: $address.city, prompt: Text("Ort"))
                    .focused($focusedField, equals: .city)
            }

            if cityChoices.count > 1 {
                HStack(spacing: 6) {
                    Text("Ort wählen:")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    ForEach(cityChoices, id: \.self) { city in
                        Button(city) {
                            address.city = city
                            cityAutoFilled = true
                            cityChoices = []
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            TextField("Straße und Hausnummer", text: $address.street,
                      prompt: Text("Straße und Hausnummer"))
                .focused($focusedField, equals: .street)

            if focusedField == .street, !completer.suggestions.isEmpty {
                suggestionList
            }
        }
        .textFieldStyle(.roundedBorder)
        .labelsHidden()
        .autocorrectionDisabled()
        // PLZ → Ort (sofort, aus der mitgelieferten Tabelle)
        .onChange(of: address.postalCode) { _, newValue in
            let digits = String(newValue.filter(\.isNumber).prefix(5))
            if digits != newValue { address.postalCode = digits; return }
            let cities = PostalCodes.cities(for: digits)
            cityChoices = cities
            if let first = cities.first, address.city.isEmpty || cityAutoFilled {
                address.city = first
                cityAutoFilled = true
            }
        }
        // Manuelle Eingabe des Orts → nicht mehr automatisch überschreiben
        .onChange(of: address.city) { _, _ in
            if focusedField == .city { cityAutoFilled = false }
        }
        // Straße → Vorschläge (Apple Maps)
        .onChange(of: address.street) { _, newValue in
            guard focusedField == .street else { return }
            if newValue == lastPickedStreet {
                completer.clear()
                return
            }
            completer.update(street: newValue, postalCode: address.postalCode, city: address.city)
        }
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(completer.suggestions) { suggestion in
                Button {
                    pick(suggestion)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(suggestion.title)
                                .foregroundStyle(Theme.ink)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if suggestion.id != completer.suggestions.last?.id {
                    Divider()
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.accentSoft.opacity(0.5))
        )
    }

    @MainActor
    private func pick(_ suggestion: AddressSuggestion) {
        Task {
            guard let resolved = await completer.resolve(suggestion) else { return }
            lastPickedStreet = resolved.street
            cityAutoFilled = false
            cityChoices = []
            address = resolved
            completer.clear()
        }
    }
}
