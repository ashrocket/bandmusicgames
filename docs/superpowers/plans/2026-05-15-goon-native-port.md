# Goon — For Cutting Grass — Native Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the "For Cutting Grass" web game from Phaser 3 to a native iOS SpriteKit game embedded in the BandMusicGames jukebox app, with all 5 levels, hazards, save state, and procedural audio.

**Architecture:** Single `SKScene` with a phase enum (`.title / .playing / .levelComplete / .gameOver / .win`) wrapped in a SwiftUI host (`SpriteView`). SwiftUI overlays handle the joystick, dig button, HUD, and phase-specific cards. All game logic is `@MainActor`-isolated on the scene. Audio is fully procedural via `AVAudioEngine`. Sprite assets are AI-generated PNGs in `SKTextureAtlas` folders, with a `GoonRenderer` abstraction that falls back to colored `SKShapeNode` shapes when an atlas is absent (placeholder strategy guarantees day-1 playability).

**Tech Stack:** Swift 5.10, SwiftUI, SpriteKit, AVAudioEngine, AVAudioSourceNode, UserDefaults, XCTest, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-05-15-goon-native-port-design.md`

**Reference web source:** `/Users/ashrocket/ashcode/forcuttinggrass/js/game.js` (1854 lines, Phaser 3).

---

## Phase 1 — Scaffolding

### Task 1: Verify xcodegen and scaffold empty Goon module

**Files:**
- Create: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameView.swift`
- Create: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`
- Modify: `bandmusicgames/ios/BandMusicGames/Views/ContentView.swift`

- [ ] **Step 1: Confirm xcodegen is installed**

Run: `which xcodegen`
Expected: `/opt/homebrew/bin/xcodegen` (or similar path)

If missing: `brew install xcodegen`

- [ ] **Step 2: Create the empty SwiftUI host**

Create `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameView.swift`:

```swift
import SwiftUI
import SpriteKit

struct GoonGameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: SpotifyAuthManager
    @StateObject private var scene = GoonGameScene.make()

    var body: some View {
        ZStack {
            Color(hex: "#0a1a0a").ignoresSafeArea()
            SpriteView(
                scene: scene,
                options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes]
            )
            .ignoresSafeArea()
            closeButton
        }
        .onAppear { scene.activate() }
        .onDisappear { scene.deactivate() }
    }

    private var closeButton: some View {
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
}
```

- [ ] **Step 3: Create the empty SKScene**

Create `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`:

```swift
import SpriteKit

@MainActor
final class GoonGameScene: SKScene, ObservableObject {
    static func make() -> GoonGameScene {
        let scene = GoonGameScene(size: CGSize(width: 800, height: 600))
        scene.scaleMode = .aspectFit
        scene.backgroundColor = SKColor(red: 0.04, green: 0.10, blue: 0.04, alpha: 1)
        return scene
    }

    func activate() {
        // Audio + music will be wired in later tasks
    }

    func deactivate() {
        // Teardown
    }
}
```

- [ ] **Step 4: Wire `.goon` into `ContentView`'s NativeGame enum**

In `ContentView.swift`, find the `NativeGame` enum and the `nativeGame(for:)` function. Modify both:

```swift
private enum NativeGame {
    case francis
    case lizzyMcGuire
    case goon
}

private func nativeGame(for song: Song) -> NativeGame? {
    if song.id == "francis" { return .francis }

    if song.id == "narasroom"
        || song.gameUrl.localizedCaseInsensitiveContains("lizzymcguire")
        || song.title.localizedCaseInsensitiveContains("lizzy") {
        return .lizzyMcGuire
    }

    if song.id == "goon" { return .goon }

    return nil
}
```

Find the `fullScreenCover(item:)` switch and add the `.goon` case:

```swift
.fullScreenCover(item: $launchingSong) { song in
    switch nativeGame(for: song) {
    case .francis:
        FrancisGameView()
            .environmentObject(auth)
    case .lizzyMcGuire:
        LizzyMcGuireGameView()
            .environmentObject(auth)
    case .goon:
        GoonGameView()
            .environmentObject(auth)
    case nil:
        GameSheetView(song: song, spotifyToken: auth.accessToken)
    }
}
```

- [ ] **Step 5: Regenerate Xcode project and build**

Run:
```bash
cd /Users/ashrocket/ashcode/bandmusicgames/ios && xcodegen generate
xcodebuild -project BandMusicGames.xcodeproj -scheme BandMusicGames \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/bmg-derived CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
```

Expected output: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
cd /Users/ashrocket/ashcode/bandmusicgames
git add ios/BandMusicGames/Views/Games/Goon/GoonGameView.swift \
        ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift \
        ios/BandMusicGames/Views/ContentView.swift \
        ios/project.yml ios/BandMusicGames.xcodeproj
git commit -m "feat(goon): scaffold native game module + ContentView wiring"
```

---

## Phase 2 — Level data & grid

### Task 2: Level configs with parity tests

**Files:**
- Create: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonLevels.swift`
- Create: `bandmusicgames/ios/BandMusicGamesTests/Goon/GoonLevelsTests.swift`

- [ ] **Step 1: Write the failing parity test**

Create `bandmusicgames/ios/BandMusicGamesTests/Goon/GoonLevelsTests.swift`:

```swift
import XCTest
@testable import BandMusicGames

