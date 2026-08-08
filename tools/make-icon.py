#!/usr/bin/env python3
"""Render sushi.at's Handoff mark as an iOS app icon.

Traced from plugin/Assets/handoff.svg upstream, not redrawn by eye: the same four
polylines, the same 45-degree rotation about the same centre, the same stroke width
and colours. sushi.at gave permission to use the artwork.

Differences from the .svg, both forced by iOS:
  * no rounded corners -- iOS masks the icon itself, and baking a radius in leaves
    a visible dark seam outside the mask,
  * no alpha -- App icons must be fully opaque.

Round caps and joins are drawn as line segments plus a disc at every vertex, which
is what stroke-linecap/linejoin="round" means geometrically. Rendered at 4x and
downsampled so the diagonals don't stair-step.
"""

import math
import sys
from PIL import Image, ImageDraw

SIZE = 1024
SS = 4                      # supersampling factor
CANVAS = 360.0              # the .svg's viewBox
BG = (0x1A, 0x1C, 0x1F)
FG = (0xF4, 0xF5, 0xF6)
STROKE = 34.0
ROTATE_DEG = 45.0
PIVOT = (180.0, 180.0)

# The four <path> elements, in order, exactly as upstream.
PATHS = [
    [(150, 20), (150, 340)],
    [(150, 20), (40, 112), (150, 112)],
    [(210, 340), (210, 20)],
    [(210, 340), (320, 248), (210, 248)],
]


def rotated(p):
    """SVG rotate() is clockwise in a y-down coordinate system."""
    a = math.radians(ROTATE_DEG)
    dx, dy = p[0] - PIVOT[0], p[1] - PIVOT[1]
    return (
        PIVOT[0] + dx * math.cos(a) - dy * math.sin(a),
        PIVOT[1] + dx * math.sin(a) + dy * math.cos(a),
    )


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "icon-1024.png"
    px = SIZE * SS
    scale = px / CANVAS
    img = Image.new("RGB", (px, px), BG)
    d = ImageDraw.Draw(img)

    w = STROKE * scale
    r = w / 2.0

    extremes = []
    for path in PATHS:
        pts = [rotated(p) for p in path]
        pts = [(x * scale, y * scale) for x, y in pts]
        for a, b in zip(pts, pts[1:]):
            d.line([a, b], fill=FG, width=int(round(w)))
        for x, y in pts:                      # round caps and joins
            d.ellipse([x - r, y - r, x + r, y + r], fill=FG)
            extremes += [(x - r, y - r), (x + r, y + r)]

    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.save(out)

    xs = [p[0] / SS for p in extremes]
    ys = [p[1] / SS for p in extremes]
    print(f"wrote {out}  {SIZE}x{SIZE}  mode={img.mode}")
    print(f"glyph bounds: x {min(xs):.0f}..{max(xs):.0f}  y {min(ys):.0f}..{max(ys):.0f}"
          f"  (margin {min(min(xs), min(ys)):.0f}px = {100*min(min(xs), min(ys))/SIZE:.1f}%)")


if __name__ == "__main__":
    main()
