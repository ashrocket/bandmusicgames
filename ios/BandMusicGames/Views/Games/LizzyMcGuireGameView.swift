import SwiftUI

private let hchW: CGFloat = 390
private let hchH: CGFloat = 750
private let hchFloorY: CGFloat = 510
private let hchCourtFarY: CGFloat = hchFloorY - 8
private let hchCourtNearY: CGFloat = hchFloorY + 42
private let hchHoopX: CGFloat = 352
private let hchRimY: CGFloat = 258
private let hchRimR: CGFloat = 19
private let hchWinScore = 11
private let hchRange3: CGFloat = 210
private let hchRange2: CGFloat = 130
private let hchLayupRange: CGFloat = 55
private let hchGreenLow: CGFloat = 52
private let hchGreenHigh: CGFloat = 76

struct LizzyMcGuireGameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: SpotifyAuthManager
    @StateObject private var game = HalfCourtHeroGame()

    var body: some View {
        ZStack {
            Canvas { context, size in
                HalfCourtHeroRenderer.draw(game: game, context: &context, size: size)
            }
            .ignoresSafeArea()

            if game.phase == .title {
                titleOverlay
            } else if game.phase == .characterSelect {
                characterSelectOverlay
            } else if game.phase == .playing {
                gameOverlay
            } else if game.phase == .ended {
                resultOverlay
            }

            closeButton
        }
        .background(Color(hex: "#1a0a3e"))
        .onAppear {
            game.prepare()
#if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-bmg-lizzy-gameplay") {
                game.debugStartGameplay()
            } else if args.contains("-bmg-lizzy-teammate-picker") {
                game.debugOpenTeammatePicker()
            }
#endif
            if auth.accessToken != nil {
                Task { await auth.playTrack("spotify:track:7kNqAfUxLmrETcwvBTQCkg") }
            }
        }
        .onDisappear { game.stop() }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 29))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.black.opacity(0.58))
                        .padding(12)
                }
            }
            Spacer()
        }
    }

    private var titleOverlay: some View {
        GeometryReader { geo in
            let usableHeight = geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom
            let compact = usableHeight < 760
            let titleSize: CGFloat = compact ? 40 : 48
            let topInset = max(geo.safeAreaInsets.top + 24, compact ? 86 : 142)
            let bottomInset = max(geo.safeAreaInsets.bottom + 16, compact ? 18 : 30)

            VStack(spacing: compact ? 12 : 18) {
                Spacer()
                    .frame(height: topInset)

                VStack(spacing: compact ? 5 : 8) {
                    Text("NARA'S ROOM")
                        .font(.system(size: compact ? 12 : 13, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(Color(hex: "#FFD700"))

                    VStack(spacing: compact ? -5 : -2) {
                        Text("HALF")
                        Text("COURT")
                        Text("HERO")
                            .foregroundColor(.white)
                    }
                    .font(.system(size: titleSize, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#FF1493"))
                    .multilineTextAlignment(.center)
                    .shadow(color: Color(hex: "#FF1493").opacity(0.5), radius: 12)
                }

                Spacer(minLength: compact ? 20 : 34)

                Picker("Difficulty", selection: $game.difficulty) {
                    ForEach(HalfCourtDifficulty.allCases) { diff in
                        Text(diff.label).tag(diff)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, compact ? 28 : 34)

                Button {
                    HapticManager.impact(.medium)
                    game.beginCharacterSelect()
                } label: {
                    Text("TAP TO PLAY")
                        .font(.system(size: compact ? 17 : 19, weight: .black, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, compact ? 13 : 15)
                        .background(Color(hex: "#FFD700"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color(hex: "#FFD700").opacity(0.35), radius: 16)
                }
                .padding(.horizontal, compact ? 28 : 34)

                Text("BANDMUSICGAMES.PARTY")
                    .font(.system(size: compact ? 9 : 11, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.42))
                    .padding(.bottom, bottomInset)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: 430)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var characterSelectOverlay: some View {
        GeometryReader { geo in
            let usableHeight = geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom
            let compact = usableHeight < 720
            let topInset = max(geo.safeAreaInsets.top + 14, 40)
            let bottomInset = max(geo.safeAreaInsets.bottom + 14, 24)
            let gridSpacing: CGFloat = compact ? 10 : 14
            let cardHeight: CGFloat = compact ? 150 : 178
            let badgeHeight: CGFloat = compact ? 64 : 82

            VStack(spacing: compact ? 6 : 10) {
                Spacer()
                    .frame(height: topInset)

                Text(game.selectStep == 1 ? "MEET THE TEAM" : "PICK TEAMMATE")
                    .font(.system(size: compact ? 15 : 18, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(game.selectStep == 1 ? Color(hex: "#FFD700") : game.selectedPlayer.character.hue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text(game.selectStep == 1 ? "Choose your ball handler" : "\(game.selectedPlayer.character.fullName) is in")
                    .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: gridSpacing) {
                    ForEach(HalfCourtHeroID.allCases) { hero in
                        let disabled = game.selectStep == 2 && hero == game.selectedPlayer
                        Button {
                            HapticManager.selection()
                            game.choose(hero)
                        } label: {
                            VStack(spacing: compact ? 5 : 9) {
                                HalfCourtHeroBadge(hero: hero, selected: game.isSelected(hero), dimmed: disabled)
                                    .frame(height: badgeHeight)

                                Text(hero.character.name)
                                    .font(.system(size: compact ? 12 : 15, weight: .black, design: .monospaced))
                                    .foregroundColor(disabled ? .white.opacity(0.24) : hero.character.hue)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)

                                Text(hero.character.ability)
                                    .font(.system(size: compact ? 8 : 9, weight: .bold, design: .monospaced))
                                    .tracking(1.2)
                                    .foregroundColor(disabled ? .white.opacity(0.2) : .white.opacity(0.58))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.65)
                            }
                            .padding(compact ? 8 : 12)
                            .frame(maxWidth: .infinity)
                            .frame(height: cardHeight)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(game.isSelected(hero) ? hero.character.hue.opacity(0.17) : Color.black.opacity(0.28))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(game.isSelected(hero) ? hero.character.hue : hero.character.hue.opacity(0.35), lineWidth: game.isSelected(hero) ? 2.5 : 1)
                            )
                        }
                        .disabled(disabled)
                    }
                }
                .padding(.horizontal, compact ? 16 : 20)
                .padding(.top, compact ? 8 : 12)
                }

                Button {
                    HapticManager.impact(.heavy)
                    game.startGame()
                } label: {
                    Text("PLAY")
                        .font(.system(size: compact ? 15 : 17, weight: .black, design: .monospaced))
                        .tracking(4)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, compact ? 11 : 13)
                        .background(Color(hex: "#FFD700"))
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                .opacity(game.readyToStart ? 1 : 0.35)
                .disabled(!game.readyToStart)
                .padding(.horizontal, compact ? 28 : 32)
                .padding(.bottom, bottomInset)
            }
            .frame(maxWidth: 430)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var gameOverlay: some View {
        VStack {
            hud
            Spacer()
            controls
        }
        .allowsHitTesting(true)
    }

    private var hud: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NARA'S ROOM")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(Color(hex: "#FF1493"))
                    Text(game.activeHuman.character.name)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.62))
                }

                Spacer()

                HStack(spacing: 14) {
                    Text("\(game.homeScore)")
                        .foregroundColor(Color(hex: "#FF1493"))
                    Text("-")
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(game.awayScore)")
                        .foregroundColor(Color(hex: "#FF6B35"))
                }
                .font(.system(size: 30, weight: .black, design: .monospaced))

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(game.possession == .home ? "OFFENSE" : "DEFENSE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundColor(game.possession == .home ? Color(hex: "#FFD700") : Color(hex: "#00BFFF"))
                    Text("\(max(0, Int(ceil(Double(game.shotClockFrames) / 60.0)))) SEC")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(game.shotClockFrames <= 180 ? Color(hex: "#FF4444") : .white.opacity(0.62))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 54)

            if let callout = game.callout {
                Text(callout.text)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(callout.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.25), value: game.callout?.id)
    }

    private var controls: some View {
        HStack(alignment: .bottom) {
            HalfCourtJoystick { dx, dy, active in
                game.setJoystick(dx: dx, dy: dy, active: active)
            }

            Spacer()

            VStack(spacing: 13) {
                if game.possession == .away {
                    Button { game.switchDefender() } label: {
                        Text("SWITCH")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(Color(hex: "#FFD700"))
                            .frame(width: 72, height: 30)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color(hex: "#FFD700").opacity(0.75), lineWidth: 1.5))
                    }
                }

                HalfCourtHoldButton(
                    label: game.possession == .home ? "SHOOT" : "BLOCK",
                    color: game.possession == .home ? Color(hex: "#FF1493") : Color(hex: "#00BFFF"),
                    power: game.possession == .home ? game.shootPower : game.blockPower,
                    showGreen: game.possession == .home,
                    onStart: { game.beginPrimaryAction() },
                    onEnd: { game.endPrimaryAction() }
                )

                Button { game.secondaryAction() } label: {
                    Text(game.possession == .home ? "PASS" : "STEAL")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.1)
                        .foregroundColor(Color(hex: "#FFD700"))
                        .frame(width: 64, height: 54)
                        .background(Color.black.opacity(0.38))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(hex: "#FFD700"), lineWidth: 2))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 26)
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.58)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(game.homeScore > game.awayScore ? "NARA'S ROOM WINS" : "ALL-STARS WIN")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(game.homeScore > game.awayScore ? Color(hex: "#FFD700") : Color(hex: "#FF6B35"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)

                HStack(spacing: 20) {
                    Text("\(game.homeScore)")
                        .foregroundColor(Color(hex: "#FF1493"))
                    Text("-")
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(game.awayScore)")
                        .foregroundColor(Color(hex: "#FF6B35"))
                }
                .font(.system(size: 46, weight: .black, design: .monospaced))

                Text("FG \(game.stats.made)/\(max(1, game.stats.shots))  STEALS \(game.stats.steals)  BLOCKS \(game.stats.blocks)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(spacing: 12) {
                    Button {
                        HapticManager.impact(.medium)
                        game.startGame()
                    } label: {
                        Text("REMATCH")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .tracking(1.5)
                            .foregroundColor(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(Color(hex: "#FFD700"))
                            .clipShape(Capsule())
                    }

                    Button { dismiss() } label: {
                        Text("JUKEBOX")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.78))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 342)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [Color(hex: "#1a0a3e"), Color(hex: "#0a2060")], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "#FFD700").opacity(0.35), lineWidth: 1.5)
            )
        }
    }
}

