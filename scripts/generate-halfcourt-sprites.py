#!/usr/bin/env python3
"""Generate Half Court Hero SpriteKit atlas frames and preview sheets.

The output is intentionally plain PNG frames inside .atlas folders because
SpriteKit and Xcode can compile those folders into optimized texture atlases.
"""

from __future__ import annotations

import json
import math
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SPRITE_ROOT = ROOT / "ios/BandMusicGames/Resources/Sprites/HalfCourtHero"
PLAYERS_ATLAS = SPRITE_ROOT / "HalfCourtHeroPlayers.atlas"
BALL_ATLAS = SPRITE_ROOT / "HalfCourtHeroBall.atlas"
MANIFEST_PATH = SPRITE_ROOT / "manifest.json"
PREVIEW_ROOT = ROOT / "previews/sprites/halfcourt"

FRAME_SIZE = 256
SCALE = 4


@dataclass(frozen=True)
class Hero:
    key: str
    display: str
    skin: str
    hair: str
    shirt: str
    pants: str
    shoes: str
    accent: str
    hair_style: str
    number: str


HEROES: tuple[Hero, ...] = (
    Hero("nara", "Nara", "#FDBCB4", "#1C0A00", "#222222", "#3366DD", "#2A2A2A", "#FF1493", "bob", "3"),
    Hero("ethan", "Ethan", "#C68642", "#3D2B1F", "#32CD32", "#1C1C2E", "#FFFFFF", "#32CD32", "long", "5"),
    Hero("brendan", "Brendan", "#FDBCB4", "#CC2200", "#FF6B35", "#2D5A27", "#222222", "#FF6B35", "beanie", "9"),
    Hero("will", "Will", "#8D5524", "#111111", "#9B59B6", "#2C2C2C", "#9B59B6", "#9B59B6", "glasses", "7"),
)

ANIMATION_FRAMES = {
    "idle": 4,
    "dribble": 6,
    "run": 6,
    "shoot": 8,
    "celebrate": 6,
}

ANIMATION_FPS = {
    "idle": 7,
    "dribble": 12,
    "run": 12,
    "shoot": 14,
    "celebrate": 10,
}


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = hex_color.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def adjust(color: tuple[int, int, int, int], factor: float) -> tuple[int, int, int, int]:
    return (
        max(0, min(255, int(color[0] * factor))),
        max(0, min(255, int(color[1] * factor))),
        max(0, min(255, int(color[2] * factor))),
        color[3],
    )


def scaled_point(point: tuple[float, float]) -> tuple[int, int]:
    return (round(point[0] * SCALE), round(point[1] * SCALE))


def scaled_box(box: tuple[float, float, float, float]) -> tuple[int, int, int, int]:
    return tuple(round(value * SCALE) for value in box)  # type: ignore[return-value]


def load_font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    candidates = (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "/Library/Fonts/Arial.ttf",
    )
    for candidate in candidates:
        try:
            if bold == ("Bold" in candidate):
                return ImageFont.truetype(candidate, size * SCALE)
        except OSError:
            continue
    return ImageFont.load_default()


def load_preview_font(size: int) -> ImageFont.ImageFont:
    candidates = (
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
    )
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    return ImageFont.load_default()


