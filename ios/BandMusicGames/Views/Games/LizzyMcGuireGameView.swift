import SwiftUI
import SpriteKit

struct LizzyMcGuireGameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: SpotifyAuthManager
    @StateObject private var scene = HalfCourtHeroScene.make()

    @State private var selectedPlayer: HalfCourtHeroID = .nara
    @State private var selectedTeammate: HalfCourtHeroID? = .ethan
    @State private var selectStep = 1

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

            closeButton
        }
        .onAppear {
            scene.onDismiss = { dismiss() }
            if auth.accessToken != nil {
                Task { await auth.playTrack("spotify:track:7kNqAfUxLmrETcwvBTQCkg") }
            }
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
                        Button {
                            HapticManager.selection()
                            if selectStep == 1 {
                                selectedPlayer = hero
                                selectStep = 2
                            } else {
                                selectedTeammate = hero
                            }
                        } label: {
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
                        }
                        .disabled(disabled)
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
