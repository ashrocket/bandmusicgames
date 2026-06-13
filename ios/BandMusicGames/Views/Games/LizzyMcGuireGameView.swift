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

    var body: some View {
        ZStack {
            Color(hex: "#1a0a3e").ignoresSafeArea()
            
            SpriteView(
                scene: scene,
                options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes]
            )
            .ignoresSafeArea()

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
                            selectedTeammate = nil
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

            closeButton
        }
        .onAppear {
            scene.onDismiss = { dismiss() }
            let uri = "spotify:track:7kNqAfUxLmrETcwvBTQCkg"
            if auth.accessToken != nil, !(auth.isPlaying && auth.currentTrackUri == uri) {
                Task { await auth.playTrack(uri) }
            }
        }
        .onDisappear {
            Task { await auth.pausePlayback() }
        }
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

                Text("DRAG TO MOVE · HOLD SHOOT, RELEASE WHEN THE SKY GOES GREEN\n3 ON-BEAT SHOTS IN A ROW = ON FIRE 🔥")
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
                                selectedTeammate = nil
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
                    scene.startGame(playerID: selectedPlayer, teammateID: selectedTeammate ?? .ethan)
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
