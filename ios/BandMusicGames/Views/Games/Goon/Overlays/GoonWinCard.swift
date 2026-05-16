import SwiftUI

struct GoonWinCard: View {
    let onReplay: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(spacing: 22) {
                Text("YOU WON")
                    .font(.system(size: 40, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.0))
                    .tracking(4)
                Text("✦ THE FINAL YARD CONQUERED ✦")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(red: 0.55, green: 0.77, blue: 0.29))
                Button(action: onReplay) {
                    Text("REPLAY (RESETS PROGRESS)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 26).padding(.vertical, 13)
                        .background(Color(red: 1.0, green: 0.8, blue: 0.0))
                        .cornerRadius(10)
                }
            }
        }
    }
}
