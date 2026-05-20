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

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 720
            let horizontalPadding = min(max(geo.size.width * 0.055, 16), 30)
            let topPadding = max(geo.safeAreaInsets.top, 54) + 12
            let bottomPadding = max(geo.safeAreaInsets.bottom, 18) + 14
            let contentWidth = max(0, geo.size.width - horizontalPadding * 2)
            let contentHeight = max(0, geo.size.height - topPadding - bottomPadding)

            ZStack(alignment: .top) {
                background(song: currentSong)

                VStack(spacing: compact ? 10 : 14) {
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
            VStack(alignment: .leading, spacing: 2) {
                Text("BAND MUSIC GAMES")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(2.2)
                    .foregroundColor(.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(currentSong.artist)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundColor(currentSong.color.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onShowSpotify) {
                Image(systemName: auth.isConnected ? "music.note" : "music.note.list")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(auth.isConnected ? .black : .white.opacity(0.88))
                    .frame(width: 44, height: 38)
                    .background(auth.isConnected ? currentSong.color : Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(auth.isConnected ? Color.clear : Color.white.opacity(0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func animatedSelector(in size: CGSize, compact: Bool) -> some View {
        let height = selectorHeight(in: size, compact: compact)

        return ZStack {
            InkJukeboxDrawing(unraveling: showingKnot, trigger: selectionTrigger)
            .frame(width: min(size.width * 1.08, 620), height: height)
            .opacity(showingKnot ? 1 : 0.96)
            .shadow(color: Color.white.opacity(showingKnot ? 0.24 : 0.14), radius: showingKnot ? 28 : 18)
            .allowsHitTesting(false)

            VStack(spacing: compact ? 14 : 18) {
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
    }

    private func transportControls(compact: Bool) -> some View {
        HStack(spacing: compact ? 18 : 26) {
            iconButton(systemName: "chevron.up") {
                navigate(backward: true)
            }

            Button(action: onPlay) {
                HStack(spacing: 9) {
                    Image(systemName: isCurrentSongPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: compact ? 16 : 18, weight: .black))
                    Text(isCurrentSongPlaying ? "PAUSE" : "PLAY GAME")
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
            ForEach(songs.indices, id: \.self) { index in
                Button {
                    select(index)
                } label: {
                    let song = songs[index]
                    let selected = index == selectedIndex

                    HStack(spacing: 12) {
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
                            Text(song.artist)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.4)
                                .lineLimit(1)
                                .foregroundColor(selected ? .black.opacity(0.56) : .white.opacity(0.44))
                        }

                        Spacer()

                        Image(systemName: selected ? "smallcircle.filled.circle" : "circle")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(selected ? .black : .white.opacity(song.unlocked ? 0.9 : 0.36))
                    .padding(.horizontal, 14)
                    .frame(height: compact ? 44 : 48)
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
        min(max(size.height * (compact ? 0.31 : 0.33), compact ? 220 : 250), compact ? 275 : 295)
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
        showingKnot = true
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

private struct InkJukeboxDrawing: View {
    let unraveling: Bool
    let trigger: Int

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
                drawGameWindow(in: &inkContext, size: size)
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
        context.fill(plate, with: .color(Color.black.opacity(0.38)))
        context.stroke(
            plate,
            with: .color(Color.white.opacity(0.18)),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
        )

        for index in 0..<5 {
            let x = size.width * (0.18 + CGFloat(index) * 0.15 + CGFloat(sin(time * 0.9 + Double(index))) * 0.005)
            var scratch = Path()
            scratch.move(to: CGPoint(x: x, y: size.height * 0.08))
            scratch.addLine(to: CGPoint(x: x + CGFloat(sin(time + Double(index))) * 7, y: size.height * 0.87))
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
        let platterRect = CGRect(
            x: platterCenter.x - platterDiameter / 2,
            y: platterCenter.y - platterDiameter / 2,
            width: platterDiameter,
            height: platterDiameter
        )

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
            var stackLine = Path()
            let y = size.height * (0.125 + CGFloat(index) * 0.018)
            stackLine.move(to: CGPoint(x: size.width * 0.39, y: y))
            stackLine.addLine(to: CGPoint(x: size.width * 0.61, y: y + CGFloat(sin(filmFrame + Double(index))) * 0.5))
            context.stroke(
                stackLine,
                with: .color(Color.white.opacity(0.18)),
                style: StrokeStyle(lineWidth: 0.9, lineCap: .round)
            )
        }

        var platter = Path()
        platter.addEllipse(in: platterRect)
        context.stroke(
            platter,
            with: .color(Color.white.opacity(0.34)),
            style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
        )

        var spindle = Path()
        spindle.addEllipse(in: CGRect(
            x: platterCenter.x - 4,
            y: platterCenter.y - 4,
            width: 8,
            height: 8
        ))
        context.fill(spindle, with: .color(Color.white.opacity(0.68)))

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
        let armJitter = CGFloat(sin(filmFrame * 1.47)) * (unravelProgress > 0 ? 1.2 : 0.45)

        var arm = Path()
        arm.move(to: pivot)
        arm.addQuadCurve(
            to: CGPoint(x: needle.x + armJitter, y: needle.y),
            control: CGPoint(x: pivot.x - size.width * 0.06, y: pivot.y + size.height * 0.13)
        )
        context.stroke(
            arm,
            with: .color(Color.white.opacity(0.76)),
            style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
        )

        var pivotPath = Path()
        pivotPath.addEllipse(in: CGRect(x: pivot.x - 12, y: pivot.y - 12, width: 24, height: 24))
        context.stroke(
            pivotPath,
            with: .color(Color.white.opacity(0.5)),
            style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)
        )

        var needlePath = Path()
        needlePath.move(to: CGPoint(x: needle.x - 5 + armJitter, y: needle.y - 2))
        needlePath.addLine(to: CGPoint(x: needle.x + armJitter, y: needle.y + 8))
        needlePath.addLine(to: CGPoint(x: needle.x + 6 + armJitter, y: needle.y - 2))
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
                var pulse = Path()
                pulse.addEllipse(in: CGRect(
                    x: platterCenter.x - diameter / 2,
                    y: platterCenter.y - diameter / 2,
                    width: diameter,
                    height: diameter
                ))
                context.stroke(
                    pulse,
                    with: .color(Color.white.opacity(opacity)),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round, dash: [8, 9], dashPhase: CGFloat(time * 28))
                )
            }
        }
    }

    private func drawSingleRecord(in context: inout GraphicsContext, center: CGPoint, diameter: CGFloat, spin: TimeInterval, opacity: Double) {
        let rect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
        var outer = Path()
        outer.addEllipse(in: rect)
        context.fill(outer, with: .color(Color.black.opacity(opacity * 0.86)))
        context.stroke(
            outer,
            with: .color(Color.white.opacity(opacity * 0.88)),
            style: StrokeStyle(lineWidth: max(1, diameter * 0.018), lineCap: .round, lineJoin: .round)
        )

        for ring in [0.78, 0.62, 0.45] {
            let ringDiameter = diameter * CGFloat(ring)
            var groove = Path()
            groove.addEllipse(in: CGRect(
                x: center.x - ringDiameter / 2,
                y: center.y - ringDiameter / 2,
                width: ringDiameter,
                height: ringDiameter
            ))
            context.stroke(
                groove,
                with: .color(Color.white.opacity(opacity * 0.18)),
                style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round)
            )
        }

        let labelDiameter = diameter * 0.36
        var label = Path()
        label.addEllipse(in: CGRect(
            x: center.x - labelDiameter / 2,
            y: center.y - labelDiameter / 2,
            width: labelDiameter,
            height: labelDiameter
        ))
        context.fill(label, with: .color(Color.black.opacity(opacity * 0.68)))
        context.stroke(
            label,
            with: .color(Color.white.opacity(opacity * 0.62)),
            style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
        )

        let holeDiameter = diameter * 0.18
        var hole = Path()
        hole.addEllipse(in: CGRect(
            x: center.x - holeDiameter / 2,
            y: center.y - holeDiameter / 2,
            width: holeDiameter,
            height: holeDiameter
        ))
        context.fill(hole, with: .color(Color.black.opacity(0.94)))
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
        var marker = Path()
        marker.move(to: markerStart)
        marker.addLine(to: markerEnd)
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
        context.fill(window, with: .color(Color.black.opacity(0.72 + Double(easedProgress) * 0.18)))
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

        for (index, normalized) in normalizedPoints.enumerated() {
            let base = point(normalized, in: size)
            let dx = sin(Double(normalized.x * 67 + normalized.y * 29) + seed * 2.17 + filmFrame * 0.83) * Double(jitter)
            let dy = cos(Double(normalized.x * 31 - normalized.y * 73) + seed * 1.83 + filmFrame * 1.07) * Double(jitter)
            let point = CGPoint(x: base.x + CGFloat(dx), y: base.y + CGFloat(dy))

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
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
