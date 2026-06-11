# Storm Timing Cue + Flip Scouting Cards — Design

**Date:** 2026-06-11
**Game:** Half Court Hero (native iOS SpriteKit, `ios/BandMusicGames/Views/Games/HalfCourtHero/`)
**Scope:** Native iOS only. The web game (`lizzymcguire` repo) is untouched.

## Problem

1. **Shot timing cue is invisible.** The charge meter's green release window and perfect
   zone are drawn as arcs around the SHOOT button — directly under the player's thumb.
   The cue is structurally hidden at the exact moment it matters.
2. **The flip-to-expand scouting cards are gone.** The loved card-flip detail view from
   branch `lizzie-direct-launch` (commit `ad132c3`) was never merged; the SpriteKit
   rebuild (`07cd55c`) replaced the select screen with a flat grid.

## Feature 1 — Storm timing cue

The sky becomes the charge meter: it darkens while you hold SHOOT, lightning strikes and
the sky turns green when the release window opens, and the clouds part when the window
has passed. The sky is the one place a thumb can never cover.

### What the storm represents

The **hold-to-charge meter only** (charge 0→1.18, green window 0.50–0.80, perfect
0.60–0.70 in `HalfCourtHeroScene.swift` tuning block). The 112 BPM beat ring, haptic
beat pulse, on-beat streak, and ON FIRE power-up are untouched — rhythm is felt and
heard; the charge window must be seen.

### New node: `StormSkyNode`

New file `ios/BandMusicGames/Views/Games/HalfCourtHero/StormSkyNode.swift`. Added to
`courtLayer` at `zPosition = -5`: above the painted `hch_court` backdrop (−10), below
players (40+), so players/ball/HUD stay bright while the world behind them storms.

**API:** `func setCharge(_ charge: CGFloat?)` — mirrors `ShootButtonNode.setCharge`.
Called every frame from the scene's existing `updateCharge(_:)` and from
`cancelCharge()` (with `nil`). The visual is a pure function of the charge value, so the
sky can never drift out of sync with the meter. An internal stage enum
(`clear / building / green / parted`) makes one-shot transitions (lightning, part
animation) fire exactly once per charge cycle.

**Stages:**

| Charge | Sky | One-shot effects |
|---|---|---|
| `nil` (idle/released/cancelled) | Everything fades out in ~0.15 s | — |
| 0 → 0.50 (building) | Dark overlay ramps 0 → ~50% black, eased, darker toward the top of the screen | — |
| 0.50 → 0.80 (green window) | Green wash (matching meter green, ~`SKColor(0.2, 0.83, 0.2)`) holds over the sky; brightest during perfect zone 0.60–0.70 | On entry: procedural jagged lightning bolt from the top of the sky (~0.2 s white flash) + heavy "thunder" haptic |
| > 0.80 (too late) | Dark layer splits into two halves that slide outward and fade (~0.25 s); sky returns to normal while still holding | Part animation fires once |

**Construction details:**

- Dark layer: two half-screen black sprites (so the "clouds part" split is free) with a
  vertical gradient bias (darker at top). Alpha driven per frame while building.
- Green wash: one full-sky sprite, alpha driven per frame inside the window.
- Lightning bolt: `SKShapeNode` with a randomly jittered 3–4 segment `CGPath` from the
  top edge down into the sky region, white core + wider faint glow path, flash-and-remove.
- Haptics: `HapticManager.impact(.heavy)` on window entry (the "thunder"), so the window
  opening is felt as well as seen. Existing haptics unchanged.

**Cleanup paths are free:** shot-clock expiry, possession change, and release all already
call `cancelCharge()`, which calls `setCharge(nil)`.

**Unchanged:** SHOOT button arcs remain as a redundant secondary cue. `flashScreen()`
(ON FIRE, z 240) and HUD (z 100) draw above the storm; no conflict. CPU shots never
drive the storm (`updateCharge` only runs for the human).

### Pacing change

`chargeRate` 1.4 → **1.0** in the tuning block: full meter in ~1 s, green window
~300 ms (was ~210 ms), so a sky-sized cue has time to read. All other tuning constants
unchanged.

## Feature 2 — Long-press flip scouting cards

Restore the flip-to-expand hero detail card on the character select screen, ported from
`git show ad132c3:ios/BandMusicGames/Views/Games/LizzyMcGuireGameView.swift`
(`HeroDetailOverlay`, `StatBar`) into the current `LizzyMcGuireGameView.swift`.

### Trigger

- **Tap = select** (unchanged two-step flow: ball handler, then teammate).
- **Long-press ~0.4 s = flip open** the scouting card, via `simultaneousGesture` on the
  existing grid `Button`, with a medium haptic on open.
- Discoverability: small caption "HOLD A CARD FOR SCOUTING REPORT" under the select
  header.

### Animation (kept exactly as the loved original)

Dimmed black backdrop (tap to dismiss); detail card animates in with
`rotation3DEffect` from −82° on the Y axis, `perspective` 0.55, scale 0.82 → 1,
opacity 0 → 1, driven by `.spring(response: 0.5, dampingFraction: 0.8)`. ✕ button or
tap-outside closes.

### Card content

- Portrait badge (`HalfCourtHeroBadge`), name, full name, role · height — all present
  in the current `HalfCourtHero` model.
- Stat bars with the original formulas: SHOOTING `min(1, 0.5 + threeBonus * 4)`,
  DEFENSE `min(1, 0.42 + stealBonus * 2.6)`, SPEED `min(1, speed * 0.78)`.
- **ABILITY section replaces the old SPECIAL section.** Special moves existed only in
  the old Canvas game and would lie about current gameplay. Instead show the hero's
  ability (e.g. "3PT SHOOTER") with one sentence of flavor text per hero, stored as a
  new `abilityBlurb: String` on `HalfCourtHero` (written during implementation, in the
  voice of the existing `quip`s), plus the real power-up tip: "3 on-beat shots in a
  row = ON FIRE 🔥".
- **Action button adapts to the select flow:** step 1 → "PICK AS BALL HANDLER";
  step 2 → "ADD AS TEAMMATE" (disabled/"ALREADY ON TEAM" for the chosen ball handler).
  Choosing from the card closes the overlay and advances the flow.
- Long-press must still open the scouting card for the step-2 disabled (already-picked)
  ball handler card — attach the long-press to the cell container, not the disabled
  `Button`, so the gesture survives `.disabled()`.

## Testing

- **Storm:** unit-test the stage mapping (charge value → stage enum) as a pure function;
  on-device playtest for readability (does the darkness ramp telegraph the strike?) and
  the chargeRate feel. Verify cleanup on shot-clock expiry and mid-charge possession
  change leaves the sky clear.
- **Cards:** verify tap-select still works first try (no gesture conflict with
  long-press), flip opens on every card in both steps, selection from the card advances
  the flow, and the overlay closes on ✕ / outside tap. Run on a compact-height device
  (the select screen has `compact` layout paths).

## Out of scope

- Web game changes, cloud sprite art (the procedural plumbing accepts art later),
  special moves as gameplay, any change to beat/ON FIRE mechanics.
