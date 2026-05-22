import SwiftUI

struct ForCuttingGrassControlOverlay: View {
    @ObservedObject var input: ForCuttingGrassInputController

    var body: some View {
        VStack(spacing: 6) {
            ControlStyleSelector(style: $input.controlStyle)

            HStack(alignment: .center, spacing: 16) {
                steeringControl
                    .frame(width: controlSize.width, height: controlSize.height)

                if input.canDig {
                    DigButton(isPressed: $input.digging)
                        .frame(width: 76, height: 76)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color.black.opacity(0.55))
    }

    private var controlSize: CGSize {
        switch input.controlStyle {
        case .joystick:
            return CGSize(width: 174, height: 174)
        case .dpad:
            return CGSize(width: 230, height: 174)
        case .wheel:
            return CGSize(width: 230, height: 174)
        case .trackpad:
            return CGSize(width: 226, height: 150)
        case .lean:
            return CGSize(width: 230, height: 166)
        }
    }

    @ViewBuilder
    private var steeringControl: some View {
        switch input.controlStyle {
        case .joystick:
            FloatingJoystickView(direction: $input.joystick, throttle: $input.throttle)
        case .dpad:
            DirectionPadView(direction: $input.joystick, throttle: $input.throttle)
        case .wheel:
            SteeringWheelView(direction: $input.joystick, throttle: $input.throttle)
        case .trackpad:
            TrackpadControlView(direction: $input.joystick, throttle: $input.throttle)
        case .lean:
            LeanControlView(direction: $input.joystick, throttle: $input.throttle)
        }
    }
}

private struct ControlStyleSelector: View {
    @Binding var style: ForCuttingGrassControlStyle

    var body: some View {
        HStack(spacing: 5) {
            ForEach(ForCuttingGrassControlStyle.allCases) { candidate in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        style = candidate
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: candidate.symbolName)
                            .font(.system(size: 14, weight: .bold))
                        Text(candidate.title)
                            .font(.system(size: 8.5, weight: .black, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                    .frame(width: 54, height: 42)
                    .foregroundColor(style == candidate ? .black : .white.opacity(0.72))
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(style == candidate ? Color(hex: "#ffd27a") : Color.black.opacity(0.42))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(style == candidate ? 0.0 : 0.14), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(candidate.title)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.26))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct FloatingJoystickView: View {
    @Binding var direction: CGVector
    @Binding var throttle: CGFloat
    @State private var anchor: CGPoint?
    @State private var knob: CGPoint?

    private let cap: CGFloat = 48

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.045))
                .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1.5))

            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 25, weight: .bold))
                .foregroundColor(.white.opacity(anchor == nil ? 0.25 : 0.12))

            if let a = anchor {
                Circle()
                    .stroke(Color.white.opacity(0.55), lineWidth: 2.5)
                    .frame(width: cap * 2, height: cap * 2)
                    .position(a)
            }

            if let k = knob {
                Circle()
                    .fill(Color.white.opacity(0.24))
                    .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 2))
                    .frame(width: 40, height: 40)
                    .position(k)
            }
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if anchor == nil { anchor = value.startLocation }
                    let origin = anchor ?? value.startLocation
                    let result = controlVector(from: value.location, origin: origin, radius: cap)
                    knob = result.knob
                    direction = cardinalBiased(result.vector)
                    throttle = vectorMagnitude(result.vector)
                }
                .onEnded { _ in
                    anchor = nil
                    knob = nil
                    direction = .zero
                    throttle = 0
                }
        )
    }
}

private struct DirectionPadView: View {
    @Binding var direction: CGVector
    @Binding var throttle: CGFloat
    @State private var thumb: CGPoint?

