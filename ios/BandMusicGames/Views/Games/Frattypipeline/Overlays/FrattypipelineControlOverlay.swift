import SwiftUI

struct FrattypipelineControlOverlay: View {
    @ObservedObject var input: FrattypipelineInputController

    var body: some View {
        GeometryReader { geo in
            ZStack {
                FrattypipelineJoystickView(direction: $input.joystick)
                    .frame(width: 128, height: 128)
                    .position(x: 76, y: geo.size.height - 76)

                BarkButton {
                    input.triggerBark()
                }
                .frame(width: 128, height: 128)
                .position(x: geo.size.width - 76, y: geo.size.height - 76)
            }
        }
    }
}

private struct FrattypipelineJoystickView: View {
    @Binding var direction: CGVector
    @State private var anchor: CGPoint?
    @State private var knob: CGPoint?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.05))
                .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1.5))

            Text("MOVE")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.28))
                .opacity(anchor == nil ? 1 : 0)

            if let anchor {
                Circle()
                    .stroke(Color.white.opacity(0.55), lineWidth: 2)
                    .frame(width: 78, height: 78)
                    .position(anchor)
            }

            if let knob {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
                    .frame(width: 38, height: 38)
                    .position(knob)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if anchor == nil { anchor = value.startLocation }
                    knob = value.location
                    let dx = value.location.x - (anchor?.x ?? 0)
                    let dy = value.location.y - (anchor?.y ?? 0)
                    let distance = sqrt(dx * dx + dy * dy)
                    let cap: CGFloat = 40
                    let magnitude = min(distance, cap) / cap
                    if distance > 0.5 {
                        direction = CGVector(dx: (dx / distance) * magnitude, dy: (dy / distance) * magnitude)
                    }
                }
                .onEnded { _ in
                    anchor = nil
                    knob = nil
                    direction = .zero
                }
        )
    }
}

private struct BarkButton: View {
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            pressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                pressed = false
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.78, blue: 0.30).opacity(pressed ? 0.26 : 0.10))
                    .overlay(
                        Circle().stroke(
                            Color(red: 1.0, green: 0.78, blue: 0.30).opacity(pressed ? 0.95 : 0.38),
                            lineWidth: 2
                        )
                    )
                VStack(spacing: 2) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 26, weight: .bold))
                    Text("BARK")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                }
                .foregroundColor(Color(red: 1.0, green: 0.82, blue: 0.38))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Bark")
    }
}
