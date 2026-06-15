import SwiftUI
import SpriteKit

struct LizzyMcGuireGameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: SpotifyAuthManager
    @StateObject private var scene = HalfCourtHeroScene.make()

    @State private var selectedPlayer: HalfCourtHeroID = .nara
    @State private var selectedTeammate: HalfCourtHeroID? = nil
    @State private var selectStep = 1
    @State private var scoutedHero: HalfCourtHeroID?
    @State private var difficulty: HalfCourtDifficulty = .normal
    @State private var hudOpacity: Double = 0
    @State private var zoomLevel: CGFloat = 1.0
    @State private var isFrozen: Bool = false
    @State private var panOffset: CGSize = .zero
    @State private var dragBase: CGSize = .zero
    @State private var overlayPinchBase: CGFloat = 1.0
    @State private var beatSynced: Bool = false

    var body: some View {
        ZStack {
            Color(hex: "#1a0a3e").ignoresSafeArea()
            
            SpriteView(
                scene: scene,
                options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes]
            )
            .ignoresSafeArea()
            .scaleEffect(zoomLevel, anchor: .center)
            .offset(x: panOffset.width, y: panOffset.height)
            .gesture(
                MagnificationGesture(minimumScaleDelta: 0.03)
                    .onChanged { value in
                        guard scene.phase == .playing else { return }
                        var tx = Transaction()
                        tx.disablesAnimations = true
                        withTransaction(tx) {
                            zoomLevel = max(1.0, min(5.0, value))
                        }
                        if !isFrozen {
                            isFrozen = true
                            scene.isPaused = true
                            Task { await auth.pausePlayback() }
                        }
                    }
                    .onEnded { value in
                        guard scene.phase == .playing else { return }
                        zoomLevel = max(1.0, min(5.0, value))
                    }
            )

            if scene.phase == .title {
                titleOverlay
            } else if scene.phase == .characterSelect {
                characterSelectOverlay
            }

            if let hero = scoutedHero, scene.phase == .characterSelect {
                HeroScoutingOverlay(
                    hero: hero,
                    selectStep: selectStep,
                    isBallHandler: selectStep == 2 && hero == selectedPlayer,
                    onPick: {
                        HapticManager.selection()
                        if selectStep == 1 {
                            selectedPlayer = hero
                            selectedTeammate = HalfCourtHeroID.allCases.first { $0 != hero }
                            selectStep = 2
                        } else {
                            selectedTeammate = hero
                        }
                        scoutedHero = nil
                    },
                    onClose: { scoutedHero = nil }
                )
                .id(hero)
                .zIndex(10)
            }

            if scene.phase == .playing {
                controlsHUD.opacity(hudOpacity)
            }

            if isFrozen {
                freezeOverlay
            }

            closeButton
        }
        .onChange(of: scene.phase) { newPhase in
            if newPhase == .playing {
                // Restart track on first game of a series so the beat clock
                // aligns with the audio rather than drifting from title-screen time.
                if !beatSynced, auth.canAttemptPlayback {
                    beatSynced = true
                    Task {
                        await auth.playTrack("spotify:track:7kNqAfUxLmrETcwvBTQCkg")
                        // Re-anchor after the 204 confirms, so beatAnchor latches to
                        // when audio actually (re)started, not when the call fired.
                        scene.realignBeatAnchor()
                    }
                }
                withAnimation(.easeIn(duration: 0.5)) { hudOpacity = 1.0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    withAnimation(.easeInOut(duration: 2.5)) { hudOpacity = 0.18 }
                }
            } else {
                hudOpacity = 0
                if newPhase == .characterSelect { beatSynced = false }
                if isFrozen {
                    isFrozen = false
                    zoomLevel = 1.0
                    panOffset = .zero
                    dragBase = .zero
                    scene.isPaused = false
                }
            }
        }
        .onAppear {
            scene.onDismiss = { dismiss() }
            let uri = "spotify:track:7kNqAfUxLmrETcwvBTQCkg"
            if auth.canAttemptPlayback, !(auth.isPlaying && auth.currentTrackUri == uri) {
                Task { await auth.playTrack(uri) }
            }
        }
        .onDisappear {
            Task { await auth.pausePlayback() }
        }
        .spotifyErrorBanner()
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
            let compact = geo.size.height < 780
            let titleSize: CGFloat = compact ? 42 : 50

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: compact ? 5 : 8) {
                    Text("NARA'S ROOM")
                        .font(.system(size: compact ? 12 : 13, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(Color(hex: "#FFD700"))

                    VStack(spacing: compact ? -5 : -2) {
                        Text("HALF")
                        Text("COURT")
                        Text("HERO").foregroundColor(.white)
                    }
                    .font(.system(size: titleSize, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#FF1493"))
                    .multilineTextAlignment(.center)
                    .shadow(color: Color(hex: "#FF1493").opacity(0.5), radius: 12)
                }

                Spacer()

                // Difficulty selector
                HStack(spacing: 6) {
                    ForEach(HalfCourtDifficulty.allCases) { d in
                        let sel = d == difficulty
                        Button {
                            HapticManager.selection()
                            difficulty = d
                        } label: {
                            Text(d.label)
                                .font(.system(size: compact ? 10 : 11, weight: .black, design: .monospaced))
                                .tracking(1.5)
                                .foregroundColor(sel ? .black : .white.opacity(0.62))
                                .padding(.vertical, compact ? 7 : 8)
                                .frame(maxWidth: .infinity)
                                .background(sel ? Color(hex: "#FFD700") : Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal, compact ? 28 : 34)
                .padding(.bottom, 10)

                Button {
                    HapticManager.impact(.medium)
                    scene.startSeries()
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

                Text("LEFT HALF: DRAG TO MOVE · RIGHT HALF: TAP TO CHARGE SHOT\nSWIPE RIGHT → STEAL · SWIPE LEFT ← PASS TO TEAMMATE\n3 ON-BEAT SHOTS = ON FIRE 🔥 · FIRST TO 11 · BEST OF 5")
                    .font(.system(size: compact ? 9 : 10, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 14)
                    .padding(.horizontal, 24)

                Text("BANDMUSICGAMES.PARTY")
                    .font(.system(size: compact ? 9 : 11, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.42))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 10)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 20)
            }
            .frame(maxWidth: 430)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#1a0a3e").opacity(0.85))
        }
    }

    private var characterSelectOverlay: some View {
        GeometryReader { geo in
            let topInset = geo.safeAreaInsets.top
            let bottomInset = geo.safeAreaInsets.bottom
            let compact = geo.size.height < 780

            VStack(spacing: 0) {
                // Header
                ZStack(alignment: .leading) {
                    if selectStep == 2 {
                        Button {
                            HapticManager.selection()
                            selectedTeammate = nil
                            selectStep = 1
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: compact ? 11 : 13, weight: .black))
                                Text("BACK")
                                    .font(.system(size: compact ? 9 : 11, weight: .black, design: .monospaced))
                                    .tracking(1)
                            }
                            .foregroundColor(.white.opacity(0.52))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, compact ? 16 : 22)
                    }
                    VStack(spacing: compact ? 3 : 5) {
                        Text(selectStep == 1 ? "MEET THE TEAM" : "PICK TEAMMATE")
                            .font(.system(size: compact ? 16 : 19, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(selectStep == 1 ? Color(hex: "#FFD700") : selectedPlayer.character.hue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Text(selectStep == 1 ? "Choose your ball handler" : "\(selectedPlayer.character.fullName) is in")
                            .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                        Text("HOLD A CARD FOR SCOUTING REPORT")
                            .font(.system(size: compact ? 7 : 8, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.top, 3)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, topInset + (compact ? 14 : 20))
                .padding(.bottom, compact ? 12 : 16)

                // Character grid
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                    spacing: compact ? 10 : 14
                ) {
                    ForEach(HalfCourtHeroID.allCases) { hero in
                        let disabled = selectStep == 2 && hero == selectedPlayer
                        let isSelected = hero == selectedPlayer || hero == selectedTeammate
                        VStack(spacing: compact ? 6 : 8) {
                            HalfCourtHeroBadge(hero: hero, selected: isSelected, dimmed: disabled)
                                .frame(height: compact ? 90 : 110)
                            Text(hero.character.name)
                                .font(.system(size: compact ? 12 : 14, weight: .black, design: .monospaced))
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
                        .padding(compact ? 10 : 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? hero.character.hue.opacity(0.17) : Color.black.opacity(0.28))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? hero.character.hue : hero.character.hue.opacity(0.35), lineWidth: isSelected ? 2.5 : 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            guard !disabled else { return }
                            HapticManager.selection()
                            if selectStep == 1 {
                                selectedPlayer = hero
                                selectedTeammate = HalfCourtHeroID.allCases.first { $0 != hero }
                                selectStep = 2
                            } else {
                                selectedTeammate = hero
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.4) {
                            HapticManager.impact(.medium)
                            scoutedHero = hero
                        }
                    }
                }
                .padding(.horizontal, compact ? 16 : 22)

                Spacer(minLength: 12)

                // Play button
                Button {
                    HapticManager.impact(.heavy)
                    scene.startGame(playerID: selectedPlayer, teammateID: selectedTeammate ?? .ethan, difficulty: difficulty)
                } label: {
                    Text("PLAY")
                        .font(.system(size: compact ? 16 : 18, weight: .black, design: .monospaced))
                        .tracking(4)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, compact ? 12 : 14)
                        .background(Color(hex: "#FFD700"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .opacity(selectedTeammate != nil ? 1 : 0.35)
                .disabled(selectedTeammate == nil)
                .padding(.horizontal, compact ? 28 : 34)
                .padding(.bottom, bottomInset + (compact ? 14 : 20))
            }
            .frame(maxWidth: 430)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#1a0a3e").opacity(0.95))
        }
    }

    private func resumeFromFreeze() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            zoomLevel = 1.0
            isFrozen = false
        }
        panOffset = .zero
        dragBase = .zero
        scene.isPaused = false
        if auth.canAttemptPlayback {
            Task { await auth.resumePlayback() }
        }
    }

    private var freezeOverlay: some View {
        ZStack {
            Color.black.opacity(0.48).ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.white.opacity(0.75))

                Text("DOUBLE-TAP TO RESUME")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .tracking(3.5)
                    .foregroundColor(.white)

                Text("zoom · \(String(format: "%.1f", zoomLevel))×  ·  drag to pan")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            resumeFromFreeze()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    panOffset = CGSize(
                        width: dragBase.width + value.translation.width,
                        height: dragBase.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    dragBase = panOffset
                }
        )
        .simultaneousGesture(
            MagnificationGesture(minimumScaleDelta: 0.03)
                .onChanged { value in
                    let delta = value / overlayPinchBase
                    overlayPinchBase = value
                    var tx = Transaction()
                    tx.disablesAnimations = true
                    withTransaction(tx) {
                        zoomLevel = max(1.0, min(5.0, zoomLevel * delta))
                    }
                }
                .onEnded { _ in
                    overlayPinchBase = 1.0
                }
        )
    }

    private var controlsHUD: some View {
        VStack {
            Spacer()
            HStack(alignment: .center, spacing: 0) {
                // Left thumb: movement
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(Color(hex: "#FFD700").opacity(0.9))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LEFT THUMB")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundColor(.white.opacity(0.45))
                        Text("DRAG TO MOVE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: 46)
                    .padding(.horizontal, 8)

                // Right thumb: actions
                VStack(alignment: .leading, spacing: 4) {
                    Text("RIGHT THUMB")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.45))
                    HStack(spacing: 12) {
                        rightAction(gesture: "TAP", label: "SHOOT")
                        rightAction(gesture: "TAP", label: "BLOCK")
                        rightAction(gesture: "→", label: "STEAL")
                        rightAction(gesture: "←", label: "PASS")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .background(Color(hex: "#0a051e").opacity(0.82))
            .overlay(Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1), alignment: .top)
        }
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func rightAction(gesture: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(gesture)
                .font(.system(size: 12, weight: .black))
                .foregroundColor(Color(hex: "#FFD700"))
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.75))
        }
    }
}

private struct HalfCourtHeroBadge: View {
    let hero: HalfCourtHeroID
    let selected: Bool
    let dimmed: Bool

    var body: some View {
        Image("hch_\(hero.rawValue)")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .opacity(dimmed ? 0.35 : 1)
            .shadow(color: selected ? hero.character.hue.opacity(0.55) : .clear, radius: 10)
            .overlay(alignment: .bottom) {
                if selected {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hero.character.hue)
                        .frame(height: 3)
                        .padding(.horizontal, 12)
                }
            }
    }
}

// MARK: - Long-press flip scouting report (ported from lizzie-direct-launch ad132c3)

private struct HeroScoutingOverlay: View {
    let hero: HalfCourtHeroID
    let selectStep: Int
    let isBallHandler: Bool
    let onPick: () -> Void
    let onClose: () -> Void

    @State private var appeared = false

    var body: some View {
        let ch = hero.character
        ZStack {
            Color.black.opacity(appeared ? 0.66 : 0)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            detailCard(ch)
                .rotation3DEffect(.degrees(appeared ? 0 : -82),
                                  axis: (x: 0, y: 1, z: 0), perspective: 0.55)
                .scaleEffect(appeared ? 1 : 0.82)
                .opacity(appeared ? 1 : 0)
                .padding(.horizontal, 26)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true }
        }
        .accessibilityAddTraits(.isModal)
    }

    private var pickLabel: String {
        if isBallHandler { return "ALREADY ON TEAM" }
        return selectStep == 1 ? "PICK AS BALL HANDLER" : "ADD AS TEAMMATE"
    }

    private func detailCard(_ ch: HalfCourtHero) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                HalfCourtHeroBadge(hero: hero, selected: true, dimmed: false)
                    .frame(width: 78, height: 100)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ch.name)
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundColor(ch.hue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(ch.fullName)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(ch.role)  ·  \(Int(ch.height))CM")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 0)
            }

            VStack(spacing: 7) {
                StatBar(label: "SHOOTING", value: min(1, 0.5 + ch.threeBonus * 4 + ch.closeBonus * 1.5), hue: ch.hue)
                StatBar(label: "DEFENSE", value: min(1, 0.42 + ch.stealBonus * 2.6), hue: ch.hue)
                StatBar(label: "SPEED", value: min(1, ch.speed * 0.78), hue: ch.hue)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("ABILITY · \(ch.ability)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(ch.hue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(ch.abilityBlurb)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                Label("3 ON-BEAT SHOTS IN A ROW = ON FIRE 🔥", systemImage: "bolt.fill")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(ch.hue.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(ch.hue.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ch.hue.opacity(0.4), lineWidth: 1))

            Button(action: onPick) {
                Text(pickLabel)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(isBallHandler ? .white.opacity(0.4) : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isBallHandler ? Color.white.opacity(0.07) : ch.hue)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .disabled(isBallHandler)
        }
        .padding(20)
        .frame(maxWidth: 360)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(hex: "#160833")))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(ch.hue, lineWidth: 2))
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, Color.black.opacity(0.5))
            }
            .padding(10)
        }
        .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
    }
}

private struct StatBar: View {
    let label: String
    let value: CGFloat
    let hue: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 74, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(hue)
                        .frame(width: max(6, geo.size.width * min(1, max(0, value))))
                }
            }
            .frame(height: 7)
        }
    }
}
