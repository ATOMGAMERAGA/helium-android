#!/usr/bin/env python3
# Copyright 2026 The Helium Authors
# You can use, redistribute, and/or modify this source code under
# the terms of the GPL-3.0 license that can be found in the LICENSE file.

"""Generates Helium-branded Android launcher icon PNGs.

All bitmaps are rendered from the official Helium logo geometry
(helium-chromium/resources/branding/product_logo.svg): a rounded
square (#3450D1, corner radius 67/256) with the white Helium star
(#FBFCFF). Rendering is done with supersampling, so no external SVG
rasterizer is needed.

Outputs (relative to --output, default: resources/android):
  mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/app_icon.png
  mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/layered_app_icon.png
  mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/layered_app_icon_background.png

These replace the equivalent Chromium assets in
chrome/android/java/res_chromium_base/ (see resources/android_resources.txt).
"""

import argparse
import pathlib

from PIL import Image, ImageDraw

# geometry from resources/branding/product_logo.svg (256x256 viewport)
VIEWPORT = 256.0
CORNER_RADIUS = 67.0
BACKGROUND = (52, 80, 209, 255)   # #3450D1
FOREGROUND = (251, 252, 255, 255)  # #FBFCFF

# the Helium star is a single polygon (straight segments only)
STAR_POINTS = [
    (145.966, 207.813), (128.0, 221.0), (110.034, 207.813),
    (118.198, 144.891), (67.4689, 183.379), (47.0, 174.5),
    (49.4993, 152.438), (108.391, 128.0), (49.4993, 103.562),
    (47.0, 81.5), (67.4689, 72.6214), (118.198, 111.109),
    (110.034, 48.1871), (128.0, 35.0), (145.966, 48.1871),
    (137.802, 111.109), (188.531, 72.6214), (209.0, 81.5),
    (206.501, 103.562), (147.609, 128.0), (206.501, 152.438),
    (209.0, 174.5), (188.531, 183.379), (137.802, 144.891),
]

# vertical extent of the star in viewport units (y: 35..221)
STAR_HEIGHT = 186.0

DENSITIES = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
}

SUPERSAMPLE = 8


def _draw_star(draw, cx, cy, scale):
    """Draws the star polygon centered at (cx, cy).

    scale converts viewport units to pixels; the star's own center
    in viewport coordinates is (128, 128).
    """
    pts = [(cx + (x - 128.0) * scale, cy + (y - 128.0) * scale)
           for x, y in STAR_POINTS]
    draw.polygon(pts, fill=FOREGROUND)


def _render(size, painter):
    ss = size * SUPERSAMPLE
    img = Image.new('RGBA', (ss, ss), (0, 0, 0, 0))
    painter(ImageDraw.Draw(img), ss)
    return img.resize((size, size), Image.LANCZOS)


def full_logo(size):
    """The complete logo: rounded square + star (edge to edge)."""
    def painter(draw, ss):
        radius = CORNER_RADIUS / VIEWPORT * ss
        draw.rounded_rectangle((0, 0, ss - 1, ss - 1), radius=radius,
                               fill=BACKGROUND)
        _draw_star(draw, ss / 2.0, ss / 2.0, ss / VIEWPORT)
    return _render(size, painter)


def adaptive_background(size):
    """Full-bleed adaptive icon layer; the launcher applies the mask.

    Chromium keeps the artwork in the *background* layer and ships a
    transparent foreground, so we do the same. The star is kept within
    the 66/108 safe zone (star height = 44% of the canvas).
    """
    def painter(draw, ss):
        draw.rectangle((0, 0, ss, ss), fill=BACKGROUND)
        _draw_star(draw, ss / 2.0, ss / 2.0, (0.44 * ss) / STAR_HEIGHT)
    return _render(size, painter).convert('RGB')


def legacy_layered(size, content_ratio=52.0 / 108.0):
    """Pre-adaptive launcher icon: logo drawn inside a transparent canvas.

    Chromium's equivalent asset keeps its content within 52/108 of the
    canvas, so the same inset is used here.
    """
    def painter(draw, ss):
        content = content_ratio * ss
        off = (ss - content) / 2.0
        radius = CORNER_RADIUS / VIEWPORT * content
        draw.rounded_rectangle((off, off, off + content - 1,
                                off + content - 1),
                               radius=radius, fill=BACKGROUND)
        _draw_star(draw, ss / 2.0, ss / 2.0, content / VIEWPORT)
    return _render(size, painter)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', default='resources/android',
                        type=pathlib.Path)
    args = parser.parse_args()

    for density, mult in DENSITIES.items():
        out = args.output / f'mipmap-{density}'
        out.mkdir(parents=True, exist_ok=True)

        app_icon = int(48 * mult)
        layered = int(108 * mult)

        full_logo(app_icon).save(out / 'app_icon.png', optimize=True)
        legacy_layered(layered).save(out / 'layered_app_icon.png',
                                     optimize=True)
        adaptive_background(layered).save(
            out / 'layered_app_icon_background.png', optimize=True)

        print(f'{density}: app_icon={app_icon}px, layered={layered}px')


if __name__ == '__main__':
    main()