private struct HalfCourtJoystick: View {
    let onChange: (CGFloat, CGFloat, Bool) -> Void
    @State private var drag: CGSize = .zero
    @State private var active = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.045))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
                .frame(width: 170, height: 128)

            if active {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .overlay(Circle().stroke(Color.white.opacity(0.42), lineWidth: 2))
                    .frame(width: 52, height: 52)
                    .offset(drag)
            } else {
                Text("MOVE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.8)
                    .foregroundColor(.white.opacity(0.22))
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    active = true
                    let clamped = clamp(value.translation, max: 55)
                    drag = clamped
                    onChange(clamped.width, clamped.height, true)
                }
                .onEnded { _ in
                    active = false
                    drag = .zero
                    onChange(0, 0, false)
                }
        )
    }

    private func clamp(_ size: CGSize, max: CGFloat) -> CGSize {
        let d = hypot(size.width, size.height)
        guard d > max, d > 0 else { return size }
        let scale = max / d
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}

private struct HalfCourtHoldButton: View {
    let label: String
    let color: Color
    let power: CGFloat
    let showGreen: Bool
    let onStart: () -> Void
    let onEnd: () -> Void

    @State private var pressed = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(pressed ? 0.58 : 0.36))
                .overlay(Circle().stroke(color, lineWidth: 2.5))
                .frame(width: 92, height: 92)

            if pressed {
                Circle()
                    .trim(from: 0, to: min(power / 100, 1))
                    .stroke(powerColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 108, height: 108)

                if showGreen {
                    Circle()
                        .trim(from: hchGreenLow / 100, to: hchGreenHigh / 100)
                        .stroke(Color(hex: "#00FF88").opacity(0.35), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 120)
                }
            }

            VStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(powerColor)
                Text("HOLD")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed {
                        pressed = true
                        onStart()
                    }
                }
                .onEnded { _ in
                    pressed = false
                    onEnd()
                }
        )
    }

    private var powerColor: Color {
        showGreen && power >= hchGreenLow && power <= hchGreenHigh ? Color(hex: "#00FF88") : color
    }
}

private struct HalfCourtHeroBadge: View {
    let hero: HalfCourtHeroID
    let selected: Bool
    let dimmed: Bool

    var body: some View {
        Canvas { context, size in
            HalfCourtHeroRenderer.drawBadge(hero: hero, in: &context, size: size, selected: selected)
        }
        .opacity(dimmed ? 0.35 : 1)
    }
}

@MainActor
private final class HalfCourtHeroGame: ObservableObject {
    @Published var phase: HalfCourtPhase = .title
    @Published var difficulty: HalfCourtDifficulty = .normal
    @Published var selectStep = 1
    @Published var selectedPlayer: HalfCourtHeroID = .nara
    @Published var selectedTeammate: HalfCourtHeroID? = .ethan
    @Published var homeScore = 0
    @Published var awayScore = 0
    @Published var possession: HalfCourtTeam = .home
    @Published var activeHuman: HalfCourtHeroID = .nara
    @Published var players: [HalfCourtHeroID: CourtPlayer] = [:]
    @Published var ball = HalfCourtBall()
    @Published var shootHeld = false
    @Published var shootPower: CGFloat = 0
    @Published var blockHeld = false
    @Published var blockPower: CGFloat = 0
    @Published var shotClockFrames = 600
    @Published var callout: HalfCourtCallout?
    @Published var frame = 0
    @Published var stats = HalfCourtStats()
    @Published var joystick = CGVector.zero

    private var timer: Timer?
    private var pauseFrames = 0
    private var calloutFrames = 0
    private var homeIDs: [HalfCourtHeroID] = [.nara, .ethan]
    private var awayIDs: [HalfCourtHeroID] = [.brendan, .will]

    var readyToStart: Bool { selectedTeammate != nil && selectedTeammate != selectedPlayer }

    func prepare() {
        if players.isEmpty {
            resetRoster()
        }
    }

    func beginCharacterSelect() {
        phase = .characterSelect
        selectStep = 1
        selectedTeammate = nil
    }

    func choose(_ hero: HalfCourtHeroID) {
        if selectStep == 1 {
            selectedPlayer = hero
            selectedTeammate = nil
            selectStep = 2
        } else if hero != selectedPlayer {
            selectedTeammate = hero
        }
    }

    func isSelected(_ hero: HalfCourtHeroID) -> Bool {
        hero == selectedPlayer || hero == selectedTeammate
    }

#if DEBUG
    func debugOpenTeammatePicker() {
        phase = .characterSelect
        selectedPlayer = .nara
        selectedTeammate = .ethan
        selectStep = 2
    }

    func debugStartGameplay() {
        selectedPlayer = .nara
        selectedTeammate = .ethan
        startGame()
    }
#endif

