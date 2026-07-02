# Half Court Hero (Nara's Room) v2.4.0 — Fun & Playability Polish

**Date:** 2026-07-01
**Subgame:** Lizzy McGuire / Nara's Room — Half Court Hero (`ios/BandMusicGames/Views/Games/HalfCourtHero/`, shell `LizzyMcGuireGameView.swift`)
**Version:** v2.3.1 → **v2.4.0** (subgame-scoped version, per project convention)
**Goal:** raise moment-to-moment fun and session playability to the bar set by Flappy Bird (instant loop, chased number, attributable failure) and Hoop Land (visible timing target, tight verbs, juice on every bucket).

Provenance: 6-agent code audit (14 ranked gaps) → 3 competing designs (feel-first / loop-first / depth-first) → 3-judge panel (arcade, engineering-risk, design-theory) → synthesis. Design B's loop chassis won (smallest invariant blast radius); A's beat-visibility and readability slices grafted; C's depth work survives as two grafts + one P2 stretch.

## Thesis

The 112 BPM pulse finally lives on the SHOOT ring and rim the thumb already watches; every make gets a 0.3 s ceremony and the score never fades; the foul exploit dies; and the session becomes an unbroken chain of attempts — 1 tap from cold launch to live ball, 1 tap from SERIES LOST to a same-squad rematch, with a persisted best-beat-streak printed beside the RUN IT BACK button so the newly visible beat becomes a chased number.

## Invariants — must not break

- **W1** Mid-series 1-tap restart (~1.3 s to live ball). Only the series-over card variant changes.
- **W2** ON FIRE economy: ±175 ms window, 3-streak, 12 s, +0.15 accuracy, +1/make. No numbers touched.
- **W3** Shot-timing attribution (under-charge misses short / over-charge long). New effects scale `errorOffset` **magnitude only, sign preserved**; move-during-shot is explicitly deferred.
- **W4** StormSkyNode semantics + phantom-strike guard. **Correction to the audit:** `StormSkyNode` is currently *dead code* — no scene reference since `6d41189` (verified: grep + `git log -S`). See F14.
- **W5** Existing haptic/callout priority ordering. New feedback is additive (second lane, button-local, sprite-local).
- **W6** Honest monotonic difficulty (a06060a); JumpBall green-never-perfect (a07e204). JumpBall apex-tap is out of scope.
- **W7** Beat-anchor rules: latch only after audio confirms (fa93bb7); reset on `startSeries` NOT `startGame` (324f9f6); rawDt shift on un-pause > 0.5 s. Each new entry point audited below.
- **W8** ON FIRE/streak reset per game in `resetMatch` (769f05c). New per-game state resets in the same place.
- **W9** Two-button + joystick control budget. Zero new buttons/gestures.
- **W10** a07e204 contest-window guard (`contestResolved`, `pendingPossession`, `scoredThisFlight`, `missResolved`) preserved verbatim.
- **W11** No sound-effect assets exist; the streamed song is the soundtrack. v2.4.0 adds **no audio** — all new feedback is visual/haptic. Synth SFX cut by all three judges (untested AVAudioSession-vs-Spotify contention).

## Features

### P0 — must ship (this set alone makes minute one noticeably better)

**F1 — Beat made visible: SHOOT-ring pulse + rim halo + streak-pip flash** *(G1 · S · low)*
In `updateBeat` (Scene:655–670), where `tapMeterNode?.beatPulse()` already fires into a permanently hidden node, add: (1) `buttonA?.beatPulse()` — new `ControlButtonNode` method: bg scales 1.0→1.06→1.0, charge-ring base alpha flashes 0.45→0.9→0.45; fires only in SHOOT contexts (`.homeLive`/`.homeFreethrow`) so it never pulses during BLOCK timing. (2) Rim beat halo: one pre-added `SKShapeNode` circle at the hoop, re-run each beat, scale 1.0→1.18 + alpha 0.5→0; fires whenever `phase == .playing`. (3) `streakPips` flash on beat while `onBeatStreak > 0`. **No audio click** (double-hits against streamed drums on 30 ms drift). Pure read of `beatAnchor` — zero W7 exposure.
*Tuning:* button scale-out 0.10 s easeOut / back 0.20 s easeIn; ring alpha up 0.10 s / down 0.20 s; halo radius 30 pt, 0.30 s, lineWidth 2, gold #FFD700; pip flash alpha 1.0→0.6→1.0 over 0.2 s; interval stays 60/112 = 535 ms via existing `lastBeatIndex`.