final class GoonLevelsTests: XCTestCase {
    func test_allLevels_matchWebGame() {
        let levels = GoonLevels.all
        XCTAssertEqual(levels.count, 5)

        // Level 1: THE HOUSE NEXT DOOR
        let l1 = levels[0]
        XCTAssertEqual(l1.n, 1)
        XCTAssertEqual(l1.title, "LEVEL 1")
        XCTAssertEqual(l1.sub, "THE HOUSE NEXT DOOR")
        XCTAssertEqual(l1.gasMax, 600)
        XCTAssertEqual(l1.gasDrain, 0.10, accuracy: 0.001)
        XCTAssertEqual(l1.cans, 0)
        XCTAssertEqual(l1.stumps, 0)
        XCTAssertEqual(l1.crickets, 0)
        XCTAssertEqual(l1.skunks, 0)
        XCTAssertEqual(l1.cricketMs, 0)
        XCTAssertEqual(l1.win, 0.80, accuracy: 0.001)

        // Level 2: RUNNING ON FUMES
        let l2 = levels[1]
        XCTAssertEqual(l2.sub, "RUNNING ON FUMES")
        XCTAssertEqual(l2.gasMax, 200)
        XCTAssertEqual(l2.gasDrain, 0.18, accuracy: 0.001)
        XCTAssertEqual(l2.cans, 2)

        // Level 3: STUMP TROUBLE
        let l3 = levels[2]
        XCTAssertEqual(l3.sub, "STUMP TROUBLE")
        XCTAssertEqual(l3.stumps, 2)

        // Level 4: CRICKET SEASON
        let l4 = levels[3]
        XCTAssertEqual(l4.sub, "CRICKET SEASON")
        XCTAssertEqual(l4.crickets, 2)
        XCTAssertEqual(l4.skunks, 1)
        XCTAssertEqual(l4.cricketMs, 1200)
        XCTAssertEqual(l4.win, 0.85, accuracy: 0.001)

        // Level 5: THE FINAL YARD
        let l5 = levels[4]
        XCTAssertEqual(l5.sub, "THE FINAL YARD")
        XCTAssertEqual(l5.gasMax, 140)
        XCTAssertEqual(l5.cans, 4)
        XCTAssertEqual(l5.stumps, 3)
        XCTAssertEqual(l5.crickets, 3)
        XCTAssertEqual(l5.skunks, 2)
        XCTAssertEqual(l5.cricketMs, 750)
        XCTAssertEqual(l5.win, 0.90, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `xcodebuild -project BandMusicGames.xcodeproj -scheme BandMusicGames -only-testing:BandMusicGamesTests/GoonLevelsTests test 2>&1 | tail -10`
Expected: FAIL with "cannot find 'GoonLevels' in scope".

- [ ] **Step 3: Create GoonLevels.swift**

Create `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonLevels.swift`:

```swift
import CoreGraphics

struct GoonLevelConfig {
    let n: Int
    let title: String
    let sub: String
    let desc: String
    let gasMax: CGFloat
    let gasDrain: CGFloat
    let cans: Int
    let stumps: Int
    let crickets: Int
    let skunks: Int
    let cricketMs: Int
    let win: CGFloat
}

enum GoonLevels {
    static let all: [GoonLevelConfig] = [
        GoonLevelConfig(
            n: 1, title: "LEVEL 1", sub: "THE HOUSE NEXT DOOR",
            desc: "Mow around the house and garden.",
            gasMax: 600, gasDrain: 0.10,
            cans: 0, stumps: 0, crickets: 0, skunks: 0, cricketMs: 0,
            win: 0.80
        ),
        GoonLevelConfig(
            n: 2, title: "LEVEL 2", sub: "RUNNING ON FUMES",
            desc: "Gas runs out — find the gas can!",
            gasMax: 200, gasDrain: 0.18,
            cans: 2, stumps: 0, crickets: 0, skunks: 0, cricketMs: 0,
            win: 0.80
        ),
        GoonLevelConfig(
            n: 3, title: "LEVEL 3", sub: "STUMP TROUBLE",
            desc: "Hold DIG near stumps to dig them up.",
            gasMax: 180, gasDrain: 0.20,
            cans: 2, stumps: 2, crickets: 0, skunks: 0, cricketMs: 0,
            win: 0.80
        ),
        GoonLevelConfig(
            n: 4, title: "LEVEL 4", sub: "CRICKET SEASON",
            desc: "Crickets hop around. Hit one = lose gas!  Watch the skunk!",
            gasMax: 160, gasDrain: 0.22,
            cans: 2, stumps: 2, crickets: 2, skunks: 1, cricketMs: 1200,
            win: 0.85
        ),
        GoonLevelConfig(
            n: 5, title: "LEVEL 5", sub: "THE FINAL YARD",
            desc: "Everything at once. Good luck.",
            gasMax: 140, gasDrain: 0.25,
            cans: 4, stumps: 3, crickets: 3, skunks: 2, cricketMs: 750,
            win: 0.90
        ),
    ]
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `xcodebuild -project BandMusicGames.xcodeproj -scheme BandMusicGames -only-testing:BandMusicGamesTests/GoonLevelsTests test 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/GoonLevels.swift \
        ios/BandMusicGamesTests/Goon/GoonLevelsTests.swift
git commit -m "feat(goon): level configs ported 1:1 from web LEVELS array"
```

---

### Task 3: Tile grid + grid generation

**Files:**
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonLevels.swift`
- Create: `bandmusicgames/ios/BandMusicGamesTests/Goon/GoonGridTests.swift`

- [ ] **Step 1: Write the failing test**

Create `bandmusicgames/ios/BandMusicGamesTests/Goon/GoonGridTests.swift`:

```swift
import XCTest
@testable import BandMusicGames

final class GoonGridTests: XCTestCase {
    func test_grid_isCorrectSize() {
        let grid = GoonGrid.make(for: GoonLevels.all[0])
        XCTAssertEqual(grid.width, 25)
        XCTAssertEqual(grid.height, 15)
        XCTAssertEqual(grid.cells.count, 25 * 15)
    }

    func test_level1_hasHouseAndGarden() {
        let grid = GoonGrid.make(for: GoonLevels.all[0])
        let houseCount = grid.cells.filter { $0 == .house }.count
        let gardenCount = grid.cells.filter { $0 == .garden }.count
        XCTAssertGreaterThan(houseCount, 0, "Level 1 must have a house footprint")
        XCTAssertGreaterThan(gardenCount, 0, "Level 1 must have garden tiles")
    }

    func test_otherLevels_areAllTallGrass() {
        for i in 1...4 {
            let grid = GoonGrid.make(for: GoonLevels.all[i])
            let nonTall = grid.cells.filter { $0 != .tall }.count
            XCTAssertEqual(nonTall, 0, "Level \(i+1) starts as full tall grass")
        }
    }

    func test_cutPercentage_isZeroAtStart() {
        let grid = GoonGrid.make(for: GoonLevels.all[1])
        XCTAssertEqual(grid.cutPercentage, 0.0, accuracy: 0.001)
    }

    func test_cutPercentage_countsCutTilesAgainstMowable() {
        var grid = GoonGrid.make(for: GoonLevels.all[1])
        let mowable = grid.cells.filter { $0 == .tall }.count
        grid.cut(at: 0, 0)
        XCTAssertEqual(grid.cutPercentage, 1.0 / Double(mowable), accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `xcodebuild -project BandMusicGames.xcodeproj -scheme BandMusicGames -only-testing:BandMusicGamesTests/GoonGridTests test 2>&1 | tail -10`
Expected: FAIL with "cannot find 'GoonGrid' in scope".

- [ ] **Step 3: Add GoonTile, GoonGrid, and generation**

Append to `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonLevels.swift`:

```swift
enum GoonTile: UInt8 {
    case tall = 0      // mowable
    case cut = 1
    case stump = 2     // impassable until dug
    case house = 3     // impassable, not mowable
    case garden = 4    // passable, not mowable
}

struct GoonGrid {
    static let width = 25
    static let height = 15

    var cells: ContiguousArray<GoonTile>

    var cutPercentage: Double {
        var mowable = 0
        var cut = 0
        for cell in cells {
            switch cell {
            case .tall: mowable += 1
            case .cut: mowable += 1; cut += 1
            default: break
            }
        }
        return mowable == 0 ? 0 : Double(cut) / Double(mowable)
    }

    func at(_ x: Int, _ y: Int) -> GoonTile {
        guard x >= 0, x < Self.width, y >= 0, y < Self.height else { return .house }
        return cells[y * Self.width + x]
    }

    mutating func set(_ x: Int, _ y: Int, _ tile: GoonTile) {
        guard x >= 0, x < Self.width, y >= 0, y < Self.height else { return }
        cells[y * Self.width + x] = tile
    }

    mutating func cut(at x: Int, _ y: Int) {
        guard at(x, y) == .tall else { return }
        set(x, y, .cut)
    }

    static func make(for config: GoonLevelConfig) -> GoonGrid {
        var cells = ContiguousArray<GoonTile>(repeating: .tall, count: width * height)
        if config.n == 1 {
            // House footprint: 6×4 block at top-right corner (rows 1–4, cols 18–23)
            for y in 1...4 {
                for x in 18...23 {
                    cells[y * width + x] = .house
                }
            }
            // Garden bed: 2 rows of garden tiles below the house
            for y in 5...6 {
                for x in 18...23 {
                    cells[y * width + x] = .garden
                }
            }
        }
        return GoonGrid(cells: cells)
    }
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `xcodebuild -project BandMusicGames.xcodeproj -scheme BandMusicGames -only-testing:BandMusicGamesTests/GoonGridTests test 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/GoonLevels.swift \
        ios/BandMusicGamesTests/Goon/GoonGridTests.swift
git commit -m "feat(goon): tile grid + per-level grid generation"
```

---

## Phase 3 — Game state machine

### Task 4: Phase enum + state machine in GoonGameScene

**Files:**
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`
- Create: `bandmusicgames/ios/BandMusicGamesTests/Goon/GoonGameStateTests.swift`

- [ ] **Step 1: Write failing state machine tests**

Create `bandmusicgames/ios/BandMusicGamesTests/Goon/GoonGameStateTests.swift`:

```swift
import XCTest
@testable import BandMusicGames

@MainActor
final class GoonGameStateTests: XCTestCase {
    func test_initialPhase_isTitle() {
        let scene = GoonGameScene.make()
        XCTAssertEqual(scene.phase, .title)
    }

    func test_startLevel_transitionsToPlaying() {
        let scene = GoonGameScene.make()
        scene.startLevel(1)
        XCTAssertEqual(scene.phase, .playing)
        XCTAssertEqual(scene.levelNum, 1)
        XCTAssertEqual(scene.gas, 600)
    }

    func test_onGasOut_transitionsToGameOver() {
        let scene = GoonGameScene.make()
        scene.startLevel(1)
        scene.gas = 0
        scene.tickGameLogic(deltaSeconds: 0.016)
        XCTAssertEqual(scene.phase, .gameOver)
    }

    func test_onWinThreshold_transitionsToLevelComplete() {
        let scene = GoonGameScene.make()
        scene.startLevel(1)
        scene.cutPctOverride = 0.81 // simulate threshold met
        scene.tickGameLogic(deltaSeconds: 0.016)
        XCTAssertEqual(scene.phase, .levelComplete)
    }

    func test_winLevel5_transitionsToWin() {
        let scene = GoonGameScene.make()
        scene.startLevel(5)
        scene.cutPctOverride = 0.91
        scene.tickGameLogic(deltaSeconds: 0.016)
        XCTAssertEqual(scene.phase, .win)
    }

    func test_retryFromGameOver_restartsSameLevel() {
        let scene = GoonGameScene.make()
        scene.startLevel(3)
        scene.gas = 0
        scene.tickGameLogic(deltaSeconds: 0.016)
        XCTAssertEqual(scene.phase, .gameOver)

        scene.retry()
        XCTAssertEqual(scene.phase, .playing)
        XCTAssertEqual(scene.levelNum, 3)
        XCTAssertEqual(scene.gas, 180)
    }
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `xcodebuild -project BandMusicGames.xcodeproj -scheme BandMusicGames -only-testing:BandMusicGamesTests/GoonGameStateTests test 2>&1 | tail -10`
Expected: FAIL with "value of type 'GoonGameScene' has no member 'phase'".

- [ ] **Step 3: Replace GoonGameScene.swift with state machine**

Replace `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`:

```swift
import SpriteKit
import Combine

enum GoonPhase {
    case title
    case playing
    case levelComplete
    case gameOver
    case win
}

@MainActor
final class GoonGameScene: SKScene, ObservableObject {

    // MARK: - Phase state (observed by SwiftUI overlays)
    @Published private(set) var phase: GoonPhase = .title

    // MARK: - Level state
    private(set) var levelNum: Int = 1
    var config: GoonLevelConfig { GoonLevels.all[levelNum - 1] }

    // MARK: - Runtime state
    var gas: CGFloat = 0
    var grid = GoonGrid(cells: ContiguousArray<GoonTile>(repeating: .tall, count: GoonGrid.width * GoonGrid.height))
    var score: Int = 0

    /// Test hook — when non-nil, used in place of grid.cutPercentage by tickGameLogic.
    var cutPctOverride: Double?

    // MARK: - Construction
    static func make() -> GoonGameScene {
        let scene = GoonGameScene(size: CGSize(width: 800, height: 600))
        scene.scaleMode = .aspectFit
        scene.backgroundColor = SKColor(red: 0.04, green: 0.10, blue: 0.04, alpha: 1)
        return scene
    }

    // MARK: - Transitions
    func startLevel(_ n: Int) {
        levelNum = max(1, min(n, GoonLevels.all.count))
        grid = GoonGrid.make(for: config)
        gas = config.gasMax
        cutPctOverride = nil
        phase = .playing
    }

    func retry() {
        startLevel(levelNum)
    }

    func nextLevel() {
        if levelNum >= GoonLevels.all.count {
            phase = .win
        } else {
            startLevel(levelNum + 1)
        }
    }

    func resetAndReturnToTitle() {
        levelNum = 1
        score = 0
        phase = .title
    }

    func tickGameLogic(deltaSeconds: CGFloat) {
        guard phase == .playing else { return }
        if gas <= 0 {
            phase = .gameOver
            return
        }
        let pct = cutPctOverride ?? grid.cutPercentage
        if pct >= config.win {
            phase = (levelNum >= GoonLevels.all.count) ? .win : .levelComplete
        }
    }

    // MARK: - Lifecycle
    func activate() {}
    func deactivate() {}

    // MARK: - SpriteKit update loop
    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate.map { CGFloat(currentTime - $0) } ?? 0.016
        lastUpdate = currentTime
        tickGameLogic(deltaSeconds: dt)
    }
    private var lastUpdate: TimeInterval?
}
```

- [ ] **Step 4: Run tests, verify they pass**

Run: `xcodebuild -project BandMusicGames.xcodeproj -scheme BandMusicGames -only-testing:BandMusicGamesTests/GoonGameStateTests test 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift \
        ios/BandMusicGamesTests/Goon/GoonGameStateTests.swift
git commit -m "feat(goon): phase state machine with transitions + tests"
```

---

### Task 5: UserDefaults save state

**Files:**
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`
- Modify: `bandmusicgames/ios/BandMusicGamesTests/Goon/GoonGameStateTests.swift`

- [ ] **Step 1: Write failing persistence tests**

Append to `GoonGameStateTests.swift`:

```swift
extension GoonGameStateTests {
    func test_savedLevel_defaultsTo1() {
        UserDefaults.standard.removeObject(forKey: "goon_level")
        XCTAssertEqual(GoonGameScene.savedLevel, 1)
    }

    func test_completingLevel_savesNextAsUnlocked() {
        UserDefaults.standard.removeObject(forKey: "goon_level")
        let scene = GoonGameScene.make()
        scene.startLevel(1)
        scene.cutPctOverride = 0.81
        scene.tickGameLogic(deltaSeconds: 0.016)
        XCTAssertEqual(scene.phase, .levelComplete)
        scene.nextLevel()
        XCTAssertEqual(GoonGameScene.savedLevel, 2)
    }

    func test_winningLevel5_setsWonFlag() {
        UserDefaults.standard.removeObject(forKey: "goon_won")
        let scene = GoonGameScene.make()
        scene.startLevel(5)
        scene.cutPctOverride = 0.91
        scene.tickGameLogic(deltaSeconds: 0.016)
        XCTAssertEqual(scene.phase, .win)
        XCTAssertTrue(GoonGameScene.hasWon)
    }

    func test_replayFromWin_resetsAllProgress() {
        UserDefaults.standard.set(5, forKey: "goon_level")
        UserDefaults.standard.set(true, forKey: "goon_won")
        let scene = GoonGameScene.make()
        scene.phase = .win
        scene.replayFromWin()
        XCTAssertEqual(scene.phase, .title)
        XCTAssertEqual(GoonGameScene.savedLevel, 1)
        XCTAssertFalse(GoonGameScene.hasWon)
    }
}
```

(For tests to assign `scene.phase` directly, expose it as `internal var phase` instead of `private(set)`. Already done above? — no, it's `private(set)`. Adjust by adding a test-only setter.)

Add the test helper to `GoonGameScene.swift`:

```swift
#if DEBUG
extension GoonGameScene {
    var phaseForTesting: GoonPhase {
        get { phase }
        set { phase = newValue }
    }
}
#endif
```

And update the failing test to use `scene.phaseForTesting = .win` instead of `scene.phase = .win`.

- [ ] **Step 2: Run tests, verify they fail**

Expected: FAIL with "type 'GoonGameScene' has no member 'savedLevel'".

- [ ] **Step 3: Add persistence to GoonGameScene**

Add to `GoonGameScene.swift`:

```swift
extension GoonGameScene {
    private static let savedLevelKey = "goon_level"
    private static let hasWonKey = "goon_won"

    static var savedLevel: Int {
        let n = UserDefaults.standard.integer(forKey: savedLevelKey)
        return n == 0 ? 1 : min(n, GoonLevels.all.count)
    }

    static var hasWon: Bool {
        UserDefaults.standard.bool(forKey: hasWonKey)
    }

    private func save(level: Int) {
        UserDefaults.standard.set(level, forKey: Self.savedLevelKey)
    }

    private func saveWon() {
        UserDefaults.standard.set(true, forKey: Self.hasWonKey)
    }

    private func clearProgress() {
        UserDefaults.standard.removeObject(forKey: Self.savedLevelKey)
        UserDefaults.standard.removeObject(forKey: Self.hasWonKey)
    }

    func replayFromWin() {
        clearProgress()
        levelNum = 1
        score = 0
        phase = .title
    }
}
```

Update `nextLevel()` and the `tickGameLogic` win path to persist:

```swift
func nextLevel() {
    if levelNum >= GoonLevels.all.count {
        saveWon()
        phase = .win
    } else {
        let next = levelNum + 1
        save(level: next)
        startLevel(next)
    }
}

func tickGameLogic(deltaSeconds: CGFloat) {
    guard phase == .playing else { return }
    if gas <= 0 {
        phase = .gameOver
        return
    }
    let pct = cutPctOverride ?? grid.cutPercentage
    if pct >= config.win {
        if levelNum >= GoonLevels.all.count {
            saveWon()
            phase = .win
        } else {
            phase = .levelComplete
        }
    }
}
```

- [ ] **Step 4: Run tests, verify they pass**

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift \
        ios/BandMusicGamesTests/Goon/GoonGameStateTests.swift
git commit -m "feat(goon): UserDefaults save state for level + won"
```

---

## Phase 4 — Rendering & mower mechanic

### Task 6: GoonRenderer with placeholder shape-node fallback

**Files:**
- Create: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonRenderer.swift`
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`

- [ ] **Step 1: Create the renderer**

Create `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonRenderer.swift`:

```swift
import SpriteKit

@MainActor
final class GoonRenderer {

    static let tileSize: CGFloat = 32

    /// Look up a sprite by name; if no texture atlas is present yet,
    /// return a colored shape-node fallback so day-1 build is playable.
    static func sprite(named name: String, size: CGSize, fallbackColor: SKColor) -> SKNode {
        if let texture = textureIfAvailable(name) {
            let node = SKSpriteNode(texture: texture, size: size)
            node.name = name
            return node
        }
        let shape = SKShapeNode(rectOf: size, cornerRadius: 2)
        shape.fillColor = fallbackColor
        shape.strokeColor = .clear
        shape.name = name
        return shape
    }

    static func tileNode(for tile: GoonTile) -> SKNode {
        let size = CGSize(width: tileSize, height: tileSize)
        switch tile {
        case .tall:    return sprite(named: "tile-tall-1",    size: size, fallbackColor: SKColor(red: 0.18, green: 0.48, blue: 0.18, alpha: 1))
        case .cut:     return sprite(named: "tile-cut-1",     size: size, fallbackColor: SKColor(red: 0.55, green: 0.77, blue: 0.29, alpha: 1))
        case .stump:   return sprite(named: "stump-full",     size: size, fallbackColor: SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1))
        case .house:   return sprite(named: "tile-house-wall", size: size, fallbackColor: SKColor(red: 0.4,  green: 0.3,  blue: 0.2,  alpha: 1))
        case .garden:  return sprite(named: "tile-garden-1",   size: size, fallbackColor: SKColor(red: 0.6,  green: 0.4,  blue: 0.7,  alpha: 1))
        }
    }

    private static func textureIfAvailable(_ name: String) -> SKTexture? {
        // SKTextureAtlas.atlasNames isn't a documented API; try loading the texture
        // and check if it's a valid sprite. If the atlas is missing, this returns nil.
        let texture = SKTexture(imageNamed: name)
        if texture.size() == .zero { return nil }
        // SpriteKit returns a "MissingResource" texture when the image isn't found,
        // but it has non-zero size. Use a Bundle lookup as authoritative.
        if Bundle.main.url(forResource: name, withExtension: "png") != nil { return texture }
        // Check inside atlas folders too
        for atlas in ["mower", "cricket", "skunk", "stump", "tiles", "fx"] {
            if Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "\(atlas).atlas") != nil {
                return texture
            }
        }
        return nil
    }
}
```

- [ ] **Step 2: Wire the grid render into the scene**

Modify `GoonGameScene.swift`. Add a `gridLayer` property and a `drawGrid()` method:

```swift
// Add as a property:
private let gridLayer = SKNode()

// In didMove(to view: SKView), add:
override func didMove(to view: SKView) {
    super.didMove(to: view)
    if gridLayer.parent == nil {
        addChild(gridLayer)
    }
}

// Add the render method:
func drawGrid() {
    gridLayer.removeAllChildren()
    let ts = GoonRenderer.tileSize
    for y in 0..<GoonGrid.height {
        for x in 0..<GoonGrid.width {
            let node = GoonRenderer.tileNode(for: grid.at(x, y))
            // Origin at top-left of lawn; tile centers stride by tileSize
            node.position = CGPoint(
                x: CGFloat(x) * ts + ts / 2,
                y: size.height - (CGFloat(y) * ts + ts / 2)
            )
            gridLayer.addChild(node)
        }
    }
}
```

Modify `startLevel(_:)` to call `drawGrid()`:

```swift
func startLevel(_ n: Int) {
    levelNum = max(1, min(n, GoonLevels.all.count))
    grid = GoonGrid.make(for: config)
    gas = config.gasMax
    cutPctOverride = nil
    phase = .playing
    drawGrid()
}
```

- [ ] **Step 3: Verify the placeholder render works visually**

Run: `xcodebuild ... build` (same command as Task 1 Step 5)
Expected: `** BUILD SUCCEEDED **`

The visual check happens after install on phone — for now, confirm compilation. The phone install/launch is later.

- [ ] **Step 4: Commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/GoonRenderer.swift \
        ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift
git commit -m "feat(goon): GoonRenderer + grid drawing with shape-node fallback"
```

---

### Task 7: Mower entity + joystick input + movement

**Files:**
- Create: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonInputController.swift`
- Create: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/Overlays/GoonControlOverlay.swift`
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameView.swift`

- [ ] **Step 1: Create the input controller**

Create `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonInputController.swift`:

```swift
import SwiftUI

@MainActor
final class GoonInputController: ObservableObject {
    @Published var joystick: CGVector = .zero    // unit vector, magnitude 0–1
    @Published var digging: Bool = false
    @Published var canDig: Bool = false

    func reset() {
        joystick = .zero
        digging = false
    }
}
```

- [ ] **Step 2: Create the joystick + dig button overlay**

Create `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/Overlays/GoonControlOverlay.swift`:

```swift
import SwiftUI

struct GoonControlOverlay: View {
    @ObservedObject var input: GoonInputController

    var body: some View {
        GeometryReader { geo in
            ZStack {
                JoystickView(direction: $input.joystick)
                    .frame(width: 130, height: 130)
                    .position(x: 75, y: geo.size.height - 75)
                if input.canDig {
                    DigButton(isPressed: $input.digging)
                        .frame(width: 130, height: 130)
                        .position(x: geo.size.width - 75, y: geo.size.height - 75)
                }
            }
        }
    }
}

private struct JoystickView: View {
    @Binding var direction: CGVector
    @State private var anchor: CGPoint?
    @State private var knob: CGPoint?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.04))
                .overlay(Circle().stroke(Color.white.opacity(0.13), lineWidth: 1.5))

            Text("MOVE")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
                .tracking(1)
                .opacity(anchor == nil ? 1 : 0)

            if let a = anchor {
                Circle()
                    .stroke(Color.white.opacity(0.55), lineWidth: 2.5)
                    .frame(width: 80, height: 80)
                    .position(a)
            }
            if let k = knob {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
                    .frame(width: 38, height: 38)
                    .position(k)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if anchor == nil { anchor = v.startLocation }
                    knob = v.location
                    let dx = v.location.x - (anchor?.x ?? 0)
                    let dy = v.location.y - (anchor?.y ?? 0)
                    let d = sqrt(dx * dx + dy * dy)
                    let cap: CGFloat = 40
                    let mag = min(d, cap) / cap
                    if d > 0.5 {
                        direction = CGVector(dx: (dx / d) * mag, dy: (dy / d) * mag)
                    }
                }
                .onEnded { _ in
                    anchor = nil
                    knob = nil
                    direction = .zero
                }
        )
    }
}

private struct DigButton: View {
    @Binding var isPressed: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isPressed ? Color(red: 1.0, green: 0.8, blue: 0.0).opacity(0.18) : Color.yellow.opacity(0.04))
                .overlay(
                    Circle().stroke(
                        isPressed ? Color(red: 1.0, green: 0.8, blue: 0.0).opacity(0.75) : Color.yellow.opacity(0.25),
                        lineWidth: 1.5
                    )
                )
            Text("DIG")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Color.yellow.opacity(0.45))
                .tracking(1)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}
```

- [ ] **Step 3: Add the mower entity + movement to the scene**

In `GoonGameScene.swift`, add:

```swift
struct GoonMower {
    var position: CGPoint
    var velocity: CGVector
    var facing: CGFloat    // radians
    var lowGas: Bool
}

extension GoonGameScene {
    private static let mowerSpeed: CGFloat = 220  // points per second
    private static let mowerSize = CGSize(width: 56, height: 56)
}

// Add properties:
//   var mower: GoonMower = GoonMower(position: .zero, velocity: .zero, facing: 0, lowGas: false)
//   var input: GoonInputController = GoonInputController()
//   private var mowerNode: SKNode?
```

(Add these to the top of the class declaration, near `var grid`.)

Update `startLevel(_:)`:

```swift
func startLevel(_ n: Int) {
    levelNum = max(1, min(n, GoonLevels.all.count))
    grid = GoonGrid.make(for: config)
    gas = config.gasMax
    cutPctOverride = nil
    input.canDig = config.stumps > 0
    mower.position = CGPoint(x: size.width / 2, y: size.height / 2)
    mower.velocity = .zero
    mower.facing = 0
    phase = .playing
    drawGrid()
    placeMowerNode()
}

private func placeMowerNode() {
    mowerNode?.removeFromParent()
    let node = GoonRenderer.sprite(
        named: "mower-body",
        size: Self.mowerSize,
        fallbackColor: SKColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1)
    )
    node.position = mower.position
    node.zPosition = 10
    addChild(node)
    mowerNode = node
}
```

Add to `tickGameLogic(deltaSeconds:)` (above the gas-out check):

```swift
// Apply input to mower
let dir = input.joystick
let speed = Self.mowerSpeed * deltaSeconds
mower.velocity = CGVector(dx: dir.dx * speed, dy: -dir.dy * speed)   // SwiftUI y is inverted vs SpriteKit
let dx = mower.velocity.dx
let dy = mower.velocity.dy
let mag = sqrt(dx * dx + dy * dy)
if mag > 0.01 {
    mower.facing = atan2(dy, dx)
}
let proposed = CGPoint(
    x: mower.position.x + mower.velocity.dx,
    y: mower.position.y + mower.velocity.dy
)
mower.position = clampToLawn(proposed)
mowerNode?.position = mower.position
mowerNode?.zRotation = mower.facing
```

Add the clamping helper:

```swift
private func clampToLawn(_ p: CGPoint) -> CGPoint {
    let half = Self.mowerSize.width / 2
    return CGPoint(
        x: max(half, min(p.x, size.width - half)),
        y: max(half, min(p.y, size.height - half))
    )
}
```

- [ ] **Step 4: Wire the overlay into GoonGameView**

Modify `GoonGameView.swift` to layer the control overlay:

```swift
var body: some View {
    ZStack {
        Color(hex: "#0a1a0a").ignoresSafeArea()
        SpriteView(
            scene: scene,
            options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes]
        )
        .ignoresSafeArea()
        if scene.phase == .playing {
            GoonControlOverlay(input: scene.input)
                .ignoresSafeArea()
        }
        closeButton
    }
    .onAppear {
        scene.activate()
        scene.startLevel(GoonGameScene.savedLevel)
    }
    .onDisappear { scene.deactivate() }
}
```

- [ ] **Step 5: Build to verify compilation**

Run: `xcodebuild ... build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/GoonInputController.swift \
        ios/BandMusicGames/Views/Games/Goon/Overlays/GoonControlOverlay.swift \
        ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift \
        ios/BandMusicGames/Views/Games/Goon/GoonGameView.swift
git commit -m "feat(goon): mower entity + SwiftUI joystick/dig overlay"
```

---

### Task 8: Tile cutting (mower passes over tall tiles)

**Files:**
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`
- Modify: `bandmusicgames/ios/BandMusicGamesTests/Goon/GoonGridTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `GoonGridTests.swift`:

```swift
extension GoonGridTests {
    func test_mowerCutsTallTileBeneathIt() {
        var grid = GoonGrid.make(for: GoonLevels.all[1])
        XCTAssertEqual(grid.at(5, 5), .tall)
        let cutsMade = grid.cutTilesUnderMower(
            atWorldPos: CGPoint(x: 5 * 32 + 16, y: 480 - (5 * 32 + 16)),
            sceneHeight: 480
        )
        XCTAssertEqual(cutsMade, 1)
        XCTAssertEqual(grid.at(5, 5), .cut)
    }

    func test_mowerDoesNotCutHouse() {
        var grid = GoonGrid.make(for: GoonLevels.all[0])
        // Level 1 row 2, col 20 is a house tile
        let before = grid.at(20, 2)
        XCTAssertEqual(before, .house)
        let cutsMade = grid.cutTilesUnderMower(
            atWorldPos: CGPoint(x: 20 * 32 + 16, y: 480 - (2 * 32 + 16)),
            sceneHeight: 480
        )
        XCTAssertEqual(cutsMade, 0)
        XCTAssertEqual(grid.at(20, 2), .house)
    }
}
```

- [ ] **Step 2: Run test, verify it fails**

Expected: FAIL with "value of type 'GoonGrid' has no member 'cutTilesUnderMower'".

- [ ] **Step 3: Add the cut function**

Append to `GoonLevels.swift`:

```swift
extension GoonGrid {
    /// Cuts the tile at the world-space position (one tile per call), returns
    /// the number of new cuts (0 or 1).
    mutating func cutTilesUnderMower(atWorldPos pos: CGPoint, sceneHeight: CGFloat) -> Int {
        let ts: CGFloat = 32
        let x = Int(pos.x / ts)
        let y = Int((sceneHeight - pos.y) / ts)
        guard x >= 0, x < Self.width, y >= 0, y < Self.height else { return 0 }
        if at(x, y) == .tall {
            set(x, y, .cut)
            return 1
        }
        return 0
    }
}
```

- [ ] **Step 4: Wire cutting into the scene update loop**

In `GoonGameScene.swift`, add to `tickGameLogic` right after the mower position update:

```swift
let cuts = grid.cutTilesUnderMower(atWorldPos: mower.position, sceneHeight: size.height)
if cuts > 0 {
    score += 1
    redrawTile(atWorldPos: mower.position)   // re-render just this tile
}
```

Add the helper:

```swift
private func redrawTile(atWorldPos pos: CGPoint) {
    let ts = GoonRenderer.tileSize
    let x = Int(pos.x / ts)
    let y = Int((size.height - pos.y) / ts)
    guard x >= 0, x < GoonGrid.width, y >= 0, y < GoonGrid.height else { return }
    // Walk the gridLayer to find & replace the tile at this cell
    let cx = CGFloat(x) * ts + ts / 2
    let cy = size.height - (CGFloat(y) * ts + ts / 2)
    for child in gridLayer.children where abs(child.position.x - cx) < 0.5 && abs(child.position.y - cy) < 0.5 {
        child.removeFromParent()
        break
    }
    let node = GoonRenderer.tileNode(for: grid.at(x, y))
    node.position = CGPoint(x: cx, y: cy)
    gridLayer.addChild(node)
}
```

- [ ] **Step 5: Run tests, verify they pass**

Expected: green.

- [ ] **Step 6: Commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/GoonLevels.swift \
        ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift \
        ios/BandMusicGamesTests/Goon/GoonGridTests.swift
git commit -m "feat(goon): tile cutting when mower passes over tall grass"
```

---

### Task 9: Gas drain during play

**Files:**
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`
- Modify: `bandmusicgames/ios/BandMusicGamesTests/Goon/GoonGameStateTests.swift`

- [ ] **Step 1: Write failing test**

Append to `GoonGameStateTests.swift`:

```swift
extension GoonGameStateTests {
    func test_gasDrainsOverTimeWhenPlaying() {
        let scene = GoonGameScene.make()
        scene.startLevel(2)
        let initial = scene.gas
        scene.tickGameLogic(deltaSeconds: 1.0)
        XCTAssertLessThan(scene.gas, initial)
    }

    func test_gasDoesNotDrainWhenNotPlaying() {
        let scene = GoonGameScene.make()
        scene.startLevel(1)
        scene.phaseForTesting = .title
        let initial = scene.gas
        scene.tickGameLogic(deltaSeconds: 1.0)
        XCTAssertEqual(scene.gas, initial)
    }
}
```

- [ ] **Step 2: Run, expect fail**

Expected: gas doesn't drain (logic missing).

- [ ] **Step 3: Add gas drain logic**

In `GoonGameScene.swift`, modify `tickGameLogic(deltaSeconds:)` — add gas drain right after the position/cut block:

```swift
// Gas drain (~16.67ms per "frame" in web; deltaSeconds * 60 is the scale factor)
let drainScale: CGFloat = (deltaSeconds * 60)   // 1.0 at 60Hz
let onCut = grid.at(
    Int(mower.position.x / GoonRenderer.tileSize),
    Int((size.height - mower.position.y) / GoonRenderer.tileSize)
) == .cut
let drain = onCut ? config.gasDrain * 0.4 : config.gasDrain
gas = max(0, gas - drain * drainScale)
mower.lowGas = (gas / config.gasMax) < 0.2
```

- [ ] **Step 4: Run, expect pass**

Expected: green.

- [ ] **Step 5: Commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift \
        ios/BandMusicGamesTests/Goon/GoonGameStateTests.swift
git commit -m "feat(goon): gas drain during play (40% drain on cut tiles)"
```

---

## Phase 5 — Hazards & pickups

### Task 10: Gas cans (pickup logic)

**Files:**
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonLevels.swift`
- Create: `bandmusicgames/ios/BandMusicGamesTests/Goon/GoonPickupsTests.swift`

- [ ] **Step 1: Write failing test**

Create `bandmusicgames/ios/BandMusicGamesTests/Goon/GoonPickupsTests.swift`:

```swift
import XCTest
@testable import BandMusicGames

@MainActor
final class GoonPickupsTests: XCTestCase {
    func test_level2_spawnsCorrectNumberOfCans() {
        let scene = GoonGameScene.make()
        scene.startLevel(2)
        XCTAssertEqual(scene.gasCans.count, 2)
    }

    func test_pickingUpCan_refillsGas() {
        let scene = GoonGameScene.make()
        scene.startLevel(2)
        scene.gas = 50
        let can = scene.gasCans[0]
        scene.mower.position = can.position
        scene.tickGameLogic(deltaSeconds: 0.016)
        XCTAssertEqual(scene.gas, scene.config.gasMax)
        XCTAssertEqual(scene.gasCans.filter { !$0.collected }.count, 1)
    }
}
```

- [ ] **Step 2: Add the entity & state**

Add to `GoonLevels.swift`:

```swift
struct GoonGasCan: Identifiable, Equatable {
    let id = UUID()
    var position: CGPoint
    var collected = false
}
```

Add to `GoonGameScene.swift`:

```swift
// Property:
var gasCans: [GoonGasCan] = []

// Helper inside startLevel:
private func placeGasCans() {
    gasCans.removeAll()
    for _ in 0..<config.cans {
        gasCans.append(GoonGasCan(position: randomLawnPosition()))
    }
}

private func randomLawnPosition() -> CGPoint {
    // Pick a random non-house non-garden cell, return its world center.
    var attempts = 0
    while attempts < 50 {
        let x = Int.random(in: 0..<GoonGrid.width)
        let y = Int.random(in: 0..<GoonGrid.height)
        if grid.at(x, y) == .tall || grid.at(x, y) == .cut {
            let ts = GoonRenderer.tileSize
            return CGPoint(
                x: CGFloat(x) * ts + ts / 2,
                y: size.height - (CGFloat(y) * ts + ts / 2)
            )
        }
        attempts += 1
    }
    return CGPoint(x: size.width / 2, y: size.height / 2)
}
```

Call `placeGasCans()` from `startLevel(_:)` (after `drawGrid()`).

Add the pickup check inside `tickGameLogic` after the cut block:

```swift
// Gas can pickup (distance check, 32pt radius)
for i in gasCans.indices where !gasCans[i].collected {
    let dx = gasCans[i].position.x - mower.position.x
    let dy = gasCans[i].position.y - mower.position.y
    if dx * dx + dy * dy < 32 * 32 {
        gasCans[i].collected = true
        gas = config.gasMax
    }
}
```

Render gas cans — add to `drawGrid()` or a new `drawEntities()`:

```swift
private func drawEntities() {
    for can in gasCans where !can.collected {
        let node = GoonRenderer.sprite(
            named: "gas-can",
            size: CGSize(width: 24, height: 24),
            fallbackColor: SKColor(red: 0.87, green: 0.13, blue: 0.13, alpha: 1)
        )
        node.position = can.position
        node.zPosition = 5
        gridLayer.addChild(node)
    }
}
```

Call `drawEntities()` from `startLevel` after `drawGrid()` and `placeGasCans()`. Re-call from inside the pickup logic to refresh.

For test passability — expose `mower` and `gasCans` as `internal`:

```swift
var mower: GoonMower = GoonMower(position: .zero, velocity: .zero, facing: 0, lowGas: false)
// Make sure 'gasCans' is also non-private
```

- [ ] **Step 3: Run tests, expect green**

Expected: all tests green.

- [ ] **Step 4: Commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/GoonLevels.swift \
        ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift \
        ios/BandMusicGamesTests/Goon/GoonPickupsTests.swift
git commit -m "feat(goon): gas can pickup + refill logic"
```

---

### Task 11: Stumps + dig button

**Files:**
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonLevels.swift`
- Modify: `bandmusicgames/ios/BandMusicGamesTests/Goon/GoonPickupsTests.swift`

- [ ] **Step 1: Write failing test**

Append to `GoonPickupsTests.swift`:

```swift
extension GoonPickupsTests {
    func test_level3_spawnsCorrectNumberOfStumps() {
        let scene = GoonGameScene.make()
        scene.startLevel(3)
        XCTAssertEqual(scene.stumps.count, 2)
    }

    func test_holdingDigNearStump_progressesDig() {
        let scene = GoonGameScene.make()
        scene.startLevel(3)
        let stump = scene.stumps[0]
        scene.mower.position = stump.position
        scene.input.digging = true
        let before = scene.stumps[0].progress
        scene.tickGameLogic(deltaSeconds: 0.5)
        XCTAssertGreaterThan(scene.stumps[0].progress, before)
    }

    func test_fullyDugStump_becomesDug() {
        let scene = GoonGameScene.make()
        scene.startLevel(3)
        scene.mower.position = scene.stumps[0].position
        scene.input.digging = true
        for _ in 0..<200 { scene.tickGameLogic(deltaSeconds: 0.05) }
        XCTAssertTrue(scene.stumps[0].dug)
    }
}
```

- [ ] **Step 2: Add the entity**

Add to `GoonLevels.swift`:

```swift
struct GoonStump: Identifiable, Equatable {
    let id = UUID()
    var position: CGPoint
    var progress: CGFloat = 0   // 0..1
    var dug: Bool = false
}
```

Add to `GoonGameScene.swift`:

```swift
var stumps: [GoonStump] = []

private func placeStumps() {
    stumps.removeAll()
    for _ in 0..<config.stumps {
        let pos = randomLawnPosition()
        stumps.append(GoonStump(position: pos))
        // Mark grid tile as stump (impassable)
        let ts = GoonRenderer.tileSize
        let x = Int(pos.x / ts)
        let y = Int((size.height - pos.y) / ts)
        grid.set(x, y, .stump)
    }
}
```

Call `placeStumps()` from `startLevel` (before `placeGasCans()` so cans don't spawn under stumps).

Add dig logic to `tickGameLogic` after the gas-can pickup block:

```swift
// Stump dig
if input.digging {
    for i in stumps.indices where !stumps[i].dug {
        let dx = stumps[i].position.x - mower.position.x
        let dy = stumps[i].position.y - mower.position.y
        if dx * dx + dy * dy < 36 * 36 {
            stumps[i].progress += deltaSeconds * 0.6   // ~1.7s to dig
            if stumps[i].progress >= 1.0 {
                stumps[i].dug = true
                stumps[i].progress = 1.0
                let ts = GoonRenderer.tileSize
                let gx = Int(stumps[i].position.x / ts)
                let gy = Int((size.height - stumps[i].position.y) / ts)
                grid.set(gx, gy, .cut)   // becomes mowable (cut tile after dig)
            }
        }
    }
}
```

- [ ] **Step 3: Run tests, expect green**

- [ ] **Step 4: Commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/GoonLevels.swift \
        ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift \
        ios/BandMusicGamesTests/Goon/GoonPickupsTests.swift
git commit -m "feat(goon): stumps with hold-to-dig mechanic"
```

---

### Task 12: Crickets + hop AI + collision

**Files:**
- Create: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonHazards.swift`
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonLevels.swift`
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`
- Create: `bandmusicgames/ios/BandMusicGamesTests/Goon/GoonHazardsTests.swift`

- [ ] **Step 1: Write failing tests**

Create `bandmusicgames/ios/BandMusicGamesTests/Goon/GoonHazardsTests.swift`:

```swift
import XCTest
@testable import BandMusicGames

@MainActor
final class GoonHazardsTests: XCTestCase {
    func test_level4_spawnsCorrectNumberOfCrickets() {
        let scene = GoonGameScene.make()
        scene.startLevel(4)
        XCTAssertEqual(scene.crickets.count, 2)
    }

    func test_crickets_hopOverTime() {
        let scene = GoonGameScene.make()
        scene.startLevel(4)
        let before = scene.crickets[0].position
        for _ in 0..<200 { scene.tickGameLogic(deltaSeconds: 0.05) }
        XCTAssertNotEqual(scene.crickets[0].position, before)
    }

    func test_mowerHittingCricket_deducts30Gas() {
        let scene = GoonGameScene.make()
        scene.startLevel(4)
        let initialGas = scene.gas
        scene.mower.position = scene.crickets[0].position
        scene.tickGameLogic(deltaSeconds: 0.016)
        XCTAssertEqual(scene.gas, initialGas - 30)
    }
}
```

- [ ] **Step 2: Add the cricket entity + AI**

Add to `GoonLevels.swift`:

```swift
struct GoonCricket: Identifiable, Equatable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var nextHopAt: TimeInterval
    var hitCooldownUntil: TimeInterval = 0
}
```

Create `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonHazards.swift`:

```swift
import CoreGraphics

@MainActor
enum GoonHazards {
    static func tickCrickets(
        _ crickets: inout [GoonCricket],
        delta: CGFloat,
        now: TimeInterval,
        bounds: CGRect,
        cricketMs: Int
    ) {
        for i in crickets.indices {
            // Apply velocity decay
            crickets[i].position.x += crickets[i].velocity.dx * delta
            crickets[i].position.y += crickets[i].velocity.dy * delta
            crickets[i].velocity.dx *= 0.92
            crickets[i].velocity.dy *= 0.92

            // Bounds clamp
            crickets[i].position.x = max(bounds.minX, min(bounds.maxX, crickets[i].position.x))
            crickets[i].position.y = max(bounds.minY, min(bounds.maxY, crickets[i].position.y))

            // Time to hop?
            if now >= crickets[i].nextHopAt {
                let angle = CGFloat.random(in: 0..<(2 * .pi))
                let speed: CGFloat = 80
                crickets[i].velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
                crickets[i].nextHopAt = now + Double(cricketMs) / 1000.0 + Double.random(in: -0.2...0.2)
            }
        }
    }
}
```

- [ ] **Step 3: Wire crickets into GoonGameScene**

Add to `GoonGameScene.swift`:

```swift
var crickets: [GoonCricket] = []

private func placeCrickets() {
    crickets.removeAll()
    let now = lastUpdate ?? 0
    for _ in 0..<config.crickets {
        crickets.append(
            GoonCricket(
                position: randomLawnPosition(),
                velocity: .zero,
                nextHopAt: now + Double.random(in: 0...1.0)
            )
        )
    }
}
```

Call from `startLevel`. Add to `tickGameLogic` (after stump dig, before win-check):

```swift
// Crickets
let bounds = CGRect(x: 16, y: 16, width: size.width - 32, height: size.height - 32)
let now = lastUpdate ?? 0
GoonHazards.tickCrickets(&crickets, delta: deltaSeconds, now: now, bounds: bounds, cricketMs: config.cricketMs)

// Mower vs cricket collision (cooldown so a single hit doesn't repeatedly drain)
for i in crickets.indices {
    let dx = crickets[i].position.x - mower.position.x
    let dy = crickets[i].position.y - mower.position.y
    if dx * dx + dy * dy < 28 * 28 && now >= crickets[i].hitCooldownUntil {
        gas = max(0, gas - 30)
        crickets[i].hitCooldownUntil = now + 1.0
        // Eject cricket away from mower so it doesn't camp
        let dist = sqrt(dx * dx + dy * dy)
        if dist > 0.01 {
            crickets[i].velocity = CGVector(dx: (dx / dist) * 200, dy: (dy / dist) * 200)
        }
    }
}
```

- [ ] **Step 4: Run tests, expect green**

- [ ] **Step 5: Commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/GoonLevels.swift \
        ios/BandMusicGames/Views/Games/Goon/GoonHazards.swift \
        ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift \
        ios/BandMusicGamesTests/Goon/GoonHazardsTests.swift
git commit -m "feat(goon): crickets with hop AI + collision (-30 gas)"
```

---

### Task 13: Skunks (wander AI)

**Files:**
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonLevels.swift`
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonHazards.swift`
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`
- Modify: `bandmusicgames/ios/BandMusicGamesTests/Goon/GoonHazardsTests.swift`

- [ ] **Step 1: Write failing tests**

Append to `GoonHazardsTests.swift`:

```swift
extension GoonHazardsTests {
    func test_level4_spawnsOneSkunk() {
        let scene = GoonGameScene.make()
        scene.startLevel(4)
        XCTAssertEqual(scene.skunks.count, 1)
    }

    func test_skunks_wanderOverTime() {
        let scene = GoonGameScene.make()
        scene.startLevel(4)
        let before = scene.skunks[0].position
        for _ in 0..<300 { scene.tickGameLogic(deltaSeconds: 0.05) }
        XCTAssertNotEqual(scene.skunks[0].position, before)
    }
}
```

- [ ] **Step 2: Add skunk entity + AI**

Add to `GoonLevels.swift`:

```swift
struct GoonSkunk: Identifiable, Equatable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var alarm: CGFloat   // 0..1
    var changeDirAt: TimeInterval
}
```

Append to `GoonHazards.swift`:

```swift
extension GoonHazards {
    static func tickSkunks(
        _ skunks: inout [GoonSkunk],
        delta: CGFloat,
        now: TimeInterval,
        bounds: CGRect,
        mowerPos: CGPoint
    ) {
        for i in skunks.indices {
            skunks[i].position.x += skunks[i].velocity.dx * delta
            skunks[i].position.y += skunks[i].velocity.dy * delta

            // Alarm rises when mower is close
            let dx = skunks[i].position.x - mowerPos.x
            let dy = skunks[i].position.y - mowerPos.y
            let d  = sqrt(dx * dx + dy * dy)
            skunks[i].alarm = max(0, min(1, (200 - d) / 200))

            // Change direction periodically, faster if alarmed
            if now >= skunks[i].changeDirAt {
                let angle = CGFloat.random(in: 0..<(2 * .pi))
                let speed: CGFloat = 30 + skunks[i].alarm * 60
                skunks[i].velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
                let nextIn = skunks[i].alarm > 0.5 ? Double.random(in: 0.3...0.8) : Double.random(in: 1.5...3.0)
                skunks[i].changeDirAt = now + nextIn
            }

            // Bounds clamp
            skunks[i].position.x = max(bounds.minX, min(bounds.maxX, skunks[i].position.x))
            skunks[i].position.y = max(bounds.minY, min(bounds.maxY, skunks[i].position.y))
        }
    }
}
```

- [ ] **Step 3: Wire skunks into GoonGameScene**

Add to `GoonGameScene.swift`:

```swift
var skunks: [GoonSkunk] = []

private func placeSkunks() {
    skunks.removeAll()
    let now = lastUpdate ?? 0
    for _ in 0..<config.skunks {
        skunks.append(
            GoonSkunk(
                position: randomLawnPosition(),
                velocity: .zero,
                alarm: 0,
                changeDirAt: now + 0.5
            )
        )
    }
}
```

Call from `startLevel`. Add to `tickGameLogic` (after crickets):

```swift
GoonHazards.tickSkunks(&skunks, delta: deltaSeconds, now: now, bounds: bounds, mowerPos: mower.position)
```

Skunks don't damage the mower — they just wander menacingly. (Web parity: skunks aren't hit-target, they're visual hazard.)

- [ ] **Step 4: Run tests, expect green**

- [ ] **Step 5: Commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/GoonLevels.swift \
        ios/BandMusicGames/Views/Games/Goon/GoonHazards.swift \
        ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift \
        ios/BandMusicGamesTests/Goon/GoonHazardsTests.swift
git commit -m "feat(goon): skunk wander AI with alarm proximity behavior"
```

---

### Task 14: Render hazards every frame

**Files:**
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`

- [ ] **Step 1: Add per-frame entity sprite layer**

In `GoonGameScene.swift`, add a separate `entitiesLayer` for things that move:

```swift
private let entitiesLayer = SKNode()

// In didMove(to:), add:
if entitiesLayer.parent == nil {
    addChild(entitiesLayer)
}
```

Replace the previous `drawEntities()` with an entity sync that runs each tick:

```swift
private func syncEntityNodes() {
    entitiesLayer.removeAllChildren()

    // Gas cans
    for can in gasCans where !can.collected {
        let node = GoonRenderer.sprite(
            named: "gas-can",
            size: CGSize(width: 24, height: 24),
            fallbackColor: SKColor(red: 0.87, green: 0.13, blue: 0.13, alpha: 1)
        )
        node.position = can.position
        node.zPosition = 5
        entitiesLayer.addChild(node)
    }
    // Stumps
    for s in stumps where !s.dug {
        let node = GoonRenderer.sprite(
            named: s.progress > 0.5 ? "stump-half" : "stump-full",
            size: CGSize(width: 28, height: 28),
            fallbackColor: SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1)
        )
        node.position = s.position
        node.zPosition = 6
        entitiesLayer.addChild(node)
    }
    // Crickets
    for c in crickets {
        let node = GoonRenderer.sprite(
            named: "cricket-idle",
            size: CGSize(width: 14, height: 14),
            fallbackColor: SKColor(red: 0.13, green: 0.55, blue: 0.13, alpha: 1)
        )
        node.position = c.position
        node.zPosition = 7
        entitiesLayer.addChild(node)
    }
    // Skunks
    for s in skunks {
        let node = GoonRenderer.sprite(
            named: "skunk-walk-1",
            size: CGSize(width: 20, height: 20),
            fallbackColor: SKColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)
        )
        node.position = s.position
        node.zPosition = 7
        entitiesLayer.addChild(node)
    }
}
```

Call `syncEntityNodes()` at the end of `tickGameLogic` (when phase == .playing).

- [ ] **Step 2: Build**

Expected: green.

- [ ] **Step 3: Commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift
git commit -m "feat(goon): per-frame entity node rendering layer"
```

---

## Phase 6 — Phase UI overlays

### Task 15: HUD overlay (gas/cut/goal/score)

**Files:**
- Create: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/Overlays/GoonHUDOverlay.swift`
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameView.swift`

- [ ] **Step 1: Create the HUD overlay**

Create `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/Overlays/GoonHUDOverlay.swift`:

```swift
import SwiftUI

struct GoonHUDOverlay: View {
    @ObservedObject var scene: GoonGameScene

    var body: some View {
        VStack {
            HStack(spacing: 16) {
                gasBar
                cutText
                goalText
                Spacer()
                scoreText
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.80))
            Spacer()
        }
    }

    private var gasBar: some View {
        HStack(spacing: 6) {
            Text("GAS").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            ZStack(alignment: .leading) {
                Capsule().fill(Color(white: 0.13)).frame(width: 56, height: 7)
                Capsule()
                    .fill(gasColor)
                    .frame(width: max(0, 56 * gasFrac), height: 7)
            }
        }
    }

    private var cutText: some View {
        HStack(spacing: 4) {
            Text("CUT").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            Text("\(Int(scene.grid.cutPercentage * 100))%").font(.system(size: 12, design: .monospaced)).foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.0))
        }
    }

    private var goalText: some View {
        HStack(spacing: 4) {
            Text("GOAL").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            Text("\(Int(scene.config.win * 100))%").font(.system(size: 12, design: .monospaced)).foregroundColor(.gray)
        }
    }

    private var scoreText: some View {
        HStack(spacing: 4) {
            Text("SCORE").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            Text("\(scene.score)").font(.system(size: 12, design: .monospaced)).foregroundColor(.white)
        }
    }

    private var gasFrac: Double { scene.gas / scene.config.gasMax }
    private var gasColor: Color {
        if gasFrac > 0.5 { return Color(red: 0.0, green: 0.8, blue: 0.27) }
        if gasFrac > 0.25 { return Color(red: 1.0, green: 0.67, blue: 0.0) }
        return Color(red: 1.0, green: 0.2, blue: 0.2)
    }
}
```

- [ ] **Step 2: Add to GoonGameView**

In `GoonGameView.swift`, add the HUD overlay above the control overlay:

```swift
if scene.phase == .playing {
    GoonHUDOverlay(scene: scene)
        .ignoresSafeArea(.container, edges: .bottom)
    GoonControlOverlay(input: scene.input)
        .ignoresSafeArea()
}
```

- [ ] **Step 3: Build, commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/Overlays/GoonHUDOverlay.swift \
        ios/BandMusicGames/Views/Games/Goon/GoonGameView.swift
git commit -m "feat(goon): HUD overlay (gas/cut/goal/score)"
```

---

### Task 16: Title overlay + level picker

**Files:**
- Create: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/Overlays/GoonTitleOverlay.swift`
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameView.swift`

- [ ] **Step 1: Create the title overlay**

Create `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/Overlays/GoonTitleOverlay.swift`:

```swift
import SwiftUI

struct GoonTitleOverlay: View {
    @ObservedObject var scene: GoonGameScene
    let onStart: (Int) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("GRASS CUTTER")
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.0))
                    .tracking(4)
                Text("✦ 2003 EDITION ✦")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Color(red: 0.55, green: 0.77, blue: 0.29))
                    .tracking(3)

                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { n in
                        let locked = n > GoonGameScene.savedLevel
                        Button {
                            guard !locked else { return }
                            onStart(n)
                        } label: {
                            Text("\(n)")
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundColor(locked ? .gray : .black)
                                .frame(width: 50, height: 50)
                                .background(locked ? Color(white: 0.15) : Color(red: 1.0, green: 0.8, blue: 0.0))
                                .cornerRadius(8)
                        }
                        .disabled(locked)
                    }
                }
                .padding(.top, 12)

                Text(currentSub)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
        }
    }

    private var currentSub: String {
        let n = GoonGameScene.savedLevel
        return GoonLevels.all[n - 1].sub
    }
}
```

- [ ] **Step 2: Wire into GoonGameView**

In `GoonGameView.swift`, add the title overlay path. Replace the body's `ZStack` content:

```swift
ZStack {
    Color(hex: "#0a1a0a").ignoresSafeArea()
    SpriteView(scene: scene, options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes])
        .ignoresSafeArea()

    switch scene.phase {
    case .title:
        GoonTitleOverlay(scene: scene) { n in scene.startLevel(n) }
    case .playing:
        GoonHUDOverlay(scene: scene)
            .ignoresSafeArea(.container, edges: .bottom)
        GoonControlOverlay(input: scene.input)
            .ignoresSafeArea()
    case .levelComplete, .gameOver, .win:
        // Placeholder until Task 17
        EmptyView()
    }
    closeButton
}
.onAppear { scene.activate() }
.onDisappear { scene.deactivate() }
```

(Remove the `scene.startLevel(GoonGameScene.savedLevel)` from `.onAppear` — let the title screen drive level selection.)

- [ ] **Step 3: Build, commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/Overlays/GoonTitleOverlay.swift \
        ios/BandMusicGames/Views/Games/Goon/GoonGameView.swift
git commit -m "feat(goon): title overlay with level picker (locked beyond saved progress)"
```

---

### Task 17: Level complete, game over, win cards

**Files:**
- Create: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/Overlays/GoonLevelCompleteCard.swift`
- Create: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/Overlays/GoonGameOverCard.swift`
- Create: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/Overlays/GoonWinCard.swift`
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameView.swift`

- [ ] **Step 1: Create level-complete card**

Create `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/Overlays/GoonLevelCompleteCard.swift`:

```swift
import SwiftUI

struct GoonLevelCompleteCard: View {
    let level: Int
    let onNext: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("LEVEL \(level)\nCOMPLETE")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.0))
                    .multilineTextAlignment(.center)
                Button(action: onNext) {
                    Text(level >= 5 ? "FINISH" : "NEXT LEVEL")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color(red: 1.0, green: 0.8, blue: 0.0))
                        .cornerRadius(10)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Create game-over card**

Create `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/Overlays/GoonGameOverCard.swift`:

```swift
import SwiftUI

struct GoonGameOverCard: View {
    let onRetry: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("OUT OF GAS")
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.2, blue: 0.2))
                HStack(spacing: 14) {
                    Button(action: onRetry) {
                        Text("RETRY")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 22).padding(.vertical, 12)
                            .background(Color(red: 1.0, green: 0.8, blue: 0.0))
                            .cornerRadius(8)
                    }
                    Button(action: onMenu) {
                        Text("MENU")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 22).padding(.vertical, 12)
                            .background(Color(white: 0.15))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Create win card**

Create `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/Overlays/GoonWinCard.swift`:

```swift
import SwiftUI

struct GoonWinCard: View {
    let onReplay: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(spacing: 22) {
                Text("YOU WON")
                    .font(.system(size: 40, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.0))
                    .tracking(4)
                Text("✦ THE FINAL YARD CONQUERED ✦")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(red: 0.55, green: 0.77, blue: 0.29))
                Button(action: onReplay) {
                    Text("REPLAY (RESETS PROGRESS)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 26).padding(.vertical, 13)
                        .background(Color(red: 1.0, green: 0.8, blue: 0.0))
                        .cornerRadius(10)
                }
            }
        }
    }
}
```

- [ ] **Step 4: Wire into GoonGameView**

Replace the placeholder `EmptyView()` in `GoonGameView.swift`:

```swift
case .levelComplete:
    GoonLevelCompleteCard(level: scene.levelNum) { scene.nextLevel() }