class Canvas:
    def __init__(self) -> None:
        self.image = Image.new("RGBA", (FRAME_SIZE * SCALE, FRAME_SIZE * SCALE), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.image)

    def ellipse(
        self,
        box: tuple[float, float, float, float],
        fill: tuple[int, int, int, int],
        outline: tuple[int, int, int, int] | None = None,
        width: float = 1.0,
    ) -> None:
        self.draw.ellipse(scaled_box(box), fill=fill, outline=outline, width=round(width * SCALE))

    def rounded_rectangle(
        self,
        box: tuple[float, float, float, float],
        radius: float,
        fill: tuple[int, int, int, int],
        outline: tuple[int, int, int, int] | None = None,
        width: float = 1.0,
    ) -> None:
        self.draw.rounded_rectangle(
            scaled_box(box),
            radius=round(radius * SCALE),
            fill=fill,
            outline=outline,
            width=round(width * SCALE),
        )

    def polygon(
        self,
        points: Iterable[tuple[float, float]],
        fill: tuple[int, int, int, int],
        outline: tuple[int, int, int, int] | None = None,
    ) -> None:
        self.draw.polygon([scaled_point(point) for point in points], fill=fill, outline=outline)

    def line(
        self,
        points: Iterable[tuple[float, float]],
        fill: tuple[int, int, int, int],
        width: float,
    ) -> None:
        points_list = list(points)
        scaled = [scaled_point(point) for point in points_list]
        self.draw.line(scaled, fill=fill, width=round(width * SCALE), joint="curve")
        radius = width / 2
        for point in (points_list[0], points_list[-1]):
            self.ellipse(
                (point[0] - radius, point[1] - radius, point[0] + radius, point[1] + radius),
                fill,
            )

    def text(
        self,
        xy: tuple[float, float],
        value: str,
        font: ImageFont.ImageFont,
        fill: tuple[int, int, int, int],
        anchor: str = "mm",
    ) -> None:
        self.draw.text(scaled_point(xy), value, font=font, fill=fill, anchor=anchor)


def clear_generated_pngs(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    for png in path.glob("*.png"):
        png.unlink()


def make_shadow(canvas: Canvas, center_x: float, ground_y: float, width: float, alpha: int) -> None:
    canvas.ellipse(
        (center_x - width / 2, ground_y - 8, center_x + width / 2, ground_y + 9),
        (0, 0, 0, alpha),
    )


def draw_ball(canvas: Canvas, center: tuple[float, float], radius: float, spin: float = 0.0, alpha: int = 255) -> None:
    orange = (221, 105, 29, alpha)
    dark = (103, 43, 15, alpha)
    light = (246, 150, 65, round(alpha * 0.8))
    cx, cy = center
    canvas.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), orange, dark, 2.0)

    canvas.line(((cx - radius * 0.9, cy), (cx + radius * 0.9, cy)), dark, 1.6)
    seam_offset = math.sin(spin) * radius * 0.42
    canvas.line(((cx + seam_offset, cy - radius * 0.9), (cx - seam_offset, cy + radius * 0.9)), dark, 1.4)
    canvas.line(
        (
            (cx - radius * 0.72, cy - radius * 0.38),
            (cx - radius * 0.24, cy),
            (cx - radius * 0.72, cy + radius * 0.38),
        ),
        dark,
        1.2,
    )
    canvas.line(
        (
            (cx + radius * 0.72, cy - radius * 0.38),
            (cx + radius * 0.24, cy),
            (cx + radius * 0.72, cy + radius * 0.38),
        ),
        dark,
        1.2,
    )
    canvas.ellipse((cx - radius * 0.45, cy - radius * 0.5, cx - radius * 0.05, cy - radius * 0.1), light)