**F2 — Foul fix: dead-ball-retain reach-in, exploit dead** *(G3 · S · low)*
Judge-verified: `giveFreethrows` (Scene:1330–1350) is home-only, so "CPU shoots FTs" is hidden M/L work — adopt the dead-ball-retain shape, stiffened. In `attemptBlockOrFoul` (Scene:1284–1315), keep every W10 guard verbatim; replace the `triggerShootingFoul()` call with `reachInFoul()`: (1) callout "REACH-IN FOUL!" red big (event lane); (2) `.error` haptic — replacing the `.success` that today makes the exploit feel rewarding; (3) 0.6 s input lockout with `.sad` animation on the human; (4) the CPU shot **flies on** with `pendingLaunch.errorOffset` magnitude ×0.6 (sign preserved) — the foul helps the shooter, so BLOCK-spam costs points on makes; (5) if the shot still misses, CPU **retains possession** ("FOUL — THEY KEEP IT"); (6) any mistimed BLOCK starts a 1.2 s cooldown on button A rendered as a draining ring; taps during it no-op with `.light` haptic. `triggerShootingFoul`/`giveFreethrows` stay as dead code this PR.
*Tuning:* contest radius 56 pt unchanged; stagger 0.6 s; cooldown 1.2 s; foul grant errorOffset ×0.6 sign-preserving; retain inbound delay 0.45 s; red (1, 0.32, 0.30).

**F3 — RUN IT BACK: 1-tap same-squad rematch from series loss** *(G2 · S · low)*
New scene method `rematchSeries()`: zero series wins + scores, `phase = .playing` **first**, then `resetMatch()` — mirroring the verified mid-series order (Scene:1753–1756). `beatAnchor` untouched: audio plays continuously through the card (Scene:499–500), `beatSynced` stays true because `.characterSelect` is never entered (view:116). Card series-over variant: yellow primary at y −180 becomes **RUN IT BACK** → `rematchSeries()`; ghost at y −228 becomes **BACK TO LOBBY** → dismiss. Mid-series variant untouched (W1).
*Merge test:* lose a series → music never stops across the card → RUN IT BACK → an on-beat release still registers.
*Tuning:* loss → live ball: 1 tap, ≤1.5 s; positions/sizes/card scale unchanged.

**F4 — QUICK START: 1-tap cold start with persisted squad + difficulty** *(G4 · M · low)*
Persist `hch_last_player` / `hch_last_teammate` (written when PLAY is tapped, view:397) and `hch_difficulty` (written on selector tap, view:230–234 — fixes the `@State` reset at view:15). Title overlay: with a saved squad, primary yellow **QUICK START** ("QUICK START" 19 pt / "NARA + ETHAN · NORMAL" 10 pt) + ghost **CHANGE SQUAD** (8 pt below) opening the existing select. QUICK START calls `scene.quickStart(playerID:teammateID:difficulty:)` = `{ homeSeriesWins=0; awaySeriesWins=0; beatAnchor=nil; startGame(...) }` — phase jumps straight to `.playing`; the existing view:94–108 onChange (`beatSynced` false at cold start) fires playTrack → `realignBeatAnchor`, the exact fa93bb7 path. First run: no saved squad → unchanged flow; PLAY writes the defaults.
*Tuning:* 1 tap → live ball ~2 s incl. audio latch. Keys match the `hch_` prefix convention (`hch_nba_jerseys_mod`, Scene:246).

**F5 — Score never fades: delete HUD dim + score-pop micro-ceremony** *(G12 · S · low)*
Delete the 6 s dim block (view:111–113, `hudOpacity` → 0.18); keep the 0.5 s fade-in. HUD holds 1.0 all game. In `HalfCourtHUDNode.update`, pop the changed score label: scale 1→1.35→1.0 over 0.25 s with a 0.3 s gold flash, then restore team color.
*Tuning:* pop up 0.10 s easeOut / down 0.15 s easeIn; flash #FFD700, restore 0.3 s.

