import SwiftUI

struct GoonControlOverlay: View {
    @ObservedObject var input: GoonInputController

    var body: some View {
        GeometryReader { geo in
            ZStack {
                JoystickView(direction: $input.joystick)
                    .frame(width: 130, height: 130)
                    .position(x: geo.size.width / 2, y: geo.size.height - 75)
                if input.canDig {
                    DigButton(isPressed: $input.digging)
                        .frame(width: 130, height: 130)
                        .position(x: geo.size.width - 75, y: geo.size.height - 75)
                }
            }
        }
    }
}

private struct JoystickView: View {
    @Binding var direction: CGVector
    @State private var anchor: CGPoint?
    @State private var knob: CGPoint?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.04))
                .overlay(Circle().stroke(Color.white.opacity(0.13), lineWidth: 1.5))

            Text("MOVE")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
                .tracking(1)
                .opacity(anchor == nil ? 1 : 0)

            if let a = anchor {
                Circle()
                    .stroke(Color.white.opacity(0.55), lineWidth: 2.5)
                    .frame(width: 80, height: 80)
                    .position(a)
            }
            if let k = knob {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
                    .frame(width: 38, height: 38)
                    .position(k)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if anchor == nil { anchor = v.startLocation }
                    knob = v.location
                    let dx = v.location.x - (anchor?.x ?? 0)
                    let dy = v.location.y - (anchor?.y ?? 0)
                    let d = sqrt(dx * dx + dy * dy)
                    let cap: CGFloat = 40
                    let mag = min(d, cap) / cap
                    if d > 0.5 {
                        direction = CGVector(dx: (dx / d) * mag, dy: (dy / d) * mag)
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

private struct DigButton: View {
    @Binding var isPressed: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isPressed ? Color(red: 1.0, green: 0.8, blue: 0.0).opacity(0.18) : Color.yellow.opacity(0.04))
                .overlay(
                    Circle().stroke(
                        isPressed ? Color(red: 1.0, green: 0.8, blue: 0.0).opacity(0.75) : Color.yellow.opacity(0.25),
                        lineWidth: 1.5
                    )
                )
            Text("DIG")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Color.yellow.opacity(0.45))
                .tracking(1)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}
