import SwiftUI

/// Animated Wurlitzer-style bubble tube — a column of rising colored bubbles
/// inside a dark glass cylinder with a chrome border.
struct BubbleTubeView: View {
    let bubbleColors: [Color]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                drawTube(ctx: ctx, size: size, t: t)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(chromeBorder, lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.55), radius: 4, x: 0, y: 2)
    }

    // MARK: - Drawing

    private func drawTube(ctx: GraphicsContext, size: CGSize, t: TimeInterval) {
        // Dark glass background
        ctx.fill(
            Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 10),
            with: .color(Color(red: 0.04, green: 0.04, blue: 0.08))
        )

        // Rising bubbles
        let count = bubbleColors.count * 3
        for i in 0..<count {
            let colorIdx = i % bubbleColors.count
            let speed    = 0.10 + Double(i % 5) * 0.025
            let phase    = (t * speed + Double(i) * 0.37).truncatingRemainder(dividingBy: 1.0)
            let y        = size.height * (1.0 - phase)
            let x        = size.width * 0.5
                         + sin(t * 0.55 + Double(i) * 2.3) * size.width * 0.18
            let r        = CGFloat(2.0 + Double(i % 3) * 1.2)
            let color    = bubbleColors[colorIdx]

            // Soft glow
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6)),
                with: .color(color.opacity(0.18))
            )
            // Bubble body
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(color.opacity(0.90))
            )
            // Specular highlight
            let hs = r * 0.45
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - r * 0.55, y: y - r * 0.7, width: hs, height: hs)),
                with: .color(.white.opacity(0.65))
            )
        }

        // Glass reflection — bright strip down the left edge
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: size.width * 0.38, height: size.height)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(0.18), location: 0),
                    .init(color: .clear, location: 1),
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width * 0.38, y: 0)
            )
        )
    }

    private var chromeBorder: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.85, green: 0.78, blue: 0.62),
                Color(red: 0.48, green: 0.44, blue: 0.35),
                Color(red: 0.88, green: 0.82, blue: 0.66),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

#Preview {
    HStack(spacing: 12) {
        BubbleTubeView(bubbleColors: [.orange, .yellow, .red])
            .frame(width: 28, height: 320)
        BubbleTubeView(bubbleColors: [.cyan, .purple, Color(hex: "#00FF88")])
            .frame(width: 28, height: 320)
    }
    .padding()
    .background(Color(red: 0.10, green: 0.05, blue: 0.03))
}