    var body: some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.045))
                        .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1.5))

                    VStack {
                        Image(systemName: "arrowtriangle.up.fill")
                        Spacer()
                        Image(systemName: "arrowtriangle.down.fill")
                    }
                    .padding(.vertical, 22)
                    .foregroundColor(.white.opacity(0.38))

                    HStack {
                        Image(systemName: "arrowtriangle.left.fill")
                        Spacer()
                        Image(systemName: "arrowtriangle.right.fill")
                    }
                    .padding(.horizontal, 22)
                    .foregroundColor(.white.opacity(0.38))

                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 46, height: 46)

                    if let thumb {
                        Circle()
                            .fill(Color(hex: "#ffd27a").opacity(0.82))
                            .frame(width: 20, height: 20)
                            .position(thumb)
                    }
                }
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let origin = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                            let result = controlVector(
                                from: value.location,
                                origin: origin,
                                radius: min(geo.size.width, geo.size.height) * 0.36,
                                fullSpeed: true
                            )
                            thumb = result.knob
                            direction = cardinalOnly(result.vector)
                        }
                        .onEnded { _ in
                            thumb = nil
                            direction = .zero
                        }
                )
            }
            .aspectRatio(1, contentMode: .fit)

            ThrottleButton(throttle: $throttle)
                .frame(width: 58, height: 112)
        }
    }
}

private struct SteeringWheelView: View {
    @Binding var direction: CGVector
    @Binding var throttle: CGFloat
    @State private var steer: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                let radius = min(geo.size.width, geo.size.height) * 0.38

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.045))
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1.5))

                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.38), lineWidth: 6)
                        ForEach(0..<3) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.22))
                                .frame(width: 5, height: radius)
                                .offset(y: -radius / 4)
                                .rotationEffect(.degrees(Double(i) * 120))
                        }
                        Circle()
                            .fill(Color(hex: "#ffd27a").opacity(0.46))
                            .frame(width: 32, height: 32)
                    }
                    .frame(width: radius * 1.75, height: radius * 1.75)
                    .rotationEffect(.degrees(Double(steer) * 72))
                }
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let centerX = geo.size.width / 2
                            steer = clamped((value.location.x - centerX) / max(1, radius))
                            direction = normalizedVector(CGVector(dx: steer * 0.85, dy: -1))
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.72)) {
                                steer = 0
                            }
                            direction = CGVector(dx: 0, dy: -1)
                        }
                )
                .onAppear {
                    direction = CGVector(dx: 0, dy: -1)
                }
            }
            .aspectRatio(1, contentMode: .fit)

            ThrottleButton(throttle: $throttle)
                .frame(width: 58, height: 112)
        }
    }
}

private struct TrackpadControlView: View {
    @Binding var direction: CGVector
    @Binding var throttle: CGFloat
    @State private var thumb: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) * 0.42

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1.5)
                    )

                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white.opacity(thumb == nil ? 0.25 : 0.10))

                if let thumb {
                    Circle()
                        .fill(Color.white.opacity(0.24))
                        .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 2))
                        .frame(width: 36, height: 36)
                        .position(thumb)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let result = controlVector(from: value.location, origin: center, radius: radius)
                        thumb = result.knob
                        direction = result.vector
                        throttle = vectorMagnitude(result.vector)
                    }
                    .onEnded { _ in
                        thumb = nil
                        direction = .zero
                        throttle = 0
                    }
            )
        }
    }
}

private struct LeanControlView: View {
    @Binding var direction: CGVector
    @Binding var throttle: CGFloat
    @State private var thumb: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) * 0.45

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1.5)
                    )

                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundColor(.white.opacity(thumb == nil ? 0.25 : 0.10))

                if let thumb {
                    Circle()
                        .fill(Color(hex: "#ffd27a").opacity(0.76))
                        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
                        .frame(width: 32, height: 32)
                        .position(thumb)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let result = controlVector(from: value.location, origin: center, radius: radius)
                        thumb = result.knob
                        let speed = min(1, abs(result.vector.dy))
                        throttle = speed
                        guard speed > 0.04 else {
                            direction = .zero
                            return
                        }
                        direction = normalizedVector(CGVector(dx: result.vector.dx * 0.85, dy: result.vector.dy))
                    }
                    .onEnded { _ in
                        thumb = nil
                        direction = .zero
                        throttle = 0
                    }
            )
        }
    }
}

