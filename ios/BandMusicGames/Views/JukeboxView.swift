import SwiftUI

struct JukeboxView: View {
    @Binding var selectedIndex: Int
    let selectionTrigger: Int
    let onPlay: () -> Void
    let onShowSpotify: () -> Void
    let onSkip: () -> Void

    @EnvironmentObject private var auth: SpotifyAuthManager

    @State private var showingKnot = false
    @State private var knotResetTask: Task<Void, Never>?

    private let songs = Song.catalog

    private var currentSong: Song { songs[selectedIndex] }
    private var isCurrentSongPlaying: Bool {
        auth.isPlaying && auth.currentTrackUri == currentSong.trackUri
    }
    private var deckStatus: String {
        if showingKnot {
            return "NEEDLE"
        }
        if isCurrentSongPlaying {
            return "SPINNING"
        }
        return "READY"
    }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 720
            let horizontalPadding = min(max(geo.size.width * 0.055, 16), 30)
            let topPadding = min(max(geo.safeAreaInsets.top * 0.55, 24), 44)
            let bottomPadding = max(geo.safeAreaInsets.bottom, 14) + 8
            let contentWidth = max(0, geo.size.width - horizontalPadding * 2)
            let contentHeight = max(0, geo.size.height - topPadding - bottomPadding)

