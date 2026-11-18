import SwiftUI

/// Formen, die relativ zum verfügbaren Rechteck gezeichnet werden (0…1).
private struct UnitShape: Shape {
    let build: (CGRect) -> Path
    func path(in rect: CGRect) -> Path { build(rect) }
}

private func pt(_ rect: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
}

/// Bildmarke: geschwungene Route vom Startpunkt zum Ziel-Pin auf Petrol-Verlauf.
struct LogoMark: View {
    var size: CGFloat = 64

    // Geometrie in Einheitskoordinaten
    private static let pinCenter = CGPoint(x: 0.68, y: 0.31)
    private static let pinRadius: CGFloat = 0.13

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Theme.accentGradient)

            // Route (S-Kurve)
            UnitShape { r in
                var p = Path()
                p.move(to: pt(r, 0.26, 0.78))
                p.addCurve(to: pt(r, 0.68, 0.52),
                           control1: pt(r, 0.74, 0.80),
                           control2: pt(r, 0.24, 0.52))
                return p
            }
            .stroke(Color.white.opacity(0.95),
                    style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round, lineJoin: .round))

            // Startpunkt
            UnitShape { r in
                Path(ellipseIn: CGRect(origin: pt(r, 0.26 - 0.065, 0.78 - 0.065),
                                       size: CGSize(width: r.width * 0.13, height: r.height * 0.13)))
            }
            .fill(Color.white)

            // Pin-Spitze (Dreieck tangential an den Kreis)
            UnitShape { r in
                let c = Self.pinCenter, rad = Self.pinRadius
                var p = Path()
                p.move(to: pt(r, c.x - 0.809 * rad, c.y + 0.588 * rad))
                p.addLine(to: pt(r, c.x + 0.809 * rad, c.y + 0.588 * rad))
                p.addLine(to: pt(r, c.x, c.y + 1.75 * rad))
                p.closeSubpath()
                return p
            }
            .fill(Color.white)

            // Pin-Kopf
            UnitShape { r in
                let c = Self.pinCenter, rad = Self.pinRadius
                return Path(ellipseIn: CGRect(origin: pt(r, c.x - rad, c.y - rad),
                                              size: CGSize(width: r.width * rad * 2, height: r.height * rad * 2)))
            }
            .fill(Color.white)

            // Loch im Pin
            UnitShape { r in
                let c = Self.pinCenter, rad: CGFloat = 0.05
                return Path(ellipseIn: CGRect(origin: pt(r, c.x - rad, c.y - rad),
                                              size: CGSize(width: r.width * rad * 2, height: r.height * rad * 2)))
            }
            .fill(Theme.accentDeep)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Schriftzug „Business Miles“.
struct Wordmark: View {
    var size: CGFloat = 28

    var body: some View {
        (Text("Business ").foregroundColor(Theme.ink)
         + Text("Miles").foregroundColor(Theme.accent))
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .accessibilityLabel("Business Miles")
    }
}

/// Logo + Schriftzug nebeneinander.
struct LogoLockup: View {
    var markSize: CGFloat = 32
    var textSize: CGFloat = 20

    var body: some View {
        HStack(spacing: markSize * 0.35) {
            LogoMark(size: markSize)
            Wordmark(size: textSize)
        }
    }
}