**F6 — Dual-lane callouts + honest steal hint** *(G10 · S · low)*
`showCallout` (Scene:1810–1839) gains a lane parameter (`.event` default, `.timing`); each lane keeps its own node reference so removal only clobbers within-lane. TIMING lane at y = height×0.58 + 36; EVENT at existing position. Route "ON BEAT ×N" / "ON FIRE!" (registerBeatTiming call sites) to `.timing`; shot-type/quips/defense stay `.event` — the same-frame collision (Scene:1377–1386 vs :1811) no longer erases streak progress. Stale hint retext: "SWIPE → STEAL" (Scene:1781) → **"B = STEAL"**; everything else unchanged.
*Tuning:* timing-lane offset +36 pt; existing display durations; no priority changes within event lane (W5).

### P1 — should ship

**F7 — Result-card stats + persisted records + NEW RECORD banner** *(G13 · M · low)*
Scene gains `gameStats: HalfCourtStats` (Types:27–35) + new `bestBeatStreak` field; incremented at `releaseShot`/`releaseJumpBallShot` (shots, threes via `beyondArc`), score contact (made), human steal success, block success, and `registerBeatTiming` (`bestBeatStreak = max(...)`); reset in `resetMatch` beside `onBeatStreak` (W8). Persist on game end: `hch_record_beat_streak`, `hch_record_margin`; on series end: `hch_career_series_w`/`_l`. Card layout in the empty band between sub (y −20) and action button (y −180): y −60 "FG 7/12 · 58%" | "3PT 3" (13 pt white 80%); y −88 "STL 2 · BLK 1" | "BEAT STREAK 4 🔥"; y −120 records line 12 pt white 45% "BEST STREAK 8 — YOU HIT 6" (near-miss framing) or pulsing gold "NEW RECORD — BEAT STREAK 6!".
*Tuning:* record pulse scale 1↔1.06, 0.6 s loop, #FFD700; verify card fits at `min(1, width/440)` on 667 pt landscape.

**F8 — Defense readability: graded block window, contest-degrade, cooldown sweep, three fail reads** *(G11 · M · medium)*
In `handleBlockAttempt`: `p = (cpuBlockFill − greenLow)/(greenHigh − greenLow)`; p ∈ [0.30, 0.70] → **95%** "SWATTED!" (big, shake 9); rest of window → **70%** "BLOCKED!" (replaces flat 72%). Failed in-window roll is no longer silent: "CONTESTED!" + CPU shot's `errorOffset` magnitude ×1.5 (min +6 pt, sign preserved, W3); if that degraded shot misses → green "FORCED THE BRICK!". STEAL cooldown made visible: button B renders a 3.0 s radial sweep, bg alpha 0.4 while cooling; taps during cooldown shake the button ±3 pt with `.light` haptic (button-local, W5). Third read: out-of-range tap → gray "GET CLOSER" (event lane); in-range failed roll → 0.3 s white glint on the handler sprite. Range vs cooldown vs luck become three distinct outcomes.
*Tuning:* 95/70% (expected in-window ≈ 0.80 — intentional slight buff); degrade ×1.5 min +6 pt; sweep 3.0 s; glint 0.3 s.

**F9 — Make/miss ceremony: net-snap, gold burst, point pop, rattle vs airball** *(G9 · M · low)*
Make: net scaleY 1→1.25→1 over 0.18 s; 12-particle gold burst at the rim (programmatic `SKEmitterNode`, 4 pt circle texture built in code in `HalfCourtSpriteFactory` — no asset); "+1/+2/+3" (actual points incl. ON FIRE bonus) pops at the rim, rises 40 pt, fades 0.6 s. Miss, reading the existing long/short branch (Scene:~1497, W3): rim-rattle path shakes rim ±3 pt ×3 over 0.24 s; airball path shows drifting "SHORT"/"LONG" tag at arc apex 0.8 s — attribution finally teaches. Camera nudge cut (risk for marginal juice).
*Tuning:* emitter lifetime 0.5 s, speed 90, one-shot 12, #FFD700; net snap 0.18 s; pop 22 pt AvenirNext-Heavy rise 40 pt/0.6 s; rattle ±3 pt ×3/0.24 s; tag 14 pt white 70%, drift +10 pt x, 0.8 s.

**F10 — Dead-time trims (constants only)** *(G6 · S · low)*
Pure constant changes, no resolution logic: miss→possession 0.6→**0.45 s**; make→possession 1.0→**0.7 s**; CPU dribble 0.8–1.5→**0.7–1.2 s**; rim-stuck fallback flight+3.2→**+2.0 s** (still safely above max flight+resolve). Shooter-locked-during-own-shot stays; move-after-release deferred to v2.5 with a snapshot test.
*Expected:* ~1.2 s less dead air per scoring exchange, ~15% more attempts/minute.