    func startGame() {
        if selectedTeammate == nil || selectedTeammate == selectedPlayer {
            selectedTeammate = HalfCourtHeroID.allCases.first { $0 != selectedPlayer }
        }

        homeScore = 0
        awayScore = 0
        stats = HalfCourtStats()
        frame = 0
        shotClockFrames = 600
        pauseFrames = 0
        callout = nil
        calloutFrames = 0
        shootHeld = false
        shootPower = 0
        blockHeld = false
        blockPower = 0
        possession = .home
        activeHuman = selectedPlayer
        joystick = .zero
        resetRoster()
        resetBall(nextPossession: .home)
        phase = .playing
        startTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setJoystick(dx: CGFloat, dy: CGFloat, active: Bool) {
        joystick = active ? CGVector(dx: dx, dy: dy) : .zero
    }

    func beginPrimaryAction() {
        guard phase == .playing else { return }
        if possession == .home {
            guard player(activeHuman).hasBall else { return }
            shootHeld = true
            shootPower = 0
            mutate(activeHuman) { $0.animation = .shoot }
        } else {
            blockHeld = true
            blockPower = 0
        }
    }

    func endPrimaryAction() {
        if possession == .home {
            releaseShot()
        } else {
            releaseBlock()
        }
    }

    func secondaryAction() {
        guard phase == .playing else { return }
        if possession == .home {
            passBall()
        } else {
            stealBall()
        }
    }

    func switchDefender() {
        guard possession == .away else { return }
        activeHuman = homeIDs.first { $0 != activeHuman } ?? activeHuman
        show(activeHuman.character.name, color: activeHuman.character.hue, frames: 36)
        HapticManager.selection()
    }

    private func startTimer() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func tick() {
        guard phase == .playing else { return }
        frame += 1
        updateCallout()
        updatePower()
        updateJumping()
        updateBall()

        if pauseFrames > 0 {
            pauseFrames -= 1
            return
        }

        updatePlayers()
        updateShotClock()
    }

    private func updatePower() {
        if shootHeld {
            shootPower = min(100, shootPower + difficulty.chargeRate)
            if shootPower >= 100 { releaseShot() }
        }
        if blockHeld {
            blockPower = min(100, blockPower + 2.7)
            if blockPower >= 100 { releaseBlock() }
        }
    }

    private func updateShotClock() {
        guard possession == .home, !ball.inAir, ball.carrier != nil else {
            shotClockFrames = 600
            return
        }

        shotClockFrames = max(0, shotClockFrames - 1)
        if shotClockFrames == 0 {
            show("SHOT CLOCK", color: Color(hex: "#FF4444"), frames: 60)
            turnoverToCPU()
        } else if shotClockFrames % 60 == 0 && shotClockFrames <= 180 {
            show("\(shotClockFrames / 60)", color: Color(hex: "#FFD700"), frames: 22)
        }
    }

    private func updateJumping() {
        for id in HalfCourtHeroID.allCases {
            var p = player(id)
            if p.jumpVelocity != 0 {
                p.jump += p.jumpVelocity
                p.jumpVelocity += 0.65
                if p.jump >= 0 {
                    p.jump = 0
                    p.jumpVelocity = 0
                    if p.animation == .jump {
                        p.animation = .land
                        p.landFrame = frame
                    }
                }
            } else if p.animation == .land && frame - p.landFrame > 18 {
                p.animation = .idle
            } else if p.animation == .shoot && frame - p.landFrame > 32 && !p.hasBall {
                p.animation = .idle
            }
            players[id] = p
        }
    }

    private func updatePlayers() {
        if possession == .home {
            updateCPUDefense()
            updateHumanOffense()
            updateHomeTeammate()
        } else {
            updateCPUOffense()
            updateHumanDefense()
            updateHomeHelpDefense()
        }
        keepPlayersInBounds()
    }

    private func updateHumanOffense() {
        var p = player(activeHuman)
        let speed: CGFloat = p.id.character.speed * (fastBreakActive ? 4.0 : 3.4)
        applyJoystick(to: &p, speed: speed, yScale: 0.6, reverseX: false)
        p.position.x = clamp(p.position.x + p.velocity.dx, 20, 320)
        p.position.y = clamp(p.position.y + p.velocity.dy, hchCourtFarY, hchCourtNearY)
        if p.hasBall, abs(p.position.x - hchHoopX) > hchRange2, frame % 90 == 0 {
            show("3PT RANGE", color: Color(hex: "#FFD700"), frames: 34)
        }
        players[p.id] = p
    }

    private func updateHumanDefense() {
        var p = player(activeHuman)
        applyJoystick(to: &p, speed: 3.25, yScale: 0.6, reverseX: false)
        p.position.x = clamp(p.position.x + p.velocity.dx, 20, 350)
        p.position.y = clamp(p.position.y + p.velocity.dy, hchCourtFarY, hchCourtNearY)
        players[p.id] = p
    }

    private func updateHomeTeammate() {
        guard let teammate = homeIDs.first(where: { $0 != activeHuman }) else { return }
        let active = player(activeHuman)
        let targetX: CGFloat
        let targetY: CGFloat
        if fastBreakActive {
            targetX = hchHoopX - 38
            targetY = hchCourtFarY + 12
        } else if active.position.x < 190 {
            targetX = hchHoopX - 52
            targetY = hchCourtFarY + 16
        } else {
            targetX = 110
            targetY = hchCourtFarY + 10
        }
        movePlayer(teammate, toward: CGPoint(x: targetX, y: targetY), speed: 2.45, ySpeed: 1.45)
    }

    private func updateHomeHelpDefense() {
        guard let teammate = homeIDs.first(where: { $0 != activeHuman }) else { return }
        let mark = awayIDs.first { player($0).hasBall == false }.map { player($0) }
        let target = mark.map { CGPoint(x: max(hchHoopX - 88, $0.position.x + 38), y: $0.position.y) }
            ?? CGPoint(x: hchHoopX - 80, y: (hchCourtFarY + hchCourtNearY) / 2)
        movePlayer(teammate, toward: target, speed: 1.85, ySpeed: 1.25)
    }

    private func updateCPUDefense() {
        let carrier = player(activeHuman)
        let cpuDeficit = homeScore - awayScore
        let zone = cpuDeficit >= 3

        if zone {
            movePlayer(awayIDs[0], toward: CGPoint(x: hchHoopX - 58, y: (hchCourtFarY + hchCourtNearY) / 2), speed: 1.9, ySpeed: 1.2)
            let willTargetX = carrier.position.x < hchHoopX - 120 ? max(carrier.position.x + 18, hchHoopX - 165) : hchHoopX - 98
            movePlayer(awayIDs[1], toward: CGPoint(x: willTargetX, y: carrier.position.y - 5), speed: 2.05, ySpeed: 1.3)
        } else {
            let pressure = homeScore >= hchWinScore - 1 ? CGFloat(1.16) : CGFloat(1.0)
            movePlayer(awayIDs[0], toward: CGPoint(x: max(carrier.position.x + 24, hchHoopX - 36), y: carrier.position.y - 8), speed: 2.35 * pressure, ySpeed: 1.85)
            let driveDepth = carrier.position.x > hchHoopX - 130
            let targetX = driveDepth ? max(hchHoopX - 98, min(carrier.position.x + 6, hchHoopX - 68)) : hchHoopX - 60
            let targetY = driveDepth ? carrier.position.y + 12 : (hchCourtFarY + hchCourtNearY) / 2
            movePlayer(awayIDs[1], toward: CGPoint(x: targetX, y: targetY), speed: driveDepth ? 2.4 : 1.8, ySpeed: 1.2)
        }

        if shootHeld && shootPower > 30, let nearest = nearestAway(to: carrier.position), player(nearest).jump == 0 {
            let dist = distance(player(nearest).position, carrier.position)
            if dist < 58 && frame % 24 == 0 {
                mutate(nearest) {
                    $0.jumpVelocity = -8.2
                    $0.animation = .jump
                }
            }
        }

        let defender = player(awayIDs[0])
        if carrier.hasBall && distance(carrier.position, defender.position) < 46 && frame % 70 == 0 {
            let rate = difficulty.cpuStealRate
            if CGFloat.random(in: 0...1) < rate {
                mutate(activeHuman) { $0.hasBall = false; $0.animation = .sad }
                mutate(awayIDs[0]) { $0.hasBall = true; $0.animation = .celebrate }
                ball.carrier = awayIDs[0]
                possession = .away
                shootHeld = false
                shootPower = 0
                show("STEAL", color: awayIDs[0].character.hue, frames: 44)
                HapticManager.notification(.warning)
            }
        }
    }

    private func updateCPUOffense() {
        guard let carrierID = awayIDs.first(where: { player($0).hasBall }) else {
            movePlayer(awayIDs[0], toward: CGPoint(x: hchHoopX - 118, y: hchCourtFarY + 20), speed: 1.5, ySpeed: 1.0)
            movePlayer(awayIDs[1], toward: CGPoint(x: hchHoopX - 160, y: hchCourtFarY + 12), speed: 1.5, ySpeed: 1.0)
            return
        }

        let otherID = awayIDs.first { $0 != carrierID } ?? awayIDs[0]
        var carrier = player(carrierID)
        carrier.cpuTimer += 1

        let dist = abs(carrier.position.x - hchHoopX)
        let targetX: CGFloat
        if carrier.cpuTimer > 95 || (dist < 76 && carrier.cpuTimer > 35) {
            players[carrierID] = carrier
            cpuShoot(carrierID)
            return
        } else if difficulty == .hard && carrier.cpuTimer > 42 && CGFloat.random(in: 0...1) < 0.012 {
            targetX = hchHoopX - 214
        } else {
            targetX = hchHoopX - (carrierID == .will ? 58 : 76)
        }

        players[carrierID] = carrier
        movePlayer(carrierID, toward: CGPoint(x: targetX, y: hchCourtFarY + (carrierID == .will ? 12 : 20)), speed: difficulty.cpuDriveSpeed, ySpeed: 1.2)
        movePlayer(otherID, toward: CGPoint(x: carrier.position.x < 185 ? hchHoopX - 50 : 112, y: hchCourtFarY + 16), speed: 1.7, ySpeed: 1.1)

        if carrier.cpuTimer > 48 && CGFloat.random(in: 0...1) < 0.018 {
            cpuPass(from: carrierID, to: otherID)
        }
    }

    private func updateBall() {
        if let carrier = ball.carrier {
            let p = player(carrier)
            let dribble = p.animation == .run ? abs(sin(CGFloat(frame) * 0.24)) * 18 : 8
            ball.position = CGPoint(x: p.position.x + p.facing * 18, y: p.position.y + p.jump - 48 + dribble)
            ball.inAir = false
            return
        }

        guard ball.inAir else { return }

        ball.velocity.dy += 0.45
        ball.position.x += ball.velocity.dx
        ball.position.y += ball.velocity.dy

        if ball.isPass, let target = ball.passTarget {
            let catchPoint = CGPoint(x: player(target).position.x, y: player(target).position.y - 50)
            if distance(ball.position, catchPoint) < 48 {
                catchPass(target)
                return
            }

            let defenders = player(target).team == .home ? awayIDs : homeIDs
            for def in defenders where def != target {
                if distance(ball.position, CGPoint(x: player(def).position.x, y: player(def).position.y - 35)) < 34,
                   CGFloat.random(in: 0...1) < 0.018 {
                    interceptPass(by: def)
                    return
                }
            }
        }

        let rimDistance = distance(ball.position, CGPoint(x: hchHoopX, y: hchRimY))
        if rimDistance < hchRimR + 10 && ball.velocity.dy > 0 && ball.position.y < hchRimY + 20 {
            if ball.made && rimDistance < hchRimR + 6 {
                scorePoint()
                return
            } else if rimDistance < hchRimR + 4 {
                ball.velocity.dx = CGFloat.random(in: -3...3)
                ball.velocity.dy = -5
                ball.made = false
                show("RIM", color: Color(hex: "#FF8C00"), frames: 24)
            }
        }

        if ball.position.y >= hchFloorY - 10 {
            ball.position.y = hchFloorY - 10
            ball.velocity.dy = -ball.velocity.dy * 0.45
            ball.velocity.dx *= 0.72
            if abs(ball.velocity.dy) < 1.5 {
                resolveRebound()
            }
        }

        if ball.position.x < -35 || ball.position.x > hchW + 50 {
            turnoverToCPU()
        }
    }

    private func releaseShot() {
        guard shootHeld else { return }
        shootHeld = false
        guard var shooter = players[activeHuman], shooter.hasBall else {
            shootPower = 0
            return
        }

        let power = shootPower
        shootPower = 0
        guard power >= 8 else {
            shooter.animation = .idle
            players[activeHuman] = shooter
            return
        }

        if power < 13 {
            show("PUMP FAKE", color: shooter.id.character.hue, frames: 40)
            shooter.animation = .shoot
            shooter.landFrame = frame
            players[activeHuman] = shooter
            return
        }

        let dist = abs(shooter.position.x - hchHoopX)
        guard dist <= hchRange3 + 20 else {
            show("TOO FAR", color: Color(hex: "#FF4444"), frames: 32)
            shooter.animation = .idle
            players[activeHuman] = shooter
            return
        }

        let green = difficulty.greenWindow
        let inGreen = power >= green.low && power <= green.high
        let perfect = power >= 60 && power <= 68
        let closestDef = awayIDs.map { distance(player($0).position, shooter.position) }.min() ?? 140
        let wideOpen = closestDef > 86
        let contested = closestDef < 38

        var accuracy: CGFloat
        var text: String
        if perfect {
            accuracy = difficulty.perfectAccuracy
            text = "PERFECT"
        } else if inGreen {
            accuracy = difficulty.greenAccuracy
            text = "GOOD"
        } else if power < green.low {
            accuracy = max(0.08, 0.14 + power * 0.006)
            text = "EARLY"
        } else {
            accuracy = difficulty.lateAccuracy
            text = "LATE"
        }

        if dist < 70 {
            accuracy = min(0.97, accuracy + 0.26)
            text = dist < 38 && power >= 40 ? "DUNK" : "LAYUP"
            if text == "DUNK" {
                shooter.jumpVelocity = -12
                shooter.animation = .jump
            }
        } else if wideOpen {
            accuracy = min(0.99, accuracy + 0.06)
            if inGreen || perfect { text = "WIDE OPEN" }
        } else if contested {
            accuracy = max(0.05, accuracy - 0.13)
            if dist > hchLayupRange { text = "CONTESTED" }
        }

        if dist > hchRange2 {
            accuracy = min(0.99, accuracy + shooter.id.character.threeBonus)
        }

        let made = CGFloat.random(in: 0...1) < accuracy
        shooter.hasBall = false
        shooter.animation = .shoot
        shooter.landFrame = frame
        players[activeHuman] = shooter

        ball.carrier = nil
        fireShot(from: CGPoint(x: shooter.position.x, y: shooter.position.y + shooter.jump - 55), made: made, dist: dist, team: .home, shooter: shooter.id)
        stats.shots += 1
        show(text, color: (perfect || inGreen) ? Color(hex: "#00FF88") : shooter.id.character.hue, frames: 48)
        HapticManager.impact(made ? .heavy : .light)
    }

    private func releaseBlock() {
        guard blockHeld else { return }
        let power = blockPower
        blockHeld = false
        blockPower = 0
        guard power >= 5 else { return }

        mutate(activeHuman) {
            $0.jumpVelocity = -(4.7 + power * 0.085)
            $0.animation = .jump
        }

        if let shooter = awayIDs.first(where: { player($0).animation == .shoot }) {
            let d = distance(player(shooter).position, player(activeHuman).position)
            if d < 90 {
                ball.velocity.dx = CGFloat.random(in: -4...4)
                ball.velocity.dy = -10
                ball.made = false
                mutate(shooter) { $0.animation = .sad }
                stats.blocks += 1
                show("BLOCKED", color: activeHuman.character.hue, frames: 54)
                HapticManager.notification(.success)
            }
        }
    }

    private func passBall() {
        guard possession == .home,
              let teammate = homeIDs.first(where: { $0 != activeHuman }),
              var passer = players[activeHuman],
              passer.hasBall
        else { return }

        let receiver = player(teammate)
        passer.hasBall = false
        passer.animation = .run
        players[activeHuman] = passer

        ball.carrier = nil
        ball.inAir = true
        ball.isPass = true
        ball.passTarget = teammate
        ball.shotTeam = .home
        ball.shotBy = passer.id
        ball.position = CGPoint(x: passer.position.x, y: passer.position.y - 50)

        let target = CGPoint(x: receiver.position.x, y: receiver.position.y - 55)
        let dx = target.x - ball.position.x
        let dy = target.y - ball.position.y
        let t = max(10, hypot(dx, dy) / 14)
        ball.velocity = CGVector(dx: dx / t, dy: (dy - 0.225 * t * t) / t - min(2.5, hypot(dx, dy) / 80))

        activeHuman = teammate
        show("CATCH", color: teammate.character.hue, frames: 38)
        HapticManager.impact(.light)
    }

    private func stealBall() {
        guard possession == .away,
              let carrierID = awayIDs.first(where: { player($0).hasBall })
        else { return }

        let defender = player(activeHuman)
        let carrier = player(carrierID)
        let stealRange = 60 * (1 + defender.id.character.stealBonus)
        mutate(activeHuman) { $0.animation = .jump; $0.stealCooldown = 42 }

        guard distance(defender.position, carrier.position) < stealRange else {
            show("TOO FAR", color: Color(hex: "#FFD700"), frames: 24)
            return
        }

        if CGFloat.random(in: 0...1) < 0.48 {
            mutate(carrierID) { $0.hasBall = false; $0.animation = .sad }
            mutate(activeHuman) { $0.hasBall = true; $0.animation = .celebrate }
            ball.carrier = activeHuman
            possession = .home
            stats.steals += 1
            show("STEAL", color: activeHuman.character.hue, frames: 48)
            HapticManager.notification(.success)
        } else {
            show("MISS", color: Color(hex: "#FF4444"), frames: 24)
            HapticManager.impact(.light)
        }
    }

    private func cpuPass(from passerID: HalfCourtHeroID, to receiverID: HalfCourtHeroID) {
        var passer = player(passerID)
        let receiver = player(receiverID)
        guard passer.hasBall else { return }
        passer.hasBall = false
        players[passerID] = passer

        ball.carrier = nil
        ball.inAir = true
        ball.isPass = true
        ball.passTarget = receiverID
        ball.shotTeam = .away
        ball.shotBy = passerID
        ball.position = CGPoint(x: passer.position.x, y: passer.position.y - 50)

        let target = CGPoint(x: receiver.position.x, y: receiver.position.y - 55)
        let dx = target.x - ball.position.x
        let dy = target.y - ball.position.y
        let t = max(10, hypot(dx, dy) / 14)
        ball.velocity = CGVector(dx: dx / t, dy: (dy - 0.225 * t * t) / t - 1.2)
    }

    private func cpuShoot(_ id: HalfCourtHeroID) {
        guard var shooter = players[id], shooter.hasBall else { return }
        let dist = abs(shooter.position.x - hchHoopX)
        let closestHuman = homeIDs.map { distance(player($0).position, shooter.position) }.min() ?? 120
        let contest = closestHuman > 85 ? CGFloat(0.12) : closestHuman < 38 ? CGFloat(-0.15) : 0
        let base: CGFloat = dist < hchLayupRange ? 0.76 : dist < hchRange2 ? 0.58 : 0.36 + shooter.id.character.threeBonus
        let acc = clamp(base * difficulty.cpuShotMultiplier + contest, 0.05, 0.96)
        let made = CGFloat.random(in: 0...1) < acc

        shooter.hasBall = false
        shooter.animation = .shoot
        shooter.landFrame = frame
        shooter.cpuTimer = 0
        players[id] = shooter

        ball.carrier = nil
        fireShot(from: CGPoint(x: shooter.position.x, y: shooter.position.y - 55), made: made, dist: dist, team: .away, shooter: id)
        show(id == .brendan ? "BOOM" : "PULL UP", color: id.character.hue, frames: 34)
    }

    private func fireShot(from: CGPoint, made: Bool, dist: CGFloat, team: HalfCourtTeam, shooter: HalfCourtHeroID) {
        let dx = hchHoopX - from.x
        let dy = hchRimY - from.y
        let arcBonus: CGFloat = dist > hchRange2 ? 8 : dist > hchLayupRange ? 3 : 0
        let tFly = 35 + dist * 0.08 + arcBonus
        let drift: CGFloat = made ? 0 : CGFloat.random(in: -17...17)

        ball.position = from
        ball.velocity = CGVector(dx: (dx + drift) / tFly, dy: (dy - 0.225 * tFly * tFly) / tFly)
        ball.inAir = true
        ball.made = made
        ball.fromX = from.x
        ball.shotTeam = team
        ball.shotBy = shooter
        ball.isPass = false
        ball.passTarget = nil
    }

    private func scorePoint() {
        let points = abs(ball.fromX - hchHoopX) > hchRange2 ? 3 : 2
        let scoringTeam = ball.shotTeam
        if scoringTeam == .home {
            homeScore += points
            stats.made += 1
            if points == 3 { stats.threes += 1 }
        } else {
            awayScore += points
        }

        let scorer = ball.shotBy ?? (scoringTeam == .home ? activeHuman : awayIDs[0])
        show(points == 3 ? "3 POINTER" : scorer.character.quip, color: scorer.character.hue, frames: 62)
        HapticManager.notification(scoringTeam == .home ? .success : .warning)

        if didWin(scoringTeam) {
            phase = .ended
            stop()
            return
        }

        resetBall(nextPossession: scoringTeam == .home ? .away : .home)
        pauseFrames = 36
    }

    private func didWin(_ team: HalfCourtTeam) -> Bool {
        let own = team == .home ? homeScore : awayScore
        let other = team == .home ? awayScore : homeScore
        if homeScore >= hchWinScore - 1 && awayScore >= hchWinScore - 1 {
            return own >= hchWinScore && own - other >= 2
        }
        return own >= hchWinScore
    }

    private func catchPass(_ target: HalfCourtHeroID) {
        mutate(target) { $0.hasBall = true; $0.animation = .idle; $0.catchFrame = frame }
        ball.carrier = target
        ball.inAir = false
        ball.isPass = false
        ball.passTarget = nil
        possession = player(target).team
        if possession == .home {
            activeHuman = target
        }
    }

    private func interceptPass(by id: HalfCourtHeroID) {
        mutate(id) { $0.hasBall = true; $0.animation = .celebrate }
        ball.carrier = id
        ball.inAir = false
        ball.isPass = false
        ball.passTarget = nil
        possession = player(id).team
        if possession == .home { activeHuman = id }
        show("PICK", color: id.character.hue, frames: 44)
    }

    private func resolveRebound() {
        let all = homeIDs + awayIDs
        let nearest = all
            .map { ($0, distance(player($0).position, ball.position)) }
            .sorted { $0.1 < $1.1 }
            .first

        ball.inAir = false
        ball.velocity = .zero

        guard let nearest, nearest.1 < 122 else {
            turnoverToCPU()
            return
        }

        for id in all { mutate(id) { $0.hasBall = false } }
        mutate(nearest.0) { $0.hasBall = true; $0.animation = .celebrate }
        ball.carrier = nearest.0
        possession = player(nearest.0).team
        if possession == .home {
            activeHuman = nearest.0
            show("REBOUND", color: nearest.0.character.hue, frames: 36)
        }
    }

    private func turnoverToCPU() {
        for id in homeIDs + awayIDs { mutate(id) { $0.hasBall = false } }
        let carrier = awayIDs[0]
        mutate(carrier) { $0.hasBall = true; $0.animation = .idle }
        possession = .away
        ball = HalfCourtBall(position: CGPoint(x: player(carrier).position.x, y: hchFloorY - 30), carrier: carrier)
        shootHeld = false
        shootPower = 0
        blockHeld = false
        blockPower = 0
        shotClockFrames = 600
        show("TURNOVER", color: Color(hex: "#FF6B35"), frames: 44)
    }

    private func resetBall(nextPossession: HalfCourtTeam) {
        for id in homeIDs + awayIDs {
            mutate(id) {
                $0.hasBall = false
                $0.animation = .idle
                $0.jump = 0
                $0.jumpVelocity = 0
                $0.cpuTimer = CGFloat.random(in: 0...40)
            }
        }

        players[homeIDs[0]]?.position = CGPoint(x: nextPossession == .home ? 110 : 205, y: hchCourtFarY + 20)
        players[homeIDs[1]]?.position = CGPoint(x: nextPossession == .home ? 155 : 255, y: hchCourtFarY + 20)
        players[awayIDs[0]]?.position = CGPoint(x: nextPossession == .home ? 205 : 110, y: hchCourtFarY + 20)
        players[awayIDs[1]]?.position = CGPoint(x: nextPossession == .home ? 255 : 155, y: hchCourtFarY + 20)

        possession = nextPossession
        let carrier = nextPossession == .home ? activeHuman : awayIDs[0]
        mutate(carrier) { $0.hasBall = true }
        ball = HalfCourtBall(position: CGPoint(x: player(carrier).position.x, y: hchFloorY - 30), carrier: carrier)
        shotClockFrames = 600
    }

    private func resetRoster() {
        let teammate = selectedTeammate ?? .ethan
        homeIDs = [selectedPlayer, teammate]
        awayIDs = HalfCourtHeroID.allCases.filter { !homeIDs.contains($0) }
        if awayIDs.count < 2 {
            awayIDs = [.brendan, .will].filter { !homeIDs.contains($0) }
        }

        var next: [HalfCourtHeroID: CourtPlayer] = [:]
        next[homeIDs[0]] = CourtPlayer(id: homeIDs[0], team: .home, position: CGPoint(x: 100, y: hchCourtFarY + 20), facing: 1)
        next[homeIDs[1]] = CourtPlayer(id: homeIDs[1], team: .home, position: CGPoint(x: 175, y: hchCourtFarY + 20), facing: 1)
        next[awayIDs[0]] = CourtPlayer(id: awayIDs[0], team: .away, position: CGPoint(x: 260, y: hchCourtFarY + 20), facing: -1)
        next[awayIDs[1]] = CourtPlayer(id: awayIDs[1], team: .away, position: CGPoint(x: 320, y: hchCourtFarY + 20), facing: -1)
        players = next
    }

    private var fastBreakActive: Bool {
        possession == .home && player(activeHuman).position.x > hchHoopX - 120
    }

    private func nearestAway(to point: CGPoint) -> HalfCourtHeroID? {
        awayIDs.min { distance(player($0).position, point) < distance(player($1).position, point) }
    }

    private func movePlayer(_ id: HalfCourtHeroID, toward target: CGPoint, speed: CGFloat, ySpeed: CGFloat) {
        var p = player(id)
        let dx = target.x - p.position.x
        let dy = target.y - p.position.y
        let old = p.position
        if abs(dx) > 6 {
            p.position.x += sign(dx) * min(speed, abs(dx))
            p.facing = dx > 0 ? 1 : -1
        }
        if abs(dy) > 6 {
            p.position.y += sign(dy) * min(ySpeed, abs(dy))
        }
        p.velocity = CGVector(dx: p.position.x - old.x, dy: p.position.y - old.y)
        p.animation = hypot(p.velocity.dx, p.velocity.dy) > 0.45 ? .run : .idle
        players[id] = p
    }

    private func applyJoystick(to p: inout CourtPlayer, speed: CGFloat, yScale: CGFloat, reverseX: Bool) {
        let norm = hypot(joystick.dx, joystick.dy)
        if norm > 8 {
            let xDir = reverseX ? -joystick.dx : joystick.dx
            let targetVx = (xDir / 55) * speed
            let targetVy = (joystick.dy / 55) * speed * yScale
            p.velocity.dx += (targetVx - p.velocity.dx) * 0.28
            p.velocity.dy += (targetVy - p.velocity.dy) * 0.28
            if abs(xDir) > 6 { p.facing = xDir > 0 ? 1 : -1 }
            p.animation = .run
        } else {
            p.velocity.dx *= 0.72
            p.velocity.dy *= 0.72
            if hypot(p.velocity.dx, p.velocity.dy) < 0.3 {
                p.velocity = .zero
                if p.animation == .run { p.animation = .idle }
            }
        }
    }

    private func keepPlayersInBounds() {
        for id in homeIDs + awayIDs {
            mutate(id) {
                $0.position.x = clamp($0.position.x, 20, 350)
                $0.position.y = clamp($0.position.y, hchCourtFarY, hchCourtNearY)
            }
        }
    }

    private func updateCallout() {
        if calloutFrames > 0 {
            calloutFrames -= 1
        } else {
            callout = nil
        }
    }

    private func show(_ text: String, color: Color, frames: Int) {
        callout = HalfCourtCallout(text: text, color: color)
        calloutFrames = frames
    }

    private func player(_ id: HalfCourtHeroID) -> CourtPlayer {
        players[id] ?? CourtPlayer(id: id, team: .home, position: CGPoint(x: 100, y: hchCourtFarY + 20), facing: 1)
    }

    private func mutate(_ id: HalfCourtHeroID, _ body: (inout CourtPlayer) -> Void) {
        var p = player(id)
        body(&p)
        players[id] = p
    }
}

@MainActor
private enum HalfCourtHeroRenderer {
    static func draw(game: HalfCourtHeroGame, context: inout GraphicsContext, size: CGSize) {
        let scale = min(size.width / hchW, size.height / hchH)
        let xOffset = (size.width - hchW * scale) / 2
        let yOffset = (size.height - hchH * scale) / 2

        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: "#1a0a3e")))
        context.translateBy(x: xOffset, y: yOffset)
        context.scaleBy(x: scale, y: scale)

        if game.phase == .title || game.phase == .characterSelect {
            drawTitleBackground(in: &context, frame: game.frame)
            return
        }

        drawCourtBackground(in: &context)
        drawHoop(in: &context)

        let ordered = game.players.values.sorted { a, b in
            if abs(a.position.y - b.position.y) > 0.5 { return a.position.y < b.position.y }
            return a.position.x < b.position.x
        }
        for p in ordered {
            drawPlayer(p, in: &context, frame: game.frame, scale: 1, active: p.id == game.activeHuman, hasBall: p.hasBall, overrideGround: nil)
        }

        if game.ball.carrier == nil || game.ball.inAir {
            drawBall(at: game.ball.position, radius: 13, in: &context)
        }
    }

    static func drawPlayer(_ p: CourtPlayer, in context: inout GraphicsContext, frame: Int, scale fixedScale: CGFloat, active: Bool, hasBall: Bool, overrideGround: CGFloat?) {
        let depth = clamp((p.position.y - hchCourtFarY) / (hchCourtNearY - hchCourtFarY), 0, 1)
        let depthScale = fixedScale * (0.85 + depth * 0.22)
        let char = p.id.character
        let groundY = overrideGround ?? p.position.y
        var ctx = context
        ctx.translateBy(x: p.position.x, y: groundY + p.jump)
        ctx.scaleBy(x: depthScale, y: depthScale)

        let bob: CGFloat
        let stretchX: CGFloat
        let stretchY: CGFloat
        switch p.animation {
        case .idle:
            bob = sin(CGFloat(frame) * 0.05) * 3.2
            stretchX = 1.0
            stretchY = 1.0
        case .run:
            bob = -abs(sin(CGFloat(frame) * 0.2)) * 5
            stretchX = 1.03
            stretchY = 0.98
        case .jump:
            bob = -8
            stretchX = 0.9
            stretchY = 1.12
        case .land:
            bob = 5
            stretchX = 1.15
            stretchY = 0.88
        case .shoot:
            bob = -10
            stretchX = 0.92
            stretchY = 1.1
        case .celebrate:
            bob = -abs(sin(CGFloat(frame) * 0.22)) * 13
            stretchX = 1.05
            stretchY = 1.02
        case .sad:
            bob = 6
            stretchX = 1.08
            stretchY = 0.9
        }

        let shadow = Path(ellipseIn: CGRect(x: -25, y: 0 - p.jump * 0.12, width: 50, height: 12))
        ctx.fill(shadow, with: .color(.black.opacity(0.23)))
        if active {
            ctx.stroke(Path(ellipseIn: CGRect(x: -38, y: -9 - p.jump * 0.12, width: 76, height: 24)), with: .color(char.hue.opacity(0.85)), lineWidth: 3)
        }

        ctx.translateBy(x: 0, y: bob)
        ctx.scaleBy(x: stretchX, y: stretchY)

        drawSprite(char: char, in: &ctx)

        if hasBall {
            if p.animation == .shoot || p.animation == .jump {
                drawBall(at: CGPoint(x: 20, y: -154), radius: 12, in: &ctx)
            } else {
                let dribble = abs(sin(CGFloat(frame) * 0.18))
                drawBall(at: CGPoint(x: 29, y: -78 + 68 * (1 - dribble)), radius: 12 - (1 - dribble) * 2, in: &ctx)
            }
        }
    }

    static func drawBadge(hero: HalfCourtHeroID, in context: inout GraphicsContext, size: CGSize, selected: Bool) {
        let char = hero.character
        let bottomPad: CGFloat = 7
        let topPad: CGFloat = 2
        let spriteHeight = max(1, size.height - topPad - bottomPad)
        let spriteWidth = spriteHeight * char.spriteAspect
        let centerX = size.width / 2
        let groundY = topPad + spriteHeight
        let shadowWidth = max(34, spriteWidth * 0.68)

        context.fill(
            Path(ellipseIn: CGRect(x: centerX - shadowWidth / 2, y: groundY - 4, width: shadowWidth, height: 8)),
            with: .color(.black.opacity(0.28))
        )

        if selected {
            context.stroke(
                Path(ellipseIn: CGRect(x: centerX - shadowWidth * 0.65, y: groundY - 10, width: shadowWidth * 1.3, height: 18)),
                with: .color(char.hue.opacity(0.85)),
                lineWidth: 3
            )
        }

        context.draw(
            Image(char.spriteAssetName),
            in: CGRect(x: centerX - spriteWidth / 2, y: topPad, width: spriteWidth, height: spriteHeight)
        )
    }

    private static func drawTitleBackground(in context: inout GraphicsContext, frame: Int) {
        drawCourtBackground(in: &context)
        context.fill(Path(CGRect(x: 0, y: 0, width: hchW, height: hchH)), with: .linearGradient(
            Gradient(colors: [Color(hex: "#1a0a3e").opacity(0.92), Color(hex: "#2d0f5a").opacity(0.72), Color(hex: "#0a2060").opacity(0.82)]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: hchH)
        ))

        for i in 0..<44 {
            let x = CGFloat((i * 97) % Int(hchW))
            let y = CGFloat((i * 61) % 286)
            let r = 0.8 + sin(CGFloat(frame) * 0.03 + CGFloat(i)) * 0.45
            context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.58)))
        }

        context.fill(Path(CGRect(x: 0, y: 482, width: hchW, height: 268)), with: .color(Color(red: 0.86, green: 0.55, blue: 0.2).opacity(0.14)))
        let ballY = 155 + abs(sin(CGFloat(frame) * 0.08)) * 40
        let ballX = hchW / 2 + sin(CGFloat(frame) * 0.048) * 130
        drawBall(at: CGPoint(x: ballX, y: ballY), radius: 11, in: &context)
    }

    private static func drawCourtBackground(in context: inout GraphicsContext) {
        context.draw(Image("hch-court-env"), in: CGRect(x: 0, y: 0, width: hchW, height: hchH))
    }

    private static func drawSky(in context: inout GraphicsContext) {
        context.fill(Path(CGRect(x: 0, y: 55, width: hchW, height: hchFloorY - 55)), with: .linearGradient(
            Gradient(colors: [Color(hex: "#4A90C0"), Color(hex: "#87CEEA"), Color(hex: "#A8D8EA")]),
            startPoint: CGPoint(x: 0, y: 55),
            endPoint: CGPoint(x: 0, y: hchFloorY)
        ))

        for cloud in [
            (72.0, 120.0, 22.0), (98.0, 110.0, 26.0), (122.0, 118.0, 20.0), (50.0, 124.0, 17.0),
            (272.0, 138.0, 20.0), (295.0, 128.0, 24.0), (318.0, 136.0, 18.0), (252.0, 142.0, 15.0),
        ] {
            let rect = CGRect(x: cloud.0 - cloud.2, y: cloud.1 - cloud.2, width: cloud.2 * 2, height: cloud.2 * 2)
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.88)))
        }
    }

    private static func drawCrowd(in context: inout GraphicsContext) {
        let baseY = hchFloorY - 8
        let trees: [(CGFloat, CGFloat)] = [(20, 55), (58, 70), (96, 52), (138, 65), (178, 58), (218, 72), (256, 55), (294, 68), (332, 60), (368, 74)]
        for (x, h) in trees {
            let trunkH = h * 0.38
            context.fill(Path(CGRect(x: x - 4, y: baseY - trunkH, width: 8, height: trunkH)), with: .color(Color(hex: "#2E1C0E")))
            context.fill(Path(ellipseIn: CGRect(x: x - h * 0.33, y: baseY - trunkH - h * 0.58, width: h * 0.66, height: h * 1.16)), with: .color(Color(hex: "#174A0F")))
            context.fill(Path(ellipseIn: CGRect(x: x - h * 0.20 + 6, y: baseY - trunkH - h * 0.40 + 5, width: h * 0.46, height: h * 0.82)), with: .color(Color(hex: "#0F3009")))
        }
    }

    private static func drawFloor(in context: inout GraphicsContext) {
        context.fill(Path(CGRect(x: 0, y: hchFloorY - 12, width: hchW, height: 92)), with: .linearGradient(
            Gradient(colors: [Color(hex: "#3A7BC8"), Color(hex: "#2A5BA8")]),
            startPoint: CGPoint(x: 0, y: hchFloorY - 12),
            endPoint: CGPoint(x: 0, y: hchFloorY + 64)
        ))

        var baseline = Path()
        baseline.move(to: CGPoint(x: 0, y: hchFloorY - 12))
        baseline.addLine(to: CGPoint(x: hchW, y: hchFloorY - 12))
        context.stroke(baseline, with: .color(.black.opacity(0.35)), lineWidth: 3)

        context.fill(Path(CGRect(x: 210, y: hchFloorY - 12, width: hchHoopX + 12 - 210, height: 60)), with: .color(Color.yellow.opacity(0.62)))

        var paint = Path()
        paint.move(to: CGPoint(x: 210, y: hchFloorY - 12))
        paint.addLine(to: CGPoint(x: hchHoopX + 12, y: hchFloorY - 12))
        paint.move(to: CGPoint(x: 210, y: hchFloorY - 12))
        paint.addLine(to: CGPoint(x: 210, y: hchFloorY + 30))
        paint.move(to: CGPoint(x: hchHoopX + 12, y: hchFloorY - 12))
        paint.addLine(to: CGPoint(x: hchHoopX + 12, y: hchFloorY + 40))
        context.stroke(paint, with: .color(.white), lineWidth: 2.5)

        var arc = Path()
        arc.addArc(center: CGPoint(x: hchHoopX + 12, y: hchFloorY - 12), radius: hchRange3, startAngle: .radians(.pi * 0.52), endAngle: .radians(.pi), clockwise: false)
        context.stroke(arc, with: .color(.white), lineWidth: 2.5)
    }

    private static func drawHoop(in context: inout GraphicsContext) {
        let bx = hchHoopX + 14
        context.fill(Path(CGRect(x: bx + 2, y: hchRimY - 2, width: 5, height: hchFloorY - hchRimY + 8)), with: .color(Color.gray))
        context.fill(Path(roundedRect: CGRect(x: bx, y: hchRimY - 62, width: 13, height: 58), cornerRadius: 2), with: .color(.white.opacity(0.93)))

        var support = Path()
        support.move(to: CGPoint(x: bx + 2, y: hchRimY - 4))
        support.addLine(to: CGPoint(x: hchHoopX, y: hchRimY))
        context.stroke(support, with: .color(.gray), lineWidth: 2)

        var rim = Path()
        rim.move(to: CGPoint(x: bx, y: hchRimY))
        rim.addLine(to: CGPoint(x: hchHoopX - hchRimR, y: hchRimY))
        rim.addEllipse(in: CGRect(x: hchHoopX - hchRimR, y: hchRimY - hchRimR * 0.3, width: hchRimR * 2, height: hchRimR * 0.6))
        context.stroke(rim, with: .color(Color(hex: "#FF6600")), lineWidth: 4)

        for i in 0...8 {
            let a = CGFloat(i) / 8 * .pi * 2
            var net = Path()
            net.move(to: CGPoint(x: hchHoopX + cos(a) * hchRimR, y: hchRimY + sin(a) * hchRimR * 0.3))
            net.addLine(to: CGPoint(x: hchHoopX + cos(a) * hchRimR * 0.38, y: hchRimY + 22))
            context.stroke(net, with: .color(.white.opacity(0.85)), lineWidth: 1.2)
        }
    }

    private static func drawSprite(char: HalfCourtHero, in context: inout GraphicsContext) {
        let h = char.height
        let w = h * char.spriteAspect
        context.draw(Image(char.spriteAssetName), in: CGRect(x: -w / 2, y: -h, width: w, height: h))
    }

    private static func drawBody(char: HalfCourtHero, in context: inout GraphicsContext) {
        let h = char.height
        context.fill(Path(ellipseIn: CGRect(x: -16, y: -h + 7, width: 32, height: 34)), with: .color(char.skin))

        switch char.hairStyle {
        case .bob:
            context.fill(Path(roundedRect: CGRect(x: -23, y: -h - 3, width: 46, height: 46), cornerRadius: 18), with: .color(char.hair))
        case .long:
            context.fill(Path(roundedRect: CGRect(x: -25, y: -h - 1, width: 50, height: 72), cornerRadius: 18), with: .color(char.hair))
            context.fill(Path(roundedRect: CGRect(x: -24, y: -h - 8, width: 48, height: 18), cornerRadius: 8), with: .color(Color.black))
        case .beanie:
            context.fill(Path(roundedRect: CGRect(x: -20, y: -h - 4, width: 40, height: 22), cornerRadius: 10), with: .color(Color(hex: "#B8B8B8")))
        case .glasses:
            context.fill(Path(ellipseIn: CGRect(x: -20, y: -h + 2, width: 40, height: 30)), with: .color(char.hair))
        }

        context.fill(Path(ellipseIn: CGRect(x: -13, y: -h + 11, width: 26, height: 25)), with: .color(char.skin))
        context.fill(Path(roundedRect: CGRect(x: -24, y: -h + 38, width: 48, height: 64), cornerRadius: 12), with: .color(char.shirt))
        context.fill(Path(roundedRect: CGRect(x: -20, y: -h + 95, width: 40, height: 38), cornerRadius: 9), with: .color(char.pants))

        var arms = Path()
        arms.move(to: CGPoint(x: -23, y: -h + 50))
        arms.addLine(to: CGPoint(x: -36, y: -h + 78))
        arms.move(to: CGPoint(x: 23, y: -h + 50))
        arms.addLine(to: CGPoint(x: 36, y: -h + 78))
        context.stroke(arms, with: .color(char.skin), lineWidth: 8)

        var legs = Path()
        legs.move(to: CGPoint(x: -10, y: -h + 128))
        legs.addLine(to: CGPoint(x: -14, y: -8))
        legs.move(to: CGPoint(x: 10, y: -h + 128))
        legs.addLine(to: CGPoint(x: 14, y: -8))
        context.stroke(legs, with: .color(char.pants.opacity(0.9)), lineWidth: 10)

        context.fill(Path(ellipseIn: CGRect(x: -20, y: -9, width: 22, height: 8)), with: .color(char.shoes))
        context.fill(Path(ellipseIn: CGRect(x: 2, y: -9, width: 22, height: 8)), with: .color(char.shoes))

        if char.hairStyle == .glasses {
            context.stroke(Path(ellipseIn: CGRect(x: -13, y: -h + 17, width: 11, height: 8)), with: .color(.black), lineWidth: 1.5)
            context.stroke(Path(ellipseIn: CGRect(x: 2, y: -h + 17, width: 11, height: 8)), with: .color(.black), lineWidth: 1.5)
        }
    }

    private static func drawBall(at point: CGPoint, radius: CGFloat, in context: inout GraphicsContext) {
        context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(Color(hex: "#D96A1B")))
        context.stroke(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(Color(hex: "#7A2A0C")), lineWidth: 1.5)

        var seam = Path()
        seam.move(to: CGPoint(x: point.x - radius, y: point.y))
        seam.addLine(to: CGPoint(x: point.x + radius, y: point.y))
        seam.move(to: CGPoint(x: point.x, y: point.y - radius))
        seam.addLine(to: CGPoint(x: point.x, y: point.y + radius))
        context.stroke(seam, with: .color(Color(hex: "#7A2A0C").opacity(0.75)), lineWidth: 1)
    }
}