case .gameOver:
    GoonGameOverCard(
        onRetry: { scene.retry() },
        onMenu:  { scene.resetAndReturnToTitle() }
    )
case .win:
    GoonWinCard { scene.replayFromWin() }
```

- [ ] **Step 5: Build, commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/Overlays/GoonLevelCompleteCard.swift \
        ios/BandMusicGames/Views/Games/Goon/Overlays/GoonGameOverCard.swift \
        ios/BandMusicGames/Views/Games/Goon/Overlays/GoonWinCard.swift \
        ios/BandMusicGames/Views/Games/Goon/GoonGameView.swift
git commit -m "feat(goon): level-complete / game-over / win cards"
```

---

### Task 18: Shake-to-back gesture

**Files:**
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameView.swift`

- [ ] **Step 1: Add shake-detection wrapper**

In `GoonGameView.swift`, append at the bottom of the file:

```swift
import UIKit

private struct ShakeDetector: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeController {
        let vc = ShakeController()
        vc.onShake = onShake
        return vc
    }

    func updateUIViewController(_ uiViewController: ShakeController, context: Context) {
        uiViewController.onShake = onShake
    }

    final class ShakeController: UIViewController {
        var onShake: () -> Void = {}
        override var canBecomeFirstResponder: Bool { true }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            becomeFirstResponder()
        }
        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            if motion == .motionShake { onShake() }
        }
    }
}
```

In the body, add a `.background(ShakeDetector { dismiss() })`:

```swift
ZStack { ... }
    .background(ShakeDetector { dismiss() })
    .onAppear { ... }