**F11 — Pinch threshold (realign REJECTED in adversarial review)** *(G7 · S · low)*
~~Add `scene.realignBeatAnchor()` after each resume~~ — **rejected during verification**: resume continues the track from its paused (arbitrary-phase) position, so a phase-0 re-latch would desync the beat grid by up to ±268 ms; the pre-existing rawDt>0.5 anchor shift (Scene `update`) is the correct compensation and stays as-is. Phase-0 latching is only valid after a fresh `playTrack` from 0:00 (the view:100–107 paths). Shipped part: pinch `minimumScaleDelta` 0.03→**0.12** at both sites (view:36, view:471) so freeze no longer hair-triggers mid-play.

**F14 — Rewire StormSkyNode to the hold-to-charge meter** *(new; from dead-code discovery · S · low)*
`StormSkyNode` (full-sky storm mirroring shot charge: clouds darken while charging, lightning + heavy haptic exactly when green opens, wash on perfect, clouds part past the window) shipped in 2a53193 and lost its call sites in the 6d41189 rework; it still compiles and `StormStageTests` still pass. Restore the original wiring against today's charge state: install via helper from `buildCourt()` **and** `startGame()` (bounds change per difficulty) at zPosition −5 in `courtLayer`; drive from `updateTapMeter`: while `.homeLive`/`.homeFreethrow` with `isChargingShot` or decaying fill > 0 → `setCharge(tapMeterFill)`, else `setCharge(nil)`; call `prime(charge:)` when recreated mid-charge by a layout rebuild. The phantom-strike guard (b579cf9) already handles decay descent. Makes charge timing readable with a thumb covering the button — Hoop Land's "visible timing target" at full-screen scale.
*Risk note:* the node fires one `.heavy` haptic at window-open (thunder) — previously shipped behavior, no current offense-side equivalent, no W5 conflict.

### P2 — severable stretch (only if P0+P1 land with playtest time)

**F12 — CPU steal telegraph: reach FSM with counters** *(G5 · M · medium)*
Replace per-frame RNG (Scene:863–877) with: defender within 48 pt continuously ≥0.35 s during `.homeLive` → REACH telegraph (red tint flash + "!" bubble + `.rigid` haptic), windup 0.5/0.4/0.3 s by difficulty. Counters: flick-dash gaining ≥30 pt → whiff, defender staggers 0.6 s, "ANKLES!", open look; PASS → lunge at empty hands, 0.4 s stagger. No counter → steal lands 55/70/85%. No reach may start once charge > 0.3 (kills charge-eating grief). Any resolution → 2.8 s cooldown. Tune trigger so net steals/possession ≈ current per difficulty; assert monotonic (W6).

**F13 — Honest joystick knob** *(G14 · S · low)*
Knob offset mirrors the **applied** movement delta each frame (clamped to base radius); knob lerps at 0.5/frame, recenters over 0.15 s on touch-up. Zero feel change — v2.3.0 "movement feel out of scope" ruling stands; velocity-from-knob explicitly rejected.

## Out of scope (judge consensus)

Synth SFX (W11 audio-session gamble — prototype behind a flag next cycle); move-after-release + aggressive dribble trims (W3 hazard, v2.5 with snapshot test); JumpBall apex-release tap (re-opens a07e204 ruling, v2.4.1 at earliest); pass travel + lane interception + catch-and-shoot (possession-logic rewrite, headline of v2.5.0); HYPE meter / special-moves port from lizzie-direct-launch (own PR); away free-throw engine; title-screen records strip; joystick-driven velocity; HUD restore-on-event choreography (superseded by F5).

## Verification plan

1. `xcodebuild` Debug for iPhone 16 simulator passes (baseline verified green pre-change).
2. `BandMusicGamesTests` pass — `StormStageTests` must stay green after F14.
3. Regression greps: a06060a difficulty table monotonic; a07e204 guards intact in `attemptBlockOrFoul`; `resetMatch` resets `gameStats` + streaks (W8).
4. Manual sim checks: cold start ≤1 tap with saved squad; series loss → RUN IT BACK ≤1 tap, music continuous, beat still registers; foul path shows REACH-IN + `.error` haptic + no human FTs; beat pulse visible on ring + rim; HUD never dims; storm sky builds/strikes/parts on a held charge.
5. Multi-agent adversarial code review of the diff before merge; fun-criteria judge re-score against the 13 benchmark principles.
