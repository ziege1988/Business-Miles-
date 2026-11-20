import WidgetKit
import SwiftUI

struct MilesEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Inhalt des Widgets – liegt in Core, damit die App ihn auch für Vorschaubilder zeichnen kann.
struct MilesWidgetContent: View {
    let entry: MilesEntry
    let family: WidgetFamily
    /// false = als Bild zeichnen (Vorschaubild), dort kann kein Link dargestellt werden
    var interactive: Bool = true

    /// macOS zeigt Schreibtisch-Widgets oft abgedunkelt/einfarbig („vibrant“) – dann Systemfarben statt fester Farben,
    /// sonst wäre dunkle Schrift auf dunklem Grund unsichtbar.
    @Environment(\.widgetRenderingMode) private var renderingMode
    private var fullColor: Bool { renderingMode == .fullColor }
    private var ink: Color { fullColor ? Theme.ink : .primary }
    private var muted: Color { fullColor ? Theme.secondaryText : .secondary }
    private var accentText: Color { fullColor ? Theme.accentDeep : .primary }

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
        case .systemMedium: medium
        default: small
        }
    }

    // MARK: Klein

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                LogoMark(size: 20).widgetAccentable()
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
            .background(Capsule().fill(fullColor ? Theme.accentSoft : Color.primary.opacity(0.12)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(AppConfig.openURL)
    }

    // MARK: Mittel

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    LogoMark(size: 20).widgetAccentable()
                    if fullColor {
                        Wordmark(size: 13)
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
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(fullColor ? Theme.background : Color.primary.opacity(0.08)))

                if interactive {
                    Link(destination: AppConfig.newTripURL) { newTripLabel }
                } else {
                    newTripLabel
                }
            }
            .frame(maxWidth: .infinity)
        }
        .widgetURL(AppConfig.openURL)
    }
}