private enum HalfCourtPhase {
    case title
    case characterSelect
    case playing
    case ended
}

private enum HalfCourtDifficulty: String, CaseIterable, Identifiable {
    case easy
    case normal
    case hard

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }

    var greenWindow: (low: CGFloat, high: CGFloat) {
        switch self {
        case .easy: return (hchGreenLow - 14, hchGreenHigh + 14)
        case .normal: return (hchGreenLow, hchGreenHigh)
        case .hard: return (hchGreenLow + 5, hchGreenHigh - 5)
        }
    }

    var chargeRate: CGFloat {
        switch self {
        case .easy: return 1.35
        case .normal: return 1.55
        case .hard: return 1.75
        }
    }

    var perfectAccuracy: CGFloat {
        switch self {
        case .easy: return 1
        case .normal: return 0.95
        case .hard: return 0.92
        }
    }

    var greenAccuracy: CGFloat {
        switch self {
        case .easy: return 0.96
        case .normal: return 0.88
        case .hard: return 0.78
        }
    }

    var lateAccuracy: CGFloat {
        switch self {
        case .easy: return 0.5
        case .normal: return 0.32
        case .hard: return 0.18
        }
    }

    var cpuDriveSpeed: CGFloat {
        switch self {
        case .easy: return 1.65
        case .normal: return 2.2
        case .hard: return 2.8
        }
    }

    var cpuShotMultiplier: CGFloat {
        switch self {
        case .easy: return 0.58
        case .normal: return 1.0
        case .hard: return 1.35
        }
    }

    var cpuStealRate: CGFloat {
        switch self {
        case .easy: return 0.10
        case .normal: return 0.20
        case .hard: return 0.32
        }
    }
}

