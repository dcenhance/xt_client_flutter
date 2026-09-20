#!/usr/bin/env python3
"""Install the Spectre launcher icon (A9 low-poly eagle) into the Android resources.

Source art: assets/branding/spectre_icon.png — a 1024 px GPT-image-2 raster
(A9 "low-poly" direction), selected in Discord out of the candidate sheet.

What this writes:
  drawable-<density>/ic_launcher_foreground.png  mark on transparent, 62 % of the
                                                 108 dp adaptive canvas (safe zone)
  drawable-<density>/ic_launcher_monochrome.png  same silhouette in flat white for
                                                 Android 13+ themed icons
  mipmap-<density>/ic_launcher.png               legacy square: mark on #0A0A0B
  mipmap-<density>/ic_launcher_round.png         legacy round, art kept inside the circle
  assets/branding/spectre_icon_512.png           composed archive/store icon

The alpha channel is derived from luminance distance to the sampled background, so
the low-poly facets stay intact while the black field becomes transparent.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

PROJECT = Path('/srv/apps/hermes/DEXCORE Projects/Spectre')
RES = PROJECT / 'android/app/src/main/res'
MASTER = PROJECT / 'assets/branding/spectre_icon.png'
BACKGROUND = (10, 10, 11, 255)          # #0A0A0B, matches @color/ic_launcher_background

ADAPTIVE_DP = 108                        # adaptive-icon canvas
LEGACY_DP = 48                           # legacy mipmap canvas
FOREGROUND_COVER = 0.62                  # mark width as a share of the adaptive canvas
LEGACY_COVER = 0.68
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def mark_rgba(master: Image.Image) -> Image.Image:
    """Cut the mark out of the near-black field and keep its own colours."""
    master = master.convert('RGB')
    width, height = master.size
    corners = [master.getpixel(p) for p in
               ((2, 2), (width - 3, 2), (2, height - 3), (width - 3, height - 3))]
    bg = tuple(sum(c[i] for c in corners) // len(corners) for i in range(3))
    pixels = list(master.getdata())
    alpha = Image.new('L', master.size, 0)
    alpha.putdata([min(255, int(max(abs(p[0] - bg[0]), abs(p[1] - bg[1]), abs(p[2] - bg[2])) * 4.2))
                   for p in pixels])
    alpha = alpha.filter(ImageFilter.GaussianBlur(1.2))
    rgba = master.convert('RGBA')
    rgba.putalpha(alpha)
    bbox = alpha.point(lambda v: 255 if v > 24 else 0).getbbox()
    if bbox:
        side = max(bbox[2] - bbox[0], bbox[3] - bbox[1])
        cx, cy = (bbox[0] + bbox[2]) // 2, (bbox[1] + bbox[3]) // 2
        rgba = rgba.crop((cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2))
    return rgba


def scaled(mark: Image.Image, canvas: int, cover: float) -> Image.Image:
    target = max(1, int(round(canvas * cover)))
    resized = mark.resize((target, target), Image.LANCZOS)
    layer = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
    offset = (canvas - target) // 2
    layer.paste(resized, (offset, offset), resized)
    return layer


def legacy(mark: Image.Image, canvas: int) -> Image.Image:
    plate = Image.new('RGBA', (canvas, canvas), BACKGROUND)
    plate.alpha_composite(scaled(mark, canvas, LEGACY_COVER))
    return plate


def main() -> int:
    if not MASTER.is_file():
        print(f'master art missing: {MASTER}')
        return 1
    mark = mark_rgba(Image.open(MASTER))
    written = 0

    for density, factor in DENSITIES.items():
        adaptive = int(ADAPTIVE_DP * factor)
        target = RES / f'drawable-{density}'
        target.mkdir(parents=True, exist_ok=True)
        foreground = scaled(mark, adaptive, FOREGROUND_COVER)
        foreground.save(target / 'ic_launcher_foreground.png', optimize=True)
        mono = Image.new('RGBA', foreground.size, (0, 0, 0, 0))
        white = Image.new('RGBA', foreground.size, (255, 255, 255, 255))
        mono.paste(white, (0, 0), foreground.getchannel('A'))
        mono.save(target / 'ic_launcher_monochrome.png', optimize=True)

        legacy_px = int(LEGACY_DP * factor)
        mip = RES / f'mipmap-{density}'
        mip.mkdir(parents=True, exist_ok=True)
        plate = legacy(mark, legacy_px)
        plate.save(mip / 'ic_launcher.png', optimize=True)
        round_plate = plate.copy()
        ImageDraw.Draw(round_plate)  # keep the exact same art; the launcher masks the circle
        round_plate.save(mip / 'ic_launcher_round.png', optimize=True)
        written += 5
        print(f'{density:8} adaptive={adaptive:4} legacy={legacy_px:3} -> foreground, monochrome, square, round')

    composed = legacy(mark, 512).convert('RGB')
    composed.save(PROJECT / 'assets/branding/spectre_icon_512.png', optimize=True)
    print(f'wrote {written} resource files plus assets/branding/spectre_icon_512.png')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
