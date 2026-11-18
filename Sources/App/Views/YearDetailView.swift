import SwiftUI
import Charts

/// Jahresübersicht: Kennzahlen, Monatsdiagramm und Fahrten nach Monaten.
struct YearDetailView: View {
    let summary: YearSummary
    let rate: Double
    let onNew: () -> Void
    let onSelect: (Trip) -> Void
    let onDuplicate: (Trip) -> Void
    let onDelete: (Trip) -> Void

    @State private var tripToDelete: Trip? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                statsRow
                if summary.tripCount > 0 {
                    MonthChartView(summary: summary)
                        .card()
                    ForEach(summary.activeMonths) { month in
                        MonthSection(month: month,
                                     rate: rate,
                                     onSelect: onSelect,
                                     onDuplicate: onDuplicate,
                                     onDelete: { tripToDelete = $0 })
                    }
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 20)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .confirmationDialog("Fahrt löschen?",
                            isPresented: Binding(get: { tripToDelete != nil },
                                                 set: { if !$0 { tripToDelete = nil } }),
                            presenting: tripToDelete) { trip in
            Button("Löschen", role: .destructive) { onDelete(trip) }
            Button("Abbrechen", role: .cancel) {}
        } message: { trip in
            Text("\(trip.title) vom \(Fmt.date(trip.date)) wird unwiderruflich gelöscht.")
        }
    }

    private let horizontalPadding: CGFloat = 32

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Fahrten \(String(summary.year))")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text("Übersicht aller Kundenfahrten mit Monats- und Jahressummen")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Button(action: onNew) {
                Label("Neue Fahrt", systemImage: "plus")
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var statsRow: some View {
        let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            StatCard(title: "Kilometer gesamt", value: Fmt.km(summary.totalKm), icon: "road.lanes", highlighted: true)
            StatCard(title: "Fahrten", value: String(summary.tripCount), icon: "car.fill")
            StatCard(title: "Ø pro Fahrt",
                     value: summary.tripCount > 0 ? Fmt.km(summary.totalKm / Double(summary.tripCount)) : "–",
                     icon: "gauge.with.dots.needle.33percent")
            StatCard(title: "Pauschale (\(Fmt.rate(rate))/km)",
                     value: Fmt.euro(summary.totalKm * rate),
                     icon: "eurosign.circle")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "map")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
            Text("Noch keine Fahrten in \(String(summary.year))")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("Lege deine erste Kundenfahrt an – die Kilometer werden automatisch berechnet.")
                .font(.callout)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            Button(action: onNew) {
                Label("Neue Fahrt", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .card()
    }
}

// MARK: - Bausteine

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var highlighted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.medium))
                .foregroundStyle(highlighted ? Color.white.opacity(0.9) : Theme.secondaryText)
                .lineLimit(1)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(highlighted ? Color.white : Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(highlighted ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(highlighted ? Color.clear : Theme.hairline, lineWidth: 1)
        )
    }
}

private struct MonthSection: View {
    let month: MonthSummary
    let rate: Double
    let onSelect: (Trip) -> Void
    let onDuplicate: (Trip) -> Void
    let onDelete: (Trip) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(month.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(Fmt.tripCount(month.trips.count))
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(Fmt.km(month.totalKm))
                    .font(.headline)
                    .foregroundStyle(Theme.accentDeep)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ForEach(Array(month.trips.enumerated()), id: \.element.id) { index, trip in
                Button { onSelect(trip) } label: {
                    TripRowView(trip: trip, rate: rate)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { onSelect(trip) } label: { Label("Bearbeiten", systemImage: "pencil") }
                    Button { onDuplicate(trip) } label: { Label("Duplizieren", systemImage: "plus.square.on.square") }
                    Divider()
                    Button(role: .destructive) { onDelete(trip) } label: { Label("Löschen", systemImage: "trash") }
                }
                if index < month.trips.count - 1 {
                    Divider().padding(.leading, 76)
                }
            }

            Divider()
            HStack {
                Text("Summe \(month.name)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(Fmt.km(month.totalKm))
                    .font(.subheadline.weight(.semibold))
                Text(Fmt.euro(month.totalKm * rate))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(minWidth: 90, alignment: .trailing)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.accentSoft.opacity(0.6))
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
    }
}

struct MonthChartView: View {
    let summary: YearSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kilometer pro Monat")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Chart(summary.months) { month in
                BarMark(
                    x: .value("Monat", Fmt.monthShort(month.month)),
                    y: .value("km", month.totalKm)
                )
                .foregroundStyle(Theme.accentGradient)
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Theme.hairline)
                    AxisValueLabel {
                        if let km = value.as(Double.self) {
                            Text(verbatim: "\(Int(km))")
                        }
                    }
                }
            }
            .frame(height: 140)
        }
    }
}
