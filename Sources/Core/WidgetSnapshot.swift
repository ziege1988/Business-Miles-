import Foundation

/// Kleine, vorberechnete Zusammenfassung, die die App für das Widget
/// in die gemeinsamen App-Group-UserDefaults schreibt.
struct WidgetSnapshot: Codable, Equatable {
    struct Period: Codable, Equatable {
        var km: Double = 0
        var trips: Int = 0
    }

    /// Schlüssel "2026-11"
    var months: [String: Period] = [:]
    /// Schlüssel "2026"
    var years: [String: Period] = [:]
    var lastTripTitle: String?
    var lastTripDate: Date?
    var lastTripKm: Double?
    var updatedAt: Date = .distantPast

    static let empty = WidgetSnapshot()

    static func monthKey(year: Int, month: Int) -> String {
        String(format: "%04d-%02d", year, month)
    }

    func month(containing date: Date) -> Period {
        let c = Fmt.calendar.dateComponents([.year, .month], from: date)
        return months[Self.monthKey(year: c.year ?? 0, month: c.month ?? 0)] ?? Period()
    }

    func year(containing date: Date) -> Period {
        let y = Fmt.calendar.component(.year, from: date)
        return years[String(y)] ?? Period()
    }

    // MARK: Persistenz (Datei, ohne App-Group – funktioniert ohne Apple-Team-ID)

    private static var fileURL: URL { AppConfig.supportDirectory.appendingPathComponent("widget.json") }

    static func load() -> WidgetSnapshot {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? FileManager.default.createDirectory(at: AppConfig.supportDirectory, withIntermediateDirectories: true)
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    // MARK: Vorschau

    static var preview: WidgetSnapshot {
        let now = Date()
        let c = Fmt.calendar.dateComponents([.year, .month], from: now)
        var s = WidgetSnapshot()
        s.months[monthKey(year: c.year ?? 2026, month: c.month ?? 1)] = Period(km: 312.4, trips: 7)
        s.years[String(c.year ?? 2026)] = Period(km: 4_812.6, trips: 96)
        s.lastTripTitle = "Hochzeit Familie Berger"
        s.lastTripDate = now
        s.lastTripKm = 84.2
        s.updatedAt = now
        return s
    }
}
