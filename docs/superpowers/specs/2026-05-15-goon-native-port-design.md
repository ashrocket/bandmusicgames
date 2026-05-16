# Goon — For Cutting Grass — Native Swift Port Design

**Status:** Approved 2026-05-15. Ready for `superpowers:writing-plans`.

**Why this exists:** The "For Cutting Grass" entry in the BandMusicGames jukebox currently launches `GameSheetView` → a WebView pointed at `https://forcuttinggrass.goon.bandmusicgames.party`. This design ports the web game to a native SpriteKit implementation so it joins Francis and Lizzy McGuire as a fully native experience on the iOS app.

## Locked decisions

| Question | Decision |
|---|---|
| Scope | **Full faithful 5-level port** — all hazards, save state, level select |
| Rendering | **SpriteKit** wrapped in `SpriteView`, embedded in a SwiftUI host (new pattern in this codebase; Francis/Lizzy use SwiftUI Canvas) |
| Visuals | **Full sprite-art overhaul** — pixel-art atlases, programmatic shape-node fallback while art lands |
| Art source | AI-generated + user curation; ChatGPT (DALL-E 3 / gpt-image-1) is the default generation path, codex CLI as fallback |
| Architecture | **Single SKScene with phase enum** (`GoonGameScene`) — matches Francis/Lizzy convention of one view + phase state |
| Replay after winning | Tapping REPLAY from `.win` **wipes both `goon_level` and `goon_won`** — fresh shot at "first win" each playthrough |
| Hazard spawning | **Random per level start** (web parity) — re-randomized each retry |
| Input | SwiftUI overlay above the SpriteView: joystick + dig button (when level has stumps) + close button + shake-to-back |
| Audio | **All procedural** via AVAudioEngine (no .wav assets). Mower drone is continuous sawtooth+distortion+lowpass; one-shots are envelope-synthesized. Spotify track plays as a third "best effort" layer like Francis |
| Save state | UserDefaults (`goon_level`, `goon_won`) — no iCloud, no server |
| Mower sprite strategy | Single rotating chassis (`zRotation`) + blade overlay + wheel overlay — no separate N/E/S/W sheets |
| Spotify OAuth UI overflow | Out of scope — separately fixed via Spotify Developer Dashboard rename to "Band Music Games Party" |

## Section 1 — Architecture overview

**File layout** under `bandmusicgames/ios/BandMusicGames/`:

```
Views/Games/Goon/
  GoonGameView.swift              # SwiftUI host: SpriteView + overlays + close button
  GoonGameScene.swift             # Single SKScene with phase state machine
  GoonLevels.swift                # Swift port of the JS LEVELS array; config types
  GoonInputController.swift       # Joystick + dig button state; shared with SwiftUI overlay
  GoonRenderer.swift              # Sprite node setup, animations, tile drawing
  GoonHazards.swift               # Cricket hopping + skunk wandering AI
  GoonAudio.swift                 # Procedural mower drone + one-shot SFX via AVAudioEngine
Resources/Sprites/Goon/           # Sprite atlases (see Section 3)
```

**Integration with the existing `ContentView` `NativeGame` enum** — three edits:

1. `NativeGame` enum gains `.goon` case
2. `nativeGame(for:)` returns `.goon` when `song.id == "goon"`
3. `fullScreenCover` switch gains `case .goon: GoonGameView().environmentObject(auth)`

That's the entire surface-area change to existing files. Everything else is in `Views/Games/Goon/`.

**SwiftUI host structure** (`GoonGameView.swift`):

```swift
ZStack {
    Color(hex: "#0a1a0a").ignoresSafeArea()
    SpriteView(scene: scene, options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes])
        .ignoresSafeArea()
    GoonControlOverlay(input: scene.input)
    GoonHUDOverlay(state: scene.state)
    phaseOverlay(for: scene.phase)            // title/levelComplete/gameOver/win cards
    closeButton                                // top-right X
}
.onAppear { /* start Spotify best-effort, scene starts in .title */ }
.onDisappear { scene.stop() }                 // tears down audio + motion
```

## Section 2 — Data model & phase state machine

