import SwiftUI

struct GoonHUDOverlay: View {
    @ObservedObject var scene: GoonGameScene

    var body: some View {
        VStack {
            HStack(spacing: 16) {
                gasBar
                cutText
                goalText
                Spacer()
                scoreText
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.80))
            Spacer()
        }
    }

    private var gasBar: some View {
        HStack(spacing: 6) {
            Text("GAS").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            ZStack(alignment: .leading) {
                Capsule().fill(Color(white: 0.13)).frame(width: 56, height: 7)
                Capsule()
                    .fill(gasColor)
                    .frame(width: max(0, 56 * CGFloat(gasFrac)), height: 7)
            }
        }
    }

    private var cutText: some View {
        HStack(spacing: 4) {
            Text("CUT").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            Text("\(Int(scene.grid.cutPercentage * 100))%")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.0))
        }
    }

    private var goalText: some View {
        HStack(spacing: 4) {
            Text("GOAL").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            Text("\(Int(scene.config.win * 100))%")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.gray)
        }
    }

    private var scoreText: some View {
        HStack(spacing: 4) {
            Text("SCORE").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            Text("\(scene.score)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    private var gasFrac: Double { Double(scene.gas / scene.config.gasMax) }
    private var gasColor: Color {
        if gasFrac > 0.5 { return Color(red: 0.0, green: 0.8, blue: 0.27) }
        if gasFrac > 0.25 { return Color(red: 1.0, green: 0.67, blue: 0.0) }
        return Color(red: 1.0, green: 0.2, blue: 0.2)
    }
}
