import SwiftUI

struct GoonLevelCompleteCard: View {
    let level: Int
    let onNext: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("LEVEL \(level)\nCOMPLETE")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.0))
                    .multilineTextAlignment(.center)
                Button(action: onNext) {
                    Text(level >= 5 ? "FINISH" : "NEXT LEVEL")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color(red: 1.0, green: 0.8, blue: 0.0))
                        .cornerRadius(10)
                }
            }
        }
    }
}
