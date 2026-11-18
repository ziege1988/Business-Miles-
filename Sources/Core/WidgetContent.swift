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
                LogoMark(size: 20)
                Text("Business Miles")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(monthName)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
            Text(Fmt.km(month.km))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(Fmt.tripCount(month.trips))
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
            Spacer(minLength: 6)
            HStack(spacing: 4) {
                Text(verbatim: yearText)
                    .font(.caption2.weight(.semibold))
                Text(Fmt.km(year.km))
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Theme.accentDeep)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.accentSoft))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(AppConfig.openURL)
    }

    // MARK: Mittel

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                LogoLockup(markSize: 20, textSize: 13)
                Spacer(minLength: 6)
                Text(monthName)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Text(Fmt.km(month.km))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("\(yearText): \(Fmt.km(year.km)) · \(Fmt.tripCount(year.trips))")
                    .font(.caption2)
                    .foregroundStyle(Theme.accentDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Letzte Fahrt")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                    if let title = entry.snapshot.lastTripTitle, let date = entry.snapshot.lastTripDate {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text("\(Fmt.date(date)) · \(Fmt.km(entry.snapshot.lastTripKm ?? 0))")
                            .font(.caption2)
                            .foregroundStyle(Theme.secondaryText)
                    } else {
                        Text("Noch keine Fahrten")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.background))

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

