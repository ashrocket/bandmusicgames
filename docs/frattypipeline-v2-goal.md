# Frattypipeline V2 Goal

## Goal

Build Frattypipeline V2 as a polished, music-driven isometric campus adventure where Groucho Barks is not just the soundtrack, but the core verb of the game.

The player controls Groucho through a dense, lively campus-town slice. Moving, barking, helping NPCs, unlocking places, and changing the mood of the world all happen in rhythm with the song. The target quality bar is the reference video analyzed in `docs/frattypipeline-reference-research.html`: a small world that feels expensive because its art, UI, animation, audio, quest loop, and environmental reactions all work together.

## Product Promise

Frattypipeline V2 should feel like a playable music video crossed with a compact life-sim quest loop.

In one 60 second phone capture, a viewer should understand:

1. Groucho is the hero.
2. Barking on beat changes the world.
3. The campus is alive with NPCs, props, color, and ambient motion.
4. The player has a clear quest and readable tools.
5. The game has enough polish to feel like a real BandMusicGames title, not a toy prototype.

## Context

The reference video shows an isometric farm-town adventure with:

- A rich tile-based world with shops, roads, paths, trees, water, props, and distinct districts.
- A readable HUD with quest text, hotbar actions, time/day state, and progression feedback.
- Small animation everywhere: character movement, particles, environmental idles, NPCs, UI feedback, and color shifts.
- A clear objective loop that gives the player a reason to move through the world.

Frattypipeline should borrow this production grammar, not the farm-sim setting. The Frattypipeline version is a campus-town pipeline: quad, porch, rehearsal room, house basement, vending area, stage, late-night path, and tunnel entrance.

## Constraints

- Native iOS work belongs in `ios/BandMusicGames/`.
- Sibling web repos stay separate deploy roots and should not receive native Swift code.
- V2 should start as a vertical slice before expanding into a full game.
- The first serious build should choose one engine path:
  - SpriteKit if the goal is iPhone-first inside the existing BandMusicGames native app.
  - Godot if the goal is broader cross-platform production with stronger visual tooling.
- The bark mechanic must affect gameplay state. It cannot be only a visual pulse.
- Scope must stay small enough to polish: one district, one quest chain, one core song mechanic, one compact cast.

## Core Player Loop

1. Explore a small campus-town district as Groucho.
2. Receive a short objective from an NPC, sign, stage, phone, or environmental cue.
3. Use bark actions on beat to reveal, activate, calm, hype, unlock, or redirect something.
4. Collect or deliver a small object, change the state of a room, or help an NPC.
5. Earn progress that opens the next path, crowd reaction, song layer, or visual state.
6. Repeat until the slice produces a complete two to three minute arc.

## V2 Design Pillars

### Groucho Is The Instrument

Barking is the main verb. A short bark, held bark, and three-beat bark phrase should each have a distinct purpose.

- Short bark: nearby interaction, reveal, pickup pulse, or NPC response.
- Held bark: room-state change, charged howl, crowd swell, or hazard interruption.
- Three-beat phrase: call-and-response puzzle, quest gate, or music-stem unlock.

### The World Reacts On Beat

The world should visibly answer the song. Lamps flicker, NPCs bob, signs shake, doors click open, speakers pulse, particles brighten, and crowd mood changes when Groucho lands the beat.

### Small World, High Density

The first slice should not be a big map. It should be a dense map. Every screen should contain a strong silhouette, two to four readable props, one interaction opportunity, and some ambient movement.

### UI Teaches Without Explaining

The HUD should show current quest, selected bark/tool, time or phase, and progress. A viewer should understand the next action without an instruction page.

### Clip-Worthy Polish

The acceptance target is a strong 60 second vertical phone capture. That clip should show traversal, bark interaction, NPC/world response, and a reward or reveal.

## Done When

Frattypipeline V2 vertical slice is done when:

1. Groucho can move through one complete isometric district with reliable collision and camera framing.
2. Groucho has readable idle, walk, bark, held bark, and interaction animations.
3. The Groucho Barks song drives a beat clock used by gameplay, VFX, NPC response, and UI feedback.
4. The player can complete one quest chain with at least three steps.
5. The world includes at least six NPCs or responsive characters, eight interactable props, and three visually distinct areas.
6. The HUD includes quest tracker, hotbar or bark selector, phase/time indicator, and feedback for successful beat timing.
7. Barking changes gameplay state in at least three ways.
8. The slice has save/load or debug reset so testing does not require replaying from scratch.
9. The game can produce a polished 60 second phone capture that meets the reference quality bar.

## Verification Required

- Run the game locally in the chosen target environment.
- Verify the HUD is readable on phone-sized screens.
- Verify the bark beat window feels responsive and not laggy.
- Verify all quest steps can be completed from a fresh state.
- Verify map triggers, NPC state, and interactable props survive scene restart.
- Verify the slice holds the target frame rate on the lowest supported device.
- Capture a 60 second vertical clip and compare it against `docs/frattypipeline-reference-research.html`.
- Use Browser-based verification for web prototypes or lobby surfaces.
- Use simulator/device verification for native iOS builds.

## V2 Milestones

### Milestone 1: Promise Prototype

Timebox: 1 to 2 weeks.

Deliver a rough but playable proof that Groucho can move, bark on beat, and cause one meaningful world reaction.

Acceptance:

- One small map.
- Placeholder Groucho.
- One bark action synced to the song tempo.
- One NPC or prop reacts.
- One simple quest objective appears and completes.

### Milestone 2: Playable Mood Slice

Timebox: 3 to 6 weeks.

Deliver the first version that looks and feels like the real direction.

Acceptance:

- One campus district with dense prop dressing.
- Three NPCs.
- Three bark interactions.
- Hotbar or bark selector.
- Quest tracker.
- Ambient particles, lighting pass, and basic day/night or phase shift.
- 30 second shareable clip.

### Milestone 3: V2 Vertical Slice

Timebox: 7 to 10 weeks.

Deliver a polished two to three minute loop.

Acceptance:

- Six NPCs or responsive characters.
- Eight to twelve interactables.
- Three-step quest chain.
- Multiple song-reactive world states.
- Save/debug reset.
- Final UI pass.
- 60 second phone capture that sells the game without explanation.

## Figma, GitHub, And Browser Handoff

### Figma

Create a Frattypipeline V2 design file with:

- One art-direction board: palette, camera angle, tile density, prop examples, UI mood.
- One HUD frame: quest tracker, hotbar, time/phase indicator, bark timing feedback.
- One map frame: quad, porch, rehearsal room, stage, tunnel entrance.
- One interaction storyboard: approach, bark, world response, reward.

### GitHub

Turn this goal into a V2 milestone with issue groups:

- Engine decision and project structure.
- Isometric movement and camera.
- Beat clock and bark input.
- Quest state and debug reset.
- Map data and interactable props.
- Groucho animation set.
- NPC reactions and crowd mood.
- HUD and mobile readability.
- Audio integration.
- Capture and QA checklist.

### Browser

Use Browser verification for:

- Static HTML concept reports.
- Web prototype playtests.
- Lobby entry points.
- Responsive screenshots of HUD concepts.
- Final shareable concept pages.

## First Implementation Ticket

Create the Frattypipeline V2 promise prototype.

Build one small isometric test scene where Groucho can move, bark on beat to trigger a visible world response, complete one tiny quest, and produce a 30 second clip that proves the direction. Keep all production code in the correct BandMusicGames target for the chosen engine path.
