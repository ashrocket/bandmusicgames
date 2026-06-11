# Storm Timing Cue + Flip Scouting Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the thumb-hidden green-circle shot-timing cue in Half Court Hero with a full-sky storm (darkens while charging, lightning + green sky during the release window, clouds part when too late), and restore the long-press flip-to-expand scouting cards on the character select screen.

**Architecture:** A new `StormSkyNode` (SpriteKit) sits in `courtLayer` at zPosition −5 — above the painted backdrop (−10), below players (40+) — and is driven every frame from the existing charge value via `setCharge(_:)`, exactly like `ShootButtonNode`. Stage mapping (`StormStage`) is a pure function so it's unit-testable. The scouting card is a SwiftUI overlay (`HeroScoutingOverlay`) ported from branch commit `ad132c3`, opened by long-press on the select-grid cards.

**Tech Stack:** Swift 5.10, SpriteKit + SwiftUI, XcodeGen (`ios/project.yml`), xcodebuild. No external deps added.

**Spec:** `docs/superpowers/specs/2026-06-11-storm-timing-cue-and-flip-cards-design.md`

---

## Build & test commands (used throughout)

All commands run from the **repo root** (`/Users/ashrocket/ashcode/bandmusicgames`).

```bash
# Regenerate the Xcode project after editing ios/project.yml (xcodegen is at /opt/homebrew/bin/xcodegen)
cd ios && xcodegen generate && cd ..

# Build (simulator, no signing needed)
xcodebuild -project ios/BandMusicGames.xcodeproj -scheme BandMusicGames \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO build

# Run unit tests (after Task 1 adds the test target)
xcodebuild -project ios/BandMusicGames.xcodeproj -scheme BandMusicGames \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

Builds take a few minutes; that's normal. `** BUILD SUCCEEDED **` / `** TEST SUCCEEDED **` are the pass markers.

**Key existing code facts:**

- `ios/BandMusicGames/Views/Games/HalfCourtHero/HalfCourtHeroScene.swift` — tuning block at lines 17–28 (`chargeRate` line 23, `greenLow`/`greenHigh`/`perfectLow`/`perfectHigh` lines 24–27); node vars around line 53; `buildCourt()` at line 212 (called from `layoutScene()` on every size change, starts with `courtLayer.removeAllChildren()` — so storm node is recreated there, like the backdrop); `updateCharge(_:)` line 542; `cancelCharge()` line 552. The scene's anchor is bottom-left; all geometry is absolute in scene coords.
- `ios/BandMusicGames/Views/Games/LizzyMcGuireGameView.swift` — SwiftUI shell. State vars lines 9–11; phase overlays in `body` lines 23–27; instructions text line 98; select header VStack lines 129–141; grid card Button lines 153–188 (`.disabled(disabled)` at 188); `HalfCourtHeroBadge` already defined at line 221.
- `ios/BandMusicGames/Views/Games/HalfCourtHero/HalfCourtHeroTypes.swift` — `HalfCourtHeroID` enum line 120, `HalfCourtHero` struct line 210. No `special` property exists (that was old-branch-only).
- `HapticManager` API (already used in the scene): `.impact(.light/.medium/.rigid/.heavy)`, `.selection()`, `.notification(...)`.
- `Color(hex:)` extension lives in `ios/BandMusicGames/Models/Song.swift`.
- TestFlight CI archives with `-scheme BandMusicGames` (`scripts/upload-testflight.sh` line 7) — the scheme name must not change.

---

### Task 1: Add unit-test target scaffold

The project has no test target. Add one via XcodeGen with a smoke test, so later tasks have a harness. The XcodeGen `scheme.testTargets` setting on the app target keeps the scheme name `BandMusicGames` (CI-safe) while wiring tests into it.

**Files:**
- Modify: `ios/project.yml`
- Create: `ios/BandMusicGamesTests/SmokeTests.swift`
- Regenerate: `ios/BandMusicGames.xcodeproj` (via xcodegen; commit the regenerated pbxproj)

- [ ] **Step 1: Add the test target and scheme to project.yml**

In `ios/project.yml`, inside the existing `BandMusicGames` target (after its `settings:` block, at the same indent level as `settings:`), add:

```yaml
    scheme:
      testTargets:
        - BandMusicGamesTests
