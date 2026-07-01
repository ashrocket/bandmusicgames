# Half Court Hero v2.4.0 Fun & Playability Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the 14-feature v2.4.0 design (spec: `docs/superpowers/specs/2026-07-01-hch-fun-polish-v2.4-design.md`) that makes the beat visible, kills the foul exploit, adds 1-tap restart/quick-start, and gives every bucket ceremony.

**Architecture:** All gameplay changes live in the SpriteKit module `ios/BandMusicGames/Views/Games/HalfCourtHero/` plus the SwiftUI shell `LizzyMcGuireGameView.swift`. New pure logic (block grading, beat-run tracking) is extracted into testable types in `HalfCourtHeroTypes.swift` with XCTest coverage mirroring the existing `StormStageTests` style. Visual work is verified by simulator build.

**Tech Stack:** Swift 5 / SpriteKit / SwiftUI, XcodeGen project (`ios/project.yml`), XCTest (`BandMusicGamesTests`), iPhone 16 simulator.

## Global Constraints

- Branch: `feat/hch-fun-polish-v2.4`. Subgame version: **v2.4.0** (shown on title footer; app `CURRENT_PROJECT_VERSION` bumped in the final task).
- Invariants W1–W11 from the spec are binding. In particular: never touch ON FIRE numbers (±175 ms / 3 / 12 s / +0.15 / +1); never change `errorOffset` sign for human shots; keep `attemptBlockOrFoul` guards (`contestResolved`, `pendingPossession`, `scoredThisFlight`, `missResolved`) verbatim; no audio assets or clicks.
- Build command (run after every task): `cd /Users/ashrocket/ashcode/bandmusicgames/ios && xcodebuild -project BandMusicGames.xcodeproj -scheme BandMusicGames -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug build 2>&1 | tail -3` — expect `** BUILD SUCCEEDED **`.
- Test command: same but `test` instead of `build` — expect `** TEST SUCCEEDED **`.
- Commit after every task with a scoped message; end commits with the standard co-author trailer.
- File shorthand used below: **Scene** = `ios/BandMusicGames/Views/Games/HalfCourtHero/HalfCourtHeroScene.swift`, **View** = `ios/BandMusicGames/Views/Games/LizzyMcGuireGameView.swift`, **Types** = `.../HalfCourtHeroTypes.swift`, **Card** = `.../HalfCourtResultCardNode.swift`, **HUD** = `.../HalfCourtHUDNode.swift`, **Factory** = `.../HalfCourtSpriteFactory.swift`, **Player** = `.../PlayerNode.swift`.

---

### Task 1: W6 regression guard — difficulty monotonicity test

**Files:**
- Create: `ios/BandMusicGamesTests/HalfCourtDifficultyTests.swift`

**Interfaces:**
- Consumes: `HalfCourtDifficulty` (Types:47–128).
- Produces: a standing regression test that fails if anyone re-inverts difficulty (a06060a).

- [ ] **Step 1: Write the test**

```swift
import XCTest
@testable import BandMusicGames

/// Regression guard for the a06060a difficulty inversion fix: every tunable
/// must stay monotonic easy → normal → hard.
final class HalfCourtDifficultyTests: XCTestCase {
    private let ordered: [HalfCourtDifficulty] = [.easy, .normal, .hard]

    private func assertStrictlyDecreasing(_ values: [CGFloat], _ name: String) {
        for i in 1..<values.count {
            XCTAssertLessThan(values[i], values[i - 1], "\(name) must decrease easy→hard")
        }
    }

    private func assertStrictlyIncreasing(_ values: [CGFloat], _ name: String) {
        for i in 1..<values.count {
            XCTAssertGreaterThan(values[i], values[i - 1], "\(name) must increase easy→hard")
        }
    }

    func testGreenWindowNarrowsWithDifficulty() {
        assertStrictlyDecreasing(ordered.map { $0.greenWindow.high - $0.greenWindow.low }, "green window width")
    }

    func testAccuraciesDropWithDifficulty() {
        assertStrictlyDecreasing(ordered.map(\.perfectAccuracy), "perfectAccuracy")
        assertStrictlyDecreasing(ordered.map(\.greenAccuracy), "greenAccuracy")
        assertStrictlyDecreasing(ordered.map(\.lateAccuracy), "lateAccuracy")
    }

    func testCPUGetsMeanerWithDifficulty() {
        // Smaller multiplier = tighter CPU shots (a06060a: hard must be the sniper).
        assertStrictlyDecreasing(ordered.map(\.cpuShotMultiplier), "cpuShotMultiplier")
        assertStrictlyIncreasing(ordered.map(\.cpuDriveSpeed), "cpuDriveSpeed")
        assertStrictlyIncreasing(ordered.map(\.cpuStealRate), "cpuStealRate")
    }

    func testPressureRisesWithDifficulty() {
        assertStrictlyDecreasing(ordered.map { CGFloat($0.shotClockSeconds) }, "shotClockSeconds")
        assertStrictlyIncreasing(ordered.map(\.chargeRate), "chargeRate")
    }
}
```

- [ ] **Step 2: Run the test suite, expect PASS** (these encode current, correct behavior).
- [ ] **Step 3: Commit** — `test: lock difficulty monotonicity (a06060a regression guard)`

---

### Task 2: F1 — Beat made visible (SHOOT-ring pulse, rim halo, pip flash)

**Files:**
- Modify: Scene — `updateBeat` (~:655), `buildCourt` (~:302), `ControlButtonNode` (~:2207), `StreakPipsNode` (~:2363); new `rimHaloNode` property near `rimNode` (~:64).

**Interfaces:**
- Produces: `ControlButtonNode.beatPulse()`, `StreakPipsNode.beatFlash()`, Scene `rimBeatHalo()` — all reused by no other task; F1 is self-contained.

- [ ] **Step 1: Add a beat ring + pulse to `ControlButtonNode`.** In the property block add `private let beatRing = SKShapeNode()`; in `init(radius:)` after the arcs loop:

```swift
beatRing.path = CGPath(ellipseIn: CGRect(x: -ringRadius, y: -ringRadius,
                                         width: ringRadius * 2, height: ringRadius * 2), transform: nil)
beatRing.strokeColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 0.9)
beatRing.lineWidth = 2.5
beatRing.fillColor = .clear
beatRing.alpha = 0
addChild(beatRing)
```

and a new method:

```swift
/// One beat of the song: subtle scale bump + gold ring flash (112 BPM cue).
func beatPulse() {
    bg.removeAction(forKey: "beatPulse")
    let up = SKAction.scale(to: 1.06, duration: 0.10); up.timingMode = .easeOut
    let down = SKAction.scale(to: 1.0, duration: 0.20); down.timingMode = .easeIn
    bg.run(.sequence([up, down]), withKey: "beatPulse")
    beatRing.removeAllActions()
    beatRing.setScale(1.0)
    beatRing.alpha = 0.9
    beatRing.run(.group([.scale(to: 1.12, duration: 0.30), .fadeOut(withDuration: 0.30)]))
}
```

- [ ] **Step 2: Add `beatFlash()` to `StreakPipsNode`:**

```swift
func beatFlash() {
    run(.sequence([.fadeAlpha(to: 0.6, duration: 0.10), .fadeAlpha(to: 1.0, duration: 0.10)]))
}
```

- [ ] **Step 3: Add the rim halo.** Property `private var rimHaloNode: SKShapeNode?` beside `rimNode`. In `buildCourt()` right after the rim visual is added:

