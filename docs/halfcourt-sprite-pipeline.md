# Half Court Hero Sprite Pipeline

## Active Runtime Format

`PlayerNode` currently loads one transparent asset-catalog PNG per hero/team
variant and puppet-animates that image procedurally in SpriteKit:

```text
ios/BandMusicGames/Assets.xcassets/hch_<hero>.imageset/
ios/BandMusicGames/Assets.xcassets/hch_<hero>_knicks.imageset/
ios/BandMusicGames/Assets.xcassets/hch_<hero>_spurs.imageset/
```

The active character asset generator is:

```sh
npm run sprites:halfcourt:characters
```

That command runs `scripts/generate-halfcourt-character-assets.py`, writes the
12 active `hch_*` PNGs, and produces review previews:

```text
previews/sprites/halfcourt/halfcourt-character-assets-sheet.png
previews/sprites/halfcourt/halfcourt-character-ingame-mock.png
```

## Release Tags

- `opus-4.8`: archived prior active `hch_*` image sets and atlas previews at
  `previews/sprites/halfcourt/releases/opus-4.8/`.
- `coxex-5.5`: current regenerated court-scale puppet assets, manifest, and
  previews at `previews/sprites/halfcourt/releases/coxex-5.5/`.

The `coxex-5.5` pass intentionally reduces in-game scale and moves the sprites
away from oversized front-facing cutouts toward slimmer court-scale figures with
softer outlines and stronger contact shadows.

## Atlas Starter Assets

The repo also has SpriteKit-native texture atlas source folders:

- `HalfCourtHeroPlayers.atlas`: transparent PNG frames for each player animation.
- `HalfCourtHeroBall.atlas`: transparent PNG frames for ball spin.
- `manifest.json`: frame names, FPS, atlas names, and frame size.

Xcode compiles `.atlas` folders into optimized SpriteKit atlases at build time,
but the current iOS scene uses the `hch_*` puppet PNG path above for players.
The atlas generator remains useful for starter animation research and ball
review sheets.

## Best Authoring Workflow

For clean hand-drawn animation, author the frames in Krita and export a
transparent PNG image sequence. Krita is open source and supports frame-by-frame
animation. Pixelorama or LibreSprite are good open-source choices for pixel-art
sprites. Aseprite is a strong sprite editor and has CLI export support, but it is
not installed in this repo environment and is not the open-source default here.

Free Texture Packer is an open-source atlas packer and is useful when a separate
sprite sheet plus JSON/plist metadata is needed. For this iOS SpriteKit app, the
native `.atlas` folder is the better runtime target because SpriteKit and Xcode
handle packing and GPU-friendly loading.

## Generate Atlas Starter Assets

From the repo root:

```sh
npm run sprites:halfcourt
```

That command runs `scripts/generate-halfcourt-sprites.py`, which uses Pillow to
generate deterministic, antialiased, transparent starter frames. It also writes
atlas review sheets to:

```text
previews/sprites/halfcourt/
```

## Naming Contract

Player frames use:

```text
<hero>_<animation>_<frame>.png
```

Examples:

```text
nara_idle_000.png
ethan_run_003.png
will_shoot_006.png
```

Ball frames use:

```text
ball_spin_000.png
```

Atlas consumers load these names from `SKTextureAtlas` and fall back to
procedural SpriteKit shapes if the atlas is missing.

## Replacing Active Puppet Art

1. Keep the asset-catalog image set names and transparent PNG format.
2. Preserve the `hch_<hero>` / `hch_<hero>_<team>` naming contract because
   `PlayerNode` derives image names at runtime.
3. Keep the character's feet near the lower center of the canvas so existing
   court placement stays stable.
4. Run `npm run sprites:halfcourt:characters`.
5. Build the app and verify Half Court Hero renders the updated puppet sprites.

## Replacing Atlas Starter Art

1. Keep the filenames and transparent PNG format.
2. Keep every frame at `256x256` pixels unless the Swift sizing constants change.
3. Leave the character's feet near the lower center of the canvas so existing
   court placement stays stable.
4. Run `cd ios && xcodegen generate`.
5. Build the app and verify Half Court Hero renders textured players and ball.
