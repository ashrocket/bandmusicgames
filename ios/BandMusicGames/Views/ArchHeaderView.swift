import SwiftUI

/// The arched top of the jukebox cabinet — warm amber glow, chrome trim,
/// neon "BAND MUSIC GAMES" title.
struct ArchHeaderView: View {
    @State private var glowing = false

    var body: some View {
        ZStack {
            // Mahogany arch fill
            ArchShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.25, green: 0.13, blue: 0.06),
                            Color(red: 0.16, green: 0.08, blue: 0.04),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Warm amber glow — pulses gently
            ArchShape()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.65, blue: 0.10)
                                .opacity(glowing ? 0.50 : 0.28),
                            Color.clear,
                        ],
                        center: .top,
                        startRadius: 0,
                        endRadius: 160
                    )
                )
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: glowing)

            // Chrome border on the arch
            ArchShape()
                .stroke(warmChrome, lineWidth: 3.5)

            // Title
            VStack(spacing: 5) {
                Text("BAND MUSIC GAMES")
                    .font(.system(size: 20, weight: .black, design: .serif))
                    .tracking(5)
                    .foregroundStyle(amberGoldGradient)
                    .shadow(
                        color: Color(red: 1.0, green: 0.68, blue: 0.10).opacity(0.90),
                        radius: glowing ? 18 : 10
                    )
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: glowing)

                Text("SELECT A SONG TO PLAY")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .tracking(3.5)
                    .foregroundColor(Color(red: 0.85, green: 0.68, blue: 0.35).opacity(0.72))
            }
            .padding(.top, 24)
        }
        .onAppear { glowing = true }
    }

    // MARK: - Shared styles

    private var warmChrome: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.90, green: 0.82, blue: 0.62),
                Color(red: 0.55, green: 0.48, blue: 0.34),
                Color(red: 0.92, green: 0.86, blue: 0.66),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var amberGoldGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.92, blue: 0.55),
                Color(red: 1.0, green: 0.68, blue: 0.12),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Tombstone / arch shape

struct ArchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect.width / 2           // arch radius = half the width
        let archCenter = CGPoint(x: rect.midX, y: rect.minY + r)

        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: archCenter.y))
        // Semicircle across the top
        p.addArc(
            center: archCenter,
            radius: r,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    ArchHeaderView()
        .frame(height: 140)
        .padding(.horizontal, 16)
        .background(Color(red: 0.10, green: 0.05, blue: 0.03))
}
