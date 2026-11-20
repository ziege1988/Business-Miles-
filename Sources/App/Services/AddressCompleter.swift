import Foundation
import MapKit

struct AddressSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let completion: MKLocalSearchCompletion
}

/// Straßenvorschläge über Apple Maps (MKLocalSearchCompleter).
@MainActor
final class AddressCompleter: NSObject, ObservableObject {
    @Published private(set) var suggestions: [AddressSuggestion] = []

    private let completer = MKLocalSearchCompleter()

    private let includesPlaces: Bool

    /// includesPlaces: auch Lokalitäten (Cafés, Firmen, Hotels …) vorschlagen
    init(includesPlaces: Bool = false) {
        self.includesPlaces = includesPlaces
        super.init()
        completer.delegate = self
        completer.resultTypes = includesPlaces ? [.pointOfInterest, .address] : .address
        // Suche auf Deutschland ausrichten (Mittelpunkt ca. Kassel, ~900 km Ausdehnung)
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.16, longitude: 10.45),
            span: MKCoordinateSpan(latitudeDelta: 8.5, longitudeDelta: 10.5)
        )
    }

    func update(street: String, postalCode: String, city: String) {
        let s = street.trimmingCharacters(in: .whitespaces)
        guard s.count >= 3 else {
            clear()
            return
        }
        let query = [s, postalCode, city]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        completer.queryFragment = query
    }

    /// Freie Suche („Café Sek Sol Fulda“)
    func search(_ text: String) {
        let q = text.trimmingCharacters(in: .whitespaces)
        guard q.count >= 3 else {
            clear()
            return
        }
        completer.queryFragment = q
    }

    func clear() {
        completer.cancel()
        suggestions = []
    }

    /// Löst einen Vorschlag in eine vollständige Adresse inkl. Koordinaten auf.
    func resolve(_ suggestion: AddressSuggestion) async -> AddressValue? {
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        request.resultTypes = includesPlaces ? [.pointOfInterest, .address] : .address
        guard let response = try? await MKLocalSearch(request: request).start(),
              let item = response.mapItems.first
        else { return nil }

        let pm = item.placemark
        var street = pm.thoroughfare ?? suggestion.title
        if let number = pm.subThoroughfare, !number.isEmpty {
            street += " " + number
        }
        var address = AddressValue(street: pm.thoroughfare == nil && item.pointOfInterestCategory != nil ? "" : street,
                                   postalCode: pm.postalCode ?? "",
                                   city: pm.locality ?? "")
        if item.pointOfInterestCategory != nil, let name = item.name {
            address.name = name
        }
        address.setCoordinate(pm.coordinate)
        return address
    }
}

extension AddressCompleter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        MainActor.assumeIsolated {
            self.suggestions = results.prefix(6).map {
                AddressSuggestion(title: $0.title, subtitle: $0.subtitle, completion: $0)
            }
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            self.suggestions = []
        }
    }
}
