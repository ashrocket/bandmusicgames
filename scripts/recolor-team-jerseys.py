#!/usr/bin/env python3
"""Recolor original HalfCourtHero sprites to Knicks/Spurs team jerseys.

Actual sprite designs (not Swift-color-constant based):
  nara:    black tee, blue shorts, dark shoes
  ethan:   green moto jersey, black jeans, white/green sneakers
  brendan: gray-striped long-sleeve, tan/olive pants, canvas shoes
  will:    white WMPG tee over orange long-sleeve, dark pants, tan shoes
"""
import colorsys
import numpy as np
from PIL import Image
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
XCASSETS = ROOT / 'ios/BandMusicGames/Assets.xcassets'

TEAM_JERSEYS = {
    'knicks': {'shirt': '#FFFFFF', 'pants': '#006BB6', 'shoes': '#006BB6'},
    'spurs':  {'shirt': '#1A1A1A', 'pants': '#B4B4B4', 'shoes': '#1A1A1A'},
}

def hex_rgb(h: str) -> tuple:
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))

def to_hls(r, g, b):
    return colorsys.rgb_to_hls(r / 255, g / 255, b / 255)  # (H, L, S)

def hue_dist(h1, h2):
    d = abs(h1 - h2)
    return min(d, 1.0 - d)

def luma(r, g, b):
    return 0.2126 * (r / 255) + 0.7152 * (g / 255) + 0.0722 * (b / 255)

def scale_pixel(target, px_r, px_g, px_b, base_luma_val):
    """Scale target color by pixel's luminance relative to the base color."""
    ratio = luma(px_r, px_g, px_b) / max(base_luma_val, 0.004)
    tr, tg, tb = target
    return (
        min(255, max(0, int(tr * ratio))),
        min(255, max(0, int(tg * ratio))),
        min(255, max(0, int(tb * ratio))),
    )

# Sampled base luminances from actual sprite pixels
BASE_LUMAS = {
    'nara':    {'shirt': luma(19, 23, 23),    'pants': luma(9, 79, 230),    'shoes': luma(42, 42, 42)},
    'ethan':   {'shirt': luma(64, 168, 34),   'pants': luma(46, 46, 46),    'shoes': luma(200, 200, 200)},
    'brendan': {'shirt': luma(170, 160, 143), 'pants': luma(141, 135, 100), 'shoes': luma(142, 136, 100)},
    'will':    {'shirt': luma(247, 242, 237),  'pants': luma(40, 41, 41),    'shoes': luma(140, 130, 100)},
}


def classify_nara(r, g, b, y, rmin, content_h):
    s = r + g + b
    # Blue shorts: b dominant
    if b > r * 1.7 and b > g * 1.1 and b > 50:
        return 'pants'
    # Dark neutral: shirt or shoes
    if r < 80 and g < 80 and b < 80:
        shirt_start = rmin + int(content_h * 0.18)   # ~y=221, below bob haircut
        shoes_start = rmin + int(content_h * 0.83)
        if y >= shirt_start and y < shoes_start and s >= 58:
            return 'shirt'
        if y >= shoes_start and s > 20:
            return 'shoes'
    return None


def classify_ethan(r, g, b, y, rmin, content_h):
    H, L, S = to_hls(r, g, b)
    pants_start = rmin + int(content_h * 0.55)
    shoes_start = rmin + int(content_h * 0.83)

    # Green moto jersey: hue near 120° (0.333), saturated; extend slightly past pants_start for waistband
    shirt_end = pants_start + int(content_h * 0.06)
    if hue_dist(H, 0.333) < 0.12 and S > 0.35 and L < 0.92 and y < shirt_end:
        return 'shirt'

    # Dark jeans: dark neutral in pants zone
    s = r + g + b
    if y >= pants_start and y < shoes_start:
        if r < 70 and g < 70 and b < 70 and s > 15:
            return 'pants'

    # Shoes zone: recolor anything that isn't just outline
    if y >= shoes_start:
        if s > 30:  # skip near-pure-black outline pixels
            return 'shoes'

    return None


