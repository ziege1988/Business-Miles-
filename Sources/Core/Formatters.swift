import Foundation

/// Einheitliche deutsche Formatierung für App, Widget und Export.
enum Fmt {
    static let locale = Locale(identifier: "de_DE")

    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        cal.timeZone = .current
        return cal
    }()

    private static let kmFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }()

    private static let euroFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()

    private static let longDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "EEEE, d. MMMM yyyy"
        return f
    }()

    private static let symbols: DateFormatter = {
        let f = DateFormatter()
        f.locale = locale
        return f
    }()

    /// "47,0"
    static func number(_ value: Double) -> String {
        kmFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    /// "47,0 km"
    static func km(_ value: Double) -> String { number(value) + " km" }

    /// "14,10 €"
    static func euro(_ value: Double) -> String {
        euroFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f €", value)
    }

    /// "0,30 €" mit zwei Nachkommastellen
    static func rate(_ value: Double) -> String { euro(value) }

    static func date(_ date: Date) -> String { dateFormatter.string(from: date) }
    static func longDate(_ date: Date) -> String { longDateFormatter.string(from: date) }

    /// 1 → "Januar"
    static func monthName(_ month: Int) -> String {
        let names = symbols.standaloneMonthSymbols ?? []
        guard month >= 1, month <= names.count else { return "" }
        return names[month - 1]
    }

    /// 1 → "Jan."
    static func monthShort(_ month: Int) -> String {
        let names = symbols.shortStandaloneMonthSymbols ?? []
        guard month >= 1, month <= names.count else { return "" }
        return names[month - 1]
    }

    /// "Mo."
    static func weekdayShort(_ date: Date) -> String {
        let names = symbols.shortWeekdaySymbols ?? []
        let index = calendar.component(.weekday, from: date) - 1
        guard index >= 0, index < names.count else { return "" }
        return names[index]
    }

    static func tripCount(_ count: Int) -> String {
        count == 1 ? "1 Fahrt" : "\(count) Fahrten"
    }
}
