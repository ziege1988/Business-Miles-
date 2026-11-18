import SwiftUI

/// Helles, ruhiges Farbschema: Navy für Text, Petrol als Akzent.
enum Theme {
    static let ink = Color(red: 0.110, green: 0.169, blue: 0.227)          // #1C2B3A
    static let secondaryText = Color(red: 0.357, green: 0.420, blue: 0.478) // #5B6B7A
    static let accent = Color(red: 0.059, green: 0.545, blue: 0.553)       // #0F8B8D
    static let accentDeep = Color(red: 0.086, green: 0.373, blue: 0.541)   // #165F8A
    static let accentSoft = Color(red: 0.890, green: 0.953, blue: 0.953)   // #E3F3F3
    static let background = Color(red: 0.961, green: 0.969, blue: 0.976)   // #F5F7F9
    static let card = Color.white
    static let hairline = Color(red: 0.886, green: 0.906, blue: 0.925)     // #E2E7EC
    static let warning = Color(red: 0.800, green: 0.467, blue: 0.133)

    static let accentGradient = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Weiße Karte mit dezentem Schatten.
struct CardBackground: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.card)
                    .shadow(color: Theme.ink.opacity(0.06), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardBackground(padding: padding)) }
}
