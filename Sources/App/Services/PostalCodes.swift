import Foundation

/// PLZ → Ort aus der mitgelieferten Tabelle `plz.json` (offline, identisch zur Web-App).
/// Daten © OpenStreetMap-Mitwirkende (ODbL), aufbereitet von suche-postleitzahl.org.
enum PostalCodes {
    private static let table: [String: [String]] = {
        guard let url = Bundle.main.url(forResource: "plz", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [:] }
        return decoded
    }()

    /// Orte zu einer fünfstelligen PLZ (meist einer, manchmal mehrere).
    static func cities(for postalCode: String) -> [String] {
        let code = postalCode.trimmingCharacters(in: .whitespaces)
        guard code.count == 5, code.allSatisfy(\.isNumber) else { return [] }
        return table[code] ?? []
    }
}
