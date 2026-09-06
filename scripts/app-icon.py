"""Draws the app icon: a flat cloud with a football rising out of it, on the app's own sky.

Run from the repo root:  python3 scripts/app-icon.py
Writes the light, dark and tinted 1024px variants into the asset catalog. Everything is
drawn at 4x and downsampled, so every edge is anti-aliased; nothing is blurred.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import math

SS = 4                      # supersample factor
N = 1024 * SS
OUT = Path(__file__).resolve().parent.parent / "SundayScaries/Assets.xcassets/AppIcon.appiconset"

# Sky.swift's 13:00 palette for the day icon, 21:00 for the dark one.
DAY = ((0x5B, 0x9B, 0xDA), (0x42, 0x82, 0xC6))
NIGHT = ((0x1B, 0x21, 0x45), (0x10, 0x14, 0x2C))
CLOUD = (0xFF, 0xFF, 0xFF)
CLOUD_NIGHT = (0xE9, 0xEC, 0xF4)
LEATHER = (0x8E, 0x4A, 0x27)
LACES = (0xFF, 0xF6, 0xEC)


def s(v):
    return v * SS


def gradient(top, bottom):
    img = Image.new("RGB", (N, N))
    px = img.load()
    for y in range(N):
        t = y / (N - 1)
        c = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(N):
            px[x, y] = c
    return img


def cloud_mask():
    """Three bumps over a flat base. The base runs between the centres of the two end
    bumps and its line is tangent to both, so the outline is convex all the way round:
    a rounded slab under the bumps left a small concave notch at each end."""
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    bumps = (((364, 608), 138), ((520, 594), 150), ((684, 626), 120))
    base = 746
    for (cx, cy), r in bumps:
        assert cy + r <= base
        d.ellipse([s(cx - r), s(cy - r), s(cx + r), s(cy + r)], fill=255)
    d.rectangle([s(bumps[0][0][0]), s(bumps[0][0][1]), s(bumps[-1][0][0]), s(base)], fill=255)
    return m


def football_layer(color, laces):
    """Lens-shaped ball, laces along its axis, rotated nose-up to the right."""
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = 512, 512          # drawn upright about the canvas centre, rotated after
    half_len, half_w = 252, 115   # slimmer than a lens of equal arcs: the tips stay pointed
    # lens = intersection of two circles whose centres sit above and below the axis
    R = (half_len ** 2 + half_w ** 2) / (2 * half_w)
    off = R - half_w
    steps = 400
    upper = []
    lower = []
    for i in range(steps + 1):
        x = -half_len + 2 * half_len * i / steps
        dy = math.sqrt(max(R * R - x * x, 0))
        upper.append((s(cx + x), s(cy + off - dy)))     # arc of the circle centred below
        lower.append((s(cx + x), s(cy - off + dy)))     # arc of the circle centred above
    d.polygon(upper + lower[::-1], fill=color + (255,))
    # laces: a short seam along the axis and four ticks across it
    w = s(18)
    d.rounded_rectangle([s(cx - 92), s(cy - 9), s(cx + 92), s(cy + 9)], radius=w // 2, fill=laces + (255,))
    for i in range(4):
        x = cx - 57 + i * 38
        d.rounded_rectangle([s(x - 9), s(cy - 30), s(x + 9), s(cy + 30)], radius=w // 2, fill=laces + (255,))
    layer = layer.rotate(24, resample=Image.BICUBIC, center=(s(cx), s(cy)))
    # place: the ball sits high and a touch left so its lower third is behind the cloud
    shifted = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    shifted.paste(layer, (s(32), s(-122)))
    return shifted


def render(sky, cloud_color):
    bg = gradient(*sky).convert("RGBA")
    ball = football_layer(LEATHER, LACES)
    bg.alpha_composite(ball)
    cloud = Image.new("RGBA", (N, N), cloud_color + (255,))
    bg.paste(cloud, (0, 0), cloud_mask())
    return bg.resize((1024, 1024), Image.LANCZOS)


def render_tinted():
    """Grayscale on transparent: the system paints the tint into the luminance."""
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ball = football_layer((150, 150, 150), (255, 255, 255))
    layer.alpha_composite(ball)
    cloud = Image.new("RGBA", (N, N), (255, 255, 255, 255))
    layer.paste(cloud, (0, 0), cloud_mask())
    return layer.resize((1024, 1024), Image.LANCZOS)


if __name__ == "__main__":
    render(DAY, CLOUD).convert("RGB").save(OUT / "AppIcon.png")
    render(NIGHT, CLOUD_NIGHT).convert("RGB").save(OUT / "AppIcon-Dark.png")
    render_tinted().save(OUT / "AppIcon-Tinted.png")
    print("wrote", OUT)
