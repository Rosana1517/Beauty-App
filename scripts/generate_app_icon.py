"""Generates the 1024x1024 master App Icon PNG for 美麗日記.

Uses the same palette as AppTheme in the SwiftUI app (warm rose primary,
cream background) so the icon matches the in-app look. Run with:
    python scripts/generate_app_icon.py
Output: iOS_Project/美麗日記/Assets.xcassets/AppIcon.appiconset/icon-1024.png
"""

import math
import os

from PIL import Image, ImageDraw

SIZE = 1024

# AppTheme colors (Constants/AppConstants.swift), 0-1 floats -> 0-255 ints.
# Icon uses the primary rose as a full-bleed background (not the pale
# cream) so it stays legible and bold at home-screen sizes - HIG wants
# icons to fill the canvas with minimal empty margin and good contrast.
PRIMARY = (201, 140, 122)             # Color(0.79, 0.55, 0.48)
BACKGROUND_TOP = (214, 158, 140)      # lighter rose, top of gradient
BACKGROUND_BOTTOM = (181, 113, 96)    # deeper rose, bottom of gradient
TEXT = (79, 59, 51)                   # Color(0.31, 0.23, 0.20)
WHITE = (255, 255, 255)
CREAM = (250, 245, 240)               # Color(0.98, 0.96, 0.94)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vertical_gradient(size, top, bottom):
    img = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        draw.line([(0, y), (size, y)], fill=lerp(top, bottom, t))
    return img


def draw_open_book(draw, cx, cy, scale):
    """A simple open-book / diary glyph, the app's core metaphor. Drawn in
    cream against the rose background for strong, legible contrast at
    small home-screen sizes."""
    half_w = 340 * scale
    height = 260 * scale
    spine_x = cx

    # Left page
    left_page = [
        (spine_x, cy - height * 0.55),
        (spine_x - half_w, cy - height * 0.30),
        (spine_x - half_w, cy + height * 0.55),
        (spine_x, cy + height * 0.30),
    ]
    # Right page
    right_page = [
        (spine_x, cy - height * 0.55),
        (spine_x + half_w, cy - height * 0.30),
        (spine_x + half_w, cy + height * 0.55),
        (spine_x, cy + height * 0.30),
    ]

    draw.polygon(left_page, fill=CREAM)
    draw.polygon(right_page, fill=CREAM)

    # A soft shadow line down the spine.
    draw.line(
        [(spine_x, cy - height * 0.55), (spine_x, cy + height * 0.30)],
        fill=lerp(PRIMARY, TEXT, 0.4),
        width=int(9 * scale),
    )

    # A few "text" lines on each page for a diary feel.
    line_color = lerp(PRIMARY, CREAM, 0.25)
    for i in range(3):
        y = cy - height * 0.05 + i * height * 0.18
        draw.line(
            [(spine_x - half_w * 0.78, y - i * height * 0.02),
             (spine_x - half_w * 0.20, y - i * height * 0.05)],
            fill=line_color, width=int(15 * scale)
        )
        draw.line(
            [(spine_x + half_w * 0.20, y - i * height * 0.05),
             (spine_x + half_w * 0.78, y - i * height * 0.02)],
            fill=line_color, width=int(15 * scale)
        )


def draw_heart(draw, cx, cy, r, color):
    points = []
    for t_deg in range(0, 360, 2):
        t = math.radians(t_deg)
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        points.append((cx + x * r / 16, cy - y * r / 16))
    draw.polygon(points, fill=color)


def main():
    img = vertical_gradient(SIZE, BACKGROUND_TOP, BACKGROUND_BOTTOM)
    draw = ImageDraw.Draw(img)

    cx, cy = SIZE / 2, SIZE / 2 + 60
    draw_open_book(draw, cx, cy, scale=SIZE / 1024)

    # Heart sparkle above the book spine, the "beauty diary" accent.
    draw_heart(draw, cx, cy - 320, r=110, color=CREAM)

    out_dir = os.path.join(
        os.path.dirname(__file__), "..", "iOS_Project", "美麗日記",
        "Assets.xcassets", "AppIcon.appiconset",
    )
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "icon-1024.png")
    img.save(out_path, "PNG")
    print(f"Wrote {out_path} ({img.size[0]}x{img.size[1]})")


if __name__ == "__main__":
    main()
