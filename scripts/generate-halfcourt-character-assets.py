#!/usr/bin/env python3
"""Generate the active Half Court Hero puppet character assets.

These images are the `hch_*` assets loaded by PlayerNode. The coxex-5.5 pass is
smaller, softer, and more court-lit than the archived opus-4.8 version.
"""

from __future__ import annotations

import json
import math
import random
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "ios/BandMusicGames/Assets.xcassets"
PREVIEW_ROOT = ROOT / "previews/sprites/halfcourt"
RELEASE_TAG = "coxex-5.5"
PREVIOUS_RELEASE_TAG = "opus-4.8"
RELEASE_ROOT = PREVIEW_ROOT / "releases" / RELEASE_TAG

CANVAS_W = 420
CANVAS_H = 960
SCALE = 3


@dataclass(frozen=True)
class Hero:
    key: str
    skin: str
    hair: str
    shirt: str
    pants: str
    shoes: str
    accent: str
    hair_style: str
    number: str
    height_scale: float = 1.0


HEROES: tuple[Hero, ...] = (
    Hero("nara", "#FDBCB4", "#1C0A00", "#151318", "#245DD8", "#26262A", "#FF1493", "bob", "3", 0.98),
    Hero("ethan", "#C68642", "#3D2B1F", "#24983B", "#1E2433", "#F6F1E7", "#52D957", "long", "5", 1.03),
    Hero("brendan", "#FDBCB4", "#CC2200", "#F4EFE8", "#24262D", "#5F5750", "#FF6B35", "cap", "9", 0.96),
    Hero("will", "#8D5524", "#151116", "#E7D7BD", "#35333A", "#9B59B6", "#9B59B6", "beanie", "7", 0.99),
)

TEAM_VARIANTS = {
    "base": None,
    "knicks": {
        "shirt": "#F7F4EF",
        "pants": "#1751BD",
        "accent": "#F36B21",
        "shoes": "#F7F4EF",
    },
    "spurs": {
        "shirt": "#E7E7E9",
        "pants": "#1E2025",
        "accent": "#A9ADB3",
        "shoes": "#EEEEEE",
    },
}

ASSET_FILES = {
    ("nara", "base"): ("hch_nara.imageset", "nara_sprite.png"),
    ("nara", "knicks"): ("hch_nara_knicks.imageset", "nara_sprite_knicks.png"),
    ("nara", "spurs"): ("hch_nara_spurs.imageset", "nara_sprite_spurs.png"),
    ("ethan", "base"): ("hch_ethan.imageset", "ethan_sprite.png"),
    ("ethan", "knicks"): ("hch_ethan_knicks.imageset", "ethan_sprite_knicks.png"),
    ("ethan", "spurs"): ("hch_ethan_spurs.imageset", "ethan_sprite_spurs.png"),
    ("brendan", "base"): ("hch_brendan.imageset", "brendan_sprite.png"),
    ("brendan", "knicks"): ("hch_brendan_knicks.imageset", "brendan_sprite_knicks.png"),
    ("brendan", "spurs"): ("hch_brendan_spurs.imageset", "brendan_sprite_spurs.png"),
    ("will", "base"): ("hch_will.imageset", "will_sprite.png"),
    ("will", "knicks"): ("hch_will_knicks.imageset", "will_sprite_knicks.png"),
    ("will", "spurs"): ("hch_will_spurs.imageset", "will_sprite_spurs.png"),
}


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = hex_color.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def mix(color: tuple[int, int, int, int], other: tuple[int, int, int, int], amount: float) -> tuple[int, int, int, int]:
    return (
        int(color[0] * (1 - amount) + other[0] * amount),
        int(color[1] * (1 - amount) + other[1] * amount),
        int(color[2] * (1 - amount) + other[2] * amount),
        int(color[3] * (1 - amount) + other[3] * amount),
    )


def shade(hex_color: str, factor: float, alpha: int = 255) -> tuple[int, int, int, int]:
    c = rgba(hex_color, alpha)
    return (
        max(0, min(255, int(c[0] * factor))),
        max(0, min(255, int(c[1] * factor))),
        max(0, min(255, int(c[2] * factor))),
        c[3],
    )


def sp(value: float) -> int:
    return round(value * SCALE)


def box(values: tuple[float, float, float, float]) -> tuple[int, int, int, int]:
    return tuple(sp(v) for v in values)  # type: ignore[return-value]


