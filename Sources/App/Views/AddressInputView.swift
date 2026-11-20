import SwiftUI

/// Adresseingabe: PLZ → Ort wird automatisch ergänzt (offline), Straßen werden vorgeschlagen.
struct AddressInputView: View {
    @Binding var address: AddressValue
    /// Zusätzlich Suchfeld für Lokalitäten (Café, Firma, Hotel …) und Feld für deren Namen
    var placeSearch: Bool = false

    @StateObject private var placeCompleter = AddressCompleter(includesPlaces: true)
    @State private var placeQuery = ""

    @StateObject private var completer = AddressCompleter()
    @State private var cityAutoFilled = false
    @State private var cityChoices: [String] = []
    @State private var lastPickedStreet: String? = nil
    @FocusState private var focusedField: Field?

    private enum Field { case place, postalCode, city, street }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if placeSearch {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondaryText)
                    TextField("Lokalität oder Adresse suchen", text: $placeQuery,
                              prompt: Text("Lokalität oder Adresse suchen, z. B. Café Fulda"))
                        .focused($focusedField, equals: .place)
                }
                if focusedField == .place, !placeCompleter.suggestions.isEmpty {
                    suggestionList(placeCompleter.suggestions) { pickPlace($0) }
                }
                TextField("Lokalität / Firma", text: $address.name, prompt: Text("Lokalität / Firma (optional)"))
            }

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
                suggestionList(completer.suggestions) { pick($0) }
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
        .onChange(of: placeQuery) { _, newValue in
            placeCompleter.search(newValue)
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

    private func suggestionList(_ suggestions: [AddressSuggestion],
                                onPick: @escaping (AddressSuggestion) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions) { suggestion in
                Button {
                    onPick(suggestion)
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
                if suggestion.id != suggestions.last?.id {
                    Divider()
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.accentSoft.opacity(0.5))
        )
    }

    /// Lokalität übernehmen: Name, Straße, PLZ, Ort und Koordinaten auf einmal.
    @MainActor
    private func pickPlace(_ suggestion: AddressSuggestion) {
        Task {
            guard let resolved = await placeCompleter.resolve(suggestion) else { return }
            lastPickedStreet = resolved.street
            cityAutoFilled = false
            cityChoices = []
            address = resolved
            placeQuery = ""
            placeCompleter.clear()
            focusedField = nil
        }
    }

    @MainActor
    private func pick(_ suggestion: AddressSuggestion) {
        Task {
            guard let resolved = await completer.resolve(suggestion) else { return }
            lastPickedStreet = resolved.street
            cityAutoFilled = false
            cityChoices = []
            // Name einer zuvor gewählten Lokalität behalten
            let name = address.name
            address = resolved
            if address.name.isEmpty { address.name = name }
            completer.clear()
        }
    }
}
