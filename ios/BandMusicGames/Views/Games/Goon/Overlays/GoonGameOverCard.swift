import SwiftUI

struct GoonGameOverCard: View {
    let onRetry: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("OUT OF GAS")
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.2, blue: 0.2))
                HStack(spacing: 14) {
                    Button(action: onRetry) {
                        Text("RETRY")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 22).padding(.vertical, 12)
                            .background(Color(red: 1.0, green: 0.8, blue: 0.0))
                            .cornerRadius(8)
                    }
                    Button(action: onMenu) {
                        Text("MENU")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 22).padding(.vertical, 12)
                            .background(Color(white: 0.15))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}
