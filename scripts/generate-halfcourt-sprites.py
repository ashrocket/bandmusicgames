#!/usr/bin/env python3
"""Generate Half Court Hero SpriteKit atlas frames — cartoon-faithful style.

Characters match the opus-4.8 portrait art:
  Nara    — bob + glasses, black shirt, blue shorts
  Ethan   — backwards cap + long beard, green motocross jersey
  Brendan — grey beanie + auburn beard, horizontal-striped shirt
  Will    — black beanie + glasses + orange beard, white WMPG tee

Frame counts are higher than before for smoother motion.
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
SCALE = 4  # 1024×1024 internal canvas → 256×256 output


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
    number: str
    hair_style: str        # "bob", "cap_long", "beanie", "beanie_glasses"
    has_glasses: bool
    beard_color: str | None
    shirt_detail: str      # "solid", "stripes", "motocross"
    sleeve_color: str | None  # long sleeve undershirt colour (Will)


HEROES: tuple[Hero, ...] = (
    Hero("nara",    "Nara",    "#FDBCB4", "#1C0A00", "#222222", "#3366DD", "#2A2A2A", "#FF1493",
         "3",  "bob",           True,  None,      "solid",     None),
    Hero("ethan",   "Ethan",   "#C68642", "#3D2B1F", "#2B7A2B", "#1C1C2E", "#1A4A1A", "#32CD32",
         "5",  "cap_long",      False, "#6B4220",  "motocross", None),
    Hero("brendan", "Brendan", "#FDBCB4", "#CC2200", "#D8D8D8", "#3D6B33", "#888888", "#FF6B35",
         "9",  "beanie",        False, "#BB3300",  "stripes",   None),
    Hero("will",    "Will",    "#8D5524", "#111111", "#F2F2F2", "#1A1A1A", "#888888", "#9B59B6",
         "7",  "beanie_glasses",True,  "#CC4400",  "solid",     "#CC4400"),
)

# More frames = smoother motion
ANIMATION_FRAMES = {
    "idle":      8,
    "dribble":   8,
    "run":       8,
    "shoot":    10,
    "celebrate": 8,
}

ANIMATION_FPS = {
    "idle":      8,
    "dribble":  14,
    "run":      14,
    "shoot":    16,
    "celebrate":12,
}


# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------

def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    v = hex_color.lstrip("#")
    return (int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16), alpha)


def adjust(color: tuple[int, int, int, int], factor: float) -> tuple[int, int, int, int]:
    return (
        max(0, min(255, int(color[0] * factor))),
        max(0, min(255, int(color[1] * factor))),
        max(0, min(255, int(color[2] * factor))),
        color[3],
    )


def blend(a: tuple[int, int, int, int], b: tuple[int, int, int, int], t: float) -> tuple[int, int, int, int]:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))  # type: ignore[return-value]


def jersey_text_fill(shirt_hex: str) -> tuple[int, int, int, int]:
    s = rgba(shirt_hex)
    lum = 0.2126 * s[0] + 0.7152 * s[1] + 0.0722 * s[2]
    return (24, 18, 24, 230) if lum > 185 else (255, 255, 255, 220)


def scaled_point(p: tuple[float, float]) -> tuple[int, int]:
    return (round(p[0] * SCALE), round(p[1] * SCALE))


def scaled_box(b: tuple[float, float, float, float]) -> tuple[int, int, int, int]:
    return tuple(round(v * SCALE) for v in b)  # type: ignore[return-value]


# ---------------------------------------------------------------------------
# Easing helpers for smoother joint motion
# ---------------------------------------------------------------------------

def ease_inout(t: float) -> float:
    return t * t * (3 - 2 * t)


def ease_out(t: float) -> float:
    return 1 - (1 - t) ** 2


# ---------------------------------------------------------------------------
# Canvas wrapper
# ---------------------------------------------------------------------------

class Canvas:
    def __init__(self) -> None:
        self.image = Image.new("RGBA", (FRAME_SIZE * SCALE, FRAME_SIZE * SCALE), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.image)

    def ellipse(self, box: tuple, fill: tuple, outline: tuple | None = None, width: float = 1.0) -> None:
        self.draw.ellipse(scaled_box(box), fill=fill, outline=outline, width=round(width * SCALE))

    def rounded_rectangle(self, box: tuple, radius: float, fill: tuple, outline: tuple | None = None, width: float = 1.0) -> None:
        self.draw.rounded_rectangle(scaled_box(box), radius=round(radius * SCALE), fill=fill, outline=outline, width=round(width * SCALE))

    def polygon(self, points: Iterable[tuple[float, float]], fill: tuple, outline: tuple | None = None, width: float = 1.0) -> None:
        self.draw.polygon([scaled_point(p) for p in points], fill=fill, outline=outline, width=round(width * SCALE))

    def line(self, points: Iterable[tuple[float, float]], fill: tuple, width: float) -> None:
        pts = list(points)
        sc = [scaled_point(p) for p in pts]
        self.draw.line(sc, fill=fill, width=round(width * SCALE), joint="curve")
        r = width / 2
        for pt in (pts[0], pts[-1]):
            self.ellipse((pt[0] - r, pt[1] - r, pt[0] + r, pt[1] + r), fill)

    def text(self, xy: tuple[float, float], value: str, font: ImageFont.ImageFont, fill: tuple, anchor: str = "mm") -> None:
        self.draw.text(scaled_point(xy), value, font=font, fill=fill, anchor=anchor)


# ---------------------------------------------------------------------------
# Assets helpers
# ---------------------------------------------------------------------------

def clear_generated_pngs(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    for png in path.glob("*.png"):
        png.unlink()


def load_font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    candidates = (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "/Library/Fonts/Arial.ttf",
    )
    for c in candidates:
        try:
            if bold == ("Bold" in c):
                return ImageFont.truetype(c, size * SCALE)
        except OSError:
            continue
    return ImageFont.load_default()


def load_preview_font(size: int) -> ImageFont.ImageFont:
    for c in ("/System/Library/Fonts/Supplemental/Arial.ttf", "/Library/Fonts/Arial.ttf"):
        try:
            return ImageFont.truetype(c, size)
        except OSError:
            continue
    return ImageFont.load_default()


# ---------------------------------------------------------------------------
# Basketball
# ---------------------------------------------------------------------------

def draw_ball(canvas: Canvas, center: tuple[float, float], radius: float, spin: float = 0.0, alpha: int = 255) -> None:
    orange = (221, 105, 29, alpha)
    dark   = (103, 43, 15, alpha)
    light  = (246, 150, 65, round(alpha * 0.8))
    cx, cy = center
    canvas.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), orange, dark, 2.0)
    canvas.line(((cx - radius * 0.9, cy), (cx + radius * 0.9, cy)), dark, 1.6)
    so = math.sin(spin) * radius * 0.42
    canvas.line(((cx + so, cy - radius * 0.9), (cx - so, cy + radius * 0.9)), dark, 1.4)
    canvas.line(((cx - radius * 0.72, cy - radius * 0.38), (cx - radius * 0.24, cy), (cx - radius * 0.72, cy + radius * 0.38)), dark, 1.2)
    canvas.line(((cx + radius * 0.72, cy - radius * 0.38), (cx + radius * 0.24, cy), (cx + radius * 0.72, cy + radius * 0.38)), dark, 1.2)
    canvas.ellipse((cx - radius * 0.45, cy - radius * 0.5, cx - radius * 0.05, cy - radius * 0.1), light)


def draw_ball_frame(frame: int, total: int) -> Image.Image:
    canvas = Canvas()
    phase = frame / total * math.tau
    canvas.ellipse((128 - 28, 151 - 8, 128 + 28, 151 + 5), (0, 0, 0, 42))
    draw_ball(canvas, (128, 128 + math.sin(phase) * 2), 48, phase)
    canvas.line(((91, 96), (99, 88), (109, 84)), (255, 255, 255, 80), 2.0)
    return canvas.image.resize((FRAME_SIZE, FRAME_SIZE), Image.Resampling.LANCZOS)


# ---------------------------------------------------------------------------
# Pose solver — returns joint positions for each animation frame
# ---------------------------------------------------------------------------

def pose(hero: Hero, animation: str, frame: int, total: int) -> dict[str, object]:
    t_linear = frame / max(1, total - 1)
    phase = (frame / total) * math.tau

    # Gentle idle bob shared by all poses
    bob = math.sin(phase) * 2.2

    cx      = 128.0
    ground  = 220.0
    hip_y   = 150.0 + bob
    chest_y = 102.0 + bob

    data: dict[str, object] = {
        "cx": cx,
        "ground": ground,
        "hip":    (cx, hip_y),
        "chest":  (cx, chest_y),
        "neck":   (cx, chest_y - 27),
        "head":   (cx, chest_y - 50),
        "torso_tilt": math.sin(phase) * 1.5,
        "left_knee":  (cx - 19, 178 + bob),
        "right_knee": (cx + 19, 178 - bob * 0.4),
        "left_foot":  (cx - 24, ground - 3),
        "right_foot": (cx + 24, ground - 2),
        "left_elbow": (cx - 46, chest_y + 23),
        "left_hand":  (cx - 42, chest_y + 56),
        "right_elbow":(cx + 46, chest_y + 25),
        "right_hand": (cx + 44, chest_y + 57),
        "ball": None,
        # secondary — hair sway lags the body by a quarter cycle
        "hair_sway": math.sin(phase - math.pi / 4) * 1.0,
    }

    if animation == "idle":
        # Gentle weight-shift: hips sway slightly side to side
        sway = math.sin(phase) * 3.0
        breathe = math.sin(phase * 2) * 1.2
        data.update({
            "hip":   (cx + sway * 0.4, hip_y),
            "chest": (cx + sway * 0.2, chest_y + breathe),
            "neck":  (cx + sway * 0.1, chest_y + breathe - 27),
            "head":  (cx + sway * 0.1, chest_y + breathe - 50),
            "left_elbow":  (cx - 44 - sway * 0.3, chest_y + breathe + 22),
            "left_hand":   (cx - 41 - sway * 0.4, chest_y + breathe + 54),
            "right_elbow": (cx + 44 + sway * 0.3, chest_y + breathe + 22),
            "right_hand":  (cx + 43 + sway * 0.4, chest_y + breathe + 55),
        })

    elif animation == "run":
        # Proper two-beat walk/run cycle
        stride  = math.sin(phase)
        counter = math.cos(phase)
        # Hip dip — hips drop on the planted foot side
        hip_dip = abs(math.sin(phase)) * 4
        # Torso lean forward
        forward_lean = -8 + stride * 4
        # Foot lift: one foot up while the other is down
        left_up  = max(0, math.sin(phase))
        right_up = max(0, -math.sin(phase))
        data.update({
            "hip":    (cx + stride * 4, hip_y + hip_dip),
            "torso_tilt": forward_lean,
            "left_knee":  (cx - 14 - stride * 18, 172 + abs(counter) * 8),
            "right_knee": (cx + 14 + stride * 18, 172 + abs(counter) * 8),
            "left_foot":  (cx - 20 - stride * 34, ground - 3 - left_up * 14),
            "right_foot": (cx + 20 + stride * 34, ground - 2 - right_up * 14),
            # Arms swing opposite to legs — exaggerated for cartoon feel
            "left_elbow":  (cx - 40 + stride * 16, chest_y + 10),
            "left_hand":   (cx - 38 + stride * 32, chest_y + 44),
            "right_elbow": (cx + 40 - stride * 16, chest_y + 10),
            "right_hand":  (cx + 38 - stride * 32, chest_y + 44),
            "hair_sway": math.sin(phase - math.pi / 3) * 3.5,
        })

    elif animation == "dribble":
        # Dribbling: weight shift, ball bounce, arm pump
        bounce   = (math.sin(phase) + 1) / 2   # 0..1 ball at bottom
        arm_pump = (1 - bounce)                 # arm up when ball is up
        sway     = math.sin(phase) * 2.5        # slight body sway
        data.update({
            "hip":    (cx + sway * 0.5, hip_y + bounce * 2),
            "chest":  (cx + sway * 0.3, chest_y),
            "neck":   (cx + sway * 0.2, chest_y - 27),
            "head":   (cx + sway * 0.2, chest_y - 50),
            "left_elbow":  (cx - 40, chest_y + 8),
            "left_hand":   (cx - 48, chest_y + 36),
            "right_elbow": (cx + 50, chest_y + 22 + arm_pump * 16),
            "right_hand":  (cx + 58, chest_y + 44 + bounce * 28),
            "right_knee":  (cx + 28, 178),
            "right_foot":  (cx + 36, ground - 3),
            "ball": (cx + 62, 196 + bounce * 20, 13, phase),
        })

    elif animation == "shoot":
        # Three-phase: crouch → rise & extend → follow-through
        crouch_t = ease_inout(min(1.0, t_linear / 0.35))
        rise_t   = ease_out(max(0.0, min(1.0, (t_linear - 0.25) / 0.55)))
        release  = max(0.0, (t_linear - 0.72) / 0.28)
        crouch   = math.sin(crouch_t * math.pi) * 14
        chest_y  += crouch

        data.update({
            "hip":    (cx, 150 + crouch),
            "chest":  (cx + rise_t * 4, chest_y),
            "neck":   (cx + rise_t * 4, chest_y - 27),
            "head":   (cx + rise_t * 4, chest_y - 50),
            "left_knee":  (cx - 24, 175 + crouch * 0.75),
            "right_knee": (cx + 26, 175 + crouch * 0.75),
            "left_foot":  (cx - 28, ground - 3),
            "right_foot": (cx + 32, ground - 6 - rise_t * 8),
            # Arms sweep overhead
            "left_elbow":  (cx - 22 + rise_t * 10, chest_y - 6  - rise_t * 38),
            "left_hand":   (cx -  8 + rise_t * 16, chest_y - 12 - rise_t * 74),
            "right_elbow": (cx + 25 + rise_t * 10, chest_y - 5  - rise_t * 40),
            "right_hand":  (cx + 12 + rise_t * 18, chest_y - 12 - rise_t * 76),
            "torso_tilt":  -3 + rise_t * 8,
        })
        bx = cx + 2 + rise_t * 18 + release * 24
        by = chest_y - 26 - rise_t * 78 - release * 36
        data["ball"] = (bx, by, 13, phase) if frame < total - 1 else None

    elif animation == "celebrate":
        # Jump with both arms raised — exaggerated up-and-down
        jump_t   = abs(math.sin(phase))
        wave     = math.sin(phase)
        air_time = jump_t * 18
        data.update({
            "hip":    (cx, hip_y - air_time * 0.6),
            "chest":  (cx, chest_y - air_time * 0.8),
            "neck":   (cx, chest_y - air_time * 0.8 - 27),
            "head":   (cx, chest_y - air_time * 0.8 - 50),
            "left_foot":  (cx - 28, ground - 3 - air_time * 0.9),
            "right_foot": (cx + 28, ground - 2 - air_time * 0.9),
            "left_knee":  (cx - 20, 174 - air_time * 0.5),
            "right_knee": (cx + 20, 174 - air_time * 0.5),
            # Both arms shoot skyward
            "left_elbow":  (cx - 38 - wave * 8, chest_y - air_time * 0.8 - 30),
            "left_hand":   (cx - 56 - wave * 12, chest_y - air_time * 0.8 - 80),
            "right_elbow": (cx + 38 + wave * 8, chest_y - air_time * 0.8 - 30),
            "right_hand":  (cx + 56 + wave * 12, chest_y - air_time * 0.8 - 80),
            "hair_sway": wave * 4.0,
        })

    return data


# ---------------------------------------------------------------------------
# Drawing primitives — character body parts
# ---------------------------------------------------------------------------

def make_shadow(canvas: Canvas, center_x: float, ground_y: float, width: float, alpha: int) -> None:
    canvas.ellipse((center_x - width / 2, ground_y - 6, center_x + width / 2, ground_y + 8), (0, 0, 0, alpha))


def draw_limb(canvas: Canvas, p1: tuple[float, float], p2: tuple[float, float], p3: tuple[float, float],
              fill: tuple, width_prox: float, width_dist: float, ink: tuple) -> None:
    """Three-point tapered limb (shoulder→elbow→hand or hip→knee→foot)."""
    # Simple version: two segments with rounded ends
    canvas.line((p1, p2, p3), fill, (width_prox + width_dist) / 2)
    # Ink outline via two thin dark strokes
    canvas.line((p1, p2, p3), ink, (width_prox + width_dist) / 2 + 1.5)
    canvas.line((p1, p2, p3), fill, (width_prox + width_dist) / 2)
    # Highlight
    canvas.line((p1, p2, p3), (255, 255, 255, 18), width_prox * 0.3)


def draw_shoe(canvas: Canvas, foot: tuple[float, float], shoes_color: tuple, ink: tuple, facing: float = 1.0) -> None:
    fx, fy = foot
    w = 18
    canvas.rounded_rectangle((fx - w, fy - 7, fx + w * facing * 0.6, fy + 8), 5, shoes_color, ink, 1.2)
    # Sole highlight
    canvas.line(((fx - w + 3, fy + 5), (fx + w * facing * 0.4, fy + 5)), (255, 255, 255, 28), 1.0)


def draw_beard(canvas: Canvas, hero: Hero, cx: float, cy: float) -> None:
    """Draw beard over the lower face; only if hero.beard_color is set."""
    if not hero.beard_color:
        return
    beard = rgba(hero.beard_color)
    ink   = adjust(beard, 0.65)
    # Full beard covers chin area
    canvas.rounded_rectangle(
        (cx - 16, cy + 5, cx + 16, cy + 27),
        radius=7, fill=beard, outline=ink, width=0.9,
    )
    # Mustache area blends into face
    canvas.rounded_rectangle(
        (cx - 11, cy + 1, cx + 11, cy + 10),
        radius=4, fill=blend(beard, rgba(hero.skin), 0.25), outline=None,
    )
    # Inner highlight stripe
    canvas.line(((cx - 6, cy + 9), (cx - 6, cy + 23)), (255, 255, 255, 30), 1.0)


def draw_glasses(canvas: Canvas, cx: float, cy: float, ink: tuple) -> None:
    """Round glasses frames."""
    canvas.ellipse((cx - 15, cy - 10, cx - 3, cy + 1), (0, 0, 0, 0), ink, 1.6)
    canvas.ellipse((cx + 3,  cy - 10, cx + 15, cy + 1), (0, 0, 0, 0), ink, 1.6)
    # Bridge
    canvas.line(((cx - 3, cy - 5), (cx + 3, cy - 5)), ink, 1.1)
    # Temples (arms)
    canvas.line(((cx - 15, cy - 5), (cx - 22, cy - 4)), ink, 1.1)
    canvas.line(((cx + 15, cy - 5), (cx + 22, cy - 4)), ink, 1.1)


def draw_hair(canvas: Canvas, hero: Hero, head: tuple[float, float], sway: float) -> None:
    cx, cy = head
    hair = rgba(hero.hair)
    ink  = (22, 16, 23, 165)
    skin = rgba(hero.skin)

    if hero.hair_style == "bob":
        # Dark bob: rounded rectangle, face cut out
        canvas.rounded_rectangle((cx - 26 + sway, cy - 25, cx + 26 + sway, cy + 30), 16, hair, ink, 1.4)
        canvas.ellipse((cx - 18, cy - 16, cx + 18, cy + 22), skin)
        # Inner hair highlight
        canvas.line(((cx - 18, cy - 18), (cx - 22, cy + 10)), (255, 255, 255, 25), 1.2)

    elif hero.hair_style == "cap_long":
        # Ethan: long hair flowing behind + backwards baseball cap
        # Long hair (drawn first, behind cap)
        canvas.rounded_rectangle((cx - 24 + sway * 0.7, cy - 18, cx + 20 + sway * 0.7, cy + 60), 14, hair, ink, 1.3)
        # Face on top of hair
        canvas.ellipse((cx - 18, cy - 14, cx + 18, cy + 22), skin, ink, 1.3)
        # Cap crown (white/light)
        cap_col = rgba("#EFEFEF")
        cap_ink = rgba("#AAAAAA")
        canvas.rounded_rectangle((cx - 23, cy - 32, cx + 23, cy - 12), 10, cap_col, cap_ink, 1.2)
        # Cap band
        canvas.rounded_rectangle((cx - 24, cy - 16, cx + 24, cy - 12), 3, rgba("#CCCCCC"), None)
        # Backwards brim sticks out on the left (character faces right)
        canvas.rounded_rectangle((cx - 40, cy - 17, cx - 22, cy - 11), 2, rgba("#DDDDDD"), cap_ink, 0.8)
        # Cap logo detail — small rectangle
        canvas.rounded_rectangle((cx + 4, cy - 28, cx + 14, cy - 20), 2, rgba("#AADDAA"), None)

    elif hero.hair_style == "beanie":
        # Brendan: grey wool beanie + auburn hair peeking out
        canvas.ellipse((cx - 20, cy - 14, cx + 20, cy + 18), skin, ink, 1.3)
        # Beanie body
        beanie = rgba("#929292")
        canvas.rounded_rectangle((cx - 23, cy - 30, cx + 23, cy - 6), 10, beanie, ink, 1.1)
        # Rib band
        canvas.rounded_rectangle((cx - 24, cy - 10, cx + 24, cy - 6), 3, adjust(beanie, 0.82), None)
        # A little hair texture at the rim (auburn)
        canvas.line(((cx - 22, cy - 6), (cx + 22, cy - 6)), rgba(hero.hair, 60), 2.0)
        # Highlight on beanie
        canvas.line(((cx - 16, cy - 28), (cx - 12, cy - 10)), (255, 255, 255, 40), 1.5)

    elif hero.hair_style == "beanie_glasses":
        # Will: black beanie, no visible hair
        canvas.ellipse((cx - 20, cy - 14, cx + 20, cy + 18), skin, ink, 1.3)
        beanie = rgba("#222222")
        canvas.rounded_rectangle((cx - 23, cy - 30, cx + 23, cy - 5), 10, beanie, ink, 1.1)
        canvas.rounded_rectangle((cx - 24, cy - 9, cx + 24, cy - 5), 3, adjust(beanie, 1.3), None)
        canvas.line(((cx - 16, cy - 28), (cx - 12, cy - 8)), (255, 255, 255, 35), 1.5)


def draw_face(canvas: Canvas, hero: Hero, head: tuple[float, float]) -> None:
    cx, cy = head
    ink  = (20, 14, 18, 210)
    skin = rgba(hero.skin)

    # Nose
    canvas.ellipse((cx - 3, cy, cx + 3, cy + 5), adjust(skin, 0.88))
    # Eyes — larger and more expressive
    canvas.ellipse((cx - 11, cy - 7, cx - 4,  cy - 1), ink)
    canvas.ellipse((cx +  4, cy - 7, cx + 11, cy - 1), ink)
    # Eye whites
    canvas.ellipse((cx - 10, cy - 6, cx - 6, cy - 2), (255, 255, 255, 120))
    canvas.ellipse((cx + 6,  cy - 6, cx + 10, cy - 2), (255, 255, 255, 120))
    # Mouth — relaxed smile
    canvas.line(((cx - 7, cy + 12), (cx, cy + 15), (cx + 7, cy + 12)), ink, 1.3)

    if hero.has_glasses:
        draw_glasses(canvas, cx, cy, ink)

    draw_beard(canvas, hero, cx, cy)


def draw_torso_detail(canvas: Canvas, hero: Hero, torso_poly: list[tuple[float, float]],
                      shoulder_y: float, hip_y: float, cx: float, shirt: tuple) -> None:
    """Add shirt-specific detail on top of the base torso polygon."""
    if hero.shirt_detail == "stripes":
        # Brendan: horizontal dark/light stripes — 3 bands
        ink = adjust(shirt, 0.6)
        for i in range(3):
            band_y = shoulder_y + 8 + i * 16
            canvas.rounded_rectangle(
                (cx - 24, band_y, cx + 24, band_y + 8),
                radius=2, fill=ink, outline=None,
            )

    elif hero.shirt_detail == "motocross":
        # Ethan: diagonal V-chevrons like a motocross jersey
        dark  = rgba("#1A5A1A", 210)
        light = rgba("#7FD07F", 160)
        # Left chevron
        canvas.polygon([
            (cx - 28, shoulder_y),
            (cx - 6,  shoulder_y + 22),
            (cx - 14, shoulder_y + 22),
            (cx - 28, shoulder_y + 6),
        ], dark)
        # Right chevron
        canvas.polygon([
            (cx + 28, shoulder_y),
            (cx + 6,  shoulder_y + 22),
            (cx + 14, shoulder_y + 22),
            (cx + 28, shoulder_y + 6),
        ], dark)
        # Centre highlight strip
        canvas.polygon([
            (cx - 6,  shoulder_y),
            (cx + 6,  shoulder_y),
            (cx + 3,  shoulder_y + 24),
            (cx - 3,  shoulder_y + 24),
        ], light)

    # Jersey number — always drawn last so it sits on top
    font = load_font(16, bold=True)
    canvas.text((cx, shoulder_y + 38), hero.number, font, jersey_text_fill(hero.shirt))


# ---------------------------------------------------------------------------
# Full frame renderer
# ---------------------------------------------------------------------------

def draw_player_frame(hero: Hero, animation: str, frame: int, total: int) -> Image.Image:
    random.seed(f"{hero.key}:{animation}:{frame}")
    canvas = Canvas()
    p = pose(hero, animation, frame, total)

    cx      = p["cx"]           # type: ignore[assignment]
    ground  = p["ground"]       # type: ignore[assignment]
    chest   = p["chest"]        # type: ignore[assignment]
    hip     = p["hip"]          # type: ignore[assignment]
    head    = p["head"]         # type: ignore[assignment]
    sway    = p["hair_sway"]    # type: ignore[assignment]

    lknee = p["left_knee"]      # type: ignore[assignment]
    rknee = p["right_knee"]     # type: ignore[assignment]
    lfoot = p["left_foot"]      # type: ignore[assignment]
    rfoot = p["right_foot"]     # type: ignore[assignment]
    lelbow= p["left_elbow"]     # type: ignore[assignment]
    lhand = p["left_hand"]      # type: ignore[assignment]
    relbow= p["right_elbow"]    # type: ignore[assignment]
    rhand = p["right_hand"]     # type: ignore[assignment]
    tilt  = p["torso_tilt"]     # type: ignore[assignment]

    chest_x, chest_y = chest
    hip_x,   hip_y   = hip
    head_cx, head_cy = head

    skin    = rgba(hero.skin)
    shirt   = rgba(hero.shirt)
    pants   = rgba(hero.pants)
    shoes   = rgba(hero.shoes)
    ink     = (22, 16, 23, 165)
    skin_sh = adjust(skin, 0.88)
    pant_sh = adjust(pants, 0.72)

    # Ground shadow
    make_shadow(canvas, cx, ground + 3, 88, 46)

    # ---- Back leg (right, in shadow) ----
    canvas.line((hip, rknee, rfoot), pant_sh, 12)
    draw_shoe(canvas, rfoot, adjust(shoes, 0.82), ink)

    # ---- Back arm (right) ----
    canvas.line(((chest_x + 23, chest_y + 4), relbow, rhand), skin_sh, 10)

    # ---- Torso (shirt) ----
    shoulder_y = chest_y
    torso = [
        (chest_x - 30 + tilt * 0.4, shoulder_y - 6),
        (chest_x + 30 + tilt * 0.4, shoulder_y - 5),
        (hip_x   + 25 - tilt * 0.2, hip_y + 20),
        (hip_x   - 25 - tilt * 0.2, hip_y + 20),
    ]
    canvas.polygon(torso, shirt, ink)

    # Collar / neck opening
    canvas.rounded_rectangle(
        (chest_x - 9, shoulder_y - 14, chest_x + 9, shoulder_y - 4),
        radius=4, fill=rgba(hero.skin, 180), outline=ink, width=0.8,
    )

    # Shirt detail & jersey number
    draw_torso_detail(canvas, hero, torso, shoulder_y, hip_y, chest_x, shirt)

    # Pants — shorts block under torso
    canvas.rounded_rectangle(
        (chest_x - 25, shoulder_y + 46, chest_x + 25, shoulder_y + 75),
        radius=10, fill=pants, outline=ink, width=1.1,
    )

    # Accent stripe on shorts
    canvas.rounded_rectangle(
        (chest_x - 19, shoulder_y + 12, chest_x + 19, shoulder_y + 19),
        radius=4, fill=rgba(hero.accent), outline=None,
    )

    # Will's long sleeves (under the shirt, visible at wrists)
    if hero.sleeve_color:
        sleeve = rgba(hero.sleeve_color)
        canvas.line(((chest_x - 23, shoulder_y + 3), lelbow, lhand), sleeve, 13)
        canvas.line(((chest_x + 23, shoulder_y + 3), relbow, rhand), sleeve, 13)

    # ---- Front leg (left) ----
    canvas.line((hip, lknee, lfoot), pants, 13)
    draw_shoe(canvas, lfoot, shoes, ink)

    # ---- Front arm (left) ----
    canvas.line(((chest_x - 23, shoulder_y + 4), lelbow, lhand), skin, 11)

    # ---- Neck ----
    canvas.rounded_rectangle(
        (chest_x - 8, shoulder_y - 27, chest_x + 8, shoulder_y - 7),
        radius=4, fill=skin, outline=None,
    )

    # ---- Head + hair + face ----
    draw_hair(canvas, hero, (head_cx, head_cy), sway)
    draw_face(canvas, hero, (head_cx, head_cy))

    # Shooting arm redraw so hand sits in front of ball/face
    if animation == "shoot":
        if hero.sleeve_color:
            canvas.line(((chest_x + 23, shoulder_y + 3), relbow, rhand), rgba(hero.sleeve_color), 13)
        canvas.line(((chest_x + 23, shoulder_y + 4), relbow, rhand), skin, 11)

    # ---- Ball ----
    ball = p["ball"]
    if ball:
        bx, by, brad, bspin = ball  # type: ignore[misc]
        draw_ball(canvas, (bx, by), brad, bspin)

    # Hand-drawn sketch accents
    for _ in range(9):
        y = random.uniform(58, 195)
        x = random.uniform(90, 168)
        canvas.line(
            ((x, y), (x + random.uniform(-8, 8), y + random.uniform(-2, 2))),
            (255, 255, 255, 20),
            random.uniform(0.5, 1.1),
        )

    # Final: unsharp mask then LANCZOS downsample
    img = canvas.image.filter(ImageFilter.UnsharpMask(radius=0.7, percent=90, threshold=2))
    return img.resize((FRAME_SIZE, FRAME_SIZE), Image.Resampling.LANCZOS)


# ---------------------------------------------------------------------------
# Preview sheet
# ---------------------------------------------------------------------------

def make_preview_sheet(frame_paths: list[Path], output: Path, cols: int = 8, thumb: int = 96) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    label_h = 16
    rows = math.ceil(len(frame_paths) / cols)
    sheet = Image.new("RGBA", (cols * thumb, rows * (thumb + label_h)), (24, 20, 32, 255))
    draw  = ImageDraw.Draw(sheet)
    font  = load_preview_font(9)
    for idx, path in enumerate(frame_paths):
        row, col = divmod(idx, cols)
        frame = Image.open(path).convert("RGBA").resize((thumb, thumb), Image.Resampling.LANCZOS)
        x = col * thumb
        y = row * (thumb + label_h)
        sheet.alpha_composite(frame, (x, y))
        label = path.stem.replace("_", " ")
        draw.rectangle((x, y + thumb, x + thumb, y + thumb + label_h), fill=(13, 11, 19, 235))
        draw.text((x + thumb / 2, y + thumb + 2), label[-15:], font=font, fill=(238, 235, 228, 230), anchor="ma")
    sheet.convert("RGB").save(output)


# ---------------------------------------------------------------------------
# Main generation entry point
# ---------------------------------------------------------------------------

def generate() -> None:
    clear_generated_pngs(PLAYERS_ATLAS)
    clear_generated_pngs(BALL_ATLAS)
    PREVIEW_ROOT.mkdir(parents=True, exist_ok=True)

    manifest: dict[str, object] = {
        "schema": 2,
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

    preview_paths: list[Path] = []
    players_anim = manifest["atlases"]["players"]["animations"]  # type: ignore[index]

    for hero in HEROES:
        hero_manifest: dict[str, object] = {}
        for anim, count in ANIMATION_FRAMES.items():
            names: list[str] = []
            for f in range(count):
                name = f"{hero.key}_{anim}_{f:03d}"
                path = PLAYERS_ATLAS / f"{name}.png"
                draw_player_frame(hero, anim, f, count).save(path)
                names.append(name)
                preview_paths.append(path)
                print(f"  {name}")
            hero_manifest[anim] = {"fps": ANIMATION_FPS[anim], "frames": names}
        players_anim[hero.key] = hero_manifest  # type: ignore[index]

    ball_names: list[str] = []
    for f in range(12):
        name = f"ball_spin_{f:03d}"
        path = BALL_ATLAS / f"{name}.png"
        draw_ball_frame(f, 12).save(path)
        ball_names.append(name)

    manifest["atlases"]["ball"]["animations"]["spin"] = {"fps": 16, "frames": ball_names}  # type: ignore[index]

    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n")

    make_preview_sheet(preview_paths, PREVIEW_ROOT / "halfcourt-players-sheet.png", cols=8, thumb=96)
    make_preview_sheet(
        [BALL_ATLAS / f"{n}.png" for n in ball_names],
        PREVIEW_ROOT / "halfcourt-ball-sheet.png",
        cols=6, thumb=108,
    )

    total = len(preview_paths)
    print(f"\nGenerated {total} player frames → {PLAYERS_ATLAS.relative_to(ROOT)}")
    print(f"Generated {len(ball_names)} ball frames  → {BALL_ATLAS.relative_to(ROOT)}")
    print(f"Wrote manifest → {MANIFEST_PATH.relative_to(ROOT)}")
    print(f"Wrote preview sheets → {PREVIEW_ROOT.relative_to(ROOT)}")


if __name__ == "__main__":
    generate()