def pose(hero: Hero, animation: str, frame: int, total: int) -> dict[str, object]:
    phase = (frame / total) * math.tau
    bob = math.sin(phase) * 2
    cx = 128.0
    ground = 222.0
    hip_y = 148.0 + bob
    chest_y = 101.0 + bob

    data: dict[str, object] = {
        "cx": cx,
        "ground": ground,
        "hip": (cx, hip_y),
        "chest": (cx, chest_y),
        "neck": (cx, chest_y - 26),
        "head": (cx, chest_y - 48),
        "torso_tilt": math.sin(phase) * 2,
        "left_knee": (cx - 18, 176 + bob),
        "right_knee": (cx + 18, 176 - bob * 0.4),
        "left_foot": (cx - 22, ground - 3),
        "right_foot": (cx + 22, ground - 2),
        "left_elbow": (cx - 44, chest_y + 22),
        "left_hand": (cx - 40, chest_y + 54),
        "right_elbow": (cx + 44, chest_y + 24),
        "right_hand": (cx + 43, chest_y + 56),
        "ball": None,
    }

    if animation == "run":
        stride = math.sin(phase)
        counter = math.cos(phase)
        data.update(
            {
                "left_knee": (cx - 13 - stride * 15, 172 + abs(counter) * 6),
                "right_knee": (cx + 13 + stride * 15, 172 + abs(counter) * 6),
                "left_foot": (cx - 18 - stride * 31, ground - 4 + max(0, counter) * 5),
                "right_foot": (cx + 18 + stride * 31, ground - 3 + max(0, -counter) * 5),
                "left_elbow": (cx - 39 + stride * 12, chest_y + 12),
                "left_hand": (cx - 40 + stride * 28, chest_y + 48),
                "right_elbow": (cx + 39 - stride * 12, chest_y + 12),
                "right_hand": (cx + 40 - stride * 28, chest_y + 48),
                "torso_tilt": -5 + stride * 3,
            }
        )
    elif animation == "dribble":
        bounce = (math.sin(phase) + 1) / 2
        data.update(
            {
                "left_elbow": (cx - 39, chest_y + 8),
                "left_hand": (cx - 46, chest_y + 36),
                "right_elbow": (cx + 48, chest_y + 38),
                "right_hand": (cx + 55, 181 + bounce * 23),
                "right_knee": (cx + 26, 177),
                "right_foot": (cx + 34, ground - 3),
                "ball": (cx + 58, 202 + bounce * 17, 13, phase),
            }
        )
    elif animation == "shoot":
        t = frame / max(1, total - 1)
        crouch = math.sin(min(t, 0.45) / 0.45 * math.pi) * 10 if t < 0.45 else 0
        lift = min(1.0, max(0.0, (t - 0.18) / 0.56))
        release = max(0.0, (t - 0.68) / 0.32)
        chest_y += crouch
        data.update(
            {
                "hip": (cx, 148 + crouch),
                "chest": (cx + lift * 3, chest_y),
                "neck": (cx + lift * 3, chest_y - 26),
                "head": (cx + lift * 3, chest_y - 48),
                "left_knee": (cx - 22, 174 + crouch * 0.8),
                "right_knee": (cx + 25, 174 + crouch * 0.8),
                "left_foot": (cx - 26, ground - 3),
                "right_foot": (cx + 31, ground - 6),
                "left_elbow": (cx - 20 + lift * 8, chest_y - 5 - lift * 35),
                "left_hand": (cx - 7 + lift * 15, chest_y - 10 - lift * 69),
                "right_elbow": (cx + 23 + lift * 9, chest_y - 4 - lift * 37),
                "right_hand": (cx + 10 + lift * 18, chest_y - 10 - lift * 72),
                "torso_tilt": -3 + lift * 7,
            }
        )
        ball_x = cx + 2 + lift * 17 + release * 22
        ball_y = chest_y - 24 - lift * 74 - release * 34
        data["ball"] = (ball_x, ball_y, 13, phase) if frame < total - 1 else None
    elif animation == "celebrate":
        wave = math.sin(phase)
        data.update(
            {
                "left_elbow": (cx - 36 - wave * 6, chest_y - 26),
                "left_hand": (cx - 52 - wave * 8, chest_y - 75),
                "right_elbow": (cx + 36 + wave * 6, chest_y - 26),
                "right_hand": (cx + 52 + wave * 8, chest_y - 75),
                "left_foot": (cx - 25, ground - 3),
                "right_foot": (cx + 28, ground - 3),
            }
        )

    return data


