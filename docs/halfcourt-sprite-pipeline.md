# Half Court Hero Sprite Pipeline

## Chosen Runtime Format

Use SpriteKit-native texture atlas source folders:

- `HalfCourtHeroPlayers.atlas`: transparent PNG frames for each player animation.
- `HalfCourtHeroBall.atlas`: transparent PNG frames for ball spin.
- `manifest.json`: frame names, FPS, atlas names, and frame size.

Xcode compiles `.atlas` folders into optimized SpriteKit atlases at build time.
The source PNG frames stay easy to review and replace.

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

## Generate Starter Assets

From the repo root:

```sh
npm run sprites:halfcourt
```

That command runs `scripts/generate-halfcourt-sprites.py`, which uses Pillow to
generate deterministic, antialiased, transparent starter frames. It also writes
review sheets to:

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

Swift loads these names from `SKTextureAtlas` and falls back to procedural
SpriteKit shapes if the atlas is missing.

## Replacing Generated Art

1. Keep the filenames and transparent PNG format.
2. Keep every frame at `256x256` pixels unless the Swift sizing constants change.
3. Leave the character's feet near the lower center of the canvas so existing
   court placement stays stable.
4. Run `cd ios && xcodegen generate`.
5. Build the app and verify Half Court Hero renders textured players and ball.
