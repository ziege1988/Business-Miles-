import Foundation
import SwiftData

/// Eine Fahrt zum Kunden.
/// Hinweis CloudKit: Alle Attribute brauchen Standardwerte, keine `@Attribute(.unique)`.
@Model
final class Trip {
    var id: UUID = UUID()
    var date: Date = Date()

    /// Kunde / Geschäftspartner
    var customer: String = ""
    /// Anlass / Zweck der Fahrt
    var purpose: String = ""
    var note: String = ""

    // Ziel
    var destStreet: String = ""
    var destPostalCode: String = ""
    var destCity: String = ""
    var destLatitude: Double?
    var destLongitude: Double?

    // Start (bei `startUsesHome` eine Momentaufnahme der hinterlegten Startadresse)
    var startUsesHome: Bool = true
    var startStreet: String = ""
    var startPostalCode: String = ""
    var startCity: String = ""

    // Rückfahrt
    var returnEnabled: Bool = true
    var returnUsesHome: Bool = true
    var returnStreet: String = ""
    var returnPostalCode: String = ""
    var returnCity: String = ""

    // Strecke
    var outboundKm: Double = 0
    var returnKm: Double = 0

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init() {}

    // MARK: Abgeleitete Werte

    var totalKm: Double { outboundKm + (returnEnabled ? returnKm : 0) }

    var destination: AddressValue {
        get {
            AddressValue(street: destStreet, postalCode: destPostalCode, city: destCity,
                         latitude: destLatitude, longitude: destLongitude,
                         coordinateKey: destLatitude == nil ? nil
                            : AddressValue(street: destStreet, postalCode: destPostalCode, city: destCity).singleLine)
        }
        set {
            destStreet = newValue.street
            destPostalCode = newValue.postalCode
            destCity = newValue.city
            let valid = newValue.validCoordinate
            destLatitude = valid?.latitude
            destLongitude = valid?.longitude
        }
    }

    var start: AddressValue {
        get { AddressValue(street: startStreet, postalCode: startPostalCode, city: startCity) }
        set { startStreet = newValue.street; startPostalCode = newValue.postalCode; startCity = newValue.city }
    }

    var returnTarget: AddressValue {
        get { AddressValue(street: returnStreet, postalCode: returnPostalCode, city: returnCity) }
        set { returnStreet = newValue.street; returnPostalCode = newValue.postalCode; returnCity = newValue.city }
    }

    /// Überschrift in Listen: Kunde, sonst Ort.
    var title: String {
        let c = customer.trimmingCharacters(in: .whitespaces)
        if !c.isEmpty { return c }
        return destCity.isEmpty ? destination.singleLine : destCity
    }

    var routeDescription: String {
        if !returnEnabled { return "Einfache Fahrt" }
        return returnUsesHome && startUsesHome ? "Hin & zurück" : "Hin & Rückfahrt"
    }

    func amount(rate: Double) -> Double { (totalKm * rate * 100).rounded() / 100 }
}