def draw_hair(canvas: Canvas, hero: Hero, head: tuple[float, float], bob: float) -> None:
    cx, cy = head
    hair = rgba(hero.hair)
    ink = (24, 18, 24, 160)
    if hero.hair_style == "bob":
        canvas.rounded_rectangle((cx - 25, cy - 24, cx + 25, cy + 28), 16, hair, ink, 1.4)
        canvas.ellipse((cx - 17, cy - 15, cx + 17, cy + 21), rgba(hero.skin), None)
    elif hero.hair_style == "long":
        canvas.rounded_rectangle((cx - 27, cy - 22, cx + 27, cy + 53), 17, hair, ink, 1.4)
        canvas.ellipse((cx - 17, cy - 15, cx + 17, cy + 21), rgba(hero.skin), None)
    elif hero.hair_style == "beanie":
        canvas.ellipse((cx - 20, cy - 16, cx + 20, cy + 17), rgba(hero.skin), ink, 1.4)
        canvas.rounded_rectangle((cx - 23, cy - 28, cx + 23, cy - 5), 10, (126, 129, 136, 255), ink, 1.2)
        canvas.rounded_rectangle((cx - 22, cy - 8, cx + 22, cy), 3, adjust(rgba(hero.accent), 0.9), None)
    else:
        canvas.ellipse((cx - 20, cy - 22, cx + 20, cy + 14), hair, ink, 1.3)
        canvas.ellipse((cx - 17, cy - 15, cx + 17, cy + 21), rgba(hero.skin), None)


def draw_face(canvas: Canvas, hero: Hero, head: tuple[float, float]) -> None:
    cx, cy = head
    ink = (20, 14, 18, 210)
    canvas.ellipse((cx - 2, cy - 1, cx + 2, cy + 4), adjust(rgba(hero.skin), 0.85))
    canvas.ellipse((cx - 10, cy - 6, cx - 5, cy - 1), ink)
    canvas.ellipse((cx + 5, cy - 6, cx + 10, cy - 1), ink)
    canvas.line(((cx - 6, cy + 12), (cx, cy + 15), (cx + 7, cy + 12)), ink, 1.2)
    if hero.hair_style == "glasses":
        canvas.ellipse((cx - 14, cy - 9, cx - 3, cy + 1), (0, 0, 0, 0), ink, 1.5)
        canvas.ellipse((cx + 3, cy - 9, cx + 14, cy + 1), (0, 0, 0, 0), ink, 1.5)
        canvas.line(((cx - 3, cy - 4), (cx + 3, cy - 4)), ink, 1.2)