```

Then at the bottom of the `targets:` map (same indent as `BandMusicGames:`), add:

```yaml
  BandMusicGamesTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "16.0"
    sources:
      - path: BandMusicGamesTests
    dependencies:
      - target: BandMusicGames
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.party.bandmusicgames.app.tests
        SWIFT_VERSION: "5.10"
        GENERATE_INFOPLIST_FILE: "YES"
```

- [ ] **Step 2: Create the smoke test**

Create `ios/BandMusicGamesTests/SmokeTests.swift`:

```swift
import XCTest

final class SmokeTests: XCTestCase {
    func testHarnessRuns() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 3: Regenerate the project and run the tests**

```bash
cd ios && xcodegen generate && cd ..
xcodebuild -project ios/BandMusicGames.xcodeproj -scheme BandMusicGames \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

Expected: `** TEST SUCCEEDED **` with `testHarnessRuns` passing.

- [ ] **Step 4: Commit**

```bash
git add ios/project.yml ios/BandMusicGamesTests/SmokeTests.swift ios/BandMusicGames.xcodeproj
git commit -m "test: add BandMusicGamesTests unit-test target via xcodegen"
```

---

### Task 2: StormStage pure stage-mapping (TDD)

The charge→stage mapping is the testable heart of the storm. It must match `shotError()`'s window semantics exactly: green is inclusive (`charge >= greenLow && charge <= greenHigh`), perfect is inclusive, parted is `charge > greenHigh`.

**Files:**
- Test: `ios/BandMusicGamesTests/StormStageTests.swift`
- Create: `ios/BandMusicGames/Views/Games/HalfCourtHero/StormSkyNode.swift` (StormStage enum only in this task)

- [ ] **Step 1: Write the failing tests**

Create `ios/BandMusicGamesTests/StormStageTests.swift`:

```swift
import XCTest
@testable import BandMusicGames

final class StormStageTests: XCTestCase {
    // Mirrors the scene's tuning block: greenLow 0.50, greenHigh 0.80,
    // perfectLow 0.60, perfectHigh 0.70.
    private func stage(_ charge: CGFloat?) -> StormStage {
        StormStage.stage(charge: charge, greenLow: 0.50, greenHigh: 0.80,
                         perfectLow: 0.60, perfectHigh: 0.70)
    }

    func testNilChargeIsClear() {
        XCTAssertEqual(stage(nil), .clear)
    }

    func testZeroChargeIsBuildingWithZeroProgress() {
        XCTAssertEqual(stage(0), .building(progress: 0))
    }

    func testHalfwayToWindowIsBuildingHalf() {
        XCTAssertEqual(stage(0.25), .building(progress: 0.5))
    }

    func testWindowEntryIsGreenNotPerfect() {
        XCTAssertEqual(stage(0.50), .green(perfect: false))
    }

    func testPerfectZoneBoundsMatchShotError() {
        XCTAssertEqual(stage(0.60), .green(perfect: true))
        XCTAssertEqual(stage(0.65), .green(perfect: true))
        XCTAssertEqual(stage(0.70), .green(perfect: true))
        XCTAssertEqual(stage(0.71), .green(perfect: false))
    }

    func testWindowTopIsStillGreen() {
        XCTAssertEqual(stage(0.80), .green(perfect: false))
    }

    func testPastWindowIsParted() {
        XCTAssertEqual(stage(0.81), .parted)
        XCTAssertEqual(stage(1.18), .parted)
    }

