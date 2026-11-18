import WidgetKit
import SwiftUI

struct MilesEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct MilesProvider: TimelineProvider {
    func placeholder(in context: Context) -> MilesEntry {
        MilesEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (MilesEntry) -> Void) {
        let snapshot = context.isPreview ? WidgetSnapshot.preview : WidgetSnapshot.load()
        completion(MilesEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MilesEntry>) -> Void) {
        let now = Date()
        // Kurz nach Mitternacht neu laden (Monats-/Jahreswechsel)
        let tomorrow = Fmt.calendar.date(byAdding: .day, value: 1, to: Fmt.calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(86_400)
        let entry = MilesEntry(date: now, snapshot: WidgetSnapshot.load())
        completion(Timeline(entries: [entry], policy: .after(tomorrow.addingTimeInterval(60))))
    }
}

struct MilesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MilesEntry

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

                Link(destination: AppConfig.newTripURL) {
                    Label("Neue Fahrt", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.accentGradient))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .widgetURL(AppConfig.openURL)
    }
}

struct BusinessMilesWidget: Widget {
    let kind = "BusinessMilesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MilesProvider()) { entry in
            MilesWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.white }
        }
        .configurationDisplayName("Business Miles")
        .description("Kilometer im aktuellen Monat und Jahr auf einen Blick.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct BusinessMilesWidgetBundle: WidgetBundle {
    var body: some Widget {
        BusinessMilesWidget()
    }
}

#Preview(as: .systemSmall) {
    BusinessMilesWidget()
} timeline: {
    MilesEntry(date: .now, snapshot: .preview)
}

#Preview(as: .systemMedium) {
    BusinessMilesWidget()
} timeline: {
    MilesEntry(date: .now, snapshot: .preview)
}
