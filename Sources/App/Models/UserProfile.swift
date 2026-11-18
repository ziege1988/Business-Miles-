import Foundation
import SwiftData

enum VehicleType: String, CaseIterable, Identifiable {
    case car, motorcycle, custom
    var id: String { rawValue }

    var label: String {
        switch self {
        case .car: "Pkw"
        case .motorcycle: "Motorrad / Motorroller"
        case .custom: "Eigener Satz"
        }
    }

    /// Pauschale Kilometersätze für Dienst-/Geschäftsreisen (Stand 2026).
    var defaultRate: Double? {
        switch self {
        case .car: 0.30
        case .motorcycle: 0.20
        case .custom: nil
        }
    }
}

/// Einstellungen (werden ebenfalls per iCloud synchronisiert).
@Model
final class UserProfile {
    var createdAt: Date = Date()

    // Angaben für die Steuer
    var fullName: String = ""
    var company: String = ""
    var taxNumber: String = ""

    // Startadresse (gleichzeitig Anschrift im Export)
    var homeStreet: String = ""
    var homePostalCode: String = ""
    var homeCity: String = ""
    var homeLatitude: Double?
    var homeLongitude: Double?
    var homeCoordinateKey: String?

    // Fahrzeug
    var vehicleName: String = ""
    var licensePlate: String = ""
    var vehicleTypeRaw: String = VehicleType.car.rawValue
    var ratePerKm: Double = 0.30

    init() {}

    var vehicleType: VehicleType {
        get { VehicleType(rawValue: vehicleTypeRaw) ?? .car }
        set { vehicleTypeRaw = newValue.rawValue }
    }

    var homeAddress: AddressValue {
        get {
            AddressValue(street: homeStreet, postalCode: homePostalCode, city: homeCity,
                         latitude: homeLatitude, longitude: homeLongitude,
                         coordinateKey: homeCoordinateKey)
        }
        set {
            homeStreet = newValue.street
            homePostalCode = newValue.postalCode
            homeCity = newValue.city
            homeLatitude = newValue.latitude
            homeLongitude = newValue.longitude
            homeCoordinateKey = newValue.coordinateKey
        }
    }

    var hasHomeAddress: Bool { homeAddress.isUsable }

    var isBlank: Bool {
        homeAddress.isEmpty && fullName.isEmpty && company.isEmpty
            && taxNumber.isEmpty && vehicleName.isEmpty && licensePlate.isEmpty
    }

    var vehicleDescription: String {
        [vehicleName, licensePlate].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// Liefert genau ein Profil – auch wenn durch den Sync kurzzeitig zwei existieren.
enum ProfileStore {
    static func current(_ profiles: [UserProfile]) -> UserProfile? {
        profiles.first(where: { $0.hasHomeAddress }) ?? profiles.first
    }

    @discardableResult
    static func ensure(in context: ModelContext, profiles: [UserProfile]) -> UserProfile {
        if let existing = current(profiles) { return existing }
        let profile = UserProfile()
        context.insert(profile)
        try? context.save()
        return profile
    }

    /// Entfernt leere Profile, die entstehen, wenn ein neues Gerät startet,
    /// bevor die Einstellungen aus iCloud geladen wurden.
    static func removeEmptyDuplicates(in context: ModelContext, profiles: [UserProfile]) {
        guard profiles.count > 1, let keep = current(profiles) else { return }
        var changed = false
        for p in profiles where p !== keep && p.isBlank {
            context.delete(p)
            changed = true
        }
        if changed { try? context.save() }
    }
}
