"""Generates the 1024x1024 master App Icon PNG for 美麗日記.

Uses the same palette as AppTheme in the SwiftUI app (warm rose primary,
cream background) so the icon matches the in-app look. Run with:
    python scripts/generate_app_icon.py
Output: iOS_Project/美麗日記/Assets.xcassets/AppIcon.appiconset/icon-1024.png
"""

import json
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


def render_master(size):
    img = vertical_gradient(size, BACKGROUND_TOP, BACKGROUND_BOTTOM)
    draw = ImageDraw.Draw(img)

    scale = size / 1024
    cx, cy = size / 2, size / 2 + 60 * scale
    draw_open_book(draw, cx, cy, scale=scale)

    # Heart sparkle above the book spine, the "beauty diary" accent.
    draw_heart(draw, cx, cy - 320 * scale, r=110 * scale, color=CREAM)
    return img


# The classic full icon set (every idiom/size/scale Xcode has required since
# before the Xcode 14 "single size" shortcut). The single-1024-only
# appiconset that shipped initially produced an Assets.car missing most of
# these - AltServer/installd rejected the sideloaded .ipa with "Could not
# install" as a result. Explicitly rendering and listing every size here
# works unconditionally for direct installs (ad-hoc/sideload), not just
# App Store Connect-processed builds.
ICON_SPECS = [
    # (filename, idiom, size_pt, scale, role-only-for-readability)
    ("icon-20@2x.png", "iphone", 20, 2),
    ("icon-20@3x.png", "iphone", 20, 3),
    ("icon-29@2x.png", "iphone", 29, 2),
    ("icon-29@3x.png", "iphone", 29, 3),
    ("icon-40@2x.png", "iphone", 40, 2),
    ("icon-40@3x.png", "iphone", 40, 3),
    ("icon-60@2x.png", "iphone", 60, 2),
    ("icon-60@3x.png", "iphone", 60, 3),
    ("icon-20-ipad@1x.png", "ipad", 20, 1),
    ("icon-20-ipad@2x.png", "ipad", 20, 2),
    ("icon-29-ipad@1x.png", "ipad", 29, 1),
    ("icon-29-ipad@2x.png", "ipad", 29, 2),
    ("icon-40-ipad@1x.png", "ipad", 40, 1),
    ("icon-40-ipad@2x.png", "ipad", 40, 2),
    ("icon-76-ipad@1x.png", "ipad", 76, 1),
    ("icon-76-ipad@2x.png", "ipad", 76, 2),
    ("icon-83.5-ipad@2x.png", "ipad", 83.5, 2),
    ("icon-1024.png", "ios-marketing", 1024, 1),
]


def main():
    out_dir = os.path.join(
        os.path.dirname(__file__), "..", "iOS_Project", "美麗日記",
        "Assets.xcassets", "AppIcon.appiconset",
    )
    os.makedirs(out_dir, exist_ok=True)

    contents_images = []
    for filename, idiom, point_size, scale in ICON_SPECS:
        pixel_size = round(point_size * scale)
        img = render_master(pixel_size)
        img.save(os.path.join(out_dir, filename), "PNG")
        print(f"Wrote {filename} ({pixel_size}x{pixel_size}, idiom={idiom})")

        size_str = f"{point_size:g}x{point_size:g}"
        entry = {
            "filename": filename,
            "idiom": idiom,
            "size": size_str,
        }
        if idiom != "ios-marketing":
            entry["scale"] = f"{scale}x"
        contents_images.append(entry)

    contents = {
        "images": contents_images,
        "info": {"author": "xcode", "version": 1},
    }
    contents_path = os.path.join(out_dir, "Contents.json")
    with open(contents_path, "w", encoding="utf-8") as f:
        json.dump(contents, f, indent=2)
        f.write("\n")
    print(f"Wrote {contents_path}")


if __name__ == "__main__":
    main()