def draw_player_frame(hero: Hero, animation: str, frame: int, total: int) -> Image.Image:
    random.seed(f"{hero.key}:{animation}:{frame}")
    canvas = Canvas()
    p = pose(hero, animation, frame, total)
    cx = p["cx"]  # type: ignore[assignment]
    ground = p["ground"]  # type: ignore[assignment]
    chest = p["chest"]  # type: ignore[assignment]
    hip = p["hip"]  # type: ignore[assignment]
    head = p["head"]  # type: ignore[assignment]

    make_shadow(canvas, cx, ground + 2, 92, 48)  # type: ignore[arg-type]

    skin = rgba(hero.skin)
    shirt = rgba(hero.shirt)
    pants = rgba(hero.pants)
    shoes = rgba(hero.shoes)
    accent = rgba(hero.accent)
    ink = (22, 16, 23, 155)
    pants_shadow = adjust(pants, 0.75)
    skin_shadow = adjust(skin, 0.9)

    left_knee = p["left_knee"]  # type: ignore[assignment]
    right_knee = p["right_knee"]  # type: ignore[assignment]
    left_foot = p["left_foot"]  # type: ignore[assignment]
    right_foot = p["right_foot"]  # type: ignore[assignment]
    left_elbow = p["left_elbow"]  # type: ignore[assignment]
    left_hand = p["left_hand"]  # type: ignore[assignment]
    right_elbow = p["right_elbow"]  # type: ignore[assignment]
    right_hand = p["right_hand"]  # type: ignore[assignment]

    # Back limbs.
    canvas.line((hip, right_knee, right_foot), pants_shadow, 12)
    canvas.line(((cx + 22, chest[1] + 3), right_elbow, right_hand), skin_shadow, 10)  # type: ignore[index]

    # Shoes.
    canvas.ellipse((right_foot[0] - 17, right_foot[1] - 6, right_foot[0] + 17, right_foot[1] + 7), shoes, ink, 1.2)

    # Torso.
    shoulder_y = chest[1]
    hip_y = hip[1]
    torso_tilt = p["torso_tilt"]  # type: ignore[assignment]
    torso = (
        (cx - 29 + torso_tilt * 0.4, shoulder_y - 5),
        (cx + 29 + torso_tilt * 0.4, shoulder_y - 4),
        (cx + 24 - torso_tilt * 0.2, hip_y + 19),
        (cx - 24 - torso_tilt * 0.2, hip_y + 19),
    )
    canvas.polygon(torso, shirt, ink)
    canvas.rounded_rectangle((cx - 24, shoulder_y + 45, cx + 24, shoulder_y + 73), 10, pants, ink, 1.2)
    canvas.rounded_rectangle((cx - 18, shoulder_y + 11, cx + 18, shoulder_y + 18), 4, accent, None)

    # Front limbs.
    canvas.line((hip, left_knee, left_foot), pants, 12)
    canvas.ellipse((left_foot[0] - 17, left_foot[1] - 6, left_foot[0] + 17, left_foot[1] + 7), shoes, ink, 1.2)
    canvas.line(((cx - 22, shoulder_y + 3), left_elbow, left_hand), skin, 10)

    # Neck, head, hair, face.
    canvas.rounded_rectangle((cx - 8, shoulder_y - 25, cx + 8, shoulder_y - 5), 4, skin, None)
    draw_hair(canvas, hero, head, math.sin((frame / total) * math.tau) * 2)  # type: ignore[arg-type]
    if hero.hair_style in {"bob", "long", "glasses"}:
        canvas.ellipse((head[0] - 17, head[1] - 15, head[0] + 17, head[1] + 21), skin, ink, 1.3)
    draw_face(canvas, hero, head)  # type: ignore[arg-type]

    # Front arm redraw for shooting so the hands sit over the face/ball.
    if animation == "shoot":
        canvas.line(((cx + 22, shoulder_y + 3), right_elbow, right_hand), skin, 10)

    # Jersey number.
    font = load_font(16, bold=True)
    canvas.text((cx, shoulder_y + 33), hero.number, font, (255, 255, 255, 220))

    # Ball carried by some poses.
    ball = p["ball"]
    if ball:
        bx, by, radius, spin = ball  # type: ignore[misc]
        draw_ball(canvas, (bx, by), radius, spin)  # type: ignore[arg-type]

    # Small sketch accents make the antialiased raster read hand-drawn.
    for _ in range(7):
        y = random.uniform(60, 188)
        x = random.uniform(92, 164)
        canvas.line(
            ((x, y), (x + random.uniform(-7, 7), y + random.uniform(-2, 2))),
            (255, 255, 255, 22),
            random.uniform(0.5, 1.0),
        )

    image = canvas.image.filter(ImageFilter.UnsharpMask(radius=0.65, percent=95, threshold=2))
    return image.resize((FRAME_SIZE, FRAME_SIZE), Image.Resampling.LANCZOS)


def draw_ball_frame(frame: int, total: int) -> Image.Image:
    canvas = Canvas()
    phase = frame / total * math.tau
    make_shadow(canvas, 128, 151, 56, 42)
    draw_ball(canvas, (128, 128 + math.sin(phase) * 2), 48, phase)
    canvas.line(((91, 96), (99, 88), (109, 84)), (255, 255, 255, 80), 2.0)
    return canvas.image.resize((FRAME_SIZE, FRAME_SIZE), Image.Resampling.LANCZOS)