def classify_brendan(r, g, b, y, rmin, content_h):
    H, L, S = to_hls(r, g, b)
    s = r + g + b

    head_end = rmin + int(content_h * 0.27)    # skip hat + head
    pants_start = rmin + int(content_h * 0.56)
    shoes_start = rmin + int(content_h * 0.82)

    # Skip head zone
    if y < head_end:
        return None

    # Skip high-saturation pixels: beard (orange-red, S~0.8), skin (S~0.5+)
    if S > 0.32:
        return None

    # Skip near-black ink outlines and near-white background
    if s < 25 or s > 720:
        return None

    # Classify by y-zone (all remaining pixels are low-sat neutral tones: shirt/pants/shoes)
    if y < pants_start:
        return 'shirt'
    elif y < shoes_start:
        return 'pants'
    else:
        return 'shoes'


def classify_will(r, g, b, y, rmin, content_h):
    H, L, S = to_hls(r, g, b)
    s = r + g + b
    head_end = rmin + int(content_h * 0.24)    # skip beanie + face
    pants_start = rmin + int(content_h * 0.55)
    shoes_start = rmin + int(content_h * 0.83)

    if y < head_end:
        return None

    # Skip orange long-sleeve / skin (warm orange hue near 0.07, high sat)
    if hue_dist(H, 0.07) < 0.06 and S > 0.5:
        return None
    # Skip blue logo text on WMPG shirt
    if b > r * 1.5 and b > g and b > 50 and r < 100:
        return None

    # White WMPG tee: high brightness in shirt zone
    if y >= head_end and y < pants_start:
        if r > 200 and g > 190 and b > 180:  # white/near-white shirt pixels
            return 'shirt'

    # Dark pants: very dark neutral in pants zone
    if y >= pants_start and y < shoes_start:
        if r < 70 and g < 70 and b < 70 and s > 15:
            return 'pants'

    # Shoes zone: warm tan pixels (not black outline, not clearly orange skin)
    if y >= shoes_start:
        if s > 25 and not (r > 180 and hue_dist(H, 0.07) < 0.08 and S > 0.5):
            return 'shoes'

    return None


CLASSIFIERS = {
    'nara': classify_nara,
    'ethan': classify_ethan,
    'brendan': classify_brendan,
    'will': classify_will,
}


def recolor(hero_key: str, team: str) -> Image.Image:
    src = XCASSETS / f'hch_{hero_key}.imageset/{hero_key}_sprite.png'
    img = Image.open(src).convert('RGBA')
    arr = np.array(img, dtype=np.uint8)
    result = arr.copy()
    H_px, W_px = arr.shape[:2]

    alpha = arr[:, :, 3]
    rows = np.any(alpha > 20, axis=1)
    rmin = int(np.where(rows)[0][0])
    rmax = int(np.where(rows)[0][-1])
    content_h = rmax - rmin

    jersey = {k: hex_rgb(v) for k, v in TEAM_JERSEYS[team].items()}
    base = BASE_LUMAS[hero_key]
    classify = CLASSIFIERS[hero_key]

    counts = {'shirt': 0, 'pants': 0, 'shoes': 0}
    for y in range(rmin, rmax + 1):
        for x in range(W_px):
            p = arr[y, x]
            if p[3] < 20:
                continue
            r, g, b = int(p[0]), int(p[1]), int(p[2])
            region = classify(r, g, b, y, rmin, content_h)
            if region is None:
                continue
            target = jersey[region]
            bl = base[region]
            nr, ng, nb = scale_pixel(target, r, g, b, bl)
            result[y, x] = (nr, ng, nb, p[3])
            counts[region] += 1

    print(f"    {hero_key}/{team}: shirt={counts['shirt']} pants={counts['pants']} shoes={counts['shoes']}")
    return Image.fromarray(result)


if __name__ == '__main__':
    heroes = ['nara', 'ethan', 'brendan', 'will']
    for hero in heroes:
        for team in ('knicks', 'spurs'):
            print(f'  {hero} → {team}...', end=' ', flush=True)
            img = recolor(hero, team)
            img.save(f'/tmp/{hero}_sprite_{team}.png')
    print('Done.')