```

- [ ] **Step 2: Build, commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/GoonGameView.swift
git commit -m "feat(goon): shake-to-back gesture (parity with web)"
```

---

## Phase 7 — Audio

### Task 19: AVAudioEngine + mower drone

**Files:**
- Create: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonAudio.swift`
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`

- [ ] **Step 1: Create the audio engine**

Create `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonAudio.swift`:

```swift
import AVFoundation
import AVFAudio

@MainActor
final class GoonAudio {
    private let engine = AVAudioEngine()
    private var mowerSrc: AVAudioSourceNode?
    private var mowerMixer = AVAudioMixerNode()
    private var mowerPhase: Double = 0
    private var mowerFreq: Double = 88
    private let sampleRate: Double

    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        sampleRate = engine.outputNode.inputFormat(forBus: 0).sampleRate.isZero
            ? 48000
            : engine.outputNode.inputFormat(forBus: 0).sampleRate
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        let src = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for buffer in ablPointer {
                let buf = buffer.mData!.bindMemory(to: Float.self, capacity: Int(frameCount))
                for i in 0..<Int(frameCount) {
                    self.mowerPhase += 2.0 * .pi * self.mowerFreq / self.sampleRate
                    if self.mowerPhase > 2 * .pi { self.mowerPhase -= 2 * .pi }
                    // Sawtooth + soft clip
                    let raw = (self.mowerPhase / .pi) - 1.0
                    let dist = tanh(Float(raw) * 4)
                    buf[i] = dist * 0.08
                }
            }
            return noErr
        }
        engine.attach(src)
        engine.attach(mowerMixer)
        engine.connect(src, to: mowerMixer, format: format)
        engine.connect(mowerMixer, to: engine.mainMixerNode, format: format)
        mowerMixer.outputVolume = 0
        mowerSrc = src

        do { try engine.start() } catch { print("GoonAudio engine start failed: \(error)") }
    }

    func startMower() { mowerMixer.outputVolume = 1.0 }
    func stopMower()  { mowerMixer.outputVolume = 0.0 }

    func setMowerPitch(velocity: CGFloat) {
        let mag = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        let normalized = min(1.0, mag / 4.0)
        mowerFreq = 88 + Double(normalized) * 52   // 88 → 140 Hz
    }

    func stop() {
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
```

