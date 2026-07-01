# Nara's Room — Button Control Modes + Landscape "Game Mode"

**Date:** 2026-06-30
**Status:** Approved, in implementation
**Target game:** Nara's Room / Lizzy McGuire = the `HalfCourtHero` engine (`HalfCourtHeroScene`)

## Goal

Give the HalfCourtHero basketball game two selectable **on-screen button** control
schemes, replacing the current gesture action-zone. Lock the game to **landscape** and
register the app for **iOS Game Mode**, matching the reference games (Hoop Land,
Basketball Battle, Mini Basketball, Basket Arena) the user recorded.

## Decisions (locked)

1. **Two modes only** — the current gesture scheme is dropped. `HoopLand` is the default; `JumpBall` selectable.
2. **Defense = context buttons** — the same buttons relabel by possession. A mistimed block becomes a foul automatically (reuse existing foul path).
3. **JumpBall shot = tap-jump, auto-shoot at apex** — no charge meter in JumpBall.
4. **Scope = engine-global** — one control-mode setting across every HalfCourtHero variant. Nara's Room is the first played this way.
5. **Movement stays** the existing left-thumb floating joystick in both modes.
6. **Build target = the full `HalfCourtHeroScene`**, not `MechanicsPrototypeScene` (a meter-only testbed with no passing/defense/CPU, which cannot host these controls). The TestFlight build boots **directly into Nara's Room** (a reversible entry flag mirroring the existing prototype-boot pattern).

## Control maps

**HoopLand (default)** — joystick (left) + two-button cluster (right):

| State | Button A | Button B |
|---|---|---|
| Offense | **PASS** — tap → pass; double-tap → bounce pass | **SHOOT** — hold → charges existing power meter; release → shoot |
| Defense | **STEAL** → `tryGestureSteal()` | **BLOCK** → `handleBlockAttempt()`; mistime → auto foul |

**JumpBall (Basketball-Battle-style)** — joystick (left) + two buttons (right), no meter:

| State | Button A | Button B |
|---|---|---|
| Offense | **PASS** — tap → pass | **JUMP** — tap → jump; shot auto-releases at apex; quality from openness/contest + small spread |
| Defense | **STEAL** | **JUMP** → block/contest; mistime → auto foul |

The charge meter shows only in HoopLand (re-anchored near the SHOOT button); hidden in JumpBall.

## Architecture

- **`HalfCourtControlMode: String`** enum (`hoopLand`, `jumpBall`) in `HalfCourtHeroTypes.swift`; persisted to `UserDefaults` key `hch_control_mode`, default `hoopLand`.
- **`HalfCourtControlsNode`** (new `SKNode`, child of `uiLayer`): renders the active mode's buttons, hit-tests touches, and reports discrete presses (`onPass`, `onShootDown`/`onShootUp` or `onJump`, `onSteal`, `onBlock`) via closures. Driven by two inputs — `mode` and `possession` (offense/defense) — so labels/handlers switch contextually. Adapts the dormant legacy `ShootButtonNode` visuals as a starting point.
- **`HalfCourtHeroScene`**: instantiate the controls node; route its callbacks to the existing action functions (`tryHumanPass`, `tryHumanBouncePass`, `releaseShot(charge:)`, `tryGestureSteal`, `handleBlockAttempt`, foul path). Retire the right-half gesture classifier (`classifyRightGesture`/`isActionZone`). Keep the left joystick. Add JumpBall auto-shoot-at-apex hooking the jump/shot system.
- **Settings UI**: a dropdown in `LizzyMcGuireGameView` following the `ForCuttingGrass` `ControlsDropdownPanel` pattern.

## Landscape + Game Mode

- Lock this game (menu + gameplay) to landscape on present, restore portrait on dismiss, via an added App-Delegate orientation hook (`@UIApplicationDelegateAdaptor` + dynamic `supportedInterfaceOrientationsFor`) and `requestGeometryUpdate`. Rest of the app stays portrait.
- `project.yml` Info.plist: declare `UISupportedInterfaceOrientations` (portrait + both landscapes so the app *can* rotate); add `GCSupportsGameMode = YES` and `LSApplicationCategoryType = public.app-category.games`. Regenerate with `xcodegen generate`.
- `layoutScene()` already recomputes court geometry from `w/h`, and shots use `launchVelocity(from:to:flightTime:)` targeting the rim, so shots self-scale to reach the hoop in landscape. Remaining work: reposition meter / HUD / joystick / buttons for landscape + safe area, and a jump-apex/arc tuning pass (vertical room shrinks).

## Files touched

- `HalfCourtHeroTypes.swift` — control-mode enum + UserDefaults helper
- `HalfCourtControlsNode.swift` — **new** button node
- `HalfCourtHeroScene.swift` — wire buttons, retire gesture zone, JumpBall apex shot, landscape layout
- `LizzyMcGuireGameView.swift` — settings dropdown; possibly host-level orientation hook
- `BandMusicGamesApp.swift` (+ new `AppDelegate`) — orientation lock; boot-into-Nara flag
- `ios/project.yml` — orientation + Game Mode Info.plist keys; version bump → 2.3.0; regenerate

## Testing / verification (manual, on device — SpriteKit)

- HoopLand: pass, double-tap bounce, hold-charge-release shot; on defense buttons relabel STEAL/BLOCK and act; mistimed block → foul/free throws.
- JumpBall: tap jump → jump + auto-shoot at apex (makeable when open, contested when guarded); pass works; on defense jump = block, pass = steal.
- Settings dropdown switches modes and persists across launches (UserDefaults round-trip; also unit-tested).
- Landscape: rotates in on launch, restores portrait on exit; shot reaches rim; no UI under notch/home indicator.
- iOS 18 Game Mode banner appears.

## Out of scope

Top-down camera (keep the side view), networked/2-player, the step/cross buttons, redesigning movement.
