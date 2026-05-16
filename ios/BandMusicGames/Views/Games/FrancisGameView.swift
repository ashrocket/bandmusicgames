import SwiftUI
import CoreMotion

// MARK: - Game constants

private let targetNormPoints: [(Double, Double)] = [
    (0.18, 0.35), (0.35, 0.52), (0.52, 0.28), (0.72, 0.62), (0.88, 0.38),
]
private let canonicalEdges: [(Int, Int)] = [(0,1),(1,2),(2,3),(3,4)]
private let ambientCount = 75
private let trackDurationMs: Double = 212_000   // Francis · Darger ≈ 3:32

// MARK: - Models

private struct AmbientStar {
    let id: Int
    let nx, ny, radius: Double
    var lit = false

    static func pseudo(_ n: Int) -> Double {
        let x = sin(Double(n) * 9301 + 49297) * 233280
        return x - floor(x)
    }
}

private struct TargetStar {
    let id: Int
    let nx, ny: Double
    var lit = false
}

private struct StarLink: Identifiable {
    let id = UUID()
    let a, b: Int
    let correct: Bool
}

private enum GamePhase { case pressPlay, intro, playing, ended }

// MARK: - Game state

@MainActor
private final class FrancisGame: ObservableObject {
    @Published var phase: GamePhase = .pressPlay
    @Published var ambient: [AmbientStar]
    @Published var targets: [TargetStar]
    @Published var links: [StarLink] = []
    @Published var dragFrom: Int? = nil
    @Published var cursorNorm: CGPoint? = nil
    @Published var revealed = false
    @Published var flashOn = false
    @Published var positionMs: Double = 0
    @Published var tiltX: Double = 0
    @Published var tiltY: Double = 0

    private var ticker: Timer?
    private var startTime: Date?
    private let motion = CMMotionManager()

    init() {
        ambient = (0..<ambientCount).map { i in
            AmbientStar(id: i,
                        nx: AmbientStar.pseudo(i * 2 + 1),
                        ny: AmbientStar.pseudo(i * 2 + 2),
                        radius: 0.6 + AmbientStar.pseudo(i * 3) * 1.4)
        }
        targets = targetNormPoints.enumerated().map { i, p in
            TargetStar(id: i, nx: p.0, ny: p.1)
        }
    }

    func onPlayPressed() {
        guard phase == .pressPlay else { return }
        phase = .intro
        startTime = Date()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        startMotion()
        // Transition from intro → playing after the dog sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 9.4) {
            if self.phase == .intro { self.phase = .playing }
        }
    }

    func stop() {
        ticker?.invalidate()
        motion.stopDeviceMotionUpdates()
    }

    private func tick() {
        guard let t0 = startTime else { return }
        positionMs = min(-t0.timeIntervalSinceNow * 1000, trackDurationMs)
        updateReveal()
        if phase == .playing && positionMs >= trackDurationMs - 500 { endMatch() }
    }

    private func updateReveal() {
        let t = positionMs / trackDurationMs
        let ambLit = Int(min(t / 0.3, 1.0) * Double(ambientCount))
        for i in ambient.indices { ambient[i].lit = i < ambLit }
        let tgtLit = Int(max(0, (t - 0.05) / 0.20) * Double(targets.count))
        for i in targets.indices { targets[i].lit = i < tgtLit }
        if t >= 0.3 && !revealed {
            revealed = true
            for i in targets.indices { targets[i].lit = true }
            doFlash(count: 3)
        }
    }

    private func doFlash(count: Int) {
        guard count > 0 else { return }
        flashOn = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.flashOn = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.doFlash(count: count - 1)
            }
        }
    }

    func tryConnect(_ a: Int, _ b: Int) {
        guard a != b else { return }
        let key = edgeKey(a, b)
        guard !links.contains(where: { edgeKey($0.a, $0.b) == key }) else { return }
        let correct = canonicalEdges.contains { edgeKey($0.0, $0.1) == key }
        links.append(StarLink(a: a, b: b, correct: correct))
        if links.filter(\.correct).count == 4 { endMatch() }
    }

    private func endMatch() {
        guard phase != .ended else { return }
        phase = .ended
        ticker?.invalidate()
    }

    func nearestTarget(nx: Double, ny: Double, threshold: Double) -> Int? {
        targets
            .filter { $0.lit || revealed }
            .min(by: { hypot($0.nx - nx, $0.ny - ny) < hypot($1.nx - nx, $1.ny - ny) })
            .flatMap { t -> Int? in
                hypot(t.nx - nx, t.ny - ny) < threshold ? t.id : nil
            }
    }

    private func edgeKey(_ a: Int, _ b: Int) -> String { a < b ? "\(a)-\(b)" : "\(b)-\(a)" }

    var correctCount: Int { links.filter(\.correct).count }

    private func startMotion() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            Task { @MainActor [weak self] in
                self?.tiltX = data.attitude.roll * 10
                self?.tiltY = (data.attitude.pitch - .pi / 2) * 5
            }
        }
    }
}