    func testKindsDistinguishStagesIgnoringValues() {
        XCTAssertEqual(stage(0.1).kind, stage(0.4).kind)
        XCTAssertNotEqual(stage(0.4).kind, stage(0.55).kind)
        XCTAssertNotEqual(stage(0.55).kind, stage(0.9).kind)
        XCTAssertNotEqual(stage(nil).kind, stage(0.1).kind)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -project ios/BandMusicGames.xcodeproj -scheme BandMusicGames \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

Expected: FAIL — compile error `cannot find 'StormStage' in scope`.

- [ ] **Step 3: Implement StormStage**

Create `ios/BandMusicGames/Views/Games/HalfCourtHero/StormSkyNode.swift`:

```swift
import SpriteKit

/// Pure mapping from the SHOOT charge value to a storm visual stage.
/// Window semantics must match HalfCourtHeroScene.shotError(): green and
/// perfect bounds are inclusive; past greenHigh the window is gone.
enum StormStage: Equatable {
    case clear
    case building(progress: CGFloat)   // 0...1 — how close the window is
    case green(perfect: Bool)
    case parted

    static func stage(charge: CGFloat?,
                      greenLow: CGFloat, greenHigh: CGFloat,
                      perfectLow: CGFloat, perfectHigh: CGFloat) -> StormStage {
        guard let c = charge else { return .clear }
        if c > greenHigh { return .parted }
        if c >= greenLow { return .green(perfect: c >= perfectLow && c <= perfectHigh) }
        return .building(progress: max(0, min(1, c / greenLow)))
    }

    /// Stage identity ignoring associated values — for one-shot transitions.
    var kind: Int {
        switch self {
        case .clear: return 0
        case .building: return 1
        case .green: return 2
        case .parted: return 3
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Same command as Step 2. Expected: `** TEST SUCCEEDED **`, all 8 StormStage tests passing.

- [ ] **Step 5: Commit**

```bash
git add ios/BandMusicGamesTests/StormStageTests.swift ios/BandMusicGames/Views/Games/HalfCourtHero/StormSkyNode.swift
git commit -m "feat: StormStage charge-to-storm stage mapping with tests"
```

---

### Task 3: StormSkyNode visuals

The SpriteKit node that renders the stages: two gradient cloud halves (so "clouds part" is a free split animation), a green wash over the sky, and a one-shot procedural lightning bolt + thunder haptic on window entry. Visual code — verified by build here, by eye in Task 5.

**Files:**
- Modify: `ios/BandMusicGames/Views/Games/HalfCourtHero/StormSkyNode.swift` (append below StormStage)

- [ ] **Step 1: Append the node implementation**

Add to the bottom of `StormSkyNode.swift`:

```swift
/// Full-sky storm mirroring the SHOOT charge meter, so shot timing is readable
/// with a thumb covering the button: the sky darkens while charging, lightning
/// strikes and the sky turns green for the release window, and the clouds part
/// once the window has passed.
final class StormSkyNode: SKNode {
    private let sceneSize: CGSize
    private let greenLow: CGFloat
    private let greenHigh: CGFloat
    private let perfectLow: CGFloat
    private let perfectHigh: CGFloat

    private let leftCloud: SKSpriteNode
    private let rightCloud: SKSpriteNode
    private let greenWash: SKSpriteNode
    private var lastKind = StormStage.clear.kind

    private let maxDim: CGFloat = 0.5

    init(size: CGSize,
         greenLow: CGFloat, greenHigh: CGFloat,
         perfectLow: CGFloat, perfectHigh: CGFloat) {
        self.sceneSize = size
        self.greenLow = greenLow
        self.greenHigh = greenHigh
        self.perfectLow = perfectLow
        self.perfectHigh = perfectHigh

        let halfSize = CGSize(width: max(1, size.width / 2), height: max(1, size.height))
        let texture = Self.cloudGradientTexture(size: halfSize)
        leftCloud = SKSpriteNode(texture: texture, size: halfSize)
        rightCloud = SKSpriteNode(texture: texture, size: halfSize)
        greenWash = SKSpriteNode(
            color: SKColor(red: 0.2, green: 0.83, blue: 0.2, alpha: 1),
            size: CGSize(width: size.width, height: size.height * 0.7)
        )
        super.init()

        leftCloud.position = CGPoint(x: size.width * 0.25, y: size.height * 0.5)
        rightCloud.position = CGPoint(x: size.width * 0.75, y: size.height * 0.5)
        greenWash.position = CGPoint(x: size.width * 0.5, y: size.height * 0.65)
        greenWash.zPosition = 1
        leftCloud.alpha = 0
        rightCloud.alpha = 0
        greenWash.alpha = 0
        addChild(leftCloud)
        addChild(rightCloud)
        addChild(greenWash)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// nil clears the sky; 0...1.18 drives the storm. Call every frame the
    /// charge changes, plus once with nil on release/cancel.
    func setCharge(_ charge: CGFloat?) {
        let stage = StormStage.stage(charge: charge,
                                     greenLow: greenLow, greenHigh: greenHigh,
                                     perfectLow: perfectLow, perfectHigh: perfectHigh)
        let entered = stage.kind != lastKind
        lastKind = stage.kind

        switch stage {
        case .clear:
            if entered { fadeOutAndRecenter() }
        case .building(let progress):
            if entered { resetForNewCharge() }
            let dim = maxDim * progress * progress   // eased — storm accelerates in
            leftCloud.alpha = dim
            rightCloud.alpha = dim
        case .green(let perfect):
            if entered {
                strikeLightning()
                HapticManager.impact(.heavy)   // thunder — feel the window open
            }
            leftCloud.alpha = maxDim
            rightCloud.alpha = maxDim
            greenWash.alpha = perfect ? 0.40 : 0.28
        case .parted:
            if entered { partClouds() }
        }
    }

    private func resetForNewCharge() {
        removeAllActions()
        for node in [leftCloud, rightCloud, greenWash] { node.removeAllActions() }
        leftCloud.position = CGPoint(x: sceneSize.width * 0.25, y: sceneSize.height * 0.5)
        rightCloud.position = CGPoint(x: sceneSize.width * 0.75, y: sceneSize.height * 0.5)
        leftCloud.alpha = 0
        rightCloud.alpha = 0
        greenWash.alpha = 0
    }

    private func fadeOutAndRecenter() {
        for node in [leftCloud, rightCloud, greenWash] {
            node.removeAllActions()
            node.run(.fadeOut(withDuration: 0.15))
        }
        // Slide the halves back once invisible so the next charge starts centered.
        removeAllActions()
        run(.sequence([
            .wait(forDuration: 0.16),
            .run { [weak self] in
                guard let self else { return }
                self.leftCloud.position = CGPoint(x: self.sceneSize.width * 0.25,
                                                  y: self.sceneSize.height * 0.5)
                self.rightCloud.position = CGPoint(x: self.sceneSize.width * 0.75,
                                                   y: self.sceneSize.height * 0.5)
            },
        ]))
    }

    private func partClouds() {
        greenWash.removeAllActions()
        greenWash.run(.fadeOut(withDuration: 0.12))
        let slide = sceneSize.width * 0.55
        for (cloud, dx) in [(leftCloud, -slide), (rightCloud, slide)] {
            cloud.removeAllActions()
            let move = SKAction.moveBy(x: dx, y: 0, duration: 0.25)
            move.timingMode = .easeIn
            cloud.run(.group([move, .fadeOut(withDuration: 0.25)]))
        }
    }

    private func strikeLightning() {
        let path = CGMutablePath()
        var point = CGPoint(
            x: CGFloat.random(in: sceneSize.width * 0.2...sceneSize.width * 0.8),
            y: sceneSize.height
        )
        path.move(to: point)
        let segments = 4
        let drop = (sceneSize.height * 0.45) / CGFloat(segments)
        for _ in 0..<segments {
            point = CGPoint(x: point.x + CGFloat.random(in: -34...34), y: point.y - drop)
            path.addLine(to: point)
        }
        let bolt = SKShapeNode(path: path)
        bolt.strokeColor = SKColor(red: 1, green: 1, blue: 0.85, alpha: 1)
        bolt.lineWidth = 3
        bolt.glowWidth = 9
        bolt.lineCap = .round
        bolt.zPosition = 2
        addChild(bolt)
        bolt.run(.sequence([
            .fadeAlpha(to: 0.6, duration: 0.05),
            .fadeAlpha(to: 1.0, duration: 0.04),
            .fadeOut(withDuration: 0.18),
            .removeFromParent(),
        ]))
    }

    private static func cloudGradientTexture(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let colors = [UIColor.black.cgColor,
                          UIColor.black.withAlphaComponent(0.35).cgColor]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors as CFArray,
                                            locations: [0, 1]) else { return }
            // UIImage y=0 is the top; SKTexture maps image top to sprite top,
            // so this is darkest at the top of the sky.
            ctx.cgContext.drawLinearGradient(gradient,
                                             start: .zero,
                                             end: CGPoint(x: 0, y: size.height),
                                             options: [])
        }
        return SKTexture(image: image)
    }
}
```

- [ ] **Step 2: Build to verify it compiles (tests still pass)**

```bash
xcodebuild -project ios/BandMusicGames.xcodeproj -scheme BandMusicGames \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ios/BandMusicGames/Views/Games/HalfCourtHero/StormSkyNode.swift
git commit -m "feat: StormSkyNode storm visuals — gradient clouds, green wash, lightning"
```

---

### Task 4: Wire the storm into the scene + slow the charge

**Files:**
- Modify: `ios/BandMusicGames/Views/Games/HalfCourtHero/HalfCourtHeroScene.swift:23` (chargeRate), `:53-57` (node var), `:232` (buildCourt), `:542-556` (updateCharge/cancelCharge)
- Modify: `ios/BandMusicGames/Views/Games/LizzyMcGuireGameView.swift:98` (instructions text)

- [ ] **Step 1: Slow the charge so the sky has time to read**

In `HalfCourtHeroScene.swift` line 23, change:

```swift
    private let chargeRate: CGFloat = 1.4      // full meter in ~0.7s
```

to:

```swift
    private let chargeRate: CGFloat = 1.0      // full meter in ~1s — sky cue needs time to read
```

- [ ] **Step 2: Add the storm node var**

Below `private var shootButton: ShootButtonNode?` (line ~53), add:

```swift
    private var stormSky: StormSkyNode?
```

- [ ] **Step 3: Create the storm in buildCourt()**

In `buildCourt()`, immediately after the backdrop `if/else` block (after the `}` at line 232, before the `// Three-point marker` comment), add:

```swift
        // Storm sky — charge-meter weather. Above backdrop, below players.
        let storm = StormSkyNode(size: size,
                                 greenLow: greenLow, greenHigh: greenHigh,
                                 perfectLow: perfectLow, perfectHigh: perfectHigh)
        storm.zPosition = -5
        courtLayer.addChild(storm)
        stormSky = storm
```

(`buildCourt()` begins with `courtLayer.removeAllChildren()`, so the storm is recreated alongside the backdrop on every layout — same lifecycle, no leaks.)

- [ ] **Step 4: Drive it from the charge**

In `updateCharge(_:)` (line 542), after `shootButton?.setCharge(charge)`, add:

```swift
        stormSky?.setCharge(charge)
```

In `cancelCharge()` (line 552), after `shootButton?.setCharge(nil)`, add:

```swift
        stormSky?.setCharge(nil)
```

- [ ] **Step 5: Update the title-screen instructions**

In `LizzyMcGuireGameView.swift` line 98, change:

```swift
                Text("DRAG TO MOVE · HOLD SHOOT & RELEASE IN THE GREEN\n3 ON-BEAT SHOTS IN A ROW = ON FIRE 🔥")
```

to:

```swift
                Text("DRAG TO MOVE · HOLD SHOOT, RELEASE WHEN THE SKY GOES GREEN\n3 ON-BEAT SHOTS IN A ROW = ON FIRE 🔥")
```

- [ ] **Step 6: Build + run tests**

```bash
xcodebuild -project ios/BandMusicGames.xcodeproj -scheme BandMusicGames \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add ios/BandMusicGames/Views/Games/HalfCourtHero/HalfCourtHeroScene.swift ios/BandMusicGames/Views/Games/LizzyMcGuireGameView.swift
git commit -m "feat: drive storm sky from shot charge; slow charge to ~1s full meter"
```

---

### Task 5: Human playtest checkpoint — storm

Touch-and-hold can't be injected via simctl, so this is a human checkpoint. The app already boots straight into Half Court Hero (`autoLaunchLizzyLobby = true` in `ContentView.swift`).

- [ ] **Step 1: Build and run on simulator or device** (Xcode ⌘R, or TestFlight build)
- [ ] **Step 2: Verify with the user:**
  - Holding SHOOT: sky behind players darkens progressively (players/ball/HUD stay bright).
  - At the window: one lightning bolt + heavy haptic (device only), sky turns green, brightest mid-window.
  - Holding past the window: dark halves slide apart and fade; sky back to normal while still holding.
  - Releasing at any point: sky clears within ~0.15 s. Next charge starts from a clear, centered sky.
  - Shot-clock expiry mid-charge clears the sky.
  - Beat ring still pulses gold on the button; ON FIRE flash/shake unchanged.
  - Charge pacing feels right (chargeRate 1.0); tune in the constants block at lines 17–28 if not.

No commit — fixes discovered here get their own commits.

---

### Task 6: Add abilityBlurb to the hero model

The scouting card's ABILITY section needs one line of flavor per hero (the old SPECIAL section described moves that don't exist in the SpriteKit game).