def pt(point: tuple[float, float]) -> tuple[int, int]:
    return (sp(point[0]), sp(point[1]))


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    paths = (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "/Library/Fonts/Arial.ttf",
    )
    for path in paths:
        try:
            if bold == ("Bold" in path):
                return ImageFont.truetype(path, size * SCALE)
        except OSError:
            continue
    return ImageFont.load_default()


class Canvas:
    def __init__(self) -> None:
        size = (CANVAS_W * SCALE, CANVAS_H * SCALE)
        self.image = Image.new("RGBA", size, (0, 0, 0, 0))
        self.paint = ImageDraw.Draw(self.image)

    def layer(self) -> tuple[Image.Image, ImageDraw.ImageDraw]:
        layer = Image.new("RGBA", self.image.size, (0, 0, 0, 0))
        return layer, ImageDraw.Draw(layer)

    def composite(self, layer: Image.Image) -> None:
        self.image.alpha_composite(layer)

    def ellipse(self, xy: tuple[float, float, float, float], fill, outline=None, width: float = 1) -> None:
        self.paint.ellipse(box(xy), fill=fill, outline=outline, width=sp(width))

    def rounded(self, xy: tuple[float, float, float, float], radius: float, fill, outline=None, width: float = 1) -> None:
        self.paint.rounded_rectangle(box(xy), radius=sp(radius), fill=fill, outline=outline, width=sp(width))

    def poly(self, points: tuple[tuple[float, float], ...], fill, outline=None) -> None:
        self.paint.polygon([pt(p) for p in points], fill=fill, outline=outline)

    def line(self, points: tuple[tuple[float, float], ...], fill, width: float) -> None:
        scaled = [pt(p) for p in points]
        self.paint.line(scaled, fill=fill, width=sp(width), joint="curve")
        r = width / 2
        for p in (points[0], points[-1]):
            self.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill)

    def text(self, xy: tuple[float, float], value: str, fill, size: int = 28) -> None:
        self.paint.text(pt(xy), value, fill=fill, font=font(size, bold=True), anchor="mm")


def variant_palette(hero: Hero, variant: str) -> dict[str, str]:
    palette = {
        "shirt": hero.shirt,
        "pants": hero.pants,
        "shoes": hero.shoes,
        "accent": hero.accent,
    }
    overrides = TEAM_VARIANTS[variant]
    if overrides:
        palette.update(overrides)
    return palette


def jersey_text_color(shirt_hex: str) -> tuple[int, int, int, int]:
    c = rgba(shirt_hex)
    luminance = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    return (35, 31, 34, 220) if luminance > 170 else (248, 242, 232, 225)


def draw_soft_shadow(canvas: Canvas, cx: float, ground: float) -> None:
    layer, d = canvas.layer()
    d.ellipse(box((cx - 108, ground - 24, cx + 92, ground + 18)), fill=(0, 0, 0, 105))
    d.ellipse(box((cx - 58, ground - 14, cx + 54, ground + 8)), fill=(0, 0, 0, 70))
    canvas.composite(layer.filter(ImageFilter.GaussianBlur(sp(7))))


def draw_skin_limb(canvas: Canvas, points: tuple[tuple[float, float], ...], skin: str, width: float, back: bool = False) -> None:
    base = shade(skin, 0.88 if back else 1.0, 245)
    ink = (35, 28, 25, 85)
    canvas.line(points, ink, width + 4)
    canvas.line(points, base, width)
    highlight = mix(base, (255, 232, 182, 190), 0.35)
    shifted = tuple((x - 2, y - 2) for x, y in points)
    canvas.line(shifted, highlight, max(2, width * 0.24))


def draw_cloth_limb(canvas: Canvas, points: tuple[tuple[float, float], ...], color: str, width: float, back: bool = False) -> None:
    base = shade(color, 0.78 if back else 1.0, 250)
    ink = (28, 24, 28, 92)
    canvas.line(points, ink, width + 5)
    canvas.line(points, base, width)
    canvas.line(tuple((x - 2, y - 3) for x, y in points), mix(base, (255, 225, 170, 160), 0.28), max(2, width * 0.2))


def draw_shoe(canvas: Canvas, x: float, y: float, color: str, flip: int = 1) -> None:
    shoe = rgba(color, 245)
    sole = (239, 230, 211, 215)
    ink = (27, 24, 26, 115)
    canvas.ellipse((x - 38, y - 14, x + 38, y + 13), ink)
    canvas.rounded((x - 35, y - 17, x + 38 * flip, y + 9), 14, shoe, ink, 2.0)
    canvas.line(((x - 29, y + 5), (x + 30 * flip, y + 3)), sole, 4)