```swift
let halo = SKShapeNode(circleOfRadius: 30)
halo.strokeColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 1)
halo.lineWidth = 2
halo.fillColor = .clear
halo.alpha = 0
halo.position = CGPoint(x: rimX, y: rimY)
courtLayer.addChild(halo)
rimHaloNode = halo
```

and a scene method:

```swift
private func rimBeatHalo() {
    guard let rimHaloNode else { return }
    rimHaloNode.removeAllActions()
    rimHaloNode.setScale(1.0)
    rimHaloNode.alpha = 0.5
    rimHaloNode.run(.group([.scale(to: 1.18, duration: 0.30), .fadeOut(withDuration: 0.30)]))
}
```

- [ ] **Step 4: Fire them from `updateBeat`.** Replace the `if idx > lastBeatIndex` body:

```swift
if idx > lastBeatIndex {
    lastBeatIndex = idx
    tapMeterNode?.beatPulse()
    rimBeatHalo()
    if playState == .homeLive || playState == .homeFreethrow {
        buttonA?.beatPulse()   // only in SHOOT contexts — never during BLOCK timing
    }
    if onBeatStreak > 0 { streakPips?.beatFlash() }
    if playState == .homeLive {
        HapticManager.selection()
    }
}
```

- [ ] **Step 5: Build; expect SUCCEEDED. Commit** — `feat: make the 112 BPM beat visible — SHOOT-ring pulse, rim halo, pip flash (F1)`

---

### Task 3: F6 — Dual-lane callouts + honest steal hint

**Files:**
- Modify: Scene — `showCallout` (~:1810), `calloutNode` property (~:62), call sites in `registerBeatTiming` (~:1528/:1533), `activatePowerUp` (~:1548), `updatePowerState` (~:687), `showStealHint` (~:1781).

**Interfaces:**
- Produces: `showCallout(_:color:big:lane:)` with `enum CalloutLane { case event, timing }` — Tasks 4, 12, 13 pass `lane:` on new call sites; all existing call sites compile unchanged via the `.event` default.

- [ ] **Step 1: Add the lane.** Beside `calloutNode` add `private var timingCalloutNode: SKNode?`. Above `showCallout` add `private enum CalloutLane { case event, timing }`. Change the signature to `showCallout(_ text: String, color: SKColor, big: Bool = false, lane: CalloutLane = .event)` and the body's first/last lines to be lane-aware:

```swift
switch lane {
case .event:  calloutNode?.removeFromParent()
case .timing: timingCalloutNode?.removeFromParent()
}
// ... existing label construction, but:
label.position = CGPoint(x: size.width / 2, y: size.height * 0.58 + (lane == .timing ? 36 : 0))
// ... and after fxLayer.addChild(label):
switch lane {
case .event:  calloutNode = label
case .timing: timingCalloutNode = label
}
```

- [ ] **Step 2: Route beat/power feedback to the timing lane.** Add `lane: .timing` to exactly these call sites: `"ON BEAT ×\(onBeatStreak)"`, `"OFF BEAT"`, `"🔥 ON FIRE!"`, `"COOLED OFF"`. Everything else stays `.event` implicitly.