private enum HalfCourtTeam {
    case home
    case away
}

private enum HalfCourtHeroID: String, CaseIterable, Identifiable {
    case nara
    case ethan
    case brendan
    case will

    var id: String { rawValue }

    var character: HalfCourtHero {
        switch self {
        case .nara:
            return HalfCourtHero(
                name: "NARA",
                fullName: "NARA AVAKIAN",
                role: "VOCALS / GUITAR",
                ability: "3PT SHOOTER",
                hue: Color(hex: "#FF1493"),
                skin: Color(hex: "#FDBCB4"),
                hair: Color(hex: "#1C0A00"),
                shirt: Color(hex: "#222222"),
                pants: Color(hex: "#3366DD"),
                shoes: Color(hex: "#2A2A2A"),
                spriteAssetName: "hch-nara-sprite",
                spriteAspect: 569.0 / 1200.0,
                hairStyle: .bob,
                threeBonus: 0.10,
                stealBonus: 0,
                speed: 1.0,
                height: 175,
                quip: "MONEY"
            )
        case .ethan:
            return HalfCourtHero(
                name: "ETHAN",
                fullName: "ETHAN NASH",
                role: "BASS",
                ability: "LOCKDOWN",
                hue: Color(hex: "#32CD32"),
                skin: Color(hex: "#C68642"),
                hair: Color(hex: "#3D2B1F"),
                shirt: Color(hex: "#32CD32"),
                pants: Color(hex: "#1C1C2E"),
                shoes: .white,
                spriteAssetName: "hch-ethan-sprite",
                spriteAspect: 320.0 / 987.0,
                hairStyle: .long,
                threeBonus: 0,
                stealBonus: 0.20,
                speed: 1.05,
                height: 180,
                quip: "FIRE"
            )
        case .brendan:
            return HalfCourtHero(
                name: "BRENDAN",
                fullName: "BRENDAN JONES",
                role: "DRUMS",
                ability: "PAINT BEAST",
                hue: Color(hex: "#FF6B35"),
                skin: Color(hex: "#FDBCB4"),
                hair: Color(hex: "#CC2200"),
                shirt: Color(hex: "#FF6B35"),
                pants: Color(hex: "#2D5A27"),
                shoes: Color(hex: "#222222"),
                spriteAssetName: "hch-brendan-sprite",
                spriteAspect: 293.0 / 993.0,
                hairStyle: .beanie,
                threeBonus: 0,
                stealBonus: 0,
                speed: 1.0,
                height: 185,
                quip: "BOOM"
            )
        case .will:
            return HalfCourtHero(
                name: "WILL",
                fullName: "WILL FISHER",
                role: "KEYS",
                ability: "DEEP RANGE",
                hue: Color(hex: "#9B59B6"),
                skin: Color(hex: "#8D5524"),
                hair: Color(hex: "#111111"),
                shirt: Color(hex: "#9B59B6"),
                pants: Color(hex: "#2C2C2C"),
                shoes: Color(hex: "#9B59B6"),
                spriteAssetName: "hch-will-sprite",
                spriteAspect: 360.0 / 986.0,
                hairStyle: .glasses,
                threeBonus: 0.08,
                stealBonus: 0,
                speed: 0.95,
                height: 174,
                quip: "PERFECT"
            )
        }
    }
}

