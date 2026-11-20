import Foundation
import CoreLocation

/// Strukturierte Adresse für Eingabe, Routenberechnung und Datei (siehe docs/DATENFORMAT.md).
/// Koordinaten gelten nur, solange die Adresse seit dem Geocoding nicht verändert wurde.
struct AddressValue: Equatable, Hashable {
    /// Name der Lokalität / Firma (optional), z. B. „Café Sek Sol“
    var name: String = ""
    var street: String = ""
    var postalCode: String = ""
    var city: String = ""
    var latitude: Double?
    var longitude: Double?
    /// `singleLine`, für die die Koordinaten ermittelt wurden (wird nicht gespeichert).
    var coordinateKey: String?

    var cityLine: String {
        [postalCode, city]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// "Musterstraße 12, 80331 München"
    var singleLine: String {
        [street.trimmingCharacters(in: .whitespaces), cityLine]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// Mit Name der Lokalität: "Café Sek Sol, Bahnhofstraße 5, 36037 Fulda"
    var displayLine: String {
        [name.trimmingCharacters(in: .whitespaces), singleLine].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var isEmpty: Bool { singleLine.isEmpty && name.isEmpty }

    /// Mindestens Ort oder PLZ – reicht für eine Routenberechnung.
    var isUsable: Bool {
        !city.trimmingCharacters(in: .whitespaces).isEmpty
            || postalCode.trimmingCharacters(in: .whitespaces).count == 5
    }

    var validCoordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude, coordinateKey == singleLine else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    mutating func setCoordinate(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        coordinateKey = singleLine
    }
}

extension AddressValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, street, postalCode, city, lat, lon
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        street = (try? c.decodeIfPresent(String.self, forKey: .street)) ?? ""
        postalCode = (try? c.decodeIfPresent(String.self, forKey: .postalCode)) ?? ""
        city = (try? c.decodeIfPresent(String.self, forKey: .city)) ?? ""
        latitude = try? c.decodeIfPresent(Double.self, forKey: .lat)
        longitude = try? c.decodeIfPresent(Double.self, forKey: .lon)
        coordinateKey = (latitude != nil && longitude != nil) ? singleLine : nil
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(street, forKey: .street)
        try c.encode(postalCode, forKey: .postalCode)
        try c.encode(city, forKey: .city)
        // Koordinaten nur speichern, wenn sie zur aktuellen Adresse gehören
        let coordinate = validCoordinate
        try c.encode(coordinate?.latitude, forKey: .lat)
        try c.encode(coordinate?.longitude, forKey: .lon)
    }
}