def draw_hair(canvas: Canvas, hero: Hero, cx: float, cy: float, face_dir: int) -> None:
    hair = rgba(hero.hair, 248)
    ink = (25, 19, 20, 92)
    if hero.hair_style == "bob":
        canvas.rounded((cx - 55, cy - 64, cx + 45, cy + 54), 34, hair, ink, 2)
        canvas.rounded((cx - 62, cy - 6, cx - 22, cy + 76), 20, hair, None)
    elif hero.hair_style == "long":
        canvas.rounded((cx - 60, cy - 62, cx + 48, cy + 128), 36, hair, ink, 2)
        canvas.rounded((cx - 28, cy - 62, cx + 62, cy + 44), 32, hair, None)
    elif hero.hair_style == "cap":
        canvas.rounded((cx - 50, cy - 68, cx + 48, cy - 22), 21, (70, 72, 79, 252), ink, 2)
        canvas.rounded((cx - 10, cy - 76, cx + 76, cy - 45), 14, (70, 72, 79, 252), ink, 1.5)
        canvas.ellipse((cx - 38, cy - 50, cx + 42, cy + 44), rgba(hero.skin, 242), None)
    else:
        canvas.rounded((cx - 54, cy - 70, cx + 52, cy - 18), 24, (134, 135, 137, 252), ink, 2)
        canvas.rounded((cx - 52, cy - 26, cx + 54, cy - 9), 8, shade(hero.accent, 0.9, 245), None)
        canvas.ellipse((cx - 42, cy - 48, cx + 42, cy + 45), rgba(hero.skin, 242), None)


def draw_face(canvas: Canvas, hero: Hero, cx: float, cy: float, face_dir: int) -> None:
    skin = rgba(hero.skin, 242)
    shade_skin = shade(hero.skin, 0.88, 205)
    ink = (38, 29, 26, 150)
    canvas.ellipse((cx - 43, cy - 50, cx + 48, cy + 52), skin, (40, 31, 29, 80), 2)
    canvas.ellipse((cx + 16 * face_dir, cy - 20, cx + 60 * face_dir, cy + 24), shade_skin, None)
    nose = (
        (cx + 16 * face_dir, cy - 4),
        (cx + 35 * face_dir, cy + 7),
        (cx + 12 * face_dir, cy + 13),
    )
    canvas.poly(nose, shade(hero.skin, 0.92, 190))
    canvas.ellipse((cx - 18, cy - 10, cx - 8, cy), ink)
    canvas.ellipse((cx + 16, cy - 11, cx + 25, cy - 1), ink)
    if hero.hair_style == "beanie":
        canvas.ellipse((cx - 30, cy - 15, cx - 7, cy + 2), (0, 0, 0, 0), ink, 2)
        canvas.ellipse((cx + 9, cy - 16, cx + 32, cy + 1), (0, 0, 0, 0), ink, 2)
        canvas.line(((cx - 7, cy - 8), (cx + 9, cy - 9)), ink, 1.8)
    canvas.line(((cx - 14, cy + 29), (cx + 5, cy + 36), (cx + 26, cy + 27)), ink, 2.2)
    canvas.line(((cx - 34, cy - 35), (cx - 14, cy - 42)), (255, 226, 174, 65), 4)


def draw_stripes(canvas: Canvas, torso: tuple[tuple[float, float], ...], accent: str, variant: str) -> None:
    y_values = [point[1] for point in torso]
    top = min(y_values)
    bottom = max(y_values)
    if variant == "spurs":
        for y in (top + 50, top + 104, top + 158):
            canvas.line(((138, y), (258, y + 18)), (45, 45, 48, 105), 8)
    elif variant == "knicks":
        canvas.line(((145, top + 34), (258, top + 50)), rgba(accent, 185), 9)
        canvas.line(((144, bottom - 28), (247, bottom - 14)), rgba(accent, 190), 9)
    else:
        canvas.line(((150, top + 30), (252, top + 46)), rgba(accent, 120), 8)


