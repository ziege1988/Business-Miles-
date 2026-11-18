import Foundation
import CoreLocation

/// Strukturierte Adresse für Eingabe & Routenberechnung.
/// Koordinaten gelten nur, solange die Adresse seit dem Geocoding nicht verändert wurde.
struct AddressValue: Equatable, Hashable {
    var street: String = ""
    var postalCode: String = ""
    var city: String = ""
    var latitude: Double?
    var longitude: Double?
    /// `singleLine`, für die die Koordinaten ermittelt wurden.
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

    var isEmpty: Bool { singleLine.isEmpty }

    /// Mindestens Ort oder PLZ – reicht für eine (grobe) Routenberechnung.
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
