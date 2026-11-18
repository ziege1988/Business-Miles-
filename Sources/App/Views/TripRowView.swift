import SwiftUI

struct TripRowView: View {
    let trip: Trip
    let rate: Double

    private var day: String { String(Fmt.calendar.component(.day, from: trip.date)) }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Datum-Kachel
            VStack(spacing: 0) {
                Text(Fmt.weekdayShort(trip.date).uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.accentDeep)
                Text(verbatim: day)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(width: 46, height: 46)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.accentSoft)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(trip.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(trip.destination.singleLine)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !trip.purpose.isEmpty {
                        Text(trip.purpose)
                    }
                    if !trip.startUsesHome {
                        Label("Start: \(trip.start.city.isEmpty ? trip.start.singleLine : trip.start.city)",
                              systemImage: "arrow.triangle.turn.up.right.diamond")
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                if trip.kmPending {
                    Text("km folgen")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.warning.opacity(0.12)))
                } else {
                    Text(Fmt.km(trip.totalKm))
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                }
                Text(trip.routeDescription)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Text(Fmt.euro(trip.amount(rate: rate)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