def draw_character(hero: Hero, variant: str) -> Image.Image:
    rng = random.Random(f"{RELEASE_TAG}:{hero.key}:{variant}")
    palette = variant_palette(hero, variant)
    canvas = Canvas()

    cx = 210.0
    face_dir = 1
    ground = 858.0
    height_scale = hero.height_scale
    head_cy = 178 + (1 - height_scale) * 20
    shoulder_y = 276 + (1 - height_scale) * 16
    hip_y = 528 + (1 - height_scale) * 14
    knee_y = 686

    draw_soft_shadow(canvas, cx, ground)

    shirt = palette["shirt"]
    pants = palette["pants"]
    shoes = palette["shoes"]
    accent = palette["accent"]
    ink = (28, 23, 27, 92)

    # Back side, lower contrast.
    draw_cloth_limb(canvas, ((cx + 34, hip_y - 4), (cx + 50, knee_y), (cx + 62, ground - 42)), pants, 43, back=True)
    draw_shoe(canvas, cx + 67, ground - 30, shoes, flip=1)
    draw_skin_limb(canvas, ((cx + 58, shoulder_y + 38), (cx + 90, shoulder_y + 133), (cx + 72, shoulder_y + 222)), hero.skin, 34, back=True)

    # Torso: narrowed, slightly side-on, lit from upper-left.
    torso = (
        (cx - 76, shoulder_y),
        (cx + 68, shoulder_y + 18),
        (cx + 52, hip_y + 10),
        (cx - 60, hip_y + 18),
    )
    canvas.poly(tuple((x + 4, y + 5) for x, y in torso), (0, 0, 0, 60))
    canvas.poly(torso, rgba(shirt, 248), ink)
    canvas.line(((cx - 70, shoulder_y + 7), (cx - 58, hip_y + 8)), (255, 232, 180, 90), 5)
    canvas.line(((cx + 62, shoulder_y + 25), (cx + 48, hip_y + 2)), (20, 16, 20, 55), 7)
    draw_stripes(canvas, torso, accent, variant)
    canvas.rounded((cx - 32, shoulder_y - 4, cx + 28, shoulder_y + 34), 13, rgba(shirt, 238), (28, 23, 27, 62), 1)

    # Shorts / waistband.
    canvas.rounded((cx - 66, hip_y - 8, cx + 54, hip_y + 88), 19, rgba(pants, 248), ink, 2)
    canvas.line(((cx - 64, hip_y + 6), (cx + 52, hip_y + 11)), rgba(accent, 150), 6)

    # Front side.
    draw_cloth_limb(canvas, ((cx - 36, hip_y + 10), (cx - 58, knee_y + 18), (cx - 68, ground - 42)), pants, 47)
    draw_shoe(canvas, cx - 72, ground - 30, shoes, flip=1)
    draw_skin_limb(canvas, ((cx - 62, shoulder_y + 32), (cx - 92, shoulder_y + 130), (cx - 72, shoulder_y + 222)), hero.skin, 35)

    # Sleeves over shoulders.
    canvas.rounded((cx - 88, shoulder_y + 10, cx - 38, shoulder_y + 88), 20, rgba(shirt, 245), ink, 1.8)
    canvas.rounded((cx + 42, shoulder_y + 22, cx + 86, shoulder_y + 96), 20, shade(shirt, 0.86, 235), ink, 1.6)

    # Neck / head / hair.
    canvas.rounded((cx - 18, head_cy + 42, cx + 20, shoulder_y + 8), 11, rgba(hero.skin, 235), None)
    draw_hair(canvas, hero, cx, head_cy, face_dir)
    if hero.hair_style not in {"cap", "beanie"}:
        draw_face(canvas, hero, cx, head_cy, face_dir)
    else:
        draw_face(canvas, hero, cx, head_cy + 2, face_dir)

    # Jersey mark.
    canvas.text((cx - 2, shoulder_y + 115), hero.number, jersey_text_color(shirt), size=34)

    # Painterly break-up strokes: subtle, deterministic, and transparent.
    for _ in range(42):
        x = rng.uniform(cx - 88, cx + 78)
        y = rng.uniform(shoulder_y - 18, ground - 70)
        length = rng.uniform(8, 24)
        alpha = rng.randint(18, 46)
        warm = (255, 226, 170, alpha)
        cool = (35, 45, 58, alpha)
        color = warm if rng.random() < 0.48 else cool
        canvas.line(((x, y), (x + length, y + rng.uniform(-5, 5))), color, rng.uniform(1.2, 2.4))

    image = canvas.image.filter(ImageFilter.SMOOTH_MORE)
    image = image.filter(ImageFilter.UnsharpMask(radius=0.7, percent=68, threshold=3))
    return image.resize((CANVAS_W, CANVAS_H), Image.Resampling.LANCZOS)


