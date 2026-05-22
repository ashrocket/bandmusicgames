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
        let ch = hero.character
        Canvas { ctx, size in
            let cx = size.width / 2
            let s = size.height / 120  // scale factor

            // Shirt / shoulders
            let shirtRect = CGRect(x: cx - 32*s, y: size.height - 50*s, width: 64*s, height: 58*s)
            ctx.fill(Path(roundedRect: shirtRect, cornerRadius: 14*s), with: .color(ch.shirt))

            // Neck
            ctx.fill(Path(roundedRect: CGRect(x: cx - 7*s, y: size.height - 62*s, width: 14*s, height: 18*s), cornerRadius: 4*s),
                     with: .color(ch.skin))

            // Head
            let headRect = CGRect(x: cx - 20*s, y: size.height - 98*s, width: 40*s, height: 44*s)
            ctx.fill(Path(ellipseIn: headRect), with: .color(ch.skin))

            // Hair (drawn before face features, behind on some styles)
            drawHair(ctx: &ctx, size: size, cx: cx, s: s, ch: ch)

            // Eyes
            let eyeY = size.height - 82*s
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 11*s, y: eyeY, width: 6*s, height: 5*s)), with: .color(.black.opacity(0.85)))
            ctx.fill(Path(ellipseIn: CGRect(x: cx + 5*s, y: eyeY, width: 6*s, height: 5*s)), with: .color(.black.opacity(0.85)))

            // Mouth
            var mouth = Path()
            mouth.move(to: CGPoint(x: cx - 6*s, y: size.height - 68*s))
            mouth.addQuadCurve(to: CGPoint(x: cx + 6*s, y: size.height - 68*s),
                               control: CGPoint(x: cx, y: size.height - 63*s))
            ctx.stroke(mouth, with: .color(.black.opacity(0.5)), lineWidth: 1.5*s)
        }
        .opacity(dimmed ? 0.35 : 1)
        .overlay(alignment: .bottom) {
            if selected {
                RoundedRectangle(cornerRadius: 4)
                    .fill(hero.character.hue)
                    .frame(height: 3)
                    .padding(.horizontal, 12)
            }
        }
    }

    private func drawHair(ctx: inout GraphicsContext, size: CGSize, cx: CGFloat, s: CGFloat, ch: HalfCourtHero) {
        switch ch.hairStyle {
        case .bob:
            let r = CGRect(x: cx - 23*s, y: size.height - 102*s, width: 46*s, height: 50*s)
            ctx.fill(Path(roundedRect: r, cornerRadius: 16*s), with: .color(ch.hair))
        case .long:
            let r = CGRect(x: cx - 25*s, y: size.height - 108*s, width: 50*s, height: 72*s)
            ctx.fill(Path(roundedRect: r, cornerRadius: 16*s), with: .color(ch.hair))
        case .beanie:
            let r = CGRect(x: cx - 21*s, y: size.height - 106*s, width: 42*s, height: 26*s)
            ctx.fill(Path(roundedRect: r, cornerRadius: 10*s), with: .color(.gray))
            // beanie stripe
            let stripe = CGRect(x: cx - 20*s, y: size.height - 83*s, width: 40*s, height: 5*s)
            ctx.fill(Path(roundedRect: stripe, cornerRadius: 2*s), with: .color(.white.opacity(0.35)))
        case .glasses:
            let r = CGRect(x: cx - 20*s, y: size.height - 104*s, width: 40*s, height: 34*s)
            ctx.fill(Path(ellipseIn: r), with: .color(ch.hair))
            // glasses
            var g = Path()
            g.addEllipse(in: CGRect(x: cx - 14*s, y: size.height - 86*s, width: 12*s, height: 9*s))
            g.addEllipse(in: CGRect(x: cx + 2*s, y: size.height - 86*s, width: 12*s, height: 9*s))
            ctx.stroke(g, with: .color(.black.opacity(0.85)), lineWidth: 1.5*s)
        }
    }
}
