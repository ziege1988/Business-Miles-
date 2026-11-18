import SwiftUI

/// Helles Start-Popup mit Logo und Schriftzug.
struct SplashView: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            Theme.background.opacity(0.96).ignoresSafeArea()

            VStack(spacing: 18) {
                LogoMark(size: 96)
                    .shadow(color: Theme.accentDeep.opacity(0.25), radius: 14, x: 0, y: 6)
                Wordmark(size: 34)
                Text("Fahrten erfassen. Kilometer im Blick.")
                    .font(.callout)
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 44)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Theme.ink.opacity(0.10), radius: 30, x: 0, y: 10)
            )
            .scaleEffect(appear ? 1 : 0.94)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appear = true }
        }
    }
}

#Preview { SplashView() }
