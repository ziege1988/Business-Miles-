import Foundation

/// Zeitstempel im Dateiformat: ISO 8601, UTC, Millisekunden.
enum ISOTime {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Aktuelle Zeit, auf Millisekunden gerundet (wie im Dateiformat).
    static var now: Date {
        Date(timeIntervalSince1970: (Date().timeIntervalSince1970 * 1000).rounded() / 1000)
    }

    static func string(_ date: Date) -> String { withFraction.string(from: date) }

    static func date(_ string: String?) -> Date? {
        guard let string else { return nil }
        return withFraction.date(from: string) ?? plain.date(from: string)
    }
}

/// Kalendertag "2026-11-18" ↔ Date (lokale Zeitzone, Mitternacht).
enum DayString {
    static func string(_ date: Date) -> String {
        let c = Fmt.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    static func date(_ string: String) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Fmt.calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

/// Eine Fahrt zum Kunden (Feldnamen = Dateiformat, siehe docs/DATENFORMAT.md).
struct Trip: Identifiable, Hashable {
    /// UUID als Zeichenkette – Schreibweise wird unverändert übernommen (Web-App nutzt Kleinbuchstaben).
    var id: String = UUID().uuidString
    var day: String = DayString.string(Date())

    var customer: String = ""
    var purpose: String = ""
    var note: String = ""

    var destination = AddressValue()
    var startUsesHome: Bool = true
    var start = AddressValue()
    var returnEnabled: Bool = true
    var returnUsesHome: Bool = true
    var returnTarget = AddressValue()

    var outboundKm: Double = 0
    var returnKm: Double = 0
    /// Kilometersatz dieser Fahrt (€/km). nil = Satz aus den Einstellungen.
    var ratePerKm: Double? = nil
    /// Optionale Uhrzeiten "HH:MM" (z. B. für Verpflegungsmehraufwand)
    var departureTime: String = ""
    var returnTime: String = ""
    /// Offline erfasst – km werden nachberechnet.
    var kmPending: Bool = false

    var source: String = "mac"
    var createdAt: Date = ISOTime.now
    var updatedAt: Date = ISOTime.now
    var deleted: Bool = false

    // MARK: Abgeleitete Werte

    var date: Date {
        get { DayString.date(day) ?? Date() }
        set { day = DayString.string(newValue) }
    }

    var totalKm: Double { outboundKm + (returnEnabled ? returnKm : 0) }

    var title: String {
        let c = customer.trimmingCharacters(in: .whitespaces)
        if !c.isEmpty { return c }
        return destination.city.isEmpty ? destination.singleLine : destination.city
    }

    var routeDescription: String { returnEnabled ? "Hin & zurück" : "Einfache Fahrt" }

    /// Wirksamer km-Satz: eigener Satz der Fahrt, sonst der aus den Einstellungen.
    func rate(default defaultRate: Double) -> Double { ratePerKm ?? defaultRate }

    func amount(rate defaultRate: Double) -> Double {
        (totalKm * rate(default: defaultRate) * 100).rounded() / 100
    }

    /// "08:30–17:45", "ab 08:30" oder ""
    var timeRange: String {
        switch (departureTime.isEmpty, returnTime.isEmpty) {
        case (false, false): return "\(departureTime)–\(returnTime)"
        case (false, true): return "ab \(departureTime)"
        case (true, false): return "bis \(returnTime)"
        case (true, true): return ""
        }
    }
}

extension Trip: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, date, customer, purpose, note, destination, startUsesHome, start
        case returnEnabled, returnUsesHome, returnTo, outboundKm, returnKm, kmPending
        case ratePerKm, departureTime, returnTime
        case source, createdAt, updatedAt, deleted
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func opt<T: Decodable>(_ type: T.Type, _ key: CodingKeys) -> T? { try? c.decodeIfPresent(type, forKey: key) }

        id = opt(String.self, .id) ?? UUID().uuidString
        day = opt(String.self, .date).flatMap { DayString.date($0) != nil ? $0 : nil } ?? DayString.string(Date())
        customer = opt(String.self, .customer) ?? ""
        purpose = opt(String.self, .purpose) ?? ""
        note = opt(String.self, .note) ?? ""
        destination = opt(AddressValue.self, .destination) ?? AddressValue()
        startUsesHome = opt(Bool.self, .startUsesHome) ?? true
        start = opt(AddressValue.self, .start) ?? AddressValue()
        returnEnabled = opt(Bool.self, .returnEnabled) ?? true
        returnUsesHome = opt(Bool.self, .returnUsesHome) ?? true
        returnTarget = opt(AddressValue.self, .returnTo) ?? AddressValue()
        outboundKm = opt(Double.self, .outboundKm) ?? 0
        returnKm = opt(Double.self, .returnKm) ?? 0
        kmPending = opt(Bool.self, .kmPending) ?? false
        ratePerKm = opt(Double.self, .ratePerKm)
        departureTime = opt(String.self, .departureTime) ?? ""
        returnTime = opt(String.self, .returnTime) ?? ""
        source = opt(String.self, .source) ?? ""
        createdAt = ISOTime.date(opt(String.self, .createdAt)) ?? ISOTime.now
        updatedAt = ISOTime.date(opt(String.self, .updatedAt)) ?? Date(timeIntervalSince1970: 0)
        deleted = opt(Bool.self, .deleted) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(day, forKey: .date)
        try c.encode(customer, forKey: .customer)
        try c.encode(purpose, forKey: .purpose)
        try c.encode(note, forKey: .note)
        try c.encode(destination, forKey: .destination)
        try c.encode(startUsesHome, forKey: .startUsesHome)
        try c.encode(start, forKey: .start)
        try c.encode(returnEnabled, forKey: .returnEnabled)
        try c.encode(returnUsesHome, forKey: .returnUsesHome)
        try c.encode(returnTarget, forKey: .returnTo)
        try c.encode(outboundKm, forKey: .outboundKm)
        try c.encode(returnKm, forKey: .returnKm)
        try c.encode(kmPending, forKey: .kmPending)
        try c.encode(ratePerKm, forKey: .ratePerKm)
        try c.encode(departureTime, forKey: .departureTime)
        try c.encode(returnTime, forKey: .returnTime)
        try c.encode(source, forKey: .source)
        try c.encode(ISOTime.string(createdAt), forKey: .createdAt)
        try c.encode(ISOTime.string(updatedAt), forKey: .updatedAt)
        try c.encode(deleted, forKey: .deleted)
    }
}