- [ ] **Step 2: Wire into GoonGameScene**

In `GoonGameScene.swift`, add:

```swift
var audio: GoonAudio?

func activate() {
    if audio == nil { audio = GoonAudio() }
}

func deactivate() {
    audio?.stop()
    audio = nil
}
```

In `tickGameLogic`, update the mower's audio after the velocity update:

```swift
audio?.setMowerPitch(velocity: mower.velocity)
```

In `startLevel(_:)`, add at the bottom:

```swift
audio?.startMower()
```

In phase transitions to `.levelComplete`, `.gameOver`, `.win`, stop the mower:

```swift
// Inside tickGameLogic, when gas <= 0:
phase = .gameOver
audio?.stopMower()
return

// And in the win-threshold branch:
audio?.stopMower()
```

- [ ] **Step 3: Build, commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/GoonAudio.swift \
        ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift
git commit -m "feat(goon): procedural mower drone via AVAudioEngine"
```

---

### Task 20: One-shot procedural SFX

**Files:**
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonAudio.swift`
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`

- [ ] **Step 1: Add one-shot SFX methods**

Append to `GoonAudio.swift`:

```swift
extension GoonAudio {
    /// Play a quick envelope on a fresh AVAudioPlayerNode-style impulse.
    private func playEnvelope(freq: Double, durationMs: Int, type: WaveType, volume: Float) {
        let frames = AVAudioFrameCount(sampleRate * Double(durationMs) / 1000.0)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let ch = buffer.floatChannelData![0]
        var phase = 0.0
        for i in 0..<Int(frames) {
            phase += 2.0 * .pi * freq / sampleRate
            if phase > 2 * .pi { phase -= 2 * .pi }
            let env = expEnvelope(i: i, total: Int(frames))
            let sample: Double
            switch type {
            case .sine:     sample = sin(phase)
            case .sawtooth: sample = (phase / .pi) - 1
            case .square:   sample = phase < .pi ? 1 : -1
            }
            ch[i] = Float(sample) * env * volume
        }

        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        player.scheduleBuffer(buffer, at: nil, options: []) { [weak self, weak player] in
            DispatchQueue.main.async {
                guard let self, let player else { return }
                self.engine.detach(player)
            }
        }
        player.play()
    }