def write_asset(hero: Hero, variant: str) -> Path:
    folder, filename = ASSET_FILES[(hero.key, variant)]
    target = ASSET_ROOT / folder / filename
    target.parent.mkdir(parents=True, exist_ok=True)
    draw_character(hero, variant).save(target)
    return target


def make_sheet(paths: list[Path], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    thumb_w = 128
    thumb_h = 292
    label_h = 22
    cols = 6
    rows = math.ceil(len(paths) / cols)
    sheet = Image.new("RGB", (cols * thumb_w, rows * (thumb_h + label_h)), (23, 21, 27))
    d = ImageDraw.Draw(sheet)
    label_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 10)
    for index, path in enumerate(paths):
        row, col = divmod(index, cols)
        x = col * thumb_w
        y = row * (thumb_h + label_h)
        sprite = Image.open(path).convert("RGBA")
        sprite.thumbnail((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        ox = x + (thumb_w - sprite.width) // 2
        oy = y + (thumb_h - sprite.height)
        sheet.paste(sprite, (ox, oy), sprite)
        d.rectangle((x, y + thumb_h, x + thumb_w, y + thumb_h + label_h), fill=(12, 10, 15))
        d.text((x + thumb_w / 2, y + thumb_h + 5), path.parent.stem.replace(".imageset", ""), fill=(235, 229, 220), font=label_font, anchor="ma")
    sheet.save(output)


def make_ingame_mock(paths: dict[tuple[str, str], Path], output: Path) -> None:
    court = Image.open(ASSET_ROOT / "hch_court.imageset" / "court_env.png").convert("RGB")
    mock = court.resize((588, 1130), Image.Resampling.LANCZOS).convert("RGBA")
    placements = [
        ("nara", "base", 88, 575, 205),
        ("ethan", "base", 285, 565, 188),
        ("brendan", "base", 330, 660, 178),
        ("will", "base", 430, 648, 184),
    ]
    for hero, variant, x, y, h in placements:
        sprite = Image.open(paths[(hero, variant)]).convert("RGBA")
        ratio = h / sprite.height
        resized = sprite.resize((round(sprite.width * ratio), h), Image.Resampling.LANCZOS)
        mock.alpha_composite(resized, (x - resized.width // 2, y - resized.height))
    output.parent.mkdir(parents=True, exist_ok=True)
    mock.convert("RGB").save(output)


def main() -> None:
    written: list[Path] = []
    by_key: dict[tuple[str, str], Path] = {}
    for hero in HEROES:
        for variant in TEAM_VARIANTS:
            path = write_asset(hero, variant)
            written.append(path)
            by_key[(hero.key, variant)] = path

    make_sheet(written, PREVIEW_ROOT / "halfcourt-character-assets-sheet.png")
    make_sheet(written, RELEASE_ROOT / "halfcourt-character-assets-sheet.png")
    make_ingame_mock(by_key, PREVIEW_ROOT / "halfcourt-character-ingame-mock.png")
    make_ingame_mock(by_key, RELEASE_ROOT / "halfcourt-character-ingame-mock.png")

    manifest = {
        "release": RELEASE_TAG,
        "previousRelease": PREVIOUS_RELEASE_TAG,
        "runtime": "Asset catalog hch_* puppet sprites loaded by PlayerNode",
        "canvas": [CANVAS_W, CANVAS_H],
        "assetCount": len(written),
        "artDirection": [
            "smaller court-scale figures",
            "semi-profile stance",
            "softer painterly outlines",
            "warm upper-left court lighting",
            "stronger foot contact shadows",
        ],
        "assets": [str(path.relative_to(ROOT)) for path in written],
        "previews": [
            str((PREVIEW_ROOT / "halfcourt-character-assets-sheet.png").relative_to(ROOT)),
            str((PREVIEW_ROOT / "halfcourt-character-ingame-mock.png").relative_to(ROOT)),
        ],
    }
    RELEASE_ROOT.mkdir(parents=True, exist_ok=True)
    (RELEASE_ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    print(f"Generated {len(written)} {RELEASE_TAG} character assets")
    print(f"Wrote {PREVIEW_ROOT / 'halfcourt-character-assets-sheet.png'}")
    print(f"Wrote {PREVIEW_ROOT / 'halfcourt-character-ingame-mock.png'}")


if __name__ == "__main__":
    main()
