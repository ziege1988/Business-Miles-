import SwiftUI

/// Jahres-Kacheln als Slider: auf dem Mac senkrecht rechts, auf dem iPhone waagerecht oben.
struct YearTilesView: View {
    let years: [YearSummary]
    @Binding var selection: Int
    var axis: Axis = .vertical

    var body: some View {
        if axis == .vertical {
            VStack(alignment: .leading, spacing: 0) {
                Text("JAHRE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .tracking(1.2)
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 6)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) { tiles }
                        .padding(16)
                }
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) { tiles }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private var tiles: some View {
        ForEach(years) { year in
            YearTile(summary: year, isSelected: year.year == selection, compact: axis == .horizontal)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = year.year }
                }
        }
    }
}

private struct YearTile: View {
    let summary: YearSummary
    let isSelected: Bool
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 6) {
            Text(verbatim: String(summary.year))
                .font(.system(compact ? .title3 : .title, design: .rounded).weight(.bold))
            Text(Fmt.km(summary.totalKm))
                .font(compact ? .footnote.weight(.semibold) : .headline)
            Text(Fmt.tripCount(summary.tripCount))
                .font(.caption)
                .opacity(0.8)
        }
        .foregroundStyle(isSelected ? Color.white : Theme.ink)
        .frame(maxWidth: compact ? nil : .infinity, alignment: .leading)
        .frame(minWidth: compact ? 112 : nil, alignment: .leading)
        .padding(compact ? 12 : 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white))
                .shadow(color: Theme.ink.opacity(isSelected ? 0.18 : 0.05), radius: isSelected ? 10 : 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.clear : Theme.hairline, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