            ZStack(alignment: .top) {
                background(song: currentSong)

                VStack(spacing: compact ? 8 : 12) {
                    topBar

                    animatedSelector(in: geo.size, compact: compact)

                    selectionList(compact: compact)
                        .opacity(showingKnot ? 0 : 1)
                        .scaleEffect(showingKnot ? 0.96 : 1)

                    musicControls(compact: compact)
                        .opacity(showingKnot ? 0 : 1)

                    Spacer(minLength: 0)
                }
                .frame(width: contentWidth, height: contentHeight, alignment: .top)
                .padding(.top, topPadding)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onChange(of: selectionTrigger) { _ in
            playKnotAnimation()
        }
        .onDisappear {
            knotResetTask?.cancel()
            showingKnot = false
        }
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            Image(systemName: "music.note")
                .font(.system(size: 13, weight: .black))
                .foregroundColor(.black.opacity(0.82))
                .frame(width: 28, height: 28)
                .background(currentSong.color)
                .clipShape(Circle())
                .shadow(color: currentSong.color.opacity(0.32), radius: 12, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text("BMG")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundColor(.white.opacity(0.88))
                    .lineLimit(1)

                Text("JUKEBOX")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(currentSong.color.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(deckStatus)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(currentSong.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(auth.isConnected ? "MUSIC READY" : "NO MUSIC OK")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.48))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Button(action: onShowSpotify) {
                Image(systemName: auth.isConnected ? "music.note" : "music.note.list")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(auth.isConnected ? .black : .white.opacity(0.88))
                    .frame(width: 40, height: 34)
                    .background(auth.isConnected ? currentSong.color : Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(auth.isConnected ? Color.clear : Color.white.opacity(0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func animatedSelector(in size: CGSize, compact: Bool) -> some View {
        let height = selectorHeight(in: size, compact: compact)

        return ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.black.opacity(0.18),
                            currentSong.color.opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: currentSong.color.opacity(0.12), radius: 24, y: 10)

            InkJukeboxDrawing(unraveling: showingKnot, trigger: selectionTrigger)
                .frame(width: min(size.width * 1.08, 620), height: height)
                .opacity(showingKnot ? 1 : 0.96)
                .shadow(color: Color.white.opacity(showingKnot ? 0.24 : 0.14), radius: showingKnot ? 28 : 18)
                .allowsHitTesting(false)

            VStack(spacing: compact ? 12 : 16) {
                songReadout(compact: compact)
                    .opacity(showingKnot ? 0 : 1)
                    .scaleEffect(showingKnot ? 0.9 : 1)
                    .blur(radius: showingKnot ? 2 : 0)

                transportControls(compact: compact)
                    .opacity(showingKnot ? 0 : 1)
                    .scaleEffect(showingKnot ? 0.88 : 1)
                    .blur(radius: showingKnot ? 2 : 0)
            }
            .animation(.easeOut(duration: 0.26), value: showingKnot)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    private func songReadout(compact: Bool) -> some View {
        VStack(spacing: compact ? 5 : 7) {
            Text(jukeboxCode(for: selectedIndex))
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(3)
                .foregroundColor(currentSong.color)

            Text(currentSong.unlocked ? currentSong.title : "LOCKED")
                .font(.system(size: compact ? 29 : 36, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.54)
                .foregroundColor(.white)
                .shadow(color: currentSong.color.opacity(0.42), radius: 14)

            Text(currentSong.gameName)
                .font(.system(size: compact ? 11 : 12, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(.white.opacity(0.54))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, compact ? 11 : 13)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.24))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(currentSong.color.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private func transportControls(compact: Bool) -> some View {
        HStack(spacing: compact ? 18 : 26) {
            iconButton(systemName: "chevron.up") {
                navigate(backward: true)
            }

            Button(action: onPlay) {
                HStack(spacing: 9) {
                    Image(systemName: "record.circle")
                        .font(.system(size: compact ? 16 : 18, weight: .black))
                    Text("DROP NEEDLE")
                        .font(.system(size: compact ? 12 : 13, weight: .black, design: .monospaced))
                        .tracking(1.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundColor(.black)
                .padding(.horizontal, compact ? 20 : 24)
                .padding(.vertical, compact ? 13 : 15)
                .background(currentSong.unlocked ? currentSong.color : Color.white.opacity(0.22))
                .clipShape(Capsule())
                .shadow(color: currentSong.color.opacity(0.34), radius: 18, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(!currentSong.unlocked)

            iconButton(systemName: "chevron.down") {
                navigate(backward: false)
            }
        }
    }

    private func selectionList(compact: Bool) -> some View {
        VStack(spacing: compact ? 7 : 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("SELECTIONS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.8)
                    .foregroundColor(.white.opacity(0.62))

                Spacer()

                Text("\(selectedIndex + 1) / \(songs.count)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(currentSong.color.opacity(0.86))
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 1)

            ForEach(songs.indices, id: \.self) { index in
                Button {
                    select(index)
                } label: {
                    let song = songs[index]
                    let selected = index == selectedIndex

                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(selected ? Color.black.opacity(0.62) : song.color.opacity(song.unlocked ? 0.74 : 0.2))
                            .frame(width: 4)

                        Text(jukeboxCode(for: index))
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .tracking(1.8)
                            .foregroundColor(selected ? .black : song.color)
                            .frame(width: 44, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.system(size: compact ? 13 : 15, weight: .black, design: .monospaced))
                                .lineLimit(1)
                                .minimumScaleFactor(0.68)

                            Text("\(song.artist)  /  \(song.gameName)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.4)
                                .lineLimit(1)
                                .foregroundColor(selected ? .black.opacity(0.56) : .white.opacity(0.44))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Image(systemName: selected ? "record.circle.fill" : "record.circle")
                                .font(.system(size: 14, weight: .bold))

                            Text(selected ? "CUED" : (song.unlocked ? "READY" : "LOCKED"))
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .tracking(1)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(selected ? .black : .white.opacity(song.unlocked ? 0.9 : 0.36))
                    .padding(.horizontal, 12)
                    .frame(height: compact ? 46 : 50)
                    .background(selected ? song.color : Color.white.opacity(0.055))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selected ? Color.clear : song.color.opacity(0.22), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!songs[index].unlocked)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func musicControls(compact: Bool) -> some View {
        HStack(spacing: 10) {
            if auth.isConnected {
                Button(action: onShowSpotify) {
                    Label("SPOTIFY", systemImage: "waveform")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(.white.opacity(0.72))
                        .padding(.horizontal, 12)
                        .padding(.vertical, compact ? 8 : 9)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onShowSpotify) {
                    Label("CONNECT", systemImage: "music.note")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(.white.opacity(0.84))
                        .padding(.horizontal, 12)
                        .padding(.vertical, compact ? 8 : 9)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onSkip) {
                    Label("NO MUSIC", systemImage: "speaker.slash")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(.white.opacity(0.62))
                        .padding(.horizontal, 12)
                        .padding(.vertical, compact ? 8 : 9)
                        .background(Color.white.opacity(0.045))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .black))
                .foregroundColor(.white.opacity(0.82))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.075))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func background(song: Song) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#06070B"),
                    Color(hex: "#101421"),
                    Color(hex: "#06070B"),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    song.color.opacity(0.20),
                    song.color.opacity(0.04),
                    .clear,
                ],
                center: .center,
                startRadius: 0,
                endRadius: 430
            )
            .blur(radius: 18)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.35), value: selectedIndex)
    }

    private func selectorHeight(in size: CGSize, compact: Bool) -> CGFloat {
        min(max(size.height * (compact ? 0.27 : 0.29), compact ? 198 : 224), compact ? 236 : 258)
    }

    private func select(_ index: Int) {
        guard index != selectedIndex else { return }
        HapticManager.selection()
        withAnimation(.spring(duration: 0.36, bounce: 0.2)) {
            selectedIndex = index
        }
    }

    private func navigate(backward: Bool) {
        let n = songs.count
        select(backward ? (selectedIndex - 1 + n) % n : (selectedIndex + 1) % n)
    }

    private func playKnotAnimation() {
        guard selectionTrigger > 0 else { return }
        knotResetTask?.cancel()
        withAnimation(.easeOut(duration: 0.18)) {
            showingKnot = true
        }
        knotResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_760_000_000)
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.2)) {
                    showingKnot = false
                }
            }
        }
    }

    private func jukeboxCode(for index: Int) -> String {
        let letter = Character(UnicodeScalar(65 + index)!)
        return "\(letter)-\(String(format: "%02d", index + 1))"
    }
}

#Preview {
    JukeboxView(
        selectedIndex: .constant(0),
        selectionTrigger: 0,
        onPlay: {},
        onShowSpotify: {},
        onSkip: {}
    )
    .environmentObject(SpotifyAuthManager())
}

struct TurntableAnimationPreview: View {
    enum Mode {
        case cycling
        case idle
        case playing
    }

    var mode: Mode = .cycling

    @State private var unraveling = false
    @State private var trigger = 0
    @State private var cycleTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 720
            let drawingWidth = min(geo.size.width * 1.08, compact ? 560 : 700)
            let drawingHeight = min(max(geo.size.height * 0.64, compact ? 320 : 420), compact ? 500 : 620)

            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "#06070B"),
                        Color(hex: "#101421"),
                        Color(hex: "#050506"),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        Color(hex: "#FFB548").opacity(0.14),
                        Color(hex: "#47D9AE").opacity(0.08),
                        .clear,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: min(geo.size.width, geo.size.height) * 0.72
                )
                .blur(radius: 22)
                .ignoresSafeArea()

                InkJukeboxDrawing(unraveling: unraveling, trigger: trigger, showsGameWindow: false)
                    .frame(width: drawingWidth, height: drawingHeight)
                    .shadow(color: .white.opacity(unraveling ? 0.22 : 0.12), radius: unraveling ? 28 : 18)
                    .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .onAppear(perform: start)
        .onDisappear {
            cycleTask?.cancel()
            cycleTask = nil
        }
    }

    private func start() {
        cycleTask?.cancel()
        cycleTask = Task { @MainActor in
            switch mode {
            case .idle:
                unraveling = false

            case .playing:
                await playOnce()

            case .cycling:
                while !Task.isCancelled {
                    await playOnce()
                    try? await Task.sleep(nanoseconds: 2_900_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.22)) {
                        unraveling = false
                    }
                    try? await Task.sleep(nanoseconds: 850_000_000)
                }
            }
        }
    }

    @MainActor
    private func playOnce() async {
        unraveling = false
        try? await Task.sleep(nanoseconds: 160_000_000)
        guard !Task.isCancelled else { return }
        unraveling = true
        trigger &+= 1
    }
}

#Preview("Turntable Animation") {
    TurntableAnimationPreview()
}

private struct InkJukeboxDrawing: View {
    let unraveling: Bool
    let trigger: Int
    var showsGameWindow = true

    @State private var unravelProgress: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let filmFrame = floor(time * 9)
                let tremorFrame = floor(time * 19)
                let projectorOffset = CGSize(
                    width: CGFloat(sin(filmFrame * 1.71) * 1.15 + sin(tremorFrame * 0.63) * 0.36),
                    height: CGFloat(cos(filmFrame * 1.19) * 1.05 + cos(tremorFrame * 0.71) * 0.34)
                )
                var inkContext = context
                inkContext.translateBy(x: projectorOffset.width, y: projectorOffset.height)

                drawFilmPlate(in: &inkContext, size: size, time: time)
                drawInkLines(in: &inkContext, size: size, time: time, filmFrame: filmFrame)
                drawSinglePlayer(in: &inkContext, size: size, time: time, filmFrame: filmFrame)
                drawUnravelThreads(in: &inkContext, size: size, time: time, filmFrame: filmFrame)
                if showsGameWindow {
                    drawGameWindow(in: &inkContext, size: size)
                }
            }
        }
        .onAppear {
            unravelProgress = unraveling ? 1 : 0
        }
        .onChange(of: unraveling) { active in
            animateUnravel(active, restart: active)
        }
        .onChange(of: trigger) { _ in
            guard unraveling else { return }
            animateUnravel(true, restart: true)
        }
    }

    private func animateUnravel(_ active: Bool, restart: Bool) {
        if active {
            if restart {
                unravelProgress = 0
            }
            withAnimation(.timingCurve(0.62, 0, 0.1, 1, duration: 1.28)) {
                unravelProgress = 1
            }
        } else {
            withAnimation(.easeOut(duration: 0.18)) {
                unravelProgress = 0
            }
        }
    }

    private func drawFilmPlate(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let rect = CGRect(
            x: size.width * 0.1,
            y: size.height * 0.03,
            width: size.width * 0.8,
            height: size.height * 0.9
        )
        let plate = Path(roundedRect: rect, cornerRadius: 10)
        context.stroke(
            plate,
            with: .color(Color.white.opacity(0.18)),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
        )

        for index in 0..<5 {
            let phase = time * (1.25 + Double(index) * 0.17) + Double(index) * 1.73
            let x = size.width * (0.18 + CGFloat(index) * 0.15 + CGFloat(sin(phase) + 0.42 * sin(phase * 2.7)) * 0.0065)
            let upper = CGPoint(
                x: x + CGFloat(sin(phase * 1.6) + 0.35 * sin(phase * 3.9)) * 5.5,
                y: size.height * 0.08
            )
            let firstBend = CGPoint(
                x: x + CGFloat(sin(phase * 2.1 + 0.7) + 0.48 * sin(phase * 4.6)) * 13,
                y: size.height * 0.34
            )
            let secondBend = CGPoint(
                x: x + CGFloat(cos(phase * 1.8 + 1.9) + 0.38 * sin(phase * 5.3)) * 11,
                y: size.height * 0.62
            )
            let lower = CGPoint(
                x: x + CGFloat(sin(phase * 1.1 + 2.6) + 0.3 * sin(phase * 6.1)) * 8,
                y: size.height * 0.87
            )
            var scratch = Path()
            scratch.move(to: upper)
            scratch.addCurve(
                to: secondBend,
                control1: CGPoint(x: firstBend.x - 7, y: size.height * 0.22),
                control2: CGPoint(x: secondBend.x + 10, y: size.height * 0.49)
            )
            scratch.addCurve(
                to: lower,
                control1: CGPoint(x: secondBend.x - 9, y: size.height * 0.7),
                control2: CGPoint(x: lower.x + 6, y: size.height * 0.79)
            )
            context.stroke(
                scratch,
                with: .color(Color.white.opacity(index.isMultiple(of: 2) ? 0.045 : 0.025)),
                style: StrokeStyle(lineWidth: 0.8, dash: [4, 12], dashPhase: CGFloat(time * 18))
            )
        }
    }

    private func drawInkLines(in context: inout GraphicsContext, size: CGSize, time: TimeInterval, filmFrame: Double) {
        let disappear = eased(clamped((unravelProgress - 0.6) / 0.36))

        for (index, line) in Self.inkLines.enumerated() {
            let localProgress = clamped((disappear - line.unravelDelay) / max(0.001, 1 - line.unravelDelay))
            let visibleEnd = max(0, 1 - localProgress * 1.08)
            let visibleStart = min(visibleEnd, localProgress * 0.16)

            guard visibleEnd - visibleStart > 0.015 else { continue }

            for pass in 0..<3 {
                let jitter = CGFloat(pass) * 0.45 + 1
                let path = jitteredPath(
                    for: line.points,
                    in: size,
                    filmFrame: filmFrame,
                    seed: line.seed + Double(pass) * 11.7,
                    jitter: jitter * (1 + disappear * 1.15)
                )
                let trimmed = path.trimmedPath(from: visibleStart, to: visibleEnd)
                let opacity = (pass == 0 ? 0.84 : 0.34) * Double(1 - localProgress * 0.76)
                let dash: [CGFloat] = unravelProgress > 0.02 ? [max(2, 18 * (1 - localProgress)), 5 + 24 * localProgress] : []

                context.stroke(
                    trimmed,
                    with: .color(Color.white.opacity(opacity)),
                    style: StrokeStyle(
                        lineWidth: line.width - CGFloat(pass) * 0.22,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: dash,
                        dashPhase: CGFloat(time * (line.seed + 9) + Double(index) * 3)
                    )
                )
            }
        }
    }

    private func drawSinglePlayer(in context: inout GraphicsContext, size: CGSize, time: TimeInterval, filmFrame: Double) {
        let dropProgress = eased(clamped(unravelProgress / 0.44))
        let armProgress = eased(clamped((unravelProgress - 0.34) / 0.3))
        let playbackProgress = clamped((unravelProgress - 0.52) / 0.24)
        let platterCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.57)
        let platterDiameter = min(size.width, size.height) * 0.52

        let magazine = Path(roundedRect: CGRect(
            x: size.width * 0.35,
            y: size.height * 0.11,
            width: size.width * 0.3,
            height: size.height * 0.08
        ), cornerRadius: 5)
        context.stroke(
            magazine,
            with: .color(Color.white.opacity(0.34)),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
        )

        for index in 0..<3 {
            let y = size.height * (0.125 + CGFloat(index) * 0.018)
            let stackLine = wavyThreadPath(
                from: CGPoint(x: size.width * 0.39, y: y),
                to: CGPoint(
                    x: size.width * 0.61,
                    y: y + CGFloat(sin(filmFrame + Double(index)) + 0.35 * sin(filmFrame * 2.4 + Double(index))) * 0.75
                ),
                time: time,
                seed: 31 + Double(index) * 3.7,
                amplitude: 0.65,
                steps: 18
            )
            context.stroke(
                stackLine,
                with: .color(Color.white.opacity(0.18)),
                style: StrokeStyle(lineWidth: 0.9, lineCap: .round)
            )
        }

        let platter = wobblyEllipsePath(
            center: platterCenter,
            radius: CGPoint(x: platterDiameter / 2, y: platterDiameter / 2),
            time: time,
            seed: 3.8,
            amplitude: max(1.15, platterDiameter * 0.013),
            steps: 104
        )
        context.stroke(
            platter,
            with: .color(Color.white.opacity(0.34)),
            style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
        )

        let spindle = wobblyEllipsePath(
            center: platterCenter,
            radius: CGPoint(x: 4, y: 4),
            time: time,
            seed: 8.9,
            amplitude: 0.38,
            steps: 22
        )
        context.stroke(
            spindle,
            with: .color(Color.white.opacity(0.68)),
            style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round)
        )

        if unravelProgress > 0.001 {
            let startCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.14)
            let bounce = sin(Double(clamped(unravelProgress / 0.44)) * .pi) * 11
            let recordCenter = CGPoint(
                x: startCenter.x + (platterCenter.x - startCenter.x) * dropProgress + CGFloat(sin(filmFrame * 1.37)) * (1 - dropProgress) * 2.8,
                y: startCenter.y + (platterCenter.y - startCenter.y) * dropProgress - CGFloat(bounce)
            )
            let scale = 0.54 + 0.46 * dropProgress
            drawSingleRecord(
                in: &context,
                center: recordCenter,
                diameter: platterDiameter * scale,
                spin: time * (unravelProgress > 0.42 ? 6.8 : 1.2) + Double(dropProgress) * 1.7,
                opacity: 0.96
            )
        } else {
            drawSingleRecord(
                in: &context,
                center: platterCenter,
                diameter: platterDiameter * 0.82,
                spin: time * 0.45,
                opacity: 0.22
            )
        }

        let pivot = CGPoint(x: size.width * 0.79, y: size.height * 0.37)
        let restNeedle = CGPoint(x: size.width * 0.82, y: size.height * 0.68)
        let grooveNeedle = CGPoint(x: platterCenter.x + platterDiameter * 0.18, y: platterCenter.y - platterDiameter * 0.1)
        let needle = interpolate(from: restNeedle, to: grooveNeedle, progress: armProgress)
        let armEnergy: CGFloat = unravelProgress > 0 ? 1 : 0.45
        let armEndJitter = CGPoint(
            x: CGFloat(sin(time * 9.4 + 1.1) + 0.48 * sin(time * 16.8 + 3.4) + 0.23 * sin(time * 27.1 + 0.3)) * armEnergy * 1.9,
            y: CGFloat(cos(time * 7.8 + 2.2) + 0.43 * sin(time * 14.2 + 0.9) + 0.2 * cos(time * 24.6 + 5.1)) * armEnergy * 1.25
        )
        let armControlWiggle = CGPoint(
            x: CGFloat(sin(time * 6.7 + filmFrame * 0.13) + 0.5 * sin(time * 13.9 + 2.6) + 0.24 * sin(time * 22.5 + 5.3)) * armEnergy * 5.2,
            y: CGFloat(cos(time * 5.9 + 1.7) + 0.46 * sin(time * 12.6 + 4.4) + 0.22 * cos(time * 20.8 + 2.1)) * armEnergy * 4.2
        )
        let armTarget = CGPoint(x: needle.x + armEndJitter.x, y: needle.y + armEndJitter.y)
        let armControl = CGPoint(
            x: pivot.x - size.width * 0.06 + armControlWiggle.x,
            y: pivot.y + size.height * 0.13 + armControlWiggle.y
        )

        var arm = Path()
        arm.move(to: pivot)
        arm.addQuadCurve(
            to: armTarget,
            control: armControl
        )
        context.stroke(
            arm,
            with: .color(Color.white.opacity(0.76)),
            style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
        )

        let pivotPath = wobblyEllipsePath(
            center: pivot,
            radius: CGPoint(x: 12, y: 12),
            time: time,
            seed: 18.6,
            amplitude: 0.72,
            steps: 38
        )
        context.stroke(
            pivotPath,
            with: .color(Color.white.opacity(0.5)),
            style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)
        )

        var needlePath = Path()
        needlePath.move(to: CGPoint(x: armTarget.x - 5, y: armTarget.y - 2))
        needlePath.addLine(to: CGPoint(x: armTarget.x, y: armTarget.y + 8))
        needlePath.addLine(to: CGPoint(x: armTarget.x + 6, y: armTarget.y - 2))
        context.stroke(
            needlePath,
            with: .color(Color.white.opacity(0.86)),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
        )

        if playbackProgress > 0 {
            for index in 0..<4 {
                let ringProgress = clamped(playbackProgress - CGFloat(index) * 0.12)
                guard ringProgress > 0 else { continue }
                let diameter = platterDiameter * (0.38 + ringProgress * 0.82)
                let opacity = Double((1 - ringProgress) * 0.28)
                let pulse = wobblyEllipsePath(
                    center: platterCenter,
                    radius: CGPoint(x: diameter / 2, y: diameter / 2),
                    time: time + Double(index) * 0.21,
                    seed: 44 + Double(index) * 6.1,
                    amplitude: max(0.85, diameter * 0.009),
                    steps: 88
                )
                context.stroke(
                    pulse,
                    with: .color(Color.white.opacity(opacity)),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round, dash: [8, 9], dashPhase: CGFloat(time * 28))
                )
            }
        }
    }

    private func drawSingleRecord(in context: inout GraphicsContext, center: CGPoint, diameter: CGFloat, spin: TimeInterval, opacity: Double) {
        let outer = wobblyEllipsePath(
            center: center,
            radius: CGPoint(x: diameter / 2, y: diameter / 2),
            time: spin,
            seed: 5.4,
            amplitude: max(0.9, diameter * 0.014),
            steps: 112
        )
        context.stroke(
            outer,
            with: .color(Color.white.opacity(opacity * 0.88)),
            style: StrokeStyle(lineWidth: max(1, diameter * 0.018), lineCap: .round, lineJoin: .round)
        )

        for (index, ring) in [0.78, 0.62, 0.45].enumerated() {
            let ringDiameter = diameter * CGFloat(ring)
            let groove = wobblyEllipsePath(
                center: center,
                radius: CGPoint(x: ringDiameter / 2, y: ringDiameter / 2),
                time: spin * (0.82 + Double(index) * 0.09),
                seed: 12.2 + Double(index) * 5.6,
                amplitude: max(0.65, ringDiameter * 0.011),
                steps: 88
            )
            context.stroke(
                groove,
                with: .color(Color.white.opacity(opacity * 0.18)),
                style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round)
            )
        }

        let labelDiameter = diameter * 0.36
        let label = wobblyEllipsePath(
            center: center,
            radius: CGPoint(x: labelDiameter / 2, y: labelDiameter / 2),
            time: spin * 0.74,
            seed: 28.3,
            amplitude: max(0.52, labelDiameter * 0.014),
            steps: 54
        )
        context.stroke(
            label,
            with: .color(Color.white.opacity(opacity * 0.62)),
            style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
        )

        let holeDiameter = diameter * 0.18
        let hole = wobblyEllipsePath(
            center: center,
            radius: CGPoint(x: holeDiameter / 2, y: holeDiameter / 2),
            time: spin * 1.11,
            seed: 34.8,
            amplitude: max(0.38, holeDiameter * 0.012),
            steps: 36
        )
        context.stroke(
            hole,
            with: .color(Color.white.opacity(opacity * 0.76)),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
        )

        let markerAngle = spin.truncatingRemainder(dividingBy: .pi * 2)
        let markerStart = CGPoint(
            x: center.x + CGFloat(cos(markerAngle)) * diameter * 0.25,
            y: center.y + CGFloat(sin(markerAngle)) * diameter * 0.25
        )
        let markerEnd = CGPoint(
            x: center.x + CGFloat(cos(markerAngle)) * diameter * 0.43,
            y: center.y + CGFloat(sin(markerAngle)) * diameter * 0.43
        )
        let marker = wavyThreadPath(
            from: markerStart,
            to: markerEnd,
            time: spin,
            seed: 49.7,
            amplitude: max(0.45, diameter * 0.006),
            steps: 10
        )
        context.stroke(
            marker,
            with: .color(Color.white.opacity(opacity * 0.54)),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
        )
    }

    private func drawUnravelThreads(in context: inout GraphicsContext, size: CGSize, time: TimeInterval, filmFrame: Double) {
        let progress = clamped((unravelProgress - 0.62) / 0.32)
        guard progress > 0 else { return }

        let easedProgress = eased(progress)
        let opacity = Double(sin(Double(progress) * .pi)) * 0.72
        let anchors = Self.unravelAnchors

        for index in anchors.indices {
            let anchor = point(anchors[index].start, in: size)
            let destination = point(anchors[index].end, in: size)
            let pull = CGPoint(
                x: anchor.x + (destination.x - anchor.x) * easedProgress,
                y: anchor.y + (destination.y - anchor.y) * easedProgress
            )
            let control = CGPoint(
                x: anchor.x + (pull.x - anchor.x) * 0.56 + CGFloat(sin(filmFrame + Double(index))) * 15,
                y: anchor.y + (pull.y - anchor.y) * 0.42 + CGFloat(cos(filmFrame * 0.73 + Double(index))) * 13
            )

            var path = Path()
            path.move(to: anchor)
            path.addQuadCurve(to: pull, control: control)

            context.stroke(
                path,
                with: .color(Color.white.opacity(opacity)),
                style: StrokeStyle(
                    lineWidth: 1.1 + CGFloat(index % 3) * 0.32,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [7, 5 + CGFloat(index % 4) * 3],
                    dashPhase: CGFloat(-(time * 32 + Double(index) * 13))
                )
            )
        }
    }

    private func drawGameWindow(in context: inout GraphicsContext, size: CGSize) {
        let progress = clamped((unravelProgress - 0.66) / 0.3)
        guard progress > 0 else { return }

        let easedProgress = eased(progress)
        let width = size.width * (0.18 + 0.7 * easedProgress)
        let height = size.height * (0.12 + 0.62 * easedProgress)
        let rect = CGRect(
            x: (size.width - width) / 2,
            y: size.height * (0.55 - 0.43 * easedProgress),
            width: width,
            height: height
        )
        let window = Path(roundedRect: rect, cornerRadius: 8)
        context.stroke(
            window,
            with: .color(Color.white.opacity(0.2 + Double(easedProgress) * 0.74)),
            style: StrokeStyle(lineWidth: 1.4 + easedProgress * 1.4, lineCap: .round, lineJoin: .round)
        )

        let titleY = rect.minY + rect.height * 0.16
        var titleLine = Path()
        titleLine.move(to: CGPoint(x: rect.minX + rect.width * 0.09, y: titleY))
        titleLine.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.09, y: titleY))
        context.stroke(
            titleLine,
            with: .color(Color.white.opacity(0.34 + Double(easedProgress) * 0.26)),
            style: StrokeStyle(lineWidth: 1, dash: [8, 5], dashPhase: easedProgress * -30)
        )

        for row in 0..<4 {
            let y = rect.minY + rect.height * (0.34 + CGFloat(row) * 0.12)
            var scanline = Path()
            scanline.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: y))
            scanline.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: y))
            context.stroke(
                scanline,
                with: .color(Color.white.opacity(0.08 + Double(easedProgress) * 0.08)),
                style: StrokeStyle(lineWidth: 0.9)
            )
        }
    }

    private func jitteredPath(for normalizedPoints: [CGPoint], in size: CGSize, filmFrame: Double, seed: Double, jitter: CGFloat) -> Path {
        var path = Path()
        guard let first = normalizedPoints.first else { return path }

        let amplitude = jitter * 1.35
        path.move(to: jitteredInkPoint(
            first,
            in: size,
            filmFrame: filmFrame,
            seed: seed,
            amplitude: amplitude,
            segmentNormal: .zero,
            segmentProgress: 0,
            segmentIndex: 0
        ))

        for index in 1..<normalizedPoints.count {
            let previous = normalizedPoints[index - 1]
            let current = normalizedPoints[index]
            let previousBase = point(previous, in: size)
            let currentBase = point(current, in: size)
            let vector = CGPoint(x: currentBase.x - previousBase.x, y: currentBase.y - previousBase.y)
            let length = max(hypot(vector.x, vector.y), 0.001)
            let normal = CGPoint(x: -vector.y / length, y: vector.x / length)
            let samples = 7

            for sample in 1...samples {
                let progress = CGFloat(sample) / CGFloat(samples)
                let normalized = CGPoint(
                    x: previous.x + (current.x - previous.x) * progress,
                    y: previous.y + (current.y - previous.y) * progress
                )
                let point = jitteredInkPoint(
                    normalized,
                    in: size,
                    filmFrame: filmFrame,
                    seed: seed,
                    amplitude: amplitude,
                    segmentNormal: normal,
                    segmentProgress: progress,
                    segmentIndex: index
                )
                path.addLine(to: point)
            }
        }

        return path
    }

    private func jitteredInkPoint(
        _ normalized: CGPoint,
        in size: CGSize,
        filmFrame: Double,
        seed: Double,
        amplitude: CGFloat,
        segmentNormal: CGPoint,
        segmentProgress: CGFloat,
        segmentIndex: Int
    ) -> CGPoint {
        let base = point(normalized, in: size)
        let anchorPhase = Double(normalized.x * 67 + normalized.y * 29) + seed * 2.17 + filmFrame * 0.83
        let crossPhase = Double(normalized.x * 31 - normalized.y * 73) + seed * 1.83 + filmFrame * 1.07
        let dx = (sin(anchorPhase) + 0.48 * sin(anchorPhase * 2.31 + seed) + 0.22 * sin(anchorPhase * 3.74 - filmFrame * 0.41)) * Double(amplitude)
        let dy = (cos(crossPhase) + 0.46 * sin(crossPhase * 2.17 + seed * 0.6) + 0.2 * cos(crossPhase * 4.12 + filmFrame * 0.37)) * Double(amplitude)
        let envelope = sin(segmentProgress * .pi)
        let stringWave = layeredStringWave(
            position: segmentProgress,
            time: filmFrame * 0.13 + Double(segmentIndex) * 0.19,
            seed: seed + Double(segmentIndex) * 4.7,
            amplitude: amplitude * 0.72
        ) * envelope

        return CGPoint(
            x: base.x + CGFloat(dx) * 0.62 + segmentNormal.x * stringWave,
            y: base.y + CGFloat(dy) * 0.62 + segmentNormal.y * stringWave
        )
    }

    private func wavyThreadPath(from start: CGPoint, to end: CGPoint, time: TimeInterval, seed: Double, amplitude: CGFloat, steps: Int) -> Path {
        let safeSteps = max(1, steps)
        let vector = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let length = max(hypot(vector.x, vector.y), 0.001)
        let tangent = CGPoint(x: vector.x / length, y: vector.y / length)
        let normal = CGPoint(x: -tangent.y, y: tangent.x)
        var path = Path()

        for index in 0...safeSteps {
            let progress = CGFloat(index) / CGFloat(safeSteps)
            let envelope = sin(progress * .pi)
            let base = CGPoint(
                x: start.x + vector.x * progress,
                y: start.y + vector.y * progress
            )
            let transverse = layeredStringWave(
                position: progress,
                time: time,
                seed: seed,
                amplitude: amplitude
            ) * envelope
            let longitudinal = layeredStringWave(
                position: progress + 0.37,
                time: time * 0.73,
                seed: seed * 1.53,
                amplitude: amplitude * 0.2
            ) * envelope
            let point = CGPoint(
                x: base.x + normal.x * transverse + tangent.x * longitudinal,
                y: base.y + normal.y * transverse + tangent.y * longitudinal
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }

    private func wobblyEllipsePath(center: CGPoint, radius: CGPoint, time: TimeInterval, seed: Double, amplitude: CGFloat, steps: Int) -> Path {
        let safeSteps = max(8, steps)
        let arcPoints = Self.arc(center: center, radius: radius, start: 0, end: .pi * 2, steps: safeSteps)
        var path = Path()

        for (index, arcPoint) in arcPoints.enumerated() {
            let progress = CGFloat(index) / CGFloat(safeSteps)
            let angle = CGFloat.pi * 2 * progress
            let radialVector = CGPoint(x: arcPoint.x - center.x, y: arcPoint.y - center.y)
            let radialLength = max(hypot(radialVector.x, radialVector.y), 0.001)
            let normal = CGPoint(x: radialVector.x / radialLength, y: radialVector.y / radialLength)
            let tangent = CGPoint(x: -normal.y, y: normal.x)
            let radial = circularStringWave(angle: angle, time: time, seed: seed, amplitude: amplitude)
            let shear = circularStringWave(angle: angle, time: time * 0.81, seed: seed * 1.7, amplitude: amplitude * 0.16)
            let point = CGPoint(
                x: arcPoint.x + normal.x * radial + tangent.x * shear,
                y: arcPoint.y + normal.y * radial + tangent.y * shear
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }

    private func layeredStringWave(position: CGFloat, time: TimeInterval, seed: Double, amplitude: CGFloat) -> CGFloat {
        let position = Double(position)
        let wave = sin(position * Double.pi * 2.7 + time * 7.1 + seed)
            + 0.52 * sin(position * Double.pi * 6.3 - time * 11.8 + seed * 1.37)
            + 0.28 * sin(position * Double.pi * 13.1 + time * 18.6 + seed * 0.63)
        return CGFloat(wave) * amplitude
    }

    private func circularStringWave(angle: CGFloat, time: TimeInterval, seed: Double, amplitude: CGFloat) -> CGFloat {
        let angle = Double(angle)
        let wave = sin(angle * 3 + time * 5.8 + seed)
            + 0.45 * sin(angle * 5 - time * 8.9 + seed * 1.53)
            + 0.25 * sin(angle * 9 + time * 13.7 + seed * 0.79)
        return CGFloat(wave) * amplitude
    }

    private func point(_ normalized: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
    }

    private func interpolate(from start: CGPoint, to end: CGPoint, progress: CGFloat) -> CGPoint {
        let t = clamped(progress)
        return CGPoint(
            x: start.x + (end.x - start.x) * t,
            y: start.y + (end.y - start.y) * t
        )
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    private func eased(_ value: CGFloat) -> CGFloat {
        let t = clamped(value)
        let inverse = 1 - t
        return 1 - inverse * inverse * inverse
    }

    private struct InkLine {
        let points: [CGPoint]
        let width: CGFloat
        let seed: Double
        let unravelDelay: CGFloat
    }

    private struct UnravelAnchor {
        let start: CGPoint
        let end: CGPoint
    }

    private static let inkLines: [InkLine] = [
        InkLine(points: arc(center: CGPoint(x: 0.5, y: 0.34), radius: CGPoint(x: 0.32, y: 0.27), start: .pi, end: 0, steps: 34), width: 2.2, seed: 1.3, unravelDelay: 0),
        InkLine(points: [CGPoint(x: 0.18, y: 0.34), CGPoint(x: 0.17, y: 0.5), CGPoint(x: 0.18, y: 0.72), CGPoint(x: 0.15, y: 0.91)], width: 2.0, seed: 4.2, unravelDelay: 0.08),
        InkLine(points: [CGPoint(x: 0.82, y: 0.34), CGPoint(x: 0.83, y: 0.52), CGPoint(x: 0.82, y: 0.72), CGPoint(x: 0.85, y: 0.91)], width: 2.0, seed: 5.8, unravelDelay: 0.08),
        InkLine(points: [CGPoint(x: 0.13, y: 0.91), CGPoint(x: 0.3, y: 0.89), CGPoint(x: 0.5, y: 0.92), CGPoint(x: 0.7, y: 0.89), CGPoint(x: 0.87, y: 0.91)], width: 2.0, seed: 6.3, unravelDelay: 0.14),
        InkLine(points: arc(center: CGPoint(x: 0.5, y: 0.38), radius: CGPoint(x: 0.13, y: 0.1), start: 0, end: .pi * 2, steps: 36), width: 1.8, seed: 8.4, unravelDelay: 0.18),
        InkLine(points: arc(center: CGPoint(x: 0.5, y: 0.38), radius: CGPoint(x: 0.045, y: 0.034), start: 0, end: .pi * 2, steps: 22), width: 1.2, seed: 9.1, unravelDelay: 0.22),
        InkLine(points: [CGPoint(x: 0.28, y: 0.53), CGPoint(x: 0.38, y: 0.51), CGPoint(x: 0.51, y: 0.54), CGPoint(x: 0.63, y: 0.51), CGPoint(x: 0.74, y: 0.53)], width: 1.7, seed: 12.2, unravelDelay: 0.26),
        InkLine(points: [CGPoint(x: 0.28, y: 0.61), CGPoint(x: 0.42, y: 0.6), CGPoint(x: 0.58, y: 0.62), CGPoint(x: 0.73, y: 0.61)], width: 1.5, seed: 13.8, unravelDelay: 0.32),
        InkLine(points: [CGPoint(x: 0.28, y: 0.69), CGPoint(x: 0.42, y: 0.7), CGPoint(x: 0.58, y: 0.68), CGPoint(x: 0.73, y: 0.69)], width: 1.5, seed: 14.6, unravelDelay: 0.38),
        InkLine(points: [CGPoint(x: 0.28, y: 0.77), CGPoint(x: 0.42, y: 0.76), CGPoint(x: 0.58, y: 0.78), CGPoint(x: 0.73, y: 0.77)], width: 1.5, seed: 15.4, unravelDelay: 0.44),
        InkLine(points: arc(center: CGPoint(x: 0.37, y: 0.84), radius: CGPoint(x: 0.033, y: 0.028), start: 0, end: .pi * 2, steps: 18), width: 1.4, seed: 17.2, unravelDelay: 0.5),
        InkLine(points: arc(center: CGPoint(x: 0.5, y: 0.84), radius: CGPoint(x: 0.04, y: 0.032), start: 0, end: .pi * 2, steps: 20), width: 1.4, seed: 18.5, unravelDelay: 0.54),
        InkLine(points: arc(center: CGPoint(x: 0.63, y: 0.84), radius: CGPoint(x: 0.033, y: 0.028), start: 0, end: .pi * 2, steps: 18), width: 1.4, seed: 19.7, unravelDelay: 0.58),
        InkLine(points: [CGPoint(x: 0.3, y: 0.43), CGPoint(x: 0.41, y: 0.4), CGPoint(x: 0.5, y: 0.38), CGPoint(x: 0.6, y: 0.4), CGPoint(x: 0.71, y: 0.43)], width: 1.1, seed: 22.1, unravelDelay: 0.22),
        InkLine(points: [CGPoint(x: 0.25, y: 0.27), CGPoint(x: 0.34, y: 0.2), CGPoint(x: 0.5, y: 0.16), CGPoint(x: 0.66, y: 0.2), CGPoint(x: 0.75, y: 0.27)], width: 1.2, seed: 23.5, unravelDelay: 0.12)
    ]

    private static let unravelAnchors: [UnravelAnchor] = [
        UnravelAnchor(start: CGPoint(x: 0.24, y: 0.26), end: CGPoint(x: -0.08, y: 0.06)),
        UnravelAnchor(start: CGPoint(x: 0.76, y: 0.26), end: CGPoint(x: 1.08, y: 0.07)),
        UnravelAnchor(start: CGPoint(x: 0.18, y: 0.55), end: CGPoint(x: -0.12, y: 0.48)),
        UnravelAnchor(start: CGPoint(x: 0.82, y: 0.55), end: CGPoint(x: 1.12, y: 0.47)),
        UnravelAnchor(start: CGPoint(x: 0.33, y: 0.61), end: CGPoint(x: -0.06, y: 0.78)),
        UnravelAnchor(start: CGPoint(x: 0.67, y: 0.61), end: CGPoint(x: 1.06, y: 0.78)),
        UnravelAnchor(start: CGPoint(x: 0.4, y: 0.85), end: CGPoint(x: 0.04, y: 1.02)),
        UnravelAnchor(start: CGPoint(x: 0.6, y: 0.85), end: CGPoint(x: 0.96, y: 1.02))
    ]

    private static func arc(center: CGPoint, radius: CGPoint, start: CGFloat, end: CGFloat, steps: Int) -> [CGPoint] {
        guard steps > 1 else { return [center] }

        return (0...steps).map { index in
            let progress = CGFloat(index) / CGFloat(steps)
            let angle = start + (end - start) * progress
            return CGPoint(
                x: center.x + cos(angle) * radius.x,
                y: center.y - sin(angle) * radius.y
            )
        }
    }
}
