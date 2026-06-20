import SwiftUI
import SpriteKit

struct MechanicsPrototypeView: View {
    @Environment(\.dismiss) private var dismiss

    private var scene: MechanicsPrototypeScene {
        let s = MechanicsPrototypeScene()
        s.scaleMode = .resizeFill
        return s
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SpriteView(scene: scene, options: [.allowsTransparency])
                .ignoresSafeArea()
                .background(Color(red: 0.06, green: 0.07, blue: 0.10))

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(14)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.top, 56)
            .padding(.trailing, 20)
        }
        .statusBarHidden()
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MechanicsPrototypeView()
}
