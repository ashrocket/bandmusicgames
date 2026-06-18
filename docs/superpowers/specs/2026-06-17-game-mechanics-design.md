# Half Court Hero — Game Mechanics Rework
**Date:** 2026-06-17  
**Status:** Approved — implementing

---

## Goal

Replace the tap-pump shot meter with a press-hold-flick gesture system. Add discrete offensive gestures (pass, bounce pass, shoot), defensive gestures (steal, block, foul, shooting foul), and free throw mode. Remove the StormSkyNode lighting effect. Make the power meter prominently visible.

---

## 1. Touch Zones

| Zone | Bounds | Purpose |
|---|---|---|
| Left side | x < width × 0.5 | Player movement (floating joystick) |
| Bottom-right | x > width × 0.5 **and** y < height × 0.5 | Action zone: all game actions |
| Top-right | x > width × 0.5 and y ≥ height × 0.5 | Dead zone (no input) |

The joystick already spawns at the touch origin and resets on each new left-side tap — no change needed to movement control logic.

---

## 2. Offense Gesture Pipeline

Applies when `playState == .homeLive` and `possession == .home`.

### Gesture Classification (on right-touch lift)

| Gesture | Detection Criteria | Action |
|---|---|---|
| Quick tap | duration < 0.15s, displacement < 30pt, no recent right tap | Pass (switch to teammate) |
| Double tap | Quick tap within 0.30s of prior quick tap | Bounce pass |
| Long press + flick up | Hold ≥ 0.30s, then fast upward velocity (dy > 50pt, speed > 200pt/s) | Shoot |
| Long press + slow lift | Hold ≥ 0.30s, no flick detected | Cancel — meter resets silently |

### Shot Meter Filling

While the right touch is held for ≥ 0.15s, the meter fills continuously at a difficulty-scaled rate (`chargeRate` replaces `tapPumpAmount`):

| Difficulty | chargeRate | Green entry | Green exit | Window |
|---|---|---|---|---|
| Easy | 0.75/s | ~0.69s | ~1.01s | ~320ms |
| Normal | 0.95/s | ~0.55s | ~0.80s | ~250ms |
| Hard | 1.10/s | ~0.47s | ~0.69s | ~220ms |

The meter decays at the existing `meterDecayRate` (0.18/s) while NOT held, so it drains between charges.

### Shot Type by Court Position

Determined by player X at the moment of flick:

| Position | Shot Type | Points | Callout |
|---|---|---|---|
| x < threePointX | 3-point pump shot | 3 | "PUMP 3!" |
| x > rimX − 90 | Layup | 2 | "LAYUP!" |
| Otherwise | Jump shot | 2 | character quip or "CONTESTED!" |

### Shot Outcome by Fill at Flick

| Fill zone | Outcome | Effect |
|---|---|---|
| Under green (< 0.52) | Airball or early rim | Miss, `lateAccuracy` |
| Green, not perfect | Rim-in or backboard-in | Scores w/ `rattleRim()` |
| Perfect zone | Swish | Scores, no rattle, `perfectAccuracy` = 1.0 |
| Over green (> 0.76) | Backboard clank or over | Miss, `lateAccuracy` |

---

## 3. Defense Gesture Pipeline

Applies when `playState == .awayLive` or `playState == .awayShot`.

| Gesture | Detection | Action |
|---|---|---|
| Quick tap (CPU has ball) | < 0.15s, near CPU handler < 52pt | Steal attempt |
| Swipe up | dy > 50pt, fast upward | Block attempt (uses green-window meter) |
| Swipe down | dy < −50pt, fast downward | Block attempt (poke) |
| Tap near non-ball-carrier | < 0.15s, within 40pt of any CPU player without ball | Foul |
| Tap near shooting player | < 0.15s, `playState == .awayShot`, within 56pt of handler | Shooting foul → free throw mode |

Block attempt: unchanged logic — succeeds if `cpuBlockFill` is in green window, else "TOO EARLY" / "TOO LATE".

---

## 4. Free Throw Mode

**Trigger:** Shooting foul detected.

**Flow:**
1. Interrupt CPU shot (`pendingLaunch = nil`, `ball?.hold()`)
2. New `PlayState.homeFreethrow(shotsRemaining: 2)` 
3. Human player moves to free throw position: `CGPoint(x: rimX − 190, y: bandMid)`
4. Show callout "SHOOTING FOUL! 2 FREE THROWS"
5. Same long-press + flick mechanic, no defenders interfere
6. Each made free throw: `homeScore += 1`; each miss: no points
7. After 0 remaining: `scheduleGivePossession(to: .away, after: 0.6)`

---

## 5. Power Meter Visibility

### Remove

- `StormSkyNode` instantiation from `buildCourt()`
- `private var stormSky: StormSkyNode?` declaration
- All `stormSky?.setCharge(...)` and `stormSky?.prime(...)` calls

### TapShotMeterNode Changes

| Property | Before | After |
|---|---|---|
| Bar height | 16pt | 28pt |
| Background alpha | 0.45 | 0.85 |
| Background stroke | 0.18 alpha white | 0.7 alpha white, 2pt |
| Green zone alpha | 0.30 | 0.70 |
| Perfect zone alpha | 0.45 | 0.85 |
| Position | y = height × 0.64 | y = height × 0.32 (near action zone) |

---

## 6. Files Changed

| File | Change |
|---|---|
| `HalfCourtHeroScene.swift` | Touch routing, gesture classifier, hold-fill meter, free throw state, storm removal, meter position |
| `HalfCourtHeroTypes.swift` | Replace `tapPumpAmount` with `chargeRate`; add `PlayState.homeFreethrow` |
| `StormSkyNode.swift` | No change — file stays, just unused |

---

## Non-Goals

- CPU free throws (CPU fouls on player — not implemented)
- Gesture tutorials / onboarding hints for new controls
- Bounce pass distinct physics (same as regular pass, just different callout)
