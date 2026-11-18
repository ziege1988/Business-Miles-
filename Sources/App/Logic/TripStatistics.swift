import Foundation

struct MonthSummary: Identifiable {
    let year: Int
    let month: Int
    let trips: [Trip]          // absteigend nach Datum
    var id: Int { month }

    var totalKm: Double { trips.reduce(0) { $0 + $1.totalKm } }
    var name: String { Fmt.monthName(month) }
    func amount(defaultRate: Double) -> Double { trips.reduce(0) { $0 + $1.amount(rate: defaultRate) } }
}

struct YearSummary: Identifiable {
    let year: Int
    let months: [MonthSummary] // immer 12 Einträge, Januar … Dezember
    var id: Int { year }

    var trips: [Trip] { months.reversed().flatMap(\.trips) }
    var totalKm: Double { months.reduce(0) { $0 + $1.totalKm } }
    var tripCount: Int { months.reduce(0) { $0 + $1.trips.count } }
    func amount(defaultRate: Double) -> Double { months.reduce(0) { $0 + $1.amount(defaultRate: defaultRate) } }
    var activeMonths: [MonthSummary] { months.filter { !$0.trips.isEmpty }.reversed() }
}

enum TripStatistics {
    /// Gruppiert Fahrten nach Jahr/Monat. Das aktuelle Jahr ist immer enthalten.
    static func years(from trips: [Trip], now: Date = .now) -> [YearSummary] {
        let cal = Fmt.calendar
        var buckets: [Int: [Int: [Trip]]] = [:]
        for trip in trips {
            let c = cal.dateComponents([.year, .month], from: trip.date)
            guard let y = c.year, let m = c.month else { continue }
            buckets[y, default: [:]][m, default: []].append(trip)
        }
        let currentYear = cal.component(.year, from: now)
        if buckets[currentYear] == nil { buckets[currentYear] = [:] }

        return buckets.keys.sorted(by: >).map { year in
            let months = (1...12).map { month in
                MonthSummary(
                    year: year,
                    month: month,
                    trips: (buckets[year]?[month] ?? []).sorted { $0.date > $1.date }
                )
            }
            return YearSummary(year: year, months: months)
        }
    }
}
