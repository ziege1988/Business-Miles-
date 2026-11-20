import Foundation

/// Berechnet die Kennzahlen für die Schreibtisch-Kachel.
enum WidgetSync {
    static func signature(of trips: [Trip]) -> Int {
        var hasher = Hasher()
        for t in trips {
            hasher.combine(t.id)
            hasher.combine(t.date)
            hasher.combine(t.totalKm)
            hasher.combine(t.title)
        }
        return hasher.finalize()
    }

    static func snapshot(for trips: [Trip]) -> WidgetSnapshot {
        let cal = Fmt.calendar
        var snapshot = WidgetSnapshot()
        for t in trips {
            let c = cal.dateComponents([.year, .month], from: t.date)
            guard let y = c.year, let m = c.month else { continue }
            let mk = WidgetSnapshot.monthKey(year: y, month: m)
            snapshot.months[mk, default: .init()].km += t.totalKm
            snapshot.months[mk, default: .init()].trips += 1
            snapshot.years[String(y), default: .init()].km += t.totalKm
            snapshot.years[String(y), default: .init()].trips += 1
        }
        if let last = trips.filter({ $0.date <= .now }).max(by: { $0.date < $1.date }) {
            snapshot.lastTripTitle = last.title
            snapshot.lastTripDate = last.date
            snapshot.lastTripKm = last.totalKm
        }
        return snapshot
    }
}
