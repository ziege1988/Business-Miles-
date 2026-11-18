import Foundation
import MapKit
import CoreLocation

enum RouteError: LocalizedError {
    case addressNotFound(String)
    case noRoute

    var errorDescription: String? {
        switch self {
        case .addressNotFound(let address):
            "Adresse nicht gefunden: \(address)"
        case .noRoute:
            "Für diese Strecke konnte keine Route berechnet werden. Bitte km manuell eintragen."
        }
    }
}

/// PLZ → Ort, Geocoding und Routen-Kilometer über Apple Maps.
enum RouteService {

    /// Ermittelt den Ort zu einer deutschen Postleitzahl.
    static func city(forPostalCode plz: String) async -> String? {
        let code = plz.trimmingCharacters(in: .whitespaces)
        guard code.count == 5, code.allSatisfy(\.isNumber) else { return nil }
        let placemarks = try? await CLGeocoder().geocodeAddressString("\(code), Deutschland")
        guard let pm = placemarks?.first(where: { $0.postalCode == code }) ?? placemarks?.first
        else { return nil }
        return pm.locality ?? pm.subAdministrativeArea
    }

    static func coordinate(for address: AddressValue) async throws -> CLLocationCoordinate2D {
        if let c = address.validCoordinate { return c }
        let query = address.singleLine
        guard !query.isEmpty else { throw RouteError.addressNotFound("(leer)") }
        let placemarks = try? await CLGeocoder().geocodeAddressString(query + ", Deutschland")
        guard let location = placemarks?.first?.location else {
            throw RouteError.addressNotFound(query)
        }
        return location.coordinate
    }

    /// Straßen-Kilometer (Auto, von Apple Maps empfohlene Route), auf 0,1 km gerundet.
    static func drivingDistanceKm(from start: AddressValue, to destination: AddressValue) async throws -> Double {
        let from = try await coordinate(for: start)
        let to = try await coordinate(for: destination)
        try Task.checkCancellation()

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let response: MKDirections.Response
        do {
            response = try await MKDirections(request: request).calculate()
        } catch {
            throw RouteError.noRoute
        }
        guard let route = response.routes.first else { throw RouteError.noRoute }
        return (route.distance / 100).rounded() / 10
    }
}