    private func expEnvelope(i: Int, total: Int) -> Float {
        let attackFrames = total / 8
        let releaseFrames = total - attackFrames
        if i < attackFrames {
            return Float(i) / Float(attackFrames)
        }
        let t = Float(i - attackFrames) / Float(releaseFrames)
        return Float(exp(-Double(t * 4)))
    }

    enum WaveType { case sine, sawtooth, square }

    func playCut()           { playEnvelope(freq: 180, durationMs: 60,  type: .square,   volume: 0.10) }
    func playPickup()        { playEnvelope(freq: 660, durationMs: 220, type: .sine,     volume: 0.12) }
    func playDig()           { playEnvelope(freq: 90,  durationMs: 80,  type: .sawtooth, volume: 0.14) }
    func playCricketHit()    { playEnvelope(freq: 110, durationMs: 150, type: .square,   volume: 0.16) }
    func playLevelComplete() { playEnvelope(freq: 880, durationMs: 600, type: .sine,     volume: 0.14) }
    func playGameOver()      { playEnvelope(freq: 110, durationMs: 700, type: .sawtooth, volume: 0.16) }
}
```

- [ ] **Step 2: Trigger SFX from game events**

In `GoonGameScene.swift`'s `tickGameLogic`:

- After a successful `cuts > 0`: `audio?.playCut()`
- After a gas-can pickup: `audio?.playPickup()`
- When a stump's `progress >= 1.0`: `audio?.playDig()`
- When `gas -= 30` from cricket hit: `audio?.playCricketHit()`
- On `phase = .levelComplete`: `audio?.playLevelComplete()`
- On `phase = .gameOver`: `audio?.playGameOver()`

- [ ] **Step 3: Build, commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/GoonAudio.swift \
        ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift
git commit -m "feat(goon): six one-shot procedural SFX wired to game events"
```

