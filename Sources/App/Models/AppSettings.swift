import Foundation

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

    /// Pauschale Kilometersätze für betrieblich veranlasste Fahrten mit Privatfahrzeug.
    var defaultRate: Double? {
        switch self {
        case .car: 0.30
        case .motorcycle: 0.20
        case .custom: nil
        }
    }
}

/// Einstellungen – liegen mit in der OneDrive-Datei und gelten damit auch auf dem iPhone.
struct AppSettings: Equatable {
    var fullName: String = ""
    var company: String = ""
    var taxNumber: String = ""
    /// Startadresse (gleichzeitig Anschrift im Export)
    var home = AddressValue()
    var vehicleName: String = ""
    var licensePlate: String = ""
    var vehicleTypeRaw: String = VehicleType.car.rawValue
    var ratePerKm: Double = 0.30
    var updatedAt = Date(timeIntervalSince1970: 0)

    var vehicleType: VehicleType {
        get { VehicleType(rawValue: vehicleTypeRaw) ?? .car }
        set { vehicleTypeRaw = newValue.rawValue }
    }

    var vehicleDescription: String {
        [vehicleName, licensePlate].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Vergleich ohne Zeitstempel (für „hat sich etwas geändert?“).
    func sameContent(as other: AppSettings) -> Bool {
        var a = self, b = other
        a.updatedAt = .distantPast
        b.updatedAt = .distantPast
        return a == b
    }
}

extension AppSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case fullName, company, taxNumber, home, vehicleName, licensePlate, vehicleType, ratePerKm, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func opt<T: Decodable>(_ type: T.Type, _ key: CodingKeys) -> T? { try? c.decodeIfPresent(type, forKey: key) }
        fullName = opt(String.self, .fullName) ?? ""
        company = opt(String.self, .company) ?? ""
        taxNumber = opt(String.self, .taxNumber) ?? ""
        home = opt(AddressValue.self, .home) ?? AddressValue()
        vehicleName = opt(String.self, .vehicleName) ?? ""
        licensePlate = opt(String.self, .licensePlate) ?? ""
        vehicleTypeRaw = opt(String.self, .vehicleType).flatMap { VehicleType(rawValue: $0)?.rawValue } ?? "car"
        ratePerKm = opt(Double.self, .ratePerKm) ?? 0.30
        updatedAt = ISOTime.date(opt(String.self, .updatedAt)) ?? Date(timeIntervalSince1970: 0)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(fullName, forKey: .fullName)
        try c.encode(company, forKey: .company)
        try c.encode(taxNumber, forKey: .taxNumber)
        try c.encode(home, forKey: .home)
        try c.encode(vehicleName, forKey: .vehicleName)
        try c.encode(licensePlate, forKey: .licensePlate)
        try c.encode(vehicleTypeRaw, forKey: .vehicleType)
        try c.encode(ratePerKm, forKey: .ratePerKm)
        try c.encode(ISOTime.string(updatedAt), forKey: .updatedAt)
    }
}

/// Inhalt der Datei `business-miles.json`.
struct DataFile: Codable {
    var format: String = "business-miles"
    var version: Int = 1
    var updatedAt: String = ISOTime.string(ISOTime.now)
    var settings = AppSettings()
    var trips: [Trip] = []

    private enum CodingKeys: String, CodingKey { case format, version, updatedAt, settings, trips }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = (try? c.decodeIfPresent(String.self, forKey: .updatedAt)) ?? ISOTime.string(ISOTime.now)
        settings = (try? c.decodeIfPresent(AppSettings.self, forKey: .settings)) ?? AppSettings()
        trips = (try? c.decodeIfPresent([Trip].self, forKey: .trips)) ?? []
    }

    /// Führt zwei Stände zusammen – pro Fahrt gewinnt das jüngere `updatedAt`,
    /// gelöschte Fahrten bleiben als Markierung erhalten (identisch zur Web-App).
    static func merge(_ a: DataFile, _ b: DataFile) -> DataFile {
        var byID: [String: Trip] = [:]
        for t in a.trips + b.trips {
            if let prev = byID[t.id], prev.updatedAt >= t.updatedAt { continue }
            byID[t.id] = t
        }
        var result = DataFile()
        result.settings = b.settings.updatedAt > a.settings.updatedAt ? b.settings : a.settings
        // Feste Reihenfolge (identisch zur Web-App): Datum → Erstellzeit → ID
        result.trips = byID.values.sorted {
            if $0.day != $1.day { return $0.day < $1.day }
            let a = ISOTime.string($0.createdAt), b = ISOTime.string($1.createdAt)
            if a != b { return a < b }
            return $0.id < $1.id
        }
        return result
    }

    /// Kanonische Darstellung ohne Datei-Zeitstempel – zum Vergleich, ob geschrieben werden muss.
    func canonicalData() -> Data {
        var copy = self
        copy.updatedAt = ""
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(copy)) ?? Data()
    }

    func fileData() throws -> Data {
        var copy = self
        copy.updatedAt = ISOTime.string(ISOTime.now)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(copy)
    }
}
