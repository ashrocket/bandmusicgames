import SwiftUI
import SpriteKit

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
            .background(Color(hex: "#1a0a3e").opacity(0.85))
        }
    }

    private var characterSelectOverlay: some View {
        GeometryReader { geo in
            let usableHeight = geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom
            let compact = usableHeight < 760
            let topInset = max(geo.safeAreaInsets.top + 18, compact ? 24 : 48)
            let bottomInset = max(geo.safeAreaInsets.bottom + 18, compact ? 18 : 34)
            let gridSpacing: CGFloat = compact ? 8 : 12
            let cardHeight = max(compact ? 142 : 168, min(compact ? 168 : 196, (usableHeight - topInset - bottomInset - 118 - gridSpacing) / 2))
            let badgeHeight = max(compact ? 58 : 70, min(compact ? 76 : 94, cardHeight * 0.5))

            VStack(spacing: compact ? 8 : 14) {
                Spacer()
                    .frame(height: topInset)

                Text(selectStep == 1 ? "MEET THE TEAM" : "PICK TEAMMATE")
                    .font(.system(size: compact ? 15 : 18, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(selectStep == 1 ? Color(hex: "#FFD700") : selectedPlayer.character.hue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text(selectStep == 1 ? "Choose your ball handler" : "\(selectedPlayer.character.fullName) is in")
                    .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: compact ? 8 : 14)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: gridSpacing) {
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
                            VStack(spacing: compact ? 5 : 9) {
                                HalfCourtHeroBadge(hero: hero, selected: isSelected, dimmed: disabled)
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
                                    .fill(isSelected ? hero.character.hue.opacity(0.17) : Color.black.opacity(0.28))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? hero.character.hue : hero.character.hue.opacity(0.35), lineWidth: isSelected ? 2.5 : 1)
                            )
                        }
                        .disabled(disabled)
                    }
                }
                .padding(.horizontal, compact ? 16 : 20)

                Spacer(minLength: compact ? 10 : 16)

                Button {
                    HapticManager.impact(.heavy)
                    scene.startGame(playerID: selectedPlayer, teammateID: selectedTeammate ?? .ethan)
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
                .opacity(selectedTeammate != nil ? 1 : 0.35)
                .disabled(selectedTeammate == nil)
                .padding(.horizontal, compact ? 28 : 32)
                .padding(.bottom, bottomInset)
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
        // Placeholder for badge (could be a SpriteView or Image)
        Image(systemName: "person.fill")
            .font(.system(size: 40))
            .foregroundColor(hero.character.hue)
            .opacity(dimmed ? 0.35 : 1)
            .overlay(
                selected ? Circle().stroke(hero.character.hue, lineWidth: 2).padding(-10) : nil
            )
    }
}