**Files:**
- Modify: `ios/BandMusicGames/Views/Games/HalfCourtHero/HalfCourtHeroTypes.swift:210-227` (struct), `:128-206` (four initializers)

- [ ] **Step 1: Add the property**

In the `HalfCourtHero` struct (line 210), after `let ability: String`, add:

```swift
    let abilityBlurb: String
```

- [ ] **Step 2: Add a blurb to each hero initializer**

In each of the four `HalfCourtHero(...)` initializers in `HalfCourtHeroID.character`, add the `abilityBlurb:` argument directly after `ability:` (argument order must match the struct):

- nara (after `ability: "3PT SHOOTER",`):
```swift
                abilityBlurb: "Deadeye from beyond the arc. Leave her open out there and it's MONEY.",
```
- ethan (after `ability: "LOCKDOWN",`):
```swift
                abilityBlurb: "A glove on defense — quick feet and a hand in every passing lane.",
```
- brendan (after `ability: "PAINT BEAST",`):
```swift
                abilityBlurb: "Owns the paint. Strong drives, stronger finishes. BOOM.",
```
- will (after `ability: "DEEP RANGE",`):
```swift
                abilityBlurb: "Limitless range off the keys — pulls from the logo like it's a layup.",
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project ios/BandMusicGames.xcodeproj -scheme BandMusicGames \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`. (A missing/misordered `abilityBlurb:` argument fails the build — that's the check.)

- [ ] **Step 4: Commit**

```bash
git add ios/BandMusicGames/Views/Games/HalfCourtHero/HalfCourtHeroTypes.swift
git commit -m "feat: per-hero abilityBlurb for scouting cards"
```

---

### Task 7: Long-press flip scouting cards

Port the loved `HeroDetailOverlay` animation from branch commit `ad132c3` (reference: `git show ad132c3:ios/BandMusicGames/Views/Games/LizzyMcGuireGameView.swift`) onto the current select screen. Tap keeps selecting; long-press flips open the scouting report.

**Files:**
- Modify: `ios/BandMusicGames/Views/Games/LizzyMcGuireGameView.swift` (state line ~11, body ZStack line ~27, header line ~141, grid Button lines 153–188, new structs at end of file)

- [ ] **Step 1: Add scouted-hero state**

After `@State private var selectStep = 1` (line 11), add:

```swift
    @State private var scoutedHero: HalfCourtHeroID?
```

- [ ] **Step 2: Show the overlay in the body**

In `body`'s ZStack, after the phase overlays block (after the `}` of `else if scene.phase == .characterSelect { ... }` at line 27), add:

```swift
            if let hero = scoutedHero, scene.phase == .characterSelect {
                HeroScoutingOverlay(
                    hero: hero,
                    selectStep: selectStep,
                    isBallHandler: selectStep == 2 && hero == selectedPlayer,
                    onPick: {
                        HapticManager.selection()
                        if selectStep == 1 {
                            selectedPlayer = hero
                            selectStep = 2
                        } else {
                            selectedTeammate = hero
                        }
                        scoutedHero = nil
                    },
                    onClose: { scoutedHero = nil }
                )
                .zIndex(10)
            }
```

- [ ] **Step 3: Add the discoverability hint**

Inside the select header VStack, after the sub-headline `Text(...)` that ends at line 141 (the one showing "Choose your ball handler"), add:

```swift
                    Text("HOLD A CARD FOR SCOUTING REPORT")
                        .font(.system(size: compact ? 7 : 8, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.top, 3)
```

- [ ] **Step 4: Long-press on grid cards (and keep it working on the disabled card)**

`.disabled()` would swallow the long-press on the step-2 ball-handler card, so replace it with a guard in the action. Change the grid card Button (lines 153–188):

```swift
                        Button {
                            guard !disabled else { return }
                            HapticManager.selection()
                            if selectStep == 1 {
                                selectedPlayer = hero
                                selectStep = 2
                            } else {
                                selectedTeammate = hero
                            }
                        } label: {
```

(label content lines 162–186 unchanged), and replace the `.disabled(disabled)` modifier at line 188 with:

```swift
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                                HapticManager.impact(.medium)
                                scoutedHero = hero
                            }
                        )
```

- [ ] **Step 5: Add the overlay + StatBar structs**

At the end of the file, after the `HalfCourtHeroBadge` struct (line 242), add:

```swift
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
                StatBar(label: "SHOOTING", value: min(1, 0.5 + ch.threeBonus * 4), hue: ch.hue)
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
```

- [ ] **Step 6: Build + run tests**

```bash
xcodebuild -project ios/BandMusicGames.xcodeproj -scheme BandMusicGames \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add ios/BandMusicGames/Views/Games/LizzyMcGuireGameView.swift
git commit -m "feat: restore long-press flip scouting cards on team select"
```

---

### Task 8: Human playtest checkpoint — scouting cards

- [ ] **Step 1: Build and run** (Xcode ⌘R or TestFlight)
- [ ] **Step 2: Verify with the user:**
  - Tap on a card still selects instantly in both steps (no added delay from the long-press gesture).
  - Long-press (~0.4 s) on any card flips open the scouting report with the 3D spring swing; haptic fires.
  - Step 1 card button reads "PICK AS BALL HANDLER" and advances to step 2.
  - Step 2: other heroes show "ADD AS TEAMMATE" (selects + closes); the chosen ball handler's card still opens via long-press but shows a disabled "ALREADY ON TEAM".
  - ✕ and tap-outside both close with the dim fading.
  - Stat bars differ per hero (Nara high SHOOTING, Ethan high DEFENSE) and the ABILITY section shows the blurb + ON FIRE tip.
  - Layout holds on a compact-height device (e.g. iPhone SE-class simulator: `geo.size.height < 780` paths).
  - Hint caption "HOLD A CARD FOR SCOUTING REPORT" shows under the header in both steps.

No commit — fixes discovered here get their own commits.