// MARK: - Main view

struct FrancisGameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: SpotifyAuthManager
    @StateObject private var game = FrancisGame()

    var body: some View {
        ZStack {
            Color(hex: "#050810").ignoresSafeArea()
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    skyBackground
                    starCanvas(size: geo.size)
                    if game.phase == .pressPlay  { pressPlayOverlay }
                    if game.phase == .intro      { DogIntroView(onDone: {}) }
                    if game.phase == .playing    { hud }
                    if game.phase == .ended      { ResultCardView(correct: game.correctCount, total: 4, onDismiss: { dismiss() }) }
                    controls
                }
                .contentShape(Rectangle())
                .gesture(dragGesture(in: geo.size))
            }
            .ignoresSafeArea()
        }
        .onAppear {
            if auth.accessToken != nil {
                Task { await auth.playTrack("spotify:track:64h0585a6LWXOdsCD2pOiW") }
            }
        }
        .onDisappear { game.stop() }
    }

    // MARK: Sky background

    private var skyBackground: some View {
        LinearGradient(
            colors: [Color(hex: "#151d36"), Color(hex: "#0a0f1e"), Color(hex: "#050810")],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: Star canvas

    private func starCanvas(size: CGSize) -> some View {
        Canvas { ctx, _ in
            let tx = game.tiltX
            let ty = game.tiltY
            let ttx = tx * 0.55
            let tty = ty * 0.55

            // Ambient stars
            for s in game.ambient where s.lit {
                let x = s.nx * size.width + tx
                let y = s.ny * size.height + ty
                let r = s.radius
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .color(.white.opacity(0.55))
                )
            }

            // User links
            for link in game.links {
                let a = game.targets[link.a], b = game.targets[link.b]
                var path = Path()
                path.move(to: CGPoint(x: a.nx * size.width + ttx, y: a.ny * size.height + tty))
                path.addLine(to: CGPoint(x: b.nx * size.width + ttx, y: b.ny * size.height + tty))
                let color: Color = link.correct ? Color(hex: "#a6f0a6") : Color(hex: "#ff8066")
                ctx.stroke(path, with: .color(color.opacity(link.correct ? 0.85 : 0.6)), lineWidth: 1.5)
            }

            // Pending drag line
            if let fi = game.dragFrom, let cur = game.cursorNorm {
                let from = game.targets[fi]
                var path = Path()
                path.move(to: CGPoint(x: from.nx * size.width + ttx, y: from.ny * size.height + tty))
                path.addLine(to: CGPoint(x: cur.x * size.width, y: cur.y * size.height))
                ctx.stroke(path, with: .color(Color(hex: "#f5b461").opacity(0.6)),
                           style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }

            // Constellation flash
            if game.flashOn {
                for e in canonicalEdges {
                    let a = game.targets[e.0], b = game.targets[e.1]
                    var path = Path()
                    path.move(to: CGPoint(x: a.nx * size.width + ttx, y: a.ny * size.height + tty))
                    path.addLine(to: CGPoint(x: b.nx * size.width + ttx, y: b.ny * size.height + tty))
                    ctx.stroke(path, with: .color(Color(hex: "#f5b461").opacity(0.9)),
                               style: StrokeStyle(lineWidth: 1.5, dash: [2, 6]))
                }
            }

            // Target stars
            for t in game.targets where t.lit {
                let x = t.nx * size.width + ttx
                let y = t.ny * size.height + tty
                let isActive = game.dragFrom == t.id
                let r: Double = isActive ? 8 : 4
                let accent = Color(hex: "#ffd27a")
                // Glow
                ctx.fill(Path(ellipseIn: CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6)),
                         with: .color(accent.opacity(0.25)))
                // Core
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .color(accent))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Drag gesture

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let nx = v.location.x / size.width
                let ny = v.location.y / size.height
                if game.dragFrom == nil {
                    game.dragFrom = game.nearestTarget(nx: nx, ny: ny, threshold: 0.07)
                }
                game.cursorNorm = CGPoint(x: nx, y: ny)
            }
            .onEnded { v in
                let nx = v.location.x / size.width
                let ny = v.location.y / size.height
                if let fi = game.dragFrom,
                   let ti = game.nearestTarget(nx: nx, ny: ny, threshold: 0.07) {
                    game.tryConnect(fi, ti)
                }
                game.dragFrom = nil
                game.cursorNorm = nil
            }
    }

    // MARK: Press play overlay

    private var pressPlayOverlay: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("Press play to begin")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(.white)
            Text("Francis · Darger")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#6d7a94"))
            Spacer().frame(height: 40)
            playButton
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { game.onPlayPressed() }
    }

    private var playButton: some View {
        Button {
            game.onPlayPressed()
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: "#ffd27a"))
                    .frame(width: 80, height: 80)
                    .shadow(color: Color(hex: "#ffd27a").opacity(0.5), radius: 20)
                Image(systemName: "play.fill")
                    .font(.system(size: 30, weight: .black))
                    .foregroundColor(Color(hex: "#050810"))
                    .offset(x: 3)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: HUD

    private var hud: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Francis")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    Text("Darger")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#6d7a94"))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(game.correctCount) / 4")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    let remaining = max(0, trackDurationMs - game.positionMs)
                    Text(fmtClock(remaining) + " left")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(remaining < 30_000 ? Color(hex: "#ff8066") : Color(hex: "#ffd27a"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)

            // Progress bar
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06)).frame(height: 2)
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "#ffd27a"), Color(hex: "#f5b461")],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * min(game.positionMs / trackDurationMs, 1), height: 2)
                }
            }
            .frame(height: 2)
            .padding(.horizontal, 16)
            .padding(.top, 6)

            Spacer()
        }
    }

    // MARK: Controls (always visible)

    private var controls: some View {
        VStack {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.black.opacity(0.5))
                        .padding(12)
                }
            }
            Spacer()
        }
    }

    // MARK: Helpers

    private func fmtClock(_ ms: Double) -> String {
        let s = max(0, Int(ms / 1000))
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}

