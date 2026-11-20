import Foundation

/// Unveränderliche Momentaufnahme für den Export (reine Werte, unabhängig vom Speicher).
struct ReportData {
    struct Row: Identifiable {
        let id: String
        let date: Date
        let customer: String
        let purpose: String
        let start: String
        let destination: String
        /// Leer = keine Rückfahrt
        let returnTo: String
        let returnEnabled: Bool
        let outboundKm: Double
        let returnKm: Double
        let totalKm: Double
        let rate: Double
        let amount: Double
        let note: String
        let departureTime: String
        let returnTime: String
        let timeRange: String
        let kmPending: Bool
    }

    struct MonthGroup: Identifiable {
        let month: Int
        let rows: [Row]  // aufsteigend nach Datum
        var id: Int { month }
        var outboundKm: Double { rows.reduce(0) { $0 + $1.outboundKm } }
        var returnKm: Double { rows.reduce(0) { $0 + $1.returnKm } }
        var totalKm: Double { rows.reduce(0) { $0 + $1.totalKm } }
        var amount: Double { rows.reduce(0) { $0 + $1.amount } }
    }

    struct Header {
        var name: String
        var company: String
        var address: String
        var taxNumber: String
        var vehicle: String
        var vehicleType: String
        var rate: Double
    }

    let year: Int
    let month: Int?
    let header: Header
    let groups: [MonthGroup]   // aufsteigend nach Monat
    let createdAt: Date

    var periodLabel: String {
        if let month { return "\(Fmt.monthName(month)) \(year)" }
        return "Jahr \(year)"
    }

    var title: String { "Fahrtenaufstellung \(periodLabel)" }

    var rows: [Row] { groups.flatMap(\.rows) }
    var tripCount: Int { rows.count }
    var totalKm: Double { groups.reduce(0) { $0 + $1.totalKm } }
    var outboundKm: Double { groups.reduce(0) { $0 + $1.outboundKm } }
    var returnKm: Double { groups.reduce(0) { $0 + $1.returnKm } }
    var amount: Double { groups.reduce(0) { $0 + $1.amount } }
    /// Haben Fahrten unterschiedliche km-Sätze?
    var hasMixedRates: Bool { Set(rows.map(\.rate)).count > 1 }
    var hasTimes: Bool { rows.contains { !$0.timeRange.isEmpty } }
    var hasPendingKm: Bool { rows.contains { $0.kmPending } }
    var rateLabel: String {
        hasMixedRates ? "je Fahrt angegeben (Standard \(Fmt.rate(header.rate)) je km)" : "\(Fmt.rate(rows.first?.rate ?? header.rate)) je km"
    }

    var fileBaseName: String {
        if let month { return String(format: "Business-Miles_Fahrten_%04d-%02d", year, month) }
        return String(format: "Business-Miles_Fahrten_%04d", year)
    }

    // MARK: Aufbau

    static func make(summary: YearSummary, month: Int?, settings: AppSettings) -> ReportData {
        let rate = settings.ratePerKm
        let months = summary.months.filter { m in
            !m.trips.isEmpty && (month == nil || m.month == month)
        }
        let groups = months.map { m in
            MonthGroup(month: m.month, rows: m.trips
                .sorted { ($0.day, $0.departureTime) < ($1.day, $1.departureTime) }
                .map { row(for: $0, rate: rate) })
        }
        let header = Header(
            name: settings.fullName,
            company: settings.company,
            address: settings.home.singleLine,
            taxNumber: settings.taxNumber,
            vehicle: settings.vehicleDescription,
            vehicleType: settings.vehicleType.exportLabel,
            rate: rate
        )
        return ReportData(year: summary.year, month: month, header: header, groups: groups, createdAt: .now)
    }

    private static func row(for trip: Trip, rate: Double) -> Row {
        Row(
            id: trip.id,
            date: trip.date,
            customer: trip.customer,
            purpose: trip.purpose,
            start: trip.start.singleLine,
            destination: trip.destination.displayLine,
            returnTo: trip.returnEnabled ? trip.returnTarget.singleLine : "",
            returnEnabled: trip.returnEnabled,
            outboundKm: trip.outboundKm,
            returnKm: trip.returnEnabled ? trip.returnKm : 0,
            totalKm: trip.totalKm,
            rate: trip.rate(default: rate),
            amount: trip.amount(rate: rate),
            note: trip.kmManual ? ["km manuell angepasst", trip.note].filter { !$0.isEmpty }.joined(separator: " – ") : trip.note,
            departureTime: trip.departureTime,
            returnTime: trip.returnTime,
            timeRange: trip.timeRange,
            kmPending: trip.kmPending
        )
    }
}