- [ ] **Step 3: Fix the stale hint.** In `showStealHint`, change `hint.text = "SWIPE \u{2192} STEAL"` to `hint.text = "TAP STEAL!"` (the on-screen button is labeled STEAL; there is no "B" label on screen, so the spec's "B = STEAL" copy is adapted to match what the player actually sees).

- [ ] **Step 4: Build; expect SUCCEEDED. Commit** — `feat: dual-lane callouts so beat streaks survive shot callouts; honest steal hint (F6)`

---

### Task 4: F2 — Foul fix: dead-ball-retain reach-in, exploit dead

**Files:**
- Modify: Scene — `attemptBlockOrFoul` (~:1284), `handlePrimaryDown` (~:1110), `handleFloorContact` (~:1694), `resolveExpiredFlight` (~:992), `givePossession` (~:560), `updateHuman` (~:747), new state properties near `humanStealCooldownUntil` (~:176).

**Interfaces:**
- Consumes: `showCallout(..., lane:)` from Task 3.
- Produces: `blockCooldownUntil: TimeInterval` (Task 12 renders it on button A is NOT needed — Task 12 renders STEAL cooldown on button B; block cooldown ring is rendered here), `foulRetainPossession: Bool`, `humanInputLockedUntil: TimeInterval`, `nextTeamAfterMiss(shotTeam:)`.

- [ ] **Step 1: Add state.**

```swift
private var blockCooldownUntil: TimeInterval = 0     // mistimed BLOCK penalty (F2)
private var foulRetainPossession = false             // reach-in foul: CPU keeps ball on miss
private var humanInputLockedUntil: TimeInterval = 0  // brief lockout after a foul
```

- [ ] **Step 2: Gate BLOCK taps on the cooldown.** In `handlePrimaryDown`, `.defenseShot` case:

```swift
case .defenseShot:
    if nowTime < blockCooldownUntil {
        HapticManager.impact(.light)
        buttonA?.setPressed(false)
    } else {
        attemptBlockOrFoul()
    }
```

- [ ] **Step 3: Replace the inverted foul.** In `attemptBlockOrFoul`, keep all guards and the in-window branch verbatim. Replace the `contesting` branch body (the `triggerShootingFoul()` path) with:

```swift
if contesting {
    contestResolved = true
    blockCooldownUntil = nowTime + 1.2
    reachInFoul()
} else {
    blockCooldownUntil = nowTime + 1.2
    showCallout(cpuBlockFill < greenLow ? "TOO EARLY!" : "TOO LATE!",
                color: SKColor.white.withAlphaComponent(0.9))
    HapticManager.impact(.light)
}
```

and add:

```swift
/// Mistimed contest = reach-in foul AGAINST the human: error haptic, brief
/// lockout, the CPU shot flies on easier, and the CPU keeps the ball on a miss.
/// Replaces the inverted foul that awarded the fouler two free throws.
private func reachInFoul() {
    showCallout("REACH-IN FOUL!", color: SKColor(red: 1, green: 0.32, blue: 0.30, alpha: 1), big: true)
    HapticManager.notification(.error)
    humanInputLockedUntil = nowTime + 0.6
    if let id = activeHumanID { players[id]?.playAnimationOnce(.sad) }
    foulRetainPossession = true
    // The foul helps the shooter: if the launch is still pending, tighten its error.
    if let launch = pendingLaunch {
        pendingLaunch = PendingLaunch(at: launch.at, team: launch.team,
                                      errorOffset: launch.errorOffset * 0.6)
    }
}
```

- [ ] **Step 4: Retain possession on the fouled miss.** Add:

```swift
private func nextTeamAfterMiss(shotTeam: HalfCourtTeam) -> HalfCourtTeam {
    if shotTeam == .away && foulRetainPossession {
        foulRetainPossession = false
        showCallout("FOUL — THEY KEEP IT", color: SKColor(red: 1, green: 0.42, blue: 0.21, alpha: 1))
        return .away
    }
    return shotTeam == .home ? .away : .home
}
```

In `handleFloorContact`, replace the final `scheduleGivePossession(to: ball.shotTeam == .home ? .away : .home, after: 0.6)` with `scheduleGivePossession(to: nextTeamAfterMiss(shotTeam: ball.shotTeam), after: 0.6)`. Same substitution in `resolveExpiredFlight` (the non-freethrow path). In `givePossession`, add `foulRetainPossession = false` after `isFreethrowInFlight = false` — wait, that would clear it before the scheduled possession fires; `nextTeamAfterMiss` already consumes the flag, and `givePossession` runs AFTER the schedule, so clearing there is safe for stale state from other paths (e.g. a make). Add it.

- [ ] **Step 5: Honor the lockout.** In `updateHuman`, extend the `canMove` line: `let canMove = nowTime >= humanInputLockedUntil && (playState == .homeLive || ...)`. In `handleSecondaryDown` and `handlePrimaryDown`, add at the top: `guard nowTime >= humanInputLockedUntil else { return }`.

- [ ] **Step 6: Render the block cooldown.** In `refreshControlButtons`, `.defenseShot` case, after `buttonA?.setRing(fill: cpuBlockFill, block: true)` add:

```swift
buttonA?.alpha = nowTime < blockCooldownUntil ? 0.35 : 1.0
```

and in every other case where buttonA is shown, ensure `buttonA?.alpha = 1.0` (add once at the top of the function: `buttonA?.alpha = 1.0` before the switch, then the defenseShot case may override).

- [ ] **Step 7: Build; manual check** — in simulator: contest a CPU shot, tap BLOCK early: expect "REACH-IN FOUL!" red + error-feel, no free throws, CPU keeps ball if it misses, button A dimmed ~1.2 s. **Commit** — `fix: reach-in foul penalizes the fouler — exploit dead (F2)`

---

### Task 5: F3 — RUN IT BACK: 1-tap same-squad series rematch

**Files:**
- Modify: Scene — new `rematchSeries()` near `startSeries` (~:463), `resolveGame` wiring (~:1759); Card — `setup` (~:84–107), `handleTouch` (~:173).

**Interfaces:**
- Produces: `rematchSeries()`; Card stores `private var isSeriesOver = false` to swap button semantics.

- [ ] **Step 1: Scene method** (order mirrors the verified mid-series restart at :1753–1756; `beatAnchor` untouched — audio is continuous through the card):

```swift
/// Series-over rematch: same squad, same difficulty, straight to tip-off.
/// beatAnchor is deliberately NOT reset — audio plays continuously through
/// the result card, so the beat clock stays valid (contrast startSeries()).
func rematchSeries() {
    homeSeriesWins = 0
    awaySeriesWins = 0
    homeScore = 0
    awayScore = 0
    phase = .playing   // before resetMatch so givePossession doesn't short-circuit
    resetMatch()
}
```

In `resolveGame`, change the rematch closure to `onRematch: isSeriesOver ? { [weak self] in self?.rematchSeries() } : nil`.

- [ ] **Step 2: Card button swap.** In `setup`, store `self.isSeriesOver = isSeriesOver` (add the property). Change `actionLabel.text = isSeriesOver ? "RUN IT BACK" : "START NEXT GAME"` and the ghost block's `rematchLabel.text = "BACK TO LOBBY"`. In `handleTouch`, when `isSeriesOver`, `"action_btn"` fires `onRematch` and `"rematch_btn"` fires `onAction`; mid-series behavior unchanged:

```swift
func handleTouch(_ touch: UITouch) -> Bool {
    let location = touch.location(in: self)
    let node = atPoint(location)
    if node.name == "action_btn" {
        (isSeriesOver ? onRematch : onAction)?()
        return true
    }
    if node.name == "rematch_btn" {
        (isSeriesOver ? onAction : onRematch)?()
        return true
    }
    return false
}
```

- [ ] **Step 3: Build; manual merge test** — lose (or win) a series in simulator: music must not stop across the card; tap RUN IT BACK → live ball ≤1.5 s, on-beat release still registers. **Commit** — `feat: RUN IT BACK — 1-tap same-squad rematch from series end (F3)`

---

### Task 6: F4 — QUICK START + persisted squad/difficulty + version footer

**Files:**
- Modify: View — `difficulty` @State (~:15), title overlay (~:174–287), PLAY button action (~:395), difficulty selector (~:230); Scene — new `quickStart` near `startSeries`.

**Interfaces:**
- Consumes: `rematchSeries` pattern from Task 5 (ordering discipline).
- Produces: `quickStart(playerID:teammateID:difficulty:)`; UserDefaults keys `hch_last_player`, `hch_last_teammate`, `hch_difficulty`.

- [ ] **Step 1: Scene method:**

```swift
/// Cold-start shortcut: skip title/select, straight to tip-off with the saved
/// squad. beatAnchor is nil'd so the view's confirmed-playback path
/// (playTrack → realignBeatAnchor) re-latches it — the fa93bb7 rule.
func quickStart(playerID: HalfCourtHeroID, teammateID: HalfCourtHeroID, difficulty: HalfCourtDifficulty) {
    homeSeriesWins = 0
    awaySeriesWins = 0
    beatAnchor = nil
    startGame(playerID: playerID, teammateID: teammateID, difficulty: difficulty)
}
```

- [ ] **Step 2: Persist difficulty.** View line 15 becomes:

```swift
@State private var difficulty: HalfCourtDifficulty =
    UserDefaults.standard.string(forKey: "hch_difficulty")
        .flatMap(HalfCourtDifficulty.init(rawValue:)) ?? .normal
```

In the difficulty selector button action add `UserDefaults.standard.set(d.rawValue, forKey: "hch_difficulty")` after `difficulty = d`.

- [ ] **Step 3: Persist squad on PLAY.** In the character-select PLAY action, before `scene.startGame(...)`:

```swift
UserDefaults.standard.set(selectedPlayer.rawValue, forKey: "hch_last_player")
if let mate = selectedTeammate {
    UserDefaults.standard.set(mate.rawValue, forKey: "hch_last_teammate")
}
```

- [ ] **Step 4: QUICK START button.** Add to the view:

```swift
private var savedSquad: (player: HalfCourtHeroID, teammate: HalfCourtHeroID)? {
    let d = UserDefaults.standard
    guard let p = d.string(forKey: "hch_last_player").flatMap(HalfCourtHeroID.init(rawValue:)),
          let t = d.string(forKey: "hch_last_teammate").flatMap(HalfCourtHeroID.init(rawValue:)),
          p != t else { return nil }
    return (p, t)
}
```

Replace the single TAP TO PLAY button block in `titleOverlay` with:

```swift
if let squad = savedSquad {
    Button {
        HapticManager.impact(.medium)
        scene.quickStart(playerID: squad.player, teammateID: squad.teammate, difficulty: difficulty)
    } label: {
        VStack(spacing: 2) {
            Text("QUICK START")
                .font(.system(size: compact ? 17 : 19, weight: .black, design: .monospaced))
                .tracking(3)
            Text("\(squad.player.character.name) + \(squad.teammate.character.name) · \(difficulty.label)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .opacity(0.7)
        }
        .foregroundColor(.black)
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 11 : 13)
        .background(Color(hex: "#FFD700"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color(hex: "#FFD700").opacity(0.35), radius: 16)
    }
    .padding(.horizontal, compact ? 28 : 34)

    Button {
        HapticManager.selection()
        scene.startSeries()
    } label: {
        Text("CHANGE SQUAD")
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .tracking(2)
            .foregroundColor(.white.opacity(0.62))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .padding(.horizontal, compact ? 28 : 34)
    .padding(.top, 8)
} else {
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
}
```

- [ ] **Step 5: Version footer.** Change the footer `Text("BANDMUSICGAMES.PARTY")` to `Text("BANDMUSICGAMES.PARTY · v2.4.0")` (subgame-versioning directive: the subgame's own version, visible).

- [ ] **Step 6: Build; manual check** — first launch shows TAP TO PLAY; after one PLAY, relaunch shows QUICK START with squad + difficulty, one tap → live ball, beat registers. **Commit** — `feat: QUICK START with persisted squad + difficulty; v2.4.0 footer (F4)`

---

### Task 7: F5 — HUD never fades + score-pop flash

**Files:**
- Modify: View — dim block (~:110–113, verify with `grep -n hudOpacity` first); HUD — `update` (~:118–133).

- [ ] **Step 1: Audit `hudOpacity`.** Run `grep -n "hudOpacity" View`. Expected finding: it is *written* (set to 1.0 / 0.18 / 0) but **never applied** to any view (`controlsHUD`, the only candidate consumer, is dead code — not referenced in `body`). If confirmed: delete the `hudOpacity` state var, its `onChange` writes, and the 6 s asyncAfter dim block entirely (dead code, G12's dim never rendered but the code invites it back). If it IS applied somewhere: delete only the asyncAfter dim (keep fade-in at 1.0).

- [ ] **Step 2: Score-pop.** In HUD `update`, replace both bump blocks with a gold-flash variant (same for away with its own color restore `SKColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1.0)`):

```swift
if homeScore != lastHomeScore {
    lastHomeScore = homeScore
    homeScoreLabel.text = "\(homeScore)"
    if homeScore > 0 {
        homeScoreLabel.removeAction(forKey: "bump")
        homeScoreLabel.fontColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 1)
        let up = SKAction.scale(to: 1.35, duration: 0.10); up.timingMode = .easeOut
        let down = SKAction.scale(to: 1.0, duration: 0.15); down.timingMode = .easeIn
        homeScoreLabel.run(.sequence([
            up, down, .wait(forDuration: 0.05),
            .run { [weak homeScoreLabel] in
                homeScoreLabel?.fontColor = SKColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 1.0)
            },
        ]), withKey: "bump")
    }
}
```

- [ ] **Step 3: Build; commit** — `feat: score pops gold on change; remove HUD-dim dead code (F5)`

---

### Task 8: F10 — Dead-time trims (constants only)

**Files:**
- Modify: Scene — `handleScore` make delay (:1667 `after: 1.0` → `0.7`), `handleFloorContact` miss delay (:1723 `after: 0.6` → `0.45`), CPU dribble (:791 `0.8...1.5` → `0.7...1.2`), rim-stuck fallback (:1575 `+ 3.2` → `+ 2.0`).

- [ ] **Step 1: Apply the four constant changes.** No resolution logic touched. Note: Task 4's `nextTeamAfterMiss` call site keeps the (now 0.45) delay.
- [ ] **Step 2: Build; manual feel check** (possession exchanges noticeably snappier). **Commit** — `tune: trim per-possession dead time ~1.2s (F10)`

---

### Task 9: F11 — Freeze-resume beat realign + pinch threshold

**Files:**
- Modify: View — `resumeFromFreeze` (~:419–432), both `MagnificationGesture(minimumScaleDelta:)` sites (:36, :471).

- [ ] **Step 1:** In `resumeFromFreeze`, realign after audio actually resumes (fa93bb7 pattern):

```swift
if appleMusic.isPreferred {
    Task {
        await appleMusic.resume()
        scene.realignBeatAnchor()
    }
} else if auth.canAttemptPlayback {
    Task {
        await auth.resumePlayback()
        scene.realignBeatAnchor()
    }
}
```

- [ ] **Step 2:** Change `minimumScaleDelta: 0.03` → `0.12` at both gesture sites.
- [ ] **Step 3: Build; commit** — `fix: realign beat anchor after freeze-resume; raise pinch threshold (F11)`

---

### Task 10: F14 — Rewire StormSkyNode to the charge meter

**Files:**
- Modify: Scene — new `stormSky` property (~:64), `installStormSky()` helper, calls in `buildCourt` and `startGame`, drive from `updateTapMeter` (~:708–736).
- Verify: `ios/BandMusicGamesTests/StormStageTests.swift` still passes.

**Interfaces:**
- Consumes: existing `StormSkyNode` API — `init(size:greenLow:greenHigh:perfectLow:perfectHigh:)`, `setCharge(_:)`, `prime(charge:)`.

- [ ] **Step 1: Property + helper:**

```swift
private var stormSky: StormSkyNode?

/// (Re)install the storm sky against current green/perfect bounds — called
/// from buildCourt (layout/resize) and startGame (bounds change per difficulty).
private func installStormSky() {
    stormSky?.removeFromParent()
    let storm = StormSkyNode(size: size,
                             greenLow: greenLow, greenHigh: greenHigh,
                             perfectLow: perfectLow, perfectHigh: perfectHigh)
    storm.zPosition = -5   // above backdrop (-10), below court lines and players
    courtLayer.addChild(storm)
    stormSky = storm
    // Layout rebuilds can happen mid-charge — sync without one-shot effects.
    storm.prime(charge: isChargingShot || tapMeterFill > 0.01 ? tapMeterFill : nil)
}
```

Call `installStormSky()` at the end of `buildCourt()` and after the `buttonA?.configureRing(...)` line in `startGame`.

- [ ] **Step 2: Drive it.** In `updateTapMeter`, in the `.homeLive where possession == .home` and `.homeFreethrow` cases after `tapMeterNode?.setFill(...)`:

```swift
stormSky?.setCharge(isChargingShot || tapMeterFill > 0.01 ? tapMeterFill : nil)
```

and in the `default:` case: `stormSky?.setCharge(nil)`. (The `.awayShot` block meter must NOT drive the storm.)

- [ ] **Step 3: Run tests** — `StormStageTests` green. **Manual check:** hold SHOOT: clouds darken, lightning + heavy haptic exactly when the ring reaches green, wash brightens on perfect, clouds part past the window; release resets. **Commit** — `feat: rewire StormSkyNode charge storm (dead since 6d41189) to the SHOOT meter (F14)`

---

### Task 11: F7 — Stats, records, NEW RECORD banner

**Files:**
- Modify: Types — `HalfCourtStats` (:27–35); Scene — `gameStats` property, increments, reset, persistence in `resolveGame`; Card — stats rows + records line.
- Create: `ios/BandMusicGamesTests/HalfCourtStatsTests.swift`

**Interfaces:**
- Produces: `HalfCourtStats.registerBeatRelease(onBeat:)`, `bestBeatStreak`/`beatRunLength` fields; Card init gains `stats: HalfCourtStats, recordBeatStreak: Int, isNewStreakRecord: Bool`.
- UserDefaults keys: `hch_record_beat_streak`, `hch_record_margin`, `hch_career_series_w`, `hch_career_series_l`.

- [ ] **Step 1: Failing test:**

```swift
import XCTest
@testable import BandMusicGames

final class HalfCourtStatsTests: XCTestCase {
    func testBeatRunAccumulatesAndSurvivesOnFireCycle() {
        var s = HalfCourtStats()
        // 5 consecutive on-beat releases — the run must NOT reset at 3 (ON FIRE
        // consumes onBeatStreak, but the chased record keeps counting).
        for _ in 0..<5 { s.registerBeatRelease(onBeat: true) }
        XCTAssertEqual(s.bestBeatStreak, 5)
        s.registerBeatRelease(onBeat: false)
        XCTAssertEqual(s.bestBeatStreak, 5, "off-beat ends the run but keeps the best")
        s.registerBeatRelease(onBeat: true)
        s.registerBeatRelease(onBeat: true)
        XCTAssertEqual(s.bestBeatStreak, 5, "shorter new run doesn't beat the best")
    }

    func testFieldGoalPercent() {
        var s = HalfCourtStats()
        s.shots = 12; s.made = 7
        XCTAssertEqual(s.fgPercent, 58)
        XCTAssertEqual(HalfCourtStats().fgPercent, 0, "no shots → 0, not divide-by-zero")
    }
}
```

- [ ] **Step 2: Run — expect FAIL (`registerBeatRelease` undefined).**
- [ ] **Step 3: Extend the struct:**

```swift
struct HalfCourtStats {
    var shots = 0
    var made = 0
    var steals = 0
    var blocks = 0
    var threes = 0
    var homeSeriesWins = 0
    var awaySeriesWins = 0
    var bestBeatStreak = 0
    private(set) var beatRunLength = 0

    var fgPercent: Int {
        shots > 0 ? Int((Double(made) / Double(shots) * 100).rounded()) : 0
    }

    /// Continuous on-beat run for the record chase. Unlike onBeatStreak, this
    /// does NOT reset when ON FIRE triggers at 3 — only an off-beat release ends it.
    mutating func registerBeatRelease(onBeat: Bool) {
        if onBeat {
            beatRunLength += 1
            bestBeatStreak = max(bestBeatStreak, beatRunLength)
        } else {
            beatRunLength = 0
        }
    }
}
```

- [ ] **Step 4: Run — expect PASS.**
- [ ] **Step 5: Wire the scene.** Property `private(set) var gameStats = HalfCourtStats()`. Increments: `gameStats.shots += 1` in `releaseShot` and `releaseJumpBallShot` (not free throws); in `handleScore` home non-FT make: `gameStats.made += 1; if points >= 3 { gameStats.threes += 1 }` (check `ball.shotPoints`, before the ON FIRE +1); `gameStats.steals += 1` in the `tryGestureSteal` success branch; `gameStats.blocks += 1` in the block success branch; in `registerBeatTiming`, first line: `gameStats.registerBeatRelease(onBeat: nearestBeatDelta(now) <= onBeatWindow)` — compute delta once and reuse. Reset: `gameStats = HalfCourtStats()` in `resetMatch` beside `onBeatStreak = 0` (W8).
- [ ] **Step 6: Persist + pass to card.** In `resolveGame`, before constructing the card:

```swift
let d = UserDefaults.standard
let priorRecord = d.integer(forKey: "hch_record_beat_streak")
let isNewStreakRecord = gameStats.bestBeatStreak > priorRecord
if isNewStreakRecord { d.set(gameStats.bestBeatStreak, forKey: "hch_record_beat_streak") }
let margin = homeScore - awayScore
if margin > d.integer(forKey: "hch_record_margin") { d.set(margin, forKey: "hch_record_margin") }
if isSeriesOver {
    let key = homeSeriesWins >= seriesWinTarget ? "hch_career_series_w" : "hch_career_series_l"
    d.set(d.integer(forKey: key) + 1, forKey: key)
}
```

Pass `stats: gameStats, recordBeatStreak: max(priorRecord, gameStats.bestBeatStreak), isNewStreakRecord: isNewStreakRecord` into the card init.

- [ ] **Step 7: Card rows** (in `setup`, after the sub text; band y −60…−120 is empty — verified):

```swift
let statFont = "AvenirNext-Bold"
func statLabel(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, alpha: CGFloat) {
    let l = SKLabelNode(fontNamed: statFont)
    l.text = text; l.fontSize = size
    l.fontColor = SKColor.white.withAlphaComponent(alpha)
    l.position = CGPoint(x: x, y: y)
    l.verticalAlignmentMode = .center
    addChild(l)
}
statLabel("FG \(stats.made)/\(stats.shots) · \(stats.fgPercent)%", x: -90, y: -60, size: 13, alpha: 0.8)
statLabel("3PT \(stats.threes)", x: 90, y: -60, size: 13, alpha: 0.8)
statLabel("STL \(stats.steals) · BLK \(stats.blocks)", x: -90, y: -88, size: 13, alpha: 0.8)
statLabel("BEAT STREAK \(stats.bestBeatStreak) 🔥", x: 90, y: -88, size: 13, alpha: 0.8)

let record = SKLabelNode(fontNamed: "AvenirNext-Bold")
record.fontSize = 12
record.verticalAlignmentMode = .center
record.position = CGPoint(x: 0, y: -120)
if isNewStreakRecord && stats.bestBeatStreak > 0 {
    record.text = "NEW RECORD — BEAT STREAK \(stats.bestBeatStreak)!"
    record.fontColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 1)
    record.run(.repeatForever(.sequence([.scale(to: 1.06, duration: 0.3), .scale(to: 1.0, duration: 0.3)])))
} else {
    record.text = "BEST STREAK \(recordBeatStreak) — YOU HIT \(stats.bestBeatStreak)"
    record.fontColor = SKColor.white.withAlphaComponent(0.45)
}
addChild(record)
```

(Card init signature grows accordingly; all params stored or used in `setup`.)

- [ ] **Step 8: Tests + build; commit** — `feat: game stats + persisted records + NEW RECORD banner on result card (F7)`

---

### Task 12: F8 — Defense readability (graded block, contest-degrade, cooldown sweep)

**Files:**
- Modify: Types — new `BlockGrade` enum; Scene — `handleBlockAttempt` (~:1259), `tryGestureSteal` (~:1217), `refreshControlButtons` (~:1138), `handleFloorContact` away-miss branch, `ControlButtonNode` (cooldown arc + denied shake); Player — `flashGlint()`.
- Create: `ios/BandMusicGamesTests/BlockGradeTests.swift`

**Interfaces:**
- Produces: `BlockGrade.grade(fill:greenLow:greenHigh:)` → `.early | .swat | .inWindow | .late`; `successChance` per grade; `ControlButtonNode.setCooldown(_:)`, `.deniedShake()`; `PlayerNode.flashGlint()`; Scene flag `contestDegradeActive`.

- [ ] **Step 1: Failing test:**

```swift
import XCTest
@testable import BandMusicGames

final class BlockGradeTests: XCTestCase {
    // Normal-difficulty window: 0.52–0.76. Center band = middle 40% (p 0.30–0.70).
    private func grade(_ fill: CGFloat) -> BlockGrade {
        BlockGrade.grade(fill: fill, greenLow: 0.52, greenHigh: 0.76)
    }

    func testOutsideWindow() {
        XCTAssertEqual(grade(0.51), .early)
        XCTAssertEqual(grade(0.77), .late)
    }

    func testCenterBandIsSwat() {
        XCTAssertEqual(grade(0.64), .swat)          // dead center
        XCTAssertEqual(grade(0.52 + 0.24 * 0.30), .swat)  // p = 0.30 boundary
        XCTAssertEqual(grade(0.52 + 0.24 * 0.70), .swat)  // p = 0.70 boundary
    }

    func testWindowEdgesAreOrdinaryBlocks() {
        XCTAssertEqual(grade(0.53), .inWindow)
        XCTAssertEqual(grade(0.75), .inWindow)
    }

    func testSuccessChances() {
        XCTAssertEqual(BlockGrade.swat.successChance, 0.95)
        XCTAssertEqual(BlockGrade.inWindow.successChance, 0.70)
        XCTAssertEqual(BlockGrade.early.successChance, 0)
        XCTAssertEqual(BlockGrade.late.successChance, 0)
    }
}
```

- [ ] **Step 2: Run — expect FAIL. Implement in Types:**

```swift
/// Graded block-timing outcome: dead-center taps are near-certain swats,
/// window edges are ordinary blocks, outside the window never connects.
enum BlockGrade: Equatable {
    case early, inWindow, swat, late

    static func grade(fill: CGFloat, greenLow: CGFloat, greenHigh: CGFloat) -> BlockGrade {
        guard fill >= greenLow else { return .early }
        guard fill <= greenHigh else { return .late }
        let p = (fill - greenLow) / max(0.001, greenHigh - greenLow)
        return (0.30...0.70).contains(p) ? .swat : .inWindow
    }

    var successChance: CGFloat {
        switch self {
        case .swat: return 0.95
        case .inWindow: return 0.70
        case .early, .late: return 0
        }
    }
}
```

- [ ] **Step 3: Run — expect PASS.**
- [ ] **Step 4: Rework `handleBlockAttempt`.** Add Scene flag `private var contestDegradeActive = false` (cleared in `givePossession` beside `foulRetainPossession`). Replace the body after the window guard:

```swift
let grade = BlockGrade.grade(fill: cpuBlockFill, greenLow: greenLow, greenHigh: greenHigh)
if CGFloat.random(in: 0...1) < grade.successChance {
    pendingLaunch = nil
    ball?.missResolved = true
    ball?.hold()
    gameStats.blocks += 1
    let swat = grade == .swat
    showCallout(swat ? "SWATTED!" : "BLOCKED!",
                color: SKColor(red: 0.4, green: 0.95, blue: 0.5, alpha: 1), big: true)
    HapticManager.notification(.success)
    shakeWorld(swat ? 9 : 7)
    scheduleGivePossession(to: .home, after: 0.35)
} else {
    // Failed roll is no longer silent: the contest degrades the shot.
    showCallout("CONTESTED!", color: SKColor(red: 1.0, green: 0.75, blue: 0.2, alpha: 1))
    HapticManager.impact(.rigid)
    contestDegradeActive = true
    if let launch = pendingLaunch {
        // Pre-launch: widen the error, sign preserved.
        let mag = max(abs(launch.errorOffset) * 1.5, abs(launch.errorOffset) + 6)
        let sign: CGFloat = launch.errorOffset >= 0 ? 1 : -1
        pendingLaunch = PendingLaunch(at: launch.at, team: launch.team, errorOffset: sign * mag)
    } else if let ball, !ball.isHeld, let body = ball.physicsBody {
        // In flight (the common case — window sits during flight): a small tip
        // shortens the arc ~12–24pt, visually a real contest.
        body.velocity = CGVector(dx: body.velocity.dx, dy: body.velocity.dy - 45)
    }
}
```

The old flat-72% `handleBlockAttempt` internals are replaced; `attemptBlockOrFoul`'s in-window call path is unchanged. Note `contestResolved = true` is already set by the caller before `handleBlockAttempt()` — verify and keep.

- [ ] **Step 5: FORCED THE BRICK.** In `handleFloorContact`, in the away-team miss branch, replace the random-callout line with:

```swift
if contestDegradeActive {
    contestDegradeActive = false
    showCallout("FORCED THE BRICK!", color: SKColor(red: 0.4, green: 0.95, blue: 0.5, alpha: 1))
} else {
    showCallout(["BRICKED!", "WALLED OFF!", "BLOCKED OUT!", "NOT TODAY!"].randomElement() ?? "BRICKED!",
                color: SKColor(red: 0.4, green: 0.95, blue: 0.5, alpha: 0.85))
}
```

- [ ] **Step 6: Steal cooldown sweep + denied shake.** In `ControlButtonNode`, add `private let cooldownArc = SKShapeNode()` configured in `init` like the other arcs (lineWidth 5, round cap, hidden, strokeColor `SKColor(white: 1, alpha: 0.5)`), plus:

```swift
/// fraction of cooldown REMAINING (1 → just used, 0/nil → ready).
func setCooldown(_ fraction: CGFloat?) {
    guard let fraction, fraction > 0.01 else {
        cooldownArc.isHidden = true
        bg.alpha = 1.0
        return
    }
    cooldownArc.isHidden = false
    cooldownArc.path = arcPath(from: startAngle, to: angle(for: fraction))
    bg.alpha = 0.4
}

func deniedShake() {
    removeAction(forKey: "denied")
    run(.sequence([
        .moveBy(x: -3, y: 0, duration: 0.04),
        .moveBy(x: 6, y: 0, duration: 0.04),
        .moveBy(x: -3, y: 0, duration: 0.04),
    ]), withKey: "denied")
}
```

In `refreshControlButtons` `.defenseLive` case, after configuring STEAL:

```swift
let cd = humanStealCooldownUntil - nowTime
buttonB?.setCooldown(cd > 0 ? CGFloat(cd / 3.0) : nil)
```

and add `buttonB?.setCooldown(nil)` in every other case that shows buttonB (`.offenseBallHoopLand`, `.offenseBallJumpBall`) plus the hidden cases (cheapest: call it once before the switch).

- [ ] **Step 7: Three distinct fail reads in `tryGestureSteal`.** Replace the leading cooldown guard:

```swift
guard nowTime > humanStealCooldownUntil else {
    buttonB?.deniedShake()
    HapticManager.impact(.light)
    return
}
```

Keep "GET CLOSER!" as-is (range read). In the failed-roll branch, before the "NO GOOD" callout, add `players[handlerID]?.flashGlint()` — and in `PlayerNode`:

```swift
/// Brief white flash — "you touched it but didn't get it" steal feedback.
func flashGlint() {
    guard let spriteNode else { return }
    spriteNode.removeAction(forKey: "glint")
    spriteNode.color = .white
    spriteNode.colorBlendFactor = 0.55
    spriteNode.run(.sequence([
        .wait(forDuration: 0.05),
        .customAction(withDuration: 0.25) { node, t in
            (node as? SKSpriteNode)?.colorBlendFactor = 0.55 * (1 - t / 0.25)
        },
    ]), withKey: "glint")
}
```

- [ ] **Step 8: Tests + build; commit** — `feat: graded block window, contest-degrade, visible steal cooldown (F8)`

---

### Task 13: F9 — Make/miss ceremony

**Files:**
- Modify: Scene — net container in `buildCourt`, `handleScore` (make ceremony), `performLaunch` (capture offset), `handleFloorContact` (rattle vs SHORT/LONG); Factory — programmatic gold-burst emitter.

**Interfaces:**
- Produces: `HalfCourtSpriteFactory.goldBurst()`; Scene `netNode: SKNode?`, `lastShotErrorOffset: CGFloat`.

- [ ] **Step 1: Net container.** In `buildCourt`, replace the loose net-line loop with a container so it can snap:

```swift
let net = SKNode()
net.position = CGPoint(x: rimX, y: rimY)
for i in 0..<6 {
    let netLine = SKShapeNode()
    let netPath = CGMutablePath()
    let xOff = -rimR + 3 + CGFloat(i) * ((rimR * 2 - 6) / 5)
    netPath.move(to: CGPoint(x: xOff, y: -3))
    netPath.addLine(to: CGPoint(x: xOff * 0.6, y: -30))
    netLine.path = netPath
    netLine.strokeColor = SKColor.white.withAlphaComponent(0.7)
    netLine.lineWidth = 1.2
    net.addChild(netLine)
}
courtLayer.addChild(net)
netNode = net
```

(Property `private var netNode: SKNode?` beside `rimNode`. Geometry identical: old absolute coords minus `(rimX, rimY)`.)

- [ ] **Step 2: Gold burst in Factory:**

```swift
private static var burstTexture: SKTexture = {
    let size = CGSize(width: 8, height: 8)
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { ctx in
        SKColor.white.setFill()
        ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
    }
    return SKTexture(image: image)
}()

/// One-shot 12-particle gold burst for made baskets — no texture assets.
static func goldBurst() -> SKEmitterNode {
    let e = SKEmitterNode()
    e.particleTexture = burstTexture
    e.particleBirthRate = 240
    e.numParticlesToEmit = 12
    e.particleLifetime = 0.5
    e.particleSpeed = 90
    e.particleSpeedRange = 30
    e.emissionAngleRange = .pi * 2
    e.particleAlpha = 1.0
    e.particleAlphaSpeed = -2.0
    e.particleColor = SKColor(red: 1, green: 0.84, blue: 0, alpha: 1)
    e.particleColorBlendFactor = 1
    e.particleScale = 0.75
    e.particleScaleSpeed = -0.8
    return e
}
```

(`import UIKit` if not present — Factory already imports SpriteKit which pulls UIKit on iOS; verify.)

- [ ] **Step 3: Make ceremony.** Scene helper:

```swift
private func celebrateMake(points: Int, powered: Bool) {
    // Net snap
    netNode?.removeAllActions()
    netNode?.yScale = 1.0
    netNode?.run(.sequence([.scaleY(to: 1.25, duration: 0.08), .scaleY(to: 1.0, duration: 0.10)]))
    // Gold burst
    let burst = HalfCourtSpriteFactory.goldBurst()
    burst.position = CGPoint(x: rimX, y: rimY - 8)
    burst.zPosition = 80
    fxLayer.addChild(burst)
    burst.run(.sequence([.wait(forDuration: 0.8), .removeFromParent()]))
    // Point pop at the rim
    let pop = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    pop.text = "+\(points)"
    pop.fontSize = 22
    pop.fontColor = powered
        ? SKColor(red: 1, green: 0.55, blue: 0.1, alpha: 1)
        : SKColor(red: 1, green: 0.84, blue: 0, alpha: 1)
    pop.position = CGPoint(x: rimX, y: rimY + 20)
    pop.zPosition = 210
    fxLayer.addChild(pop)
    pop.run(.sequence([
        .group([.moveBy(x: 0, y: 40, duration: 0.6), .fadeOut(withDuration: 0.6)]),
        .removeFromParent(),
    ]))
}
```

Call `celebrateMake(points: points, powered: isPowered)` in `handleScore`'s home-make branch (after `homeScore += points`), and `celebrateMake(points: 1, powered: false)` in the free-throw make branch. CPU makes get net-snap only: `netNode?.run(...)` — add the two-line snap there (no burst/pop for the opponent).

- [ ] **Step 4: Rattle vs SHORT/LONG.** In `performLaunch`, add property `private var lastShotErrorOffset: CGFloat = 0` and set `lastShotErrorOffset = launch.errorOffset` at the top. In `handleFloorContact`'s home-miss branch, replace the random miss callout block with:

```swift
let off = lastShotErrorOffset
if abs(off) <= 32 {
    // Grazed the iron — near-miss read
    rimNode?.removeAction(forKey: "rattle")
    rimNode?.run(.repeat(.sequence([
        .moveBy(x: 0, y: -3, duration: 0.04),
        .moveBy(x: 0, y: 3, duration: 0.04),
    ]), count: 3), withKey: "rattle")
    showCallout(["OFF THE RIM!", "RATTLED OUT!", "SO CLOSE!"].randomElement() ?? "OFF THE RIM!",
                color: SKColor.white.withAlphaComponent(0.6))
} else {
    // Clean miss — teach the direction
    let tag = SKLabelNode(fontNamed: "AvenirNext-Bold")
    tag.text = off < 0 ? "SHORT" : "LONG"
    tag.fontSize = 14
    tag.fontColor = SKColor.white.withAlphaComponent(0.7)
    tag.position = CGPoint(x: rimX - 80, y: rimY + 60)
    tag.zPosition = 210
    fxLayer.addChild(tag)
    tag.run(.sequence([
        .group([.moveBy(x: 10, y: 0, duration: 0.8), .fadeOut(withDuration: 0.8)]),
        .removeFromParent(),
    ]))
    showCallout(off < 0 ? "SHORT!" : "TOO STRONG!", color: SKColor.white.withAlphaComponent(0.6))
}
HapticManager.impact(.medium)
```

- [ ] **Step 5: Build; manual check** (make → net snap + burst + "+2" pop + gold score flash; near-miss → rim rattle; big miss → SHORT/LONG). **Commit** — `feat: make/miss ceremony — net snap, gold burst, point pop, rattle vs SHORT/LONG (F9)`

---

### Task 14: Final verification + version bump

**Files:**
- Modify: `ios/project.yml` (`CURRENT_PROJECT_VERSION` → today's timestamp `20260701HHMMSS`).

- [ ] **Step 1:** Full build + full test suite — both green.
- [ ] **Step 2:** Regression greps: `grep -n "contestResolved, *$\|contestResolved," Scene` guards intact; `grep -n "onBeatWindow\|powerUpDuration" Scene` values unchanged (0.175 / 12); `grep -n "gameStats = HalfCourtStats()" Scene` inside `resetMatch`.
- [ ] **Step 3:** Bump `CURRENT_PROJECT_VERSION` in `ios/project.yml`; regenerate project if the repo workflow requires (`xcodegen` — check README) — note: the checked-in `.xcodeproj` reads the value at build time via build settings; verify by building.
- [ ] **Step 4:** Commit — `chore: v2.4.0 build stamp` — then run the adversarial review + fun-criteria judge per the spec's verification plan (workflow, outside this document).

---

### Task 15 (P2 stretch, only after Task 14 is green): F12 — CPU steal telegraph FSM

**Files:**
- Modify: Scene — replace per-frame steal RNG in `updateOffBall` (~:863–877); Player — reach telegraph visuals.

**Interfaces:**
- Produces: Scene `enum CPUReachState { case none, stalking(since: TimeInterval), reaching(until: TimeInterval) }`, `PlayerNode.showReachTelegraph()` / `.stagger(duration:)`.

- [ ] **Step 1: Player telegraph + stagger:**

```swift
/// Red flash + "!" bubble: the defender is about to reach in.
func showReachTelegraph() {
    guard let spriteNode else { return }
    spriteNode.removeAction(forKey: "reachTint")
    spriteNode.color = SKColor(red: 1, green: 0.25, blue: 0.2, alpha: 1)
    spriteNode.colorBlendFactor = 0.35
    spriteNode.run(.sequence([
        .wait(forDuration: 0.35),
        .run { [weak spriteNode] in spriteNode?.colorBlendFactor = 0 },
    ]), withKey: "reachTint")

    let bubble = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    bubble.text = "!"
    bubble.fontSize = 26
    bubble.fontColor = SKColor(red: 1, green: 0.35, blue: 0.3, alpha: 1)
    bubble.position = CGPoint(x: 0, y: playerHeight + 8)
    bubble.setScale(0.2)
    addChild(bubble)
    bubble.run(.sequence([
        .group([.scale(to: 1.0, duration: 0.12), .fadeAlpha(to: 1, duration: 0.12)]),
        .wait(forDuration: 0.5),
        .fadeOut(withDuration: 0.15),
        .removeFromParent(),
    ]))
}

private var staggeredUntil: TimeInterval = 0
var isStaggered: Bool { lastTickTime < staggeredUntil }

/// Defender lunged and missed — brief stun with a sad wobble.
func stagger(duration: TimeInterval) {
    staggeredUntil = lastTickTime + duration
    playAnimationOnce(.sad)
}
```

- [ ] **Step 2: Scene FSM.** Add state + difficulty-tabled tuning:

```swift
private enum CPUReachState { case none, stalking(since: TimeInterval), reaching(until: TimeInterval) }
private var cpuReach: CPUReachState = .none
private var reachCooldownUntil: TimeInterval = 0

private var reachWindup: TimeInterval {
    switch difficulty {   // monotonic (W6)
    case .easy: return 0.5
    case .normal: return 0.4
    case .hard: return 0.3
    }
}
private var reachLandChance: CGFloat {
    switch difficulty {
    case .easy: return 0.55
    case .normal: return 0.70
    case .hard: return 0.85
    }
}
```

Replace the per-frame steal block in `updateOffBall` with:

```swift
if possession == .home, playState == .homeLive, nowTime > reachCooldownUntil,
   let awayID = awayIDs.first, let defender = players[awayID],
   let humanID = activeHumanID, let human = players[humanID] {
    let dist = hypot(defender.position.x - human.position.x, defender.position.y - human.position.y)
    switch cpuReach {
    case .none:
        // No reach may START once the shot is gathered (charge > 0.3) — kills charge-eating grief.
        if dist < 48, tapMeterFill <= 0.3, !defender.isStaggered {
            cpuReach = .stalking(since: nowTime)
        }
    case .stalking(let since):
        if dist >= 48 || tapMeterFill > 0.3 {
            cpuReach = .none
        } else if nowTime - since >= 0.35 {
            cpuReach = .reaching(until: nowTime + reachWindup)
            defender.showReachTelegraph()
            HapticManager.impact(.rigid)
        }
    case .reaching(let until):
        if dist >= 30 + 48 - 48 + 30 {  // see resolve below; escape check uses 30pt separation gain
            // handled at resolution
        }
        if nowTime >= until {
            cpuReach = .none
            reachCooldownUntil = nowTime + 2.8
            if dist >= 48 + 30 {
                // Escaped: dash created separation
                defender.stagger(duration: 0.6)
                showCallout("ANKLES!", color: SKColor(red: 0.4, green: 0.95, blue: 0.5, alpha: 1))
            } else if CGFloat.random(in: 0...1) < reachLandChance {
                showCallout("STOLEN!", color: SKColor(red: 1, green: 0.35, blue: 0.3, alpha: 1))
                HapticManager.notification(.error)
                givePossession(to: .away)
            } else {
                defender.stagger(duration: 0.4)
                showCallout("HELD ON!", color: SKColor.white.withAlphaComponent(0.7))
            }
        }
    }
} else if case .reaching = cpuReach {
    // Possession/state changed mid-reach (e.g. PASS) — defender lunges at air.
    cpuReach = .none
    reachCooldownUntil = nowTime + 2.8
    if let awayID = awayIDs.first { players[awayID]?.stagger(duration: 0.4) }
} else {
    cpuReach = .none
}
```

Clean the stray `if dist >= ...` placeholder line before committing — escape is resolved once at `until`, and the PASS counter is the `else if case .reaching` branch (activeHumanID changes → the human/defender pair distance recomputes against the new handler far away). Reset `cpuReach = .none`, `reachCooldownUntil = 0` in `givePossession`.

- [ ] **Step 3: Remove `stealCooldownUntil` uses in that block** (the FSM's `reachCooldownUntil` replaces the 3.5 s cooldown); leave the property if other references exist (verify with grep; `startGame` resets it — keep harmless resets).
- [ ] **Step 4: Build; manual playtest per difficulty** — steals must feel dodgeable; approximate prior steal frequency. **Commit** — `feat: CPU steal telegraph FSM with dash/pass counters (F12, stretch)`

---

### Task 16 (P2 stretch): F13 — Honest joystick knob

**Files:**
- Modify: Scene — `updateHuman` (~:747), `JoystickNode` (~:2311).

- [ ] **Step 1:** In `JoystickNode` add:

```swift
/// Mirror the APPLIED movement delta so the visual never lies (F13):
/// the knob shows where the player is actually being pushed this frame.
func reflectApplied(dx: CGFloat, dy: CGFloat) {
    let scale: CGFloat = 6  // visual gain: 5pt/frame drag ≈ 30pt knob deflection
    var vx = dx * scale, vy = dy * scale
    let dist = hypot(vx, vy)
    if dist > baseRadius { vx = vx / dist * baseRadius; vy = vy / dist * baseRadius }
    let target = CGPoint(x: vx, y: vy)
    knob.position = CGPoint(x: knob.position.x + (target.x - knob.position.x) * 0.5,
                            y: knob.position.y + (target.y - knob.position.y) * 0.5)
}
```

and in `end()` replace `knob.position = .zero` with `knob.run(.move(to: .zero, duration: 0.15))` — but the node hides immediately, so keep `.zero` (hidden anyway) — **skip the recenter animation; keep `end()` as-is.**

- [ ] **Step 2:** In `updateHuman`, after the `player.position` update inside the `if abs(dx) > 0.3 || abs(dy) > 0.3` block, add `joystickNode?.reflectApplied(dx: dx, dy: dy)`; in `JoystickNode.move(to:)`, stop moving the knob to the raw touch point (delete the knob.position assignment there — `reflectApplied` now owns it) but keep `vector` updated for potential future use.
- [ ] **Step 3:** Build; manual check (knob tracks actual push, stops when player stops). **Commit** — `fix: joystick knob mirrors applied movement (F13, stretch)`

---

## Self-Review Notes

- **Spec coverage:** F1→T2, F2→T4, F3→T5, F4→T6, F5→T7, F6→T3, F7→T11, F8→T12, F9→T13, F10→T8, F11→T9, F14→T10, F12→T15, F13→T16. W6 guard → T1. Version bump → T6 (footer) + T14 (build stamp). All 14 features + verification covered.
- **Order rationale:** T3 (lanes) before T4 (foul callouts use event lane defaults — no dependency break either way); T4 before T8 because T8 edits the same `handleFloorContact` line T4 rewrites (avoid conflicting instructions); T12 step 5 further edits the away-miss branch — instructions written against the post-T4 code.
- **Known deviations from spec, justified inline:** hint copy "TAP STEAL!" (no "B" label exists on-screen); F8 contest-degrade uses an in-flight velocity tip because the block window sits mid-flight (`pendingLaunch` is nil by then — the spec's own timing note confirms); F5 expects `hudOpacity` to be dead code (verify by grep in T7 step 1).
- **Type consistency check:** `BlockGrade` used in T12 only; `HalfCourtStats.registerBeatRelease` defined T11 step 3, consumed T11 step 5; `nextTeamAfterMiss` defined T4, referenced T8/T12 edits — verified consistent naming throughout.
