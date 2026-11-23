import SwiftUI

/// Größe der Schreibtisch-Kachel
enum TileSize: String, CaseIterable, Identifiable {
    case small, medium
    var id: String { rawValue }
    var label: String { self == .small ? "Klein" : "Mittel" }
    var contentSize: CGSize { self == .small ? CGSize(width: 170, height: 170) : CGSize(width: 364, height: 170) }
}

struct MilesEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Inhalt der Schreibtisch-Kachel (Monats-/Jahres-km, letzte Fahrt, „Neue Fahrt“).
struct MilesWidgetContent: View {
    let entry: MilesEntry
    let family: TileSize
    /// Aktion für den Knopf „Neue Fahrt“ (nil = Knopf nur anzeigen, z. B. im Vorschaubild)
    var onNewTrip: (() -> Void)? = nil
    /// Dunkle Darstellung (dunkelgrauer Hintergrund, helle Schrift)
    var dark: Bool = false

    private let fullColor = true
    private var ink: Color { dark ? Color(white: 0.95) : Theme.ink }
    private var muted: Color { dark ? Color(white: 0.68) : Theme.secondaryText }
    private var accentText: Color { dark ? Color(red: 0.42, green: 0.80, blue: 0.81) : Theme.accentDeep }
    private var chipBackground: Color { dark ? Color.white.opacity(0.10) : Theme.accentSoft }
    private var boxBackground: Color { dark ? Color.white.opacity(0.07) : Theme.background }

    private var newTripLabel: some View {
        Label("Neue Fahrt", systemImage: "plus")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Capsule().fill(Theme.accentGradient))
    }

    private var month: WidgetSnapshot.Period { entry.snapshot.month(containing: entry.date) }
    private var year: WidgetSnapshot.Period { entry.snapshot.year(containing: entry.date) }
    private var monthName: String { Fmt.monthName(Fmt.calendar.component(.month, from: entry.date)) }
    private var yearText: String { String(Fmt.calendar.component(.year, from: entry.date)) }

    var body: some View {
        switch family {
        case .medium: medium
        default: small
        }
    }

    // MARK: Klein

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                LogoMark(size: 20)
                Text("Business Miles")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(monthName)
                .font(.caption)
                .foregroundStyle(muted)
            Text(Fmt.km(month.km))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(Fmt.tripCount(month.trips))
                .font(.caption2)
                .foregroundStyle(muted)
            Spacer(minLength: 6)
            HStack(spacing: 4) {
                Text(verbatim: yearText)
                    .font(.caption2.weight(.semibold))
                Text(Fmt.km(year.km))
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(accentText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(chipBackground))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Mittel

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    LogoMark(size: 20)
                    if fullColor {
                        (Text("Business ").foregroundColor(ink) + Text("Miles").foregroundColor(Theme.accent))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    } else {
                        Text("Business Miles").font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                }
                Spacer(minLength: 6)
                Text(monthName)
                    .font(.caption)
                    .foregroundStyle(muted)
                Text(Fmt.km(month.km))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("\(yearText): \(Fmt.km(year.km)) · \(Fmt.tripCount(year.trips))")
                    .font(.caption2)
                    .foregroundStyle(accentText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Letzte Fahrt")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(muted)
                    if let title = entry.snapshot.lastTripTitle, let date = entry.snapshot.lastTripDate {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ink)
                            .lineLimit(1)
                        Text("\(Fmt.date(date)) · \(Fmt.km(entry.snapshot.lastTripKm ?? 0))")
                            .font(.caption2)
                            .foregroundStyle(muted)
                    } else {
                        Text("Noch keine Fahrten")
                            .font(.caption)
                            .foregroundStyle(muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(boxBackground))

                if let onNewTrip {
                    Button(action: onNewTrip) { newTripLabel }
                        .buttonStyle(.plain)
                } else {
                    newTripLabel
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