def make_preview_sheet(frame_paths: list[Path], output: Path, cols: int = 8, thumb: int = 96) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    label_h = 16
    rows = math.ceil(len(frame_paths) / cols)
    sheet = Image.new("RGBA", (cols * thumb, rows * (thumb + label_h)), (24, 20, 32, 255))
    draw = ImageDraw.Draw(sheet)
    font = load_preview_font(9)
    for index, path in enumerate(frame_paths):
        row, col = divmod(index, cols)
        frame = Image.open(path).convert("RGBA").resize((thumb, thumb), Image.Resampling.LANCZOS)
        x = col * thumb
        y = row * (thumb + label_h)
        sheet.alpha_composite(frame, (x, y))
        label = path.stem.replace("_", " ")
        draw.rectangle((x, y + thumb, x + thumb, y + thumb + label_h), fill=(13, 11, 19, 235))
        draw.text((x + thumb / 2, y + thumb + 2), label[-15:], font=font, fill=(238, 235, 228, 230), anchor="ma")
    sheet.convert("RGB").save(output)


def generate() -> None:
    clear_generated_pngs(PLAYERS_ATLAS)
    clear_generated_pngs(BALL_ATLAS)
    PREVIEW_ROOT.mkdir(parents=True, exist_ok=True)

    manifest: dict[str, object] = {
        "schema": 1,
        "frameSize": [FRAME_SIZE, FRAME_SIZE],
        "runtime": "SpriteKit SKTextureAtlas",
        "generator": "scripts/generate-halfcourt-sprites.py",
        "atlases": {
            "players": {
                "name": "HalfCourtHeroPlayers",
                "path": str(PLAYERS_ATLAS.relative_to(ROOT)),
                "animations": {},
            },
            "ball": {
                "name": "HalfCourtHeroBall",
                "path": str(BALL_ATLAS.relative_to(ROOT)),
                "animations": {},
            },
        },
    }

    player_preview_paths: list[Path] = []
    players = manifest["atlases"]["players"]["animations"]  # type: ignore[index]
    for hero in HEROES:
        hero_manifest: dict[str, object] = {}
        for animation, count in ANIMATION_FRAMES.items():
            frame_names: list[str] = []
            for frame in range(count):
                name = f"{hero.key}_{animation}_{frame:03d}"
                path = PLAYERS_ATLAS / f"{name}.png"
                draw_player_frame(hero, animation, frame, count).save(path)
                frame_names.append(name)
                player_preview_paths.append(path)
            hero_manifest[animation] = {
                "fps": ANIMATION_FPS[animation],
                "frames": frame_names,
            }
        players[hero.key] = hero_manifest  # type: ignore[index]

    ball_names: list[str] = []
    for frame in range(12):
        name = f"ball_spin_{frame:03d}"
        path = BALL_ATLAS / f"{name}.png"
        draw_ball_frame(frame, 12).save(path)
        ball_names.append(name)

    manifest["atlases"]["ball"]["animations"]["spin"] = {  # type: ignore[index]
        "fps": 16,
        "frames": ball_names,
    }

    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n")

    make_preview_sheet(player_preview_paths, PREVIEW_ROOT / "halfcourt-players-sheet.png", cols=8, thumb=96)
    make_preview_sheet([BALL_ATLAS / f"{name}.png" for name in ball_names], PREVIEW_ROOT / "halfcourt-ball-sheet.png", cols=6, thumb=108)

    print(f"Generated {len(player_preview_paths)} player frames in {PLAYERS_ATLAS.relative_to(ROOT)}")
    print(f"Generated {len(ball_names)} ball frames in {BALL_ATLAS.relative_to(ROOT)}")
    print(f"Wrote {MANIFEST_PATH.relative_to(ROOT)}")
    print(f"Wrote previews to {PREVIEW_ROOT.relative_to(ROOT)}")


if __name__ == "__main__":
    generate()