private struct HalfCourtHero {
    let name: String
    let fullName: String
    let role: String
    let ability: String
    let hue: Color
    let skin: Color
    let hair: Color
    let shirt: Color
    let pants: Color
    let shoes: Color
    let spriteAssetName: String
    let spriteAspect: CGFloat
    let hairStyle: HairStyle
    let threeBonus: CGFloat
    let stealBonus: CGFloat
    let speed: CGFloat
    let height: CGFloat
    let quip: String

    enum HairStyle {
        case bob
        case long
        case beanie
        case glasses
    }
}

private struct CourtPlayer {
    let id: HalfCourtHeroID
    let team: HalfCourtTeam
    var position: CGPoint
    var facing: CGFloat
    var velocity: CGVector = .zero
    var jump: CGFloat = 0
    var jumpVelocity: CGFloat = 0
    var animation: CourtAnimation = .idle
    var hasBall = false
    var cpuTimer: CGFloat = 0
    var landFrame = 0
    var stealCooldown = 0
    var catchFrame = 0
}

private enum CourtAnimation {
    case idle
    case run
    case jump
    case land
    case shoot
    case celebrate
    case sad
}

private struct HalfCourtBall {
    var position: CGPoint = CGPoint(x: 100, y: hchFloorY - 30)
    var velocity: CGVector = .zero
    var inAir = false
    var carrier: HalfCourtHeroID? = .nara
    var made = false
    var fromX: CGFloat = 100
    var shotTeam: HalfCourtTeam = .home
    var shotBy: HalfCourtHeroID?
    var isPass = false
    var passTarget: HalfCourtHeroID?
}

private struct HalfCourtStats {
    var shots = 0
    var made = 0
    var steals = 0
    var blocks = 0
    var threes = 0
}

private struct HalfCourtCallout: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let color: Color

    static func == (lhs: HalfCourtCallout, rhs: HalfCourtCallout) -> Bool {
        lhs.id == rhs.id
    }
}

private func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
    min(max(value, low), high)
}

private func sign(_ value: CGFloat) -> CGFloat {
    value < 0 ? -1 : 1
}

private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    hypot(a.x - b.x, a.y - b.y)
}
