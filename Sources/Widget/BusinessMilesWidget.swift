import WidgetKit
import SwiftUI

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

    var body: some View {
        MilesWidgetContent(entry: entry, family: family)
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