private struct ThrottleButton: View {
    @Binding var throttle: CGFloat

    var body: some View {
        let pressed = throttle > 0.5

        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(pressed ? Color(hex: "#ffd27a").opacity(0.28) : Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(pressed ? Color(hex: "#ffd27a").opacity(0.75) : Color.white.opacity(0.18), lineWidth: 1.5)
                )

            VStack(spacing: 7) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .black))
                Text("GO")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .lineLimit(1)
            }
            .foregroundColor(pressed ? Color(hex: "#ffd27a") : .white.opacity(0.52))
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in throttle = 1 }
                .onEnded { _ in throttle = 0 }
        )
    }
}

private struct DigButton: View {
    @Binding var isPressed: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isPressed ? Color(red: 1.0, green: 0.8, blue: 0.0).opacity(0.18) : Color.yellow.opacity(0.06))
                .overlay(
                    Circle().stroke(
                        isPressed ? Color(red: 1.0, green: 0.8, blue: 0.0).opacity(0.75) : Color.yellow.opacity(0.27),
                        lineWidth: 1.5
                    )
                )
            Text("DIG")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(Color.yellow.opacity(0.58))
                .tracking(1)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

private func controlVector(
    from location: CGPoint,
    origin: CGPoint,
    radius: CGFloat,
    fullSpeed: Bool = false
) -> (vector: CGVector, knob: CGPoint) {
    let dx = location.x - origin.x
    let dy = location.y - origin.y
    let distance = sqrt(dx * dx + dy * dy)
    guard distance > 4 else {
        return (.zero, origin)
    }

    let limitedDistance = min(distance, radius)
    let unitX = dx / distance
    let unitY = dy / distance
    let magnitude = fullSpeed ? 1 : limitedDistance / radius
    let vector = CGVector(dx: unitX * magnitude, dy: unitY * magnitude)
    let knob = CGPoint(x: origin.x + unitX * limitedDistance, y: origin.y + unitY * limitedDistance)
    return (vector, knob)
}

private func cardinalBiased(_ vector: CGVector) -> CGVector {
    let magnitude = vectorMagnitude(vector)
    guard magnitude > 0.001 else { return .zero }

    let absX = abs(vector.dx)
    let absY = abs(vector.dy)
    let major = max(absX, absY)
    let minor = min(absX, absY)
    guard major > 0 else { return .zero }

    let effort = unitClamped((minor / major - 0.62) / 0.28)
    let adjusted: CGVector
    if absX >= absY {
        adjusted = CGVector(dx: vector.dx, dy: vector.dy * effort)
    } else {
        adjusted = CGVector(dx: vector.dx * effort, dy: vector.dy)
    }

    return normalizedVector(adjusted, magnitude: magnitude)
}

private func cardinalOnly(_ vector: CGVector) -> CGVector {
    guard vectorMagnitude(vector) > 0.001 else { return .zero }
    if abs(vector.dx) > abs(vector.dy) {
        return CGVector(dx: vector.dx < 0 ? -1 : 1, dy: 0)
    }
    return CGVector(dx: 0, dy: vector.dy < 0 ? -1 : 1)
}

private func normalizedVector(_ vector: CGVector, magnitude: CGFloat = 1) -> CGVector {
    let current = vectorMagnitude(vector)
    guard current > 0.001 else { return .zero }
    let target = max(0, min(1, magnitude))
    return CGVector(dx: vector.dx / current * target, dy: vector.dy / current * target)
}

private func clamped(_ value: CGFloat) -> CGFloat {
    min(1, max(-1, value))
}

private func unitClamped(_ value: CGFloat) -> CGFloat {
    min(1, max(0, value))
}

private func vectorMagnitude(_ vector: CGVector) -> CGFloat {
    sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
}
