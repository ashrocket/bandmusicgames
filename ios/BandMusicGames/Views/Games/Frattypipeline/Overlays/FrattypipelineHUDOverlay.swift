import SwiftUI

struct FrattypipelineHUDOverlay: View {
    @ObservedObject var scene: FrattypipelineScene

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                questPanel
                Spacer(minLength: 8)
                beatMeter
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            Spacer()
        }
    }

    private var questPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(scene.questState.title.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.30))
            Text(scene.questState.detail)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.86))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            HStack(spacing: 6) {
                statusPill(scene.lastBarkWasOnBeat ? "ON BEAT" : "BARKS \(scene.barkCount)")
                statusPill("PATCH 01")
            }
            .padding(.top, 2)
        }
        .padding(12)
        .frame(maxWidth: 330, alignment: .leading)
        .background(Color.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var beatMeter: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.62))
                .frame(width: 76, height: 76)
                .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))

            Circle()
                .trim(from: 0, to: CGFloat(scene.beatPhase))
                .stroke(Color(red: 1.0, green: 0.78, blue: 0.30), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 58, height: 58)
                .rotationEffect(.degrees(-90))

            Text("BEAT")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundColor(.white.opacity(0.88))
        }
        .accessibilityLabel("Beat timing meter")
    }

    private func statusPill(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .foregroundColor(.white.opacity(0.72))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08), in: Capsule())
    }
}