```swift
struct GoonLevelConfig {
    let n: Int
    let title: String              // "LEVEL 1"
    let sub: String                // "THE HOUSE NEXT DOOR"
    let desc: String
    let gasMax: CGFloat            // 600 → 140 across levels 1–5
    let gasDrain: CGFloat          // 0.10 → 0.25 per 16.67ms tick
    let cans: Int
    let stumps: Int
    let crickets: Int
    let skunks: Int
    let cricketMs: Int             // hop interval, in ms
    let win: CGFloat               // 0.80 → 0.90 cut-percentage threshold
}

enum GoonLevels {
    static let all: [GoonLevelConfig] = [ /* 5 entries, copied 1:1 from forcuttinggrass/js/game.js LEVELS */ ]
}

enum GoonTile: UInt8 { case tall, cut, stump, house, garden }
typealias GoonGrid = ContiguousArray<GoonTile>   // 25*15 = 375 cells, flat for cache locality

enum GoonPhase { case title, playing, levelComplete, gameOver, win }
```

**Runtime entities** (owned by `GoonGameScene`):

```swift
struct GoonMower    { var position: CGPoint; var velocity: CGVector; var facing: CGFloat; var lowGas: Bool }
struct GoonGasCan   { let id = UUID(); var position: CGPoint; var collected = false }
struct GoonStump    { let id = UUID(); var position: CGPoint; var progress: CGFloat; var dug: Bool }
struct GoonCricket  { let id = UUID(); var position: CGPoint; var velocity: CGVector; var nextHopAt: TimeInterval }
struct GoonSkunk    { let id = UUID(); var position: CGPoint; var velocity: CGVector; var alarm: CGFloat }
```

