# Goon Sprite Prompts

Canonical style prefix — paste before every individual prompt:

> 2003-era chunky pixel art, top-down 3/4 view, no anti-aliasing, saturated retro colors (greens #2d7a2d / #45b045 / #8bc44a, mower yellow #ffcc00, stripe orange #ff8800, gas can red #dd2222), transparent background, sharp pixel edges, sprite-sheet style for arcade lawn-mowing game.

---

## Mower (`mower.atlas/`)

### mower-body.png — 56×56
Top-down lawn-mower chassis only. Yellow body (#ffcc00) with orange (#ff8800) diagonal racing stripes. No wheels, no blade — those are separate overlays. Centered on transparent background, square base, symmetric so the chassis can rotate freely in code.

### mower-blade-1.png … mower-blade-4.png — 56×56 each
Four-frame spinning circular blade overlay. Translucent silver/steel disc with motion-blur radial spokes, hint of green grass shred caught in the spin. Frame 1: blade horizontal. Frame 2: rotated 22°. Frame 3: rotated 45°. Frame 4: rotated 67°. Background fully transparent; only the spinning blade is opaque.

### mower-wheels-1.png … mower-wheels-3.png — 56×56 each
Three-frame wheel-rotation overlay. Two visible black tires positioned for a top-down lawnmower, each with a white-rim hub. Frame 1: hub spokes vertical. Frame 2: hubs rotated 30°. Frame 3: hubs rotated 60°. Background fully transparent.

---

## Cricket (`cricket.atlas/`)

### cricket-idle.png — 16×16
Cute pixel-art cricket facing forward. Dark green (#228b22) body, lighter green legs, two antennae visible. Sitting still, alert posture. Top-down.

### cricket-hop-1.png … cricket-hop-4.png — 16×16
Four-frame hop cycle. Frame 1: crouched low, legs gathered. Frame 2: mid-jump, legs extended fully behind. Frame 3: peak of jump, body slightly stretched. Frame 4: landing crouch, legs absorbing impact. Same dark-green palette throughout.

---

## Skunk (`skunk.atlas/`)

### skunk-walk-1.png … skunk-walk-4.png — 24×24
Four-frame walk cycle. Top-down view. Black (#111111) body, white stripe down the back, white-tipped tail trailing behind. Frame 1: legs neutral stance. Frame 2: front-left + back-right legs forward. Frame 3: legs neutral. Frame 4: front-right + back-left legs forward.

### skunk-alarmed.png — 24×24
Same skunk silhouette but tail raised straight up, body slightly puffed/poofed, more contrast between black and white. Top-down view.

---

## Stump (`stump.atlas/`)

### stump-full.png — 32×32
Top-down view of an undug tree stump. Brown (#8b4513) cross-section with concentric tree-rings visible, small green grass tufts around the base. Centered, square crop.

### stump-half.png — 32×32
Same stump but visibly being pulled out: tilted at ~15° angle, dirt ring exposed around the base, lighter brown showing where it's been disturbed.

### stump-hole.png — 32×32
Just an empty hole in dirt where the stump was. Dark center (the hole), brown disturbed dirt around it. Maybe one or two stray wood-chip pixels for texture.

---

## Tiles (`tiles.atlas/`)

### tile-tall-1.png, tile-tall-2.png, tile-tall-3.png — 32×32 each
Three variants of tall, uncut grass tile. Dark green (#2d7a2d) base with brighter green (#45b045) blade strokes sticking up at slight angles. Each variant has a subtly different blade arrangement (Variant 1: blades lean left. Variant 2: blades straight up. Variant 3: blades lean right). Tile-able — edges blend seamlessly.

### tile-cut-1.png, tile-cut-2.png, tile-cut-3.png — 32×32 each
Three variants of mowed grass. Pale green (#8bc44a) with horizontal mower-stripe patterns. Variant 1: stripes horizontal. Variant 2: stripes diagonal 45°. Variant 3: stripes slightly curved. Tile-able.

### tile-transition.png — 32×32
A "currently being mowed" half-state tile. Top half is tall grass, bottom half is cut grass, with a clean line between.

### tile-house-roof.png — 32×32
Top-down roof tile. Dark brown (#5c4033) shingles with subtle texture, slight perspective so it reads as a sloped roof from above.

### tile-house-wall.png — 32×32
Top-down house wall tile. Beige (#c8a878) with subtle horizontal siding pattern.

### tile-house-corner.png — 32×32
Corner tile combining roof on top and wall on side — usable as a 9-slice corner piece.

### tile-garden-1.png, tile-garden-2.png, tile-garden-3.png — 32×32 each
Three variants of garden bed tile. Dark soil (#3e2c1c) base with colorful flowers. Variant 1: pink + purple flowers. Variant 2: yellow + orange. Variant 3: red + white. Tile-able.

---

## Items

### gas-can.png — 32×32
Top-down red (#dd2222) gasoline can, classic 2-gallon shape with handle on top. White "GAS" stencil text on the side. Subtle gold rim glow suggesting collectability. Centered, transparent background.

---

## FX (`fx.atlas/`)

### clipping.png — 4×4
Tiny grass clipping. Single bright-green (#45b045) pixel speck with one or two darker pixels for shape. Used as a particle emitter texture.

### dust.png — 8×8
Brown (#8b6f47) dust puff with soft circular falloff. Used when digging stumps.

### spark.png — 8×8
Gold (#ffcc00) radial glow with a bright white core. Used for gas-can pickup feedback.

---

## UI (`ui/`)

### goon-title-logo.png — 800×200
"GRASS CUTTER 2003" pixel-art title banner. Yellow (#ffcc00) with thick black outline, drop shadow. Slight perspective tilt for arcade-marquee feel. The "2003" smaller and below in green.

### goon-gameover.png — 400×100
"OUT OF GAS" stamped lettering, red-orange (#dd4422) with cracked-paint texture. Looks rubber-stamped on.

### goon-win-card.png — 600×400
Celebration art: a small mower in the center with confetti bursts, manicured lawn beneath, "YOU WON" yellow text above with thick black outline. Arcade-victory vibe.
