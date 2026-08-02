# Nara — hand-drawn sprite pipeline (Affinity Designer + Synfig)

Source-of-truth working files for redrawing Nara's in-game poses by hand
(mouse-only, no AI), so the finished PNGs in
`ios/BandMusicGames/Resources/Sprites/HalfCourtHero/HalfCourtHeroPlayers.atlas`
can eventually be replaced with hand-drawn art and the process itself is the
evidence trail for a "no AI was used" claim.

Nara is the vector + bone-rig pipeline. [Will runs the same 4 poses through
Krita instead](../will/README.md) (layered parts, no rig, one tool) as a
side-by-side workflow comparison.

Keep every stage's native source files here and commit them — the timestamped
git history is part of the evidence bundle, so don't flatten/discard
intermediate stages.

## Frame spec (must match `PlayerNode.swift`)

- Export size: **256×256 px**, transparent background.
- Character body fills **~82%** of the frame height.
- Feet sit at **~14%** from the bottom edge (anchor point `(0.5, 0.14)`).
- Frame naming: `nara_<pose>_<NNN>.png`, zero-padded 3 digits, starting at `000`.
- Frame counts / playback (from `PlayerNode.installSpriteBody`/`setupAtlas`):
  - `idle` — 8 frames, loop @ 8 fps
  - `run` — 8 frames, loop @ 14 fps
  - `dribble` — 8 frames, loop @ 14 fps
  - `shoot` — 10 frames, one-shot @ 16 fps
- A separate procedural "puppet" layer (bob / lean / squash-stretch) runs on
  top of whatever frames you draw — don't bake heavy bounce/squash into the
  frames themselves or it'll double up.
- Palette (from `HalfCourtHeroTypes.swift`, case `.nara`): hue `#FF1493`,
  skin `#FDBCB4`, hair `#1C0A00`, shirt `#222222`, pants `#3366DD`,
  shoes `#2A2A2A`.

## Stages

1. **01-reference** — model sheet (`nara_model_sheet.png`): master portrait,
   current in-game atlas frames for idle/run/dribble/shoot, and the code
   palette swatches. Open this as a reference/trace layer, not something to
   edit.
2. **02-rough** — loose construction sketches per pose (pose/silhouette only).
3. **03-vector** — clean vector linework in Affinity Designer (Pen Tool:
   click = corner point, click-drag = curve point). One `.afdesign` file per
   pose, or one file with an artboard per pose.
4. **04-color** — flat cel-shade fills on top of the linework: flat color +
   one shadow tone per surface, no gradients/brushwork.
5. **05-rig** — split into modular pieces (head / torso / upper-lower arm /
   upper-lower leg) as independently posable layers/groups.
6. **06-poses** — the rig posed per animation state, ready to render frames
   from (Reallusion Cartoon Animator "Bone Actor" import, or a Synfig
   skeleton).
7. **07-export** — final 256×256 PNG frame sequences, named per the spec
   above, staged here before copying into the Xcode atlas.

## Evidence-of-authorship checklist per pose

- [ ] Native layered source file kept unflattened (`.afdesign`, not just PNG).
- [ ] Source file committed to git incrementally (not one giant final commit).
- [ ] Time-lapse or screen recording of at least the vector/color stages.