Updates run in `update(_:)` (SpriteKit's per-frame callback). Collisions are manual tile-grid lookups — no `SKPhysicsBody`, matching the web's Phaser-style simulation.

**Phase transitions:**

```
.title         → tap PLAY         → .playing
.playing       → cutPct ≥ win     → .levelComplete   (save level, increment score)
.playing       → gas ≤ 0          → .gameOver        (cricket hits do NOT cause game over — they only deduct 30 gas)
.levelComplete → tap NEXT (1–4)   → .playing (next level)
.levelComplete → tap FINISH (L5)  → .win
.gameOver      → tap RETRY        → .playing (same level)
.gameOver      → tap MENU         → .title
.win           → tap REPLAY       → .title (resets goon_level=1, goon_won=false)
```

**Persistent state** (UserDefaults, mirrors web cookies):

| Key | Type | Mirrors | Notes |
|---|---|---|---|
| `goon_level` | Int | `fcg_level` | Highest unlocked level (1–5). Loaded in `didMove`, written on level-complete + on .win reset |
| `goon_won` | Bool | `fcg_won` | True after L5 complete. Reset by REPLAY from .win |

**Tile-grid generation** at level start: house footprint, garden beds, gas can positions, stump positions are ported from `forcuttinggrass/js/game.js` placement logic. Cricket/skunk positions are randomized within bounds at each level start (re-randomized on retry).

## Section 3 — Sprite assets & generation pipeline

**Asset organization:**

```
Resources/Sprites/Goon/
  PROMPTS.md                   # versioned prompt catalog (one entry per asset)
  raw/                         # generated candidates (gitignored — pick from these, then move)
  mower.atlas/
    mower-body.png             # 56x56, rotating chassis, transparent bg
    mower-blade-{1..4}.png     # 4-frame blade-spin loop
    mower-wheels-{1..3}.png    # 3-frame wheel rotation
  cricket.atlas/
    cricket-idle.png           # 16x16
    cricket-hop-{1..4}.png
  skunk.atlas/
    skunk-walk-{1..4}.png      # 24x24
    skunk-alarmed.png
  stump.atlas/
    stump-full.png             # 32x32 un-dug
    stump-half.png             # mid-dig
    stump-hole.png             # post-dig
  tiles.atlas/
    tile-tall-{1..3}.png       # 32x32 grass variants
    tile-cut-{1..3}.png        # mowed variants
    tile-transition.png        # mid-cut frame
    tile-house-roof.png
    tile-house-wall.png
    tile-house-corner.png
    tile-garden-{1..3}.png
  gas-can.png                  # 32x32, single sprite (no atlas)
  fx.atlas/                    # particle textures
    clipping.png               # 4x4 grass clipping
    dust.png                   # 8x8 dig puff
    spark.png                  # 8x8 gas pickup glow
  ui/
    goon-title-logo.png
    goon-gameover.png
    goon-win-card.png
```

**Total: ~40 PNGs + 3 UI images.**

**Canonical style prompt prefix** (every generation uses this, plus an asset-specific suffix):

> 2003-era chunky pixel art, top-down 3/4 view, no anti-aliasing, saturated retro colors (greens #2d7a2d / #45b045 / #8bc44a, mower yellow #ffcc00, stripe orange #ff8800, gas can red #dd2222), transparent background, sharp pixel edges, sprite-sheet style for arcade lawn-mowing game

**Generation workflow:**

1. Implementation plan creates `Resources/Sprites/Goon/PROMPTS.md` with one entry per asset (size, frame description, suffix prompt).
2. User pastes prompts into ChatGPT (DALL-E 3 / gpt-image-1), downloads variants into `Resources/Sprites/Goon/raw/`.
3. User curates: pick best variant per asset, move to final atlas folder with canonical name.
4. Codex CLI is the fallback if ChatGPT path is unavailable.

**Placeholder strategy:** `GoonRenderer.sprite(named:) -> SKNode` tries `SKTextureAtlas` first, falls back to a colored `SKShapeNode` matching the web palette. The game is fully playable day 1 with shapes; each art swap is a no-code-change improvement.

**Particle effects** stay programmatic via `SKEmitterNode` configured with `fx.atlas` textures + color ramps. Grass clipping burst on cut, dust puff on dig, gold spark on can pickup.

## Section 4 — Input & audio

**Input controller** — shared between SwiftUI overlay and the SKScene:

```swift
@MainActor
final class GoonInputController: ObservableObject {
    @Published var joystick: CGVector = .zero    // unit vector, magnitude 0–1
    @Published var digging: Bool = false
    @Published var canDig: Bool = false           // scene flips this when current level has stumps
}
```

**Joystick** (bottom-left, 130×130 circular pad):
- Touch anywhere inside → ring + knob appear at touch point
- Drag → knob follows cursor up to 40pt cap (clamps beyond)
- Release → joystick = `.zero`
- Semantics match the web's `index.html` joystick exactly

**Dig button** (bottom-right, 130×130, only rendered when `input.canDig`):
- Press-and-hold via `DragGesture(minimumDistance: 0)` for accurate press/release
- Yellow "DIG" label, brighter when pressed

**Close button** (top-right X): calls `dismiss()` and pauses Spotify on the way out (mirrors Francis).

**Shake-to-back**: SwiftUI host wraps a `UIViewControllerRepresentable` that overrides `motionEnded(_:with:)`; on `.motionShake`, triggers `dismiss()`. Matches the web's DeviceMotion behavior.

**Audio architecture** (`GoonAudio.swift`):

```swift
@MainActor
final class GoonAudio {
    func startMower(baseHz: Float = 88)        // continuous sawtooth + WaveShaper distortion + lowpass
    func setMowerPitch(velocity: CGFloat)      // 88 Hz idle → 140 Hz full throttle
    func stopMower()

    // One-shot envelopes via AVAudioSourceNode
    func playCut()
    func playPickup()
    func playDig()
    func playCricketHit()
    func playLevelComplete()
    func playGameOver()

    func stop()                                 // tears down engine on .onDisappear
}
```

**Audio session category:** `.ambient` — mixes with Spotify so the band track keeps playing under our procedural SFX.

**Spotify integration:** identical pattern to Francis — `GoonGameView.onAppear` calls `auth.playTrack("spotify:track:6EJAb3oTjDFwrt1dpIJPbr")` if `auth.accessToken != nil`. No-op if not authed (game uses its own procedural audio). Paused on dismiss via `auth.pausePlayback()`.

## Section 5 — Phase UI, testing, shipping

**Phase-specific SwiftUI overlays** (all rendered above the `SpriteView` based on `scene.phase`):

| Phase | Overlay |
|---|---|
| `.title` | `GoonTitleOverlay` — pixel-art logo, level picker (taps unlock 1..goon_level), big PLAY button |
| `.playing` | `GoonHUDOverlay` (gas bar + %, cut %, goal %, score, anchored top) + `GoonControlOverlay` (joystick + dig) |
| `.levelComplete` | `GoonLevelCompleteCard` — score breakdown, NEXT LEVEL (or FINISH on L5) |
| `.gameOver` | `GoonGameOverCard` — "OUT OF GAS" stamp, RETRY + MENU buttons |
| `.win` | `GoonWinCard` — celebration art, single REPLAY button (resets progress) |

**Project file regeneration:** `bandmusicgames/ios/project.yml` is XcodeGen-managed with `sources: [path: BandMusicGames]` (recursive). New files in `Views/Games/Goon/` and `Resources/Sprites/Goon/` are picked up automatically on next `xcodegen generate`. Implementation plan includes the `xcodegen generate` step before rebuild.

**Testing strategy:**

| Layer | Approach |
|---|---|
| Level configs | Unit test: `GoonLevels.all` matches the JS `LEVELS` array values 1:1 |
| Phase state machine | Unit tests on transitions (`startLevel`, `onGasOut`, `onWinThresholdReached`) |
| Grid logic | Unit tests on tile placement, win-percentage calculation, collision queries |
| Hazard AI | Unit tests on cricket hop trajectories + skunk wander (seedable RNG for determinism) |
| Rendering | Manual on device — no UI snapshot tests |
| Audio | Manual — verify mower pitches with velocity, SFX fire on events |
| Spotify | Manual — track starts/pauses correctly with sheet open/close |
| End-to-end | Manual playthrough levels 1→5 on Eine von Zwei; verify save state across app restarts |

Unit tests live in `BandMusicGamesTests/Goon/`.

**Shipping checklist:**

1. All 5 levels playable end-to-end with placeholder shapes
2. Save state survives app kill (level + won state)
3. Spotify plays in `.playing`, pauses on dismiss, no-ops if no auth
4. Joystick + dig + shake-to-back work on Eine von Zwei
5. Procedural audio sounds right (no AVAudioEngine warnings, no crashes)
6. `xcodebuild` succeeds for the iPhone 17 destination with signing
7. Real sprites for at least: mower, cricket, skunk, gas can, stumps, grass tiles (other UI may ship with placeholders)
8. App installed via `xcrun devicectl device install app` on Eine von Zwei
9. ContentView NativeGame enum updated; Goon launches one-tap (no Spotify gate, like Francis)

**Out of scope:**

- Leaderboards / score persistence beyond per-session
- iCloud sync (UserDefaults only)
- Multiplayer / co-op
- Apple Watch companion
- iPad-specific layout (works as scaled iPhone)
- macOS / Mac Catalyst
- Haptics tuning (reuse existing `HapticManager`)
- Background-running mower audio when app is backgrounded

**Known risks:**

1. **AVAudioEngine + Spotify mixing** — never validated in this codebase. Spike this early in implementation; if AVAudioSession category conflicts cut Spotify, fall back to silent procedural SFX (Spotify owns audio).
2. **Sprite generation timeline** — placeholder shapes guarantee day-1 playability, but real art is what makes the chosen "full sprite-art overhaul" scope. Art lands incrementally.
3. **xcodegen presence** — confirm `which xcodegen` returns a path; `brew install xcodegen` if not.

## Resume notes / next step

The implementation plan needs to:
1. Confirm `xcodegen` is installed
2. Scaffold all 7 Swift files in `Views/Games/Goon/` (per Section 1 file layout)
3. Wire into `ContentView` (3 edits in `NativeGame` enum, `nativeGame(for:)`, fullScreenCover switch)
4. Run `xcodegen generate` + `xcodebuild` to confirm green
5. Push placeholder build to Eine von Zwei
6. Write `Resources/Sprites/Goon/PROMPTS.md` with ~40 prompts
7. Spike AVAudioEngine + Spotify mixing before committing to procedural SFX
8. Implement game logic, port from `forcuttinggrass/js/game.js`
9. Iteratively swap placeholders for real sprites as they're generated/curated
10. End-to-end manual playthrough on device

Hand off to `superpowers:writing-plans` for the detailed implementation plan.