// MARK: - Dog intro

private struct DogIntroView: View {
    let onDone: () -> Void
    @State private var dogVisible = false
    @State private var thought1 = false
    @State private var thought2 = false
    @State private var thought3 = false

    var body: some View {
        ZStack {
            // Dog
            VStack {
                Spacer()
                HStack {
                    dogShape
                        .offset(x: dogVisible ? 0 : -300)
                        .animation(.spring(duration: 0.9, bounce: 0.2), value: dogVisible)
                    Spacer()
                }
                .padding(.bottom, 120)
            }

            // Thought bubbles
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        if thought1 {
                            ThoughtBubble(text: "stars will appear")
                                .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                         removal: .opacity))
                        }
                        if thought2 {
                            ThoughtBubble(text: "a constellation will blink")
                                .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                         removal: .opacity))
                        }
                        if thought3 {
                            ThoughtBubble(text: "drag between stars to match it")
                                .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                         removal: .opacity))
                        }
                    }
                    .padding(.leading, 100)
                    Spacer()
                }
                .padding(.bottom, 160)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { runSequence() }
    }

    private var dogShape: some View {
        Text("🐕")
            .font(.system(size: 72))
            .padding(.leading, 24)
    }

    private func runSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation { dogVisible = true }
        }
        show("thought1", at: 1.4, hide: 3.4)
        show("thought2", at: 3.6, hide: 5.6)
        show("thought3", at: 5.8, hide: 8.3)
    }

    private func show(_ name: String, at show: Double, hide: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + show) {
            withAnimation(.easeOut(duration: 0.4)) {
                switch name {
                case "thought1": thought1 = true
                case "thought2": thought2 = true
                default:         thought3 = true
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + hide) {
            withAnimation(.easeIn(duration: 0.3)) {
                switch name {
                case "thought1": thought1 = false
                case "thought2": thought2 = false
                default:         thought3 = false
                }
            }
        }
    }
}