---

### Task 21: Spotify integration (best-effort)

**Files:**
- Modify: `bandmusicgames/ios/BandMusicGames/Views/Games/Goon/GoonGameView.swift`

- [ ] **Step 1: Start track in onAppear, pause on dismiss**

In `GoonGameView.swift`'s `.onAppear`:

```swift
.onAppear {
    scene.activate()
    if auth.accessToken != nil {
        Task { await auth.playTrack("spotify:track:6EJAb3oTjDFwrt1dpIJPbr") }
    }
}
.onDisappear {
    scene.deactivate()
    Task { await auth.pausePlayback() }
}
```

- [ ] **Step 2: Build, commit**

```bash
git add ios/BandMusicGames/Views/Games/Goon/GoonGameView.swift
git commit -m "feat(goon): best-effort Spotify track playback during play"
```

---

## Phase 8 — Sprite assets

### Task 22: Write PROMPTS.md

**Files:**
- Create: `bandmusicgames/ios/BandMusicGames/Resources/Sprites/Goon/PROMPTS.md`

- [ ] **Step 1: Create the prompts catalog**

Create `bandmusicgames/ios/BandMusicGames/Resources/Sprites/Goon/PROMPTS.md`:

```markdown
# Goon Sprite Prompts

**Canonical style prefix** (paste before every individual prompt):

> 2003-era chunky pixel art, top-down 3/4 view, no anti-aliasing, saturated retro colors (greens #2d7a2d / #45b045 / #8bc44a, mower yellow #ffcc00, stripe orange #ff8800, gas can red #dd2222), transparent background, sharp pixel edges, sprite-sheet style for arcade lawn-mowing game.

---

## Mower (`mower.atlas/`)

### mower-body.png — 56×56
Top-down lawn mower chassis only, yellow body with orange diagonal stripes, no wheels, no blade. Centered on transparent background. Square base, symmetric so the sprite can rotate.

### mower-blade-{1..4}.png — 56×56
Spinning circular blade overlay (separate from chassis). Frame 1: blade horizontal. Frame 2: 22° rotated. Frame 3: 45°. Frame 4: 67°. Translucent motion blur, silver with hint of green grass shred.

### mower-wheels-{1..3}.png — 56×56
Three frames of mower wheels in motion, top-down. Two visible black tires with white-rim hubs. Frame 1: hubs aligned. Frame 2: hubs rotated 30°. Frame 3: hubs rotated 60°.

---

## Cricket (`cricket.atlas/`)

### cricket-idle.png — 16×16
Cute pixel-art cricket, dark green, top-down, sitting still. Two antennae visible.

### cricket-hop-{1..4}.png — 16×16
Four-frame hop animation. Frame 1: crouched. Frame 2: mid-jump (legs extended). Frame 3: peak of jump. Frame 4: landing crouch.

---

## Skunk (`skunk.atlas/`)

### skunk-walk-{1..4}.png — 24×24
Four-frame walk cycle, top-down. Black body with white stripe down the back. Frame 1: legs neutral. Frame 2: legs forward. Frame 3: legs neutral. Frame 4: legs back.

### skunk-alarmed.png — 24×24
Same skunk but tail raised straight up, body slightly puffed. Top-down.

---

## Stump (`stump.atlas/`)

### stump-full.png — 32×32
Top-down view of a tree stump, brown cross-section with rings visible. Small grass tufts around base.

### stump-half.png — 32×32
Same stump partly dug, exposed dirt ring around it, slight tilt suggesting it's been pulled.

### stump-hole.png — 32×32
Empty hole in dirt where stump was. Optional: tiny debris.

---

## Tiles (`tiles.atlas/`)

### tile-tall-{1..3}.png — 32×32 each
Three variants of tall grass tile. Dark green (#2d7a2d) base with brighter blades (#45b045) sticking up at slight angles. Each variant has subtly different blade arrangement.

### tile-cut-{1..3}.png — 32×32 each
Three variants of mowed grass. Pale green (#8bc44a) with horizontal mower-stripe patterns. Variants have stripes at different angles.

### tile-transition.png — 32×32
Half tall, half cut — a "currently being mowed" tile.

### tile-house-roof.png — 32×32
Top-down roof tile, brown shingles with slight texture variation.

### tile-house-wall.png — 32×32
Top-down house wall tile, beige with subtle siding pattern.

### tile-house-corner.png — 32×32
Corner tile combining roof + wall edges (for 9-slice composition).

### tile-garden-{1..3}.png — 32×32 each
Three variants of garden bed tile. Dark soil base with colorful flowers (pink, purple, yellow). Variants have different flower arrangements.

---

## Items

### gas-can.png — 32×32
Top-down red gasoline can, classic 2-gallon shape. White "GAS" stencil on side. Subtle gold glow rim suggesting collectability.

---

## FX (`fx.atlas/`)

### clipping.png — 4×4
Tiny grass clipping, bright green pixel speck for particle emission.

### dust.png — 8×8
Brown dust puff for digging effects.

### spark.png — 8×8
Gold radial glow for gas can pickup.

---

## UI (`ui/`)

### goon-title-logo.png — 800×200
"GRASS CUTTER 2003" pixel-art title banner. Yellow with thick black outline, drop shadow. Slight perspective tilt for arcade-marquee feel.

### goon-gameover.png — 400×100
"OUT OF GAS" stamped lettering, red-orange with cracked-paint texture.

### goon-win-card.png — 600×400
Celebration art: mower in center with confetti, manicured lawn beneath, "YOU WON" yellow text above. Arcade-victory vibe.
```

