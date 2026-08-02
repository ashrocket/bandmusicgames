# Will — hand-drawn sprite pipeline (Krita)

Companion pipeline to [Nara's Affinity + Synfig pipeline](../nara/README.md),
run through **Krita** instead, so the two can be compared side by side:
tool cost/complexity, drawing feel, and how well each round-trips into
`HalfCourtHeroPlayers.atlas`. Same frame spec and evidence-of-authorship
goals as Nara's — see her README for the shared rationale.

Krita has no bone/skeleton rig system. Instead of Synfig's rig-and-pose
step, this pipeline keeps head/torso/limbs as **separate Krita layers**
that get nudged per frame using onion-skinning + the built-in Animation
timeline, then exported straight to a PNG image sequence
(`File > Render Animation`). One tool, no export/import handoff between
apps — that's the main structural difference from Nara's pipeline, worth
noting when comparing.

## Frame spec (must match `PlayerNode.swift`) — same as Nara

- Export size: **256×256 px**, transparent background.
- Character body fills **~82%** of the frame height, feet at **~14%** from
  the bottom edge (anchor point `(0.5, 0.14)`).
- Frame naming: `will_<pose>_<NNN>.png`, zero-padded 3 digits, from `000`.
- Frame counts / playback: `idle` 8 @ 8fps loop, `run` 8 @ 14fps loop,
  `dribble` 8 @ 14fps loop, `shoot` 10 @ 16fps one-shot.
- Procedural "puppet" layer (bob/lean/squash-stretch) runs on top in-engine
  — don't bake heavy bounce into the frames themselves.
- Palette (`HalfCourtHeroTypes.swift`, case `.will`): hue `#9B59B6`,
  skin `#8D5524`, hair `#111111`, shirt `#9B59B6`, pants `#2C2C2C`,
  shoes `#9B59B6`.

## Stages

1. **01-reference** — model sheet (`will_model_sheet.png`): master portrait,
   current in-game atlas frames for idle/run/dribble/shoot, code palette.
2. **02-rough** — loose construction sketch per pose, own Krita layer.
3. **03-linework** — clean linework (Krita vector layer or a steady freehand
   layer at high zoom — Krita's pen tool supports both).
4. **04-color** — flat cel-shade fills below the linework layer, one shadow
   tone per surface, no gradients/brushwork/painterly shading.
5. **05-layered-parts** — split into separate layers/groups: head, torso,
   upper/lower arm (×2), upper/lower leg (×2). This is Krita's stand-in for
   Nara's bone rig — same idea (independently movable pieces), done by hand
   per frame instead of by a skeleton.
6. **06-poses** — use the Animation docker (timeline + onion skin) to nudge
   the layered parts into each pose per frame, per animation state.
7. **07-export** — `File > Render Animation` to PNG sequence, named per the
   spec above, staged here before copying into the Xcode atlas.

## Evidence-of-authorship checklist per pose

- [ ] Native `.kra` source kept unflattened (full layer stack, not merged).
- [ ] Source file committed to git incrementally.
- [ ] Screen-recorded session for at least the linework/color stages — Krita
      has no verified automatic time-lapse equivalent to Procreate's, so this
      is a manual step, not a toggle.

## Comparison notes vs. Nara (fill in as you go)

- [ ] Time to first clean pose, Krita vs. Affinity+Synfig.
- [ ] Whether layered-parts-per-frame in Krita feels faster or slower than
      posing a bone rig in Synfig once the rig exists.
- [ ] Whether the single-tool Krita round-trip (draw → animate → export, no
      app handoff) avoids the SpriteKit-atlas export risk flagged for the
      Cartoon Animator/Synfig path.