private struct ThoughtBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color(hex: "#1a1408"))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "#ffd27a").opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color(hex: "#ffd27a").opacity(0.2), radius: 8)
    }
}

// MARK: - Result card

private struct ResultCardView: View {
    let correct: Int
    let total: Int
    let onDismiss: () -> Void

    @State private var flipped = false

    private let won: Bool

    init(correct: Int, total: Int, onDismiss: @escaping () -> Void) {
        self.correct = correct
        self.total = total
        self.onDismiss = onDismiss
        self.won = correct == total
    }

    var body: some View {
        ZStack {
            Color(hex: "#050810").opacity(0.7)
                .ignoresSafeArea()

            ZStack {
                // Card back
                cardBack
                    .opacity(flipped ? 0 : 1)

                // Card front
                cardFront
                    .opacity(flipped ? 1 : 0)
                    .rotation3DEffect(.degrees(flipped ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            }
            .frame(width: min(360, UIScreen.main.bounds.width * 0.86))
            .aspectRatio(3/4, contentMode: .fit)
            .rotation3DEffect(.degrees(flipped ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            .animation(.spring(duration: 1.2), value: flipped)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                flipped = true
            }
        }
    }

    private var cardBack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(colors: [Color(hex: "#131a33"), Color(hex: "#0e1328")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Text("CASSIOPEIA")
                .font(.system(size: 32, weight: .light))
                .tracking(8)
                .foregroundColor(Color(hex: "#ffd27a"))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#ffd27a").opacity(0.3), lineWidth: 1)
        )
    }

    private var cardFront: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Cassiopeia")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(Color(hex: "#ffd27a"))
            Text("the Seated Queen")
                .font(.system(size: 12))
                .italic()
                .foregroundColor(Color(hex: "#6d7a94"))
                .padding(.top, 2)
                .padding(.bottom, 20)

            // Score
            HStack {
                Rectangle()
                    .fill(Color(hex: "#ffd27a"))
                    .frame(width: 3)
                Text(won ? "Perfect match — \(total) / \(total) lines" : "You matched \(correct) of \(total) lines.")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color(hex: "#ffd27a").opacity(0.08))
            .cornerRadius(8)
            .padding(.bottom, 18)

            Text("Named for the vain queen of Greek myth, punished by the sea god Poseidon to circle the north celestial pole for eternity, seated on her throne.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(4)
                .padding(.bottom, 12)

            Text("Her distinctive **W** shape is one of the easiest patterns to find in the northern sky. Visible all year round from most of the Northern Hemisphere, best seen in autumn.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(4)

            Spacer()

            // Star list
            VStack(alignment: .leading, spacing: 6) {
                ForEach(["α · Schedar · \"the breast\"",
                         "β · Caph · \"the palm\"",
                         "γ · Gamma Cassiopeiae · unnamed",
                         "δ · Ruchbah · \"the knee\"",
                         "ε · Segin · unnamed"], id: \.self) { s in
                    Text(s).font(.system(size: 11)).foregroundColor(Color(hex: "#6d7a94"))
                }
            }
            .padding(.top, 16)
            .padding(.top, 16)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color(hex: "#ffd27a").opacity(0.15))
                    .frame(height: 1)
            }

            Button(action: onDismiss) {
                Text("← BACK TO JUKEBOX")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(Color(hex: "#1a1408"))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#ffd27a"))
                    .clipShape(Capsule())
            }
            .padding(.top, 20)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [Color(hex: "#181f3a"), Color(hex: "#0d1224")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#ffd27a").opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 20)
    }
}