- [ ] **Step 2: Add the empty atlas directories with .gitkeep**

```bash
mkdir -p ios/BandMusicGames/Resources/Sprites/Goon/{mower,cricket,skunk,stump,tiles,fx}.atlas
mkdir -p ios/BandMusicGames/Resources/Sprites/Goon/{raw,ui}
touch ios/BandMusicGames/Resources/Sprites/Goon/mower.atlas/.gitkeep \
      ios/BandMusicGames/Resources/Sprites/Goon/cricket.atlas/.gitkeep \
      ios/BandMusicGames/Resources/Sprites/Goon/skunk.atlas/.gitkeep \
      ios/BandMusicGames/Resources/Sprites/Goon/stump.atlas/.gitkeep \
      ios/BandMusicGames/Resources/Sprites/Goon/tiles.atlas/.gitkeep \
      ios/BandMusicGames/Resources/Sprites/Goon/fx.atlas/.gitkeep \
      ios/BandMusicGames/Resources/Sprites/Goon/ui/.gitkeep
echo "raw/" > ios/BandMusicGames/Resources/Sprites/Goon/.gitignore
```

- [ ] **Step 3: Commit**

```bash
git add ios/BandMusicGames/Resources/Sprites/Goon/
git commit -m "docs(goon): sprite prompt catalog + atlas folder scaffolding"
```

---

### Task 23: Wire generated atlases into the project (placeholder until user provides)

**Files:**
- Modify: `bandmusicgames/ios/project.yml`

- [ ] **Step 1: Verify Resources subfolder is picked up by XcodeGen**

Check `bandmusicgames/ios/project.yml` `sources` block. If it only includes `BandMusicGames`, the new `Resources/` folder under it should be picked up automatically (recursive). Verify by running:

```bash
cd ios && xcodegen generate
xcodebuild ... build 2>&1 | grep "Resources/Sprites/Goon" | head -3
```

If atlas folders aren't being copied into the .app bundle, add to project.yml:

```yaml
targets:
  BandMusicGames:
    sources:
      - path: BandMusicGames
        type: group
    resources:
      - path: BandMusicGames/Resources/Sprites/Goon
```

- [ ] **Step 2: Build & verify**

Run: `xcodebuild ... build` then check the .app bundle has Sprites:

```bash
ls /tmp/bmg-derived/Build/Products/Debug-iphonesimulator/BandMusicGames.app/Sprites/Goon/ 2>/dev/null
```

- [ ] **Step 3: Commit if project.yml changed**

```bash
git add ios/project.yml ios/BandMusicGames.xcodeproj
git commit -m "build(goon): ensure Sprites/Goon resources copy into .app bundle"
```

---

## Phase 9 — Verification & shipping

### Task 24: End-to-end manual playthrough + device install

**Files:** None — verification only.

- [ ] **Step 1: Run full test suite**

```bash
cd /Users/ashrocket/ashcode/bandmusicgames/ios
xcodebuild -project BandMusicGames.xcodeproj -scheme BandMusicGames \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/bmg-derived \
  test 2>&1 | tail -20
```

Expected: All Goon tests green (`GoonLevelsTests`, `GoonGridTests`, `GoonGameStateTests`, `GoonPickupsTests`, `GoonHazardsTests`).

- [ ] **Step 2: Signed device build**

```bash
xcodebuild \
  -project BandMusicGames.xcodeproj \
  -scheme BandMusicGames \
  -configuration Debug \
  -destination 'id=79298428-A366-52F3-A761-69840BC6A016' \
  -derivedDataPath /private/tmp/bmg-derived \
  -allowProvisioningUpdates \
  build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Install on Eine von Zwei**

```bash
xcrun devicectl device install app \
  --device 79298428-A366-52F3-A761-69840BC6A016 \
  /tmp/bmg-derived/Build/Products/Debug-iphoneos/BandMusicGames.app 2>&1 | tail -3
```

Expected: `App installed:`

- [ ] **Step 4: Manual playthrough checklist on device**

Open BandMusicGames → select "FOR CUTTING GRASS" on the jukebox → tap PLAY.

Verify each:

- [ ] Goon launches one-tap (no Spotify gate). Title screen with "GRASS CUTTER" + level picker.
- [ ] Level 1 picker shows only Level 1 unlocked. Tap "1".
- [ ] Joystick (bottom-left) drives the mower; HUD shows gas/cut/goal/score; close button (top-right) works.
- [ ] Mowing tall grass tiles turns them light green. CUT % rises.
- [ ] At 80%, Level 1 completes. "NEXT LEVEL" button appears.
- [ ] Level 2 spawns 2 gas cans (red). Driving over one refills the gas.
- [ ] Gas runs out → game over → RETRY or MENU works.
- [ ] Level 3 spawns 2 stumps. DIG button appears (bottom-right). Hold DIG near a stump → progress bar fills → stump disappears.
- [ ] Level 4 spawns 2 crickets + 1 skunk. Hitting a cricket deducts 30 gas.
- [ ] Level 5 needs 90% cut. Beating it shows the WIN card. REPLAY resets progress to Level 1.
- [ ] Kill the app from app switcher and relaunch — progress (highest unlocked level) persists.
- [ ] Spotify track plays during gameplay if connected; pauses when you close. SFX (cut, pickup, dig, hit) audible alongside.
- [ ] Mower drone is audible and pitches up when mower moves faster.
- [ ] Shake the device during gameplay → returns to jukebox.

- [ ] **Step 5: Commit shipping verification note (optional)**

If anything was tweaked during verification, commit those fixes. Otherwise:

```bash
echo "All Phase 1-9 tasks complete. See playthrough checklist." > /dev/null
```

---

## Self-Review Summary

**Spec coverage:**
- ✅ Section 1 (Architecture) → Tasks 1, 6, 23
- ✅ Section 2 (Data model + phases) → Tasks 2, 3, 4, 5
- ✅ Section 3 (Sprite assets) → Tasks 6 (renderer fallback), 14 (entity nodes), 22 (PROMPTS), 23 (bundle copy)
- ✅ Section 4 (Input + audio) → Tasks 7, 15, 18, 19, 20, 21
- ✅ Section 5 (Phase UI + testing + shipping) → Tasks 15, 16, 17, 24

**Notes / known gaps:**
- The `randomLawnPosition()` helper in Task 10 must check that gas cans don't collide with stumps; if implementing strictly in order, stump placement happens first (`placeStumps` called before `placeGasCans`) so the .stump grid cells will be skipped automatically.
- Level 1 grid generation uses a fixed house+garden footprint. The web game has a more elaborate Level 1 layout — if exact parity is required, port the JS `_buildLevel1Map` logic in a follow-up.
- The Hazard tests rely on `lastUpdate` being non-nil; consider initializing `lastUpdate = 0` in `startLevel` to make hop timing deterministic in tests.
- SwiftUI joystick uses absolute coordinates from `DragGesture.startLocation`. On iPad split-view this may need clamping; defer until issue is observed.

---

**Plan complete and saved to `docs/superpowers/plans/2026-05-15-goon-native-port.md`.**

Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
