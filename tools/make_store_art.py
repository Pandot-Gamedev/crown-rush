"""Draws the Roblox store art for Crown Rush into store/:
game icon, thumbnails, the VIP pass icon and developer product icons.

Usage: python3 tools/make_store_art.py
"""

import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "store")
FONT_BOLD = "/usr/share/fonts/opentype/inter/InterDisplay-ExtraBold.otf"
FONT_SEMI = "/usr/share/fonts/opentype/inter/Inter-SemiBold.otf"

GOLD = (255, 200, 40)
NAVY = (20, 32, 52)
SKY_TOP, SKY_BOTTOM = (90, 170, 255), (190, 230, 255)
FOAM_RED, FOAM_YELLOW = (235, 60, 60), (255, 210, 60)
# The five Adventure worlds (floor colour, accent), as in src/shared/Worlds.luau
WORLDS = {
    "candy": ("CANDY CLOUDS", (255, 170, 210), (255, 105, 170)),
    "jungle": ("JUNGLE RUINS", (120, 160, 90), (250, 200, 80)),
    "frost": ("FROST PEAK", (175, 220, 250), (110, 170, 220)),
    "lava": ("LAVA FACTORY", (95, 95, 105), (255, 150, 40)),
    "space": ("STAR STATION", (70, 60, 120), (90, 255, 230)),
}
SHIRTS = [(230, 60, 60), (60, 140, 255), (90, 200, 90), (255, 170, 40), (200, 90, 255), (40, 200, 200)]


def font(path, size):
    return ImageFont.truetype(path, size)


def gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", size, top)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (w, y)], fill=color)
    return img


def shade(color, amount):
    return tuple(max(0, min(255, c + amount)) for c in color[:3])


def star(d, x, y, r, color, points=4, inner=0.35, outline=None, width=0):
    pts = []
    for i in range(points * 2):
        rr = r if i % 2 == 0 else r * inner
        a = math.pi / points * i - math.pi / 2
        pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
    d.polygon(pts, fill=color, outline=outline, width=width)


def paste_center(base, layer, cx, cy):
    base.alpha_composite(layer, (int(cx - layer.width / 2), int(cy - layer.height / 2)))


def outlined_text(draw, xy, text, fnt, fill, outline=(30, 20, 40), width=6, anchor="mm"):
    draw.text(xy, text, font=fnt, fill=fill, anchor=anchor, stroke_width=width, stroke_fill=outline)


def layer(size):
    return Image.new("RGBA", (int(size), int(size)), (0, 0, 0, 0))


def cloud(d, x, y, r, color=(255, 255, 255)):
    for dx, dy, rr in ((-1.1, 0.15, 0.75), (0, 0, 1), (1.1, 0.15, 0.75), (0.5, -0.45, 0.7), (-0.5, -0.35, 0.6)):
        cx, cy, rad = x + dx * r, y + dy * r, rr * r
        d.ellipse([cx - rad, cy - rad * 0.8, cx + rad, cy + rad * 0.8], fill=color)


def hammer(size, head=FOAM_RED, handle=FOAM_YELLOW, shape="hammer", angle=-35, sparkle=False):
    """A hammer seen from the side, head at the top, leaning by angle degrees."""
    img = layer(size)
    d = ImageDraw.Draw(img)
    s = size
    w = max(3, int(s * 0.018))
    # handle
    d.rounded_rectangle([s * 0.46, s * 0.36, s * 0.54, s * 0.95], radius=int(s * 0.03), fill=handle, outline=shade(handle, -90), width=w)
    d.rectangle([s * 0.48, s * 0.4, s * 0.5, s * 0.9], fill=shade(handle, 50))
    if shape == "chicken":
        body = head
        d.ellipse([s * 0.22, s * 0.1, s * 0.78, s * 0.42], fill=body, outline=shade(body, -100), width=w)
        d.ellipse([s * 0.62, s * 0.02, s * 0.86, s * 0.24], fill=body, outline=shade(body, -100), width=w)
        d.polygon([(s * 0.85, s * 0.12), (s * 0.97, s * 0.15), (s * 0.85, s * 0.18)], fill=handle, outline=shade(handle, -90))
        d.polygon([(s * 0.68, s * 0.02), (s * 0.72, -s * 0.02), (s * 0.76, s * 0.02), (s * 0.8, -s * 0.01), (s * 0.8, s * 0.05)], fill=(230, 40, 40))
        d.ellipse([s * 0.73, s * 0.08, s * 0.78, s * 0.13], fill=(20, 20, 20))
        d.arc([s * 0.3, s * 0.18, s * 0.6, s * 0.36], 20, 160, fill=shade(body, -60), width=w)
    elif shape == "fish":
        d.ellipse([s * 0.12, s * 0.12, s * 0.74, s * 0.4], fill=head, outline=shade(head, -100), width=w)
        d.polygon([(s * 0.7, s * 0.26), (s * 0.94, s * 0.1), (s * 0.94, s * 0.42)], fill=handle, outline=shade(handle, -90), width=w)
        d.ellipse([s * 0.2, s * 0.2, s * 0.27, s * 0.27], fill=(255, 255, 255))
        d.ellipse([s * 0.22, s * 0.22, s * 0.26, s * 0.26], fill=(20, 20, 20))
        for i in range(3):
            x = s * (0.36 + i * 0.1)
            d.arc([x, s * 0.18, x + s * 0.1, s * 0.34], 300, 60, fill=shade(head, -50), width=w)
    else:
        long = shape == "mallet"
        top, bottom = (0.12, 0.38) if not long else (0.16, 0.36)
        left, right = (0.16, 0.84) if not long else (0.2, 0.8)
        # barrel-shaped head with rounded ends
        d.rounded_rectangle([s * left, s * top, s * right, s * bottom], radius=int(s * 0.07), fill=head, outline=shade(head, -100), width=w)
        for x in (left, right):
            d.ellipse([s * (x - 0.05), s * top, s * (x + 0.05), s * bottom], fill=shade(head, -30), outline=shade(head, -100), width=w)
        d.rounded_rectangle([s * (left + 0.07), s * (top + 0.03), s * (right - 0.07), s * (top + 0.08)], radius=int(s * 0.02), fill=shade(head, 70))
        if not long:
            for x in (left + 0.12, right - 0.12):
                d.rectangle([s * (x - 0.02), s * top, s * (x + 0.02), s * bottom], fill=handle)
    if sparkle:
        for _ in range(7):
            star(d, random.uniform(s * 0.1, s * 0.9), random.uniform(s * 0.05, s * 0.6), s * 0.045, (255, 250, 210))
    return img.rotate(angle, resample=Image.BICUBIC, expand=True)


def brawler(size, shirt=(60, 140, 255), pants=(40, 50, 90), pose="stand", face="happy"):
    """A blocky avatar. pose: stand, swing (arm up), fly (arms and legs out), cheer."""
    img = layer(size)
    d = ImageDraw.Draw(img)
    s = size
    u = s / 7
    cx, ground = s / 2, s * 0.94
    skin = (255, 205, 150)
    outline = (40, 30, 30)
    w = max(2, int(s * 0.01))
    if pose == "run":
        d.polygon([(cx - u * 0.45, ground - u * 2), (cx - u * 0.05, ground - u * 2), (cx - u * 0.7, ground - u * 0.1), (cx - u * 1.1, ground - u * 0.3)], fill=pants, outline=outline)
        d.polygon([(cx + u * 0.05, ground - u * 2), (cx + u * 0.45, ground - u * 2), (cx + u * 0.9, ground - u * 0.6), (cx + u * 0.6, ground - u * 0.3)], fill=pants, outline=outline)
    elif pose == "fly":
        d.polygon([(cx - u * 0.45, ground - u * 2), (cx - u * 0.05, ground - u * 2), (cx - u * 0.9, ground - u * 0.2), (cx - u * 1.3, ground - u * 0.5)], fill=pants, outline=outline)
        d.polygon([(cx + u * 0.05, ground - u * 2), (cx + u * 0.45, ground - u * 2), (cx + u * 1.3, ground - u * 0.5), (cx + u * 0.9, ground - u * 0.2)], fill=pants, outline=outline)
    else:
        d.rectangle([cx - u * 0.45, ground - u * 2, cx - u * 0.05, ground], fill=pants, outline=outline, width=w)
        d.rectangle([cx + u * 0.05, ground - u * 2, cx + u * 0.45, ground], fill=pants, outline=outline, width=w)
    d.rectangle([cx - u * 0.5, ground - u * 4, cx + u * 0.5, ground - u * 2], fill=shirt, outline=outline, width=w)
    arms = {
        "stand": ((-0.95, -4, -0.55, -2.2), (0.55, -4, 0.95, -2.2)),
        "swing": ((-0.95, -4, -0.55, -2.2), (0.55, -5.6, 0.95, -3.8)),
        "fly": ((-0.95, -5.6, -0.55, -3.8), (0.55, -5.6, 0.95, -3.8)),
        "cheer": ((-0.95, -5.8, -0.55, -4), (0.55, -5.8, 0.95, -4)),
        "run": ((-1.1, -4.2, -0.7, -2.6), (0.6, -4.6, 1.0, -3.0)),
    }[pose]
    for x0, y0, x1, y1 in arms:
        d.rectangle([cx + u * x0, ground + u * y0, cx + u * x1, ground + u * y1], fill=skin, outline=outline, width=w)
    d.rounded_rectangle([cx - u * 0.5, ground - u * 5.05, cx + u * 0.5, ground - u * 4.05], radius=int(u * 0.18), fill=skin, outline=outline, width=w)
    ey = ground - u * 4.7
    if face == "dizzy":
        for ex in (-0.2, 0.2):
            x = cx + u * ex
            d.line([x - u * 0.08, ey - u * 0.08, x + u * 0.08, ey + u * 0.08], fill=outline, width=w * 2)
            d.line([x - u * 0.08, ey + u * 0.08, x + u * 0.08, ey - u * 0.08], fill=outline, width=w * 2)
        d.ellipse([cx - u * 0.1, ey + u * 0.2, cx + u * 0.1, ey + u * 0.42], fill=outline)
    else:
        for ex in (-0.2, 0.2):
            x = cx + u * ex
            d.ellipse([x - u * 0.06, ey - u * 0.08, x + u * 0.06, ey + u * 0.08], fill=outline)
        d.arc([cx - u * 0.22, ey + u * 0.02, cx + u * 0.22, ey + u * 0.38], 20, 160, fill=outline, width=w * 2)
    return img


def burst(size, color=(255, 230, 60), text="BONK!", text_color=(230, 50, 50)):
    """A comic-book impact burst with a word."""
    img = layer(size)
    d = ImageDraw.Draw(img)
    s = size
    pts = []
    for i in range(24):
        r = s * (0.48 if i % 2 == 0 else 0.32) * random.uniform(0.92, 1.05)
        a = math.pi * 2 / 24 * i
        pts.append((s / 2 + math.cos(a) * r, s / 2 + math.sin(a) * r * 0.8))
    d.polygon(pts, fill=color, outline=(40, 20, 10), width=max(3, int(s * 0.02)))
    if text:
        outlined_text(d, (s / 2, s / 2), text, font(FONT_BOLD, int(s * 0.2)), text_color, outline=(255, 255, 255), width=max(2, int(s * 0.015)))
    return img


def island(d, cx, top, rx, color, depth=None):
    """A floating arena: a flat top with a rocky underside."""
    depth = depth or rx * 0.7
    d.polygon([(cx - rx, top), (cx + rx, top), (cx + rx * 0.6, top + depth * 0.55), (cx + rx * 0.2, top + depth), (cx - rx * 0.25, top + depth * 0.8), (cx - rx * 0.7, top + depth * 0.45)], fill=(120, 95, 80))
    d.polygon([(cx - rx, top), (cx - rx * 0.7, top + depth * 0.45), (cx - rx * 0.3, top + depth * 0.3)], fill=(95, 75, 65))
    d.ellipse([cx - rx, top - rx * 0.16, cx + rx, top + rx * 0.16], fill=color, outline=shade(color, -60), width=4)
    d.ellipse([cx - rx * 0.8, top - rx * 0.11, cx + rx * 0.8, top + rx * 0.09], outline=shade(color, 40), width=3)


def motion_lines(d, x, y, length, angle, color=(255, 255, 255), count=3, spacing=26, width=10):
    a = math.radians(angle)
    nx, ny = -math.sin(a), math.cos(a)
    for i in range(count):
        off = (i - (count - 1) / 2) * spacing
        sx, sy = x + nx * off, y + ny * off
        d.line([sx, sy, sx - math.cos(a) * length, sy - math.sin(a) * length], fill=color, width=width)


def save(img, name, size=None):
    os.makedirs(os.path.dirname(os.path.join(OUT, name)), exist_ok=True)
    if size:
        img = img.resize(size, Image.LANCZOS)
    img.convert("RGB").save(os.path.join(OUT, name), quality=95)
    print("wrote store/" + name)


def badge(bg_top, bg_bottom, draw_fn, label):
    """512x512 square icon with a rounded tile, a picture and a label."""
    s = 1024
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    tile = gradient((s, s), bg_top, bg_bottom).convert("RGBA")
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s, s], radius=180, fill=255)
    img.paste(tile, (0, 0), mask)
    d = ImageDraw.Draw(img)
    draw_fn(img, d, s)
    if label:
        d = ImageDraw.Draw(img)
        size = 120 if len(label) <= 9 else 92
        outlined_text(d, (s / 2, s * 0.86), label, font(FONT_BOLD, size), (255, 255, 255), outline=(20, 20, 30), width=10)
    return img


def hammer_icon(head, handle, shape="hammer"):
    def draw(img, d, s):
        paste_center(img, hammer(s * 0.74, head=head, handle=handle, shape=shape, angle=-35, sparkle=True), s / 2, s * 0.42)
    return draw


def confetti(img, d, s):
    colors = [(255, 70, 70), (255, 220, 50), (70, 200, 255), (120, 255, 120), (220, 100, 255)]
    d.polygon([(s * 0.2, s * 0.72), (s * 0.36, s * 0.42), (s * 0.5, s * 0.56)], fill=(255, 120, 180), outline=(120, 30, 70), width=10)
    for i in range(60):
        a = random.uniform(-math.pi * 0.95, -math.pi * 0.05)
        r = random.uniform(s * 0.1, s * 0.42)
        x, y = s * 0.42 + math.cos(a) * r, s * 0.5 + math.sin(a) * r * 0.9
        size = random.uniform(14, 30)
        color = random.choice(colors)
        if i % 3 == 0:
            d.ellipse([x - size / 2, y - size / 2, x + size / 2, y + size / 2], fill=color)
        else:
            rot = random.uniform(0, math.pi)
            pts = [(x + math.cos(rot + k * math.pi / 2) * size * (0.8 if k % 2 else 0.35), y + math.sin(rot + k * math.pi / 2) * size * (0.8 if k % 2 else 0.35)) for k in range(4)]
            d.polygon(pts, fill=color)


def cartoon_star(img, d, s):
    star(d, s / 2, s * 0.42, s * 0.32, (255, 230, 40), points=5, inner=0.45, outline=(170, 100, 0), width=14)
    d.ellipse([s * 0.42, s * 0.36, s * 0.46, s * 0.42], fill=(40, 30, 20))
    d.ellipse([s * 0.54, s * 0.36, s * 0.58, s * 0.42], fill=(40, 30, 20))
    d.arc([s * 0.43, s * 0.4, s * 0.57, s * 0.5], 20, 160, fill=(40, 30, 20), width=10)
    for i in range(3):
        star(d, s * (0.16 + i * 0.34), s * (0.16 + (i % 2) * 0.5), s * 0.05, (255, 250, 200))


def fireworks(img, d, s):
    for cx, cy, r, color in ((0.36, 0.36, 0.22, (255, 90, 60)), (0.66, 0.3, 0.17, (80, 160, 255)), (0.62, 0.6, 0.14, (255, 240, 120))):
        x, y, rr = s * cx, s * cy, s * r
        for k in range(14):
            a = math.pi * 2 / 14 * k
            d.line([x + math.cos(a) * rr * 0.25, y + math.sin(a) * rr * 0.25, x + math.cos(a) * rr, y + math.sin(a) * rr], fill=color, width=14)
            d.ellipse([x + math.cos(a) * rr - 10, y + math.sin(a) * rr - 10, x + math.cos(a) * rr + 10, y + math.sin(a) * rr + 10], fill=shade(color, 60))
    d.line([s * 0.36, s * 0.75, s * 0.36, s * 0.58], fill=(255, 220, 160), width=8)


def lightning(img, d, s):
    cloud(d, s * 0.5, s * 0.2, s * 0.13, color=(90, 100, 130))
    bolt = [(s * 0.52, s * 0.24), (s * 0.36, s * 0.52), (s * 0.48, s * 0.52), (s * 0.4, s * 0.76), (s * 0.66, s * 0.44), (s * 0.53, s * 0.44), (s * 0.62, s * 0.24)]
    d.polygon(bolt, fill=(255, 255, 255), outline=(140, 220, 255), width=16)
    for i in range(6):
        a = math.pi * 2 / 6 * i
        d.line([s * 0.4 + math.cos(a) * s * 0.08, s * 0.76 + math.sin(a) * s * 0.04, s * 0.4 + math.cos(a) * s * 0.16, s * 0.76 + math.sin(a) * s * 0.08], fill=(140, 220, 255), width=10)


def title_icon(text, color):
    def draw(img, d, s):
        d.rounded_rectangle([s * 0.06, s * 0.3, s * 0.94, s * 0.6], radius=60, fill=NAVY, outline=color, width=16)
        size = 150 if len(text) < 10 else 116
        outlined_text(d, (s / 2, s * 0.45), text, font(FONT_BOLD, size), color, outline=(10, 15, 25), width=6)
    return draw



def big_crown(size, jewels=True):
    """A shiny golden crown on its own layer."""
    img = layer(size)
    d = ImageDraw.Draw(img)
    s = size
    w = max(3, int(s * 0.03))
    base_top, base_bottom = s * 0.62, s * 0.82
    pts = [(s * 0.12, base_top), (s * 0.08, s * 0.22), (s * 0.32, s * 0.45), (s * 0.5, s * 0.12), (s * 0.68, s * 0.45), (s * 0.92, s * 0.22), (s * 0.88, base_top)]
    d.polygon(pts, fill=GOLD, outline=(150, 100, 0), width=w)
    d.rounded_rectangle([s * 0.1, base_top, s * 0.9, base_bottom], radius=int(s * 0.04), fill=(235, 170, 20), outline=(150, 100, 0), width=w)
    for x, y in ((0.08, 0.22), (0.5, 0.12), (0.92, 0.22)):
        r = s * 0.06
        d.ellipse([s * x - r, s * y - r, s * x + r, s * y + r], fill=(255, 235, 140), outline=(150, 100, 0), width=w)
    if jewels:
        for x, color in ((0.3, (60, 140, 255)), (0.5, (230, 40, 90)), (0.7, (70, 200, 110))):
            r = s * 0.055
            cy = (base_top + base_bottom) / 2
            d.ellipse([s * x - r, cy - r, s * x + r, cy + r], fill=color, outline=shade(color, -80), width=max(2, w // 2))
    d.polygon([(s * 0.2, s * 0.5), (s * 0.27, s * 0.34), (s * 0.3, s * 0.52)], fill=(255, 240, 170))
    return img


def platform(d, x0, x1, top, color, depth=26):
    """A floating course block, seen from the side."""
    d.rectangle([x0, top, x1, top + depth], fill=shade(color, -40), outline=shade(color, -90), width=3)
    d.rectangle([x0, top - depth * 0.35, x1, top], fill=color, outline=shade(color, -70), width=3)


def trail_icon(colors):
    """A runner zooming past with a coloured trail."""
    def draw(img, d, s):
        # A tapering streak behind the runner, one band per colour
        n = len(colors)
        bands = max(n, 3)
        wide, narrow = s * 0.34, s * 0.14
        for i in range(bands):
            color = colors[i % n]
            y0 = s * 0.42 - wide / 2 + wide * i / bands
            y1 = s * 0.42 - narrow / 2 + narrow * i / bands
            d.polygon([(s * 0.04, y0), (s * 0.55, y1), (s * 0.55, y1 + narrow / bands), (s * 0.04, y0 + wide / bands)], fill=color)
        for _ in range(10):
            star(d, random.uniform(s * 0.08, s * 0.5), random.uniform(s * 0.2, s * 0.62), s * 0.025, (255, 255, 240))
        paste_center(img, brawler(s * 0.48, shirt=(60, 140, 255), pose="run"), s * 0.66, s * 0.42)
    return draw


FONT_POSTER = os.path.join(ROOT, "tools", "fonts", "LuckiestGuy-Regular.ttf")
SKIN = (255, 205, 150)
INK = (35, 20, 30)
LAVA_TOP, LAVA_BOTTOM = (255, 170, 40), (220, 40, 20)


def sticker(img, width, color=(255, 255, 255)):
    """Puts a solid rim around everything drawn on img, like a cut-out sticker."""
    pad = int(width * 2) + 4
    big = Image.new("RGBA", (img.width + pad * 2, img.height + pad * 2), (0, 0, 0, 0))
    big.alpha_composite(img, (pad, pad))
    alpha = big.getchannel("A").point(lambda a: 255 if a > 60 else 0)
    grown = alpha.filter(ImageFilter.GaussianBlur(width * 0.6)).point(lambda a: 255 if a > 6 else 0)
    grown = grown.filter(ImageFilter.GaussianBlur(1.5))
    rim = Image.new("RGBA", big.size, color + (255,))
    rim.putalpha(grown)
    rim.alpha_composite(big)
    return rim


def glow(img, cx, cy, r, color, strength=220):
    """A soft round light centred on (cx, cy)."""
    size = int(r * 3)
    g = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(g).ellipse([size / 2 - r, size / 2 - r, size / 2 + r, size / 2 + r], fill=color + (strength,))
    g = g.filter(ImageFilter.GaussianBlur(r * 0.35))
    paste_center(img, g, cx, cy)


def sunburst(size, cx, cy, base, ray, count=20, edge=None):
    """Rays spreading from (cx, cy), darker towards the corners."""
    w, h = size
    img = Image.new("RGBA", size, base + (255,))
    d = ImageDraw.Draw(img)
    big = max(w, h) * 2
    for i in range(count):
        a0 = math.pi * 2 / count * i
        a1 = a0 + math.pi / count
        d.polygon([(cx, cy), (cx + math.cos(a0) * big, cy + math.sin(a0) * big), (cx + math.cos(a1) * big, cy + math.sin(a1) * big)], fill=ray)
    if edge:
        # vignette: fade to the edge colour away from the centre
        v = Image.new("L", size, 0)
        vd = ImageDraw.Draw(v)
        r = max(w, h) * 0.75
        vd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
        v = v.filter(ImageFilter.GaussianBlur(max(w, h) * 0.18))
        dark = Image.new("RGBA", size, edge + (255,))
        dark.paste(img, (0, 0), v)
        img = dark
    return img


def headline(text, size, top, bottom, stroke=INK, depth=None, angle=0, rim=(255, 255, 255)):
    """Big poster lettering: gradient fill, dark outline, a 3D drop and a white rim."""
    fnt = font(FONT_POSTER, size)
    sw = max(4, int(size * 0.08))
    depth = int(size * 0.09) if depth is None else depth
    box = fnt.getbbox(text, stroke_width=sw)
    w, h = box[2] - box[0] + sw * 4, box[3] - box[1] + sw * 4 + depth
    lay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    x, y = sw * 2 - box[0], sw * 2 - box[1]
    for k in range(depth, 0, -2):
        d.text((x, y + k), text, font=fnt, fill=shade(stroke, 0), stroke_width=sw, stroke_fill=stroke)
    d.text((x, y), text, font=fnt, fill=stroke, stroke_width=sw, stroke_fill=stroke)
    mask = Image.new("L", lay.size, 0)
    ImageDraw.Draw(mask).text((x, y), text, font=fnt, fill=255)
    fill = gradient((w, h), top, bottom).convert("RGBA")
    lay.paste(fill, (0, 0), mask)
    # a shine across the top half of the letters
    shine = Image.new("L", lay.size, 0)
    ImageDraw.Draw(shine).rectangle([0, 0, w, y + (box[3] - box[1]) * 0.42], fill=70)
    shine = ImageChops.multiply(shine, mask)
    lay.paste(Image.new("RGBA", lay.size, (255, 255, 255, 255)), (0, 0), shine)
    if rim:
        lay = sticker(lay, max(3, size * 0.035), rim)
    if angle:
        lay = lay.rotate(angle, resample=Image.BICUBIC, expand=True)
    return lay


def face(size, shirt=(60, 140, 255), mood="shock", look=(0, -0.3), hands=True):
    """A big close-up of a blocky avatar. mood: shock (mouth open, hands on cheeks) or smug."""
    s = size
    img = layer(s)
    d = ImageDraw.Draw(img)
    w = max(3, int(s * 0.014))
    # shoulders and neck
    d.rounded_rectangle([s * 0.04, s * 0.7, s * 0.96, s * 1.2], radius=int(s * 0.08), fill=shirt, outline=INK, width=w)
    d.rectangle([s * 0.36, s * 0.66, s * 0.64, s * 0.74], fill=shade(SKIN, -30), outline=INK, width=w)
    d.polygon([(s * 0.38, s * 0.72), (s * 0.5, s * 0.82), (s * 0.62, s * 0.72)], fill=shade(shirt, -45))
    # head with a little shading on the right
    d.rounded_rectangle([s * 0.16, s * 0.06, s * 0.84, s * 0.68], radius=int(s * 0.12), fill=SKIN, outline=INK, width=w)
    d.rounded_rectangle([s * 0.7, s * 0.12, s * 0.8, s * 0.62], radius=int(s * 0.05), fill=shade(SKIN, -18))
    d.ellipse([s * 0.24, s * 0.1, s * 0.42, s * 0.2], fill=shade(SKIN, 30))
    ey = s * 0.31
    lx, ly = look
    for ex in (0.37, 0.63):
        x = s * ex
        if mood == "shock":
            rx, ry = s * 0.085, s * 0.105
            d.ellipse([x - rx, ey - ry, x + rx, ey + ry], fill=(255, 255, 255), outline=INK, width=w)
            pr = s * 0.035
            px, py = x + lx * rx * 0.45, ey + ly * ry * 0.45
            d.ellipse([px - pr, py - pr, px + pr, py + pr], fill=INK)
            d.ellipse([px - pr * 0.2, py - pr * 0.75, px + pr * 0.35, py - pr * 0.2], fill=(255, 255, 255))
            # eyebrows shot up
            side = -1 if ex < 0.5 else 1
            bx = x + side * s * 0.01
            d.line([(bx - s * 0.075, s * 0.17 + (s * 0.012 if side < 0 else -s * 0.012) * 0), (bx, s * 0.14), (bx + s * 0.075, s * 0.17)], fill=INK, width=int(s * 0.032), joint="curve")
        else:
            rx, ry = s * 0.08, s * 0.07
            d.ellipse([x - rx, ey - ry, x + rx, ey + ry], fill=(255, 255, 255), outline=INK, width=w)
            pr = s * 0.032
            px, py = x + lx * rx * 0.4, ey + ry * 0.2
            d.ellipse([px - pr, py - pr, px + pr, py + pr], fill=INK)
            # heavy lids and eyebrows angled down to the middle: up to something
            d.chord([x - rx - w, ey - ry - w, x + rx + w, ey + ry * 0.6], 180, 360, fill=SKIN, outline=INK, width=w)
            inner = 1 if ex < 0.5 else -1
            d.line([(x - inner * s * 0.08, s * 0.17), (x + inner * s * 0.06, s * 0.21)], fill=INK, width=int(s * 0.034))
    if mood == "shock":
        # a big open mouth with teeth and tongue
        mx, my, rx, ry = s * 0.5, s * 0.53, s * 0.09, s * 0.1
        d.ellipse([mx - rx, my - ry, mx + rx, my + ry], fill=(90, 20, 35), outline=INK, width=w)
        d.chord([mx - rx * 0.75, my + ry * 0.1, mx + rx * 0.75, my + ry * 0.95], 0, 180, fill=(240, 90, 110))
        d.chord([mx - rx * 0.8, my - ry * 0.98, mx + rx * 0.8, my - ry * 0.2], 180, 360, fill=(255, 255, 255))
        # sweat drops
        for sx, sy, r in ((0.86, 0.16, 0.035), (0.92, 0.3, 0.025), (0.12, 0.2, 0.028)):
            x, y, rr = s * sx, s * sy, s * r
            d.polygon([(x, y - rr * 2.2), (x - rr, y), (x + rr, y)], fill=(120, 210, 255))
            d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(120, 210, 255), outline=(40, 120, 200), width=max(2, w // 2))
        if hands:
            for hx in (0.1, 0.9):
                x = s * hx
                d.rounded_rectangle([x - s * 0.075, s * 0.38, x + s * 0.075, s * 0.68], radius=int(s * 0.04), fill=SKIN, outline=INK, width=w)
                for k in range(3):
                    fy = s * (0.44 + k * 0.06)
                    d.line([(x - s * 0.06, fy), (x + s * 0.06, fy)], fill=shade(SKIN, -45), width=max(2, w // 2))
    else:
        # a sly grin
        d.chord([s * 0.33, s * 0.4, s * 0.7, s * 0.6], 0, 180, fill=(90, 20, 35), outline=INK, width=w)
        d.rectangle([s * 0.36, s * 0.5, s * 0.67, s * 0.535], fill=(255, 255, 255))
        d.line([(s * 0.3, s * 0.48), (s * 0.34, s * 0.5)], fill=INK, width=w)
    return img


def curved_arrow(img, p0, p1, p2, width, color=(240, 30, 40)):
    """A fat red arrow along a curve from p0 to p2 (p1 bends it), with a white rim."""
    pad = width * 3
    xs, ys = [p[0] for p in (p0, p1, p2)], [p[1] for p in (p0, p1, p2)]
    ox, oy = min(xs) - pad, min(ys) - pad
    lay = Image.new("RGBA", (int(max(xs) - ox + pad), int(max(ys) - oy + pad)), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)

    def at(t):
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        return x - ox, y - oy

    head = width * 1.4
    pts = [at(i / 40) for i in range(41)]
    # stop the shaft where the head starts
    end = len(pts) - 1
    while end > 1 and math.dist(pts[end], pts[-1]) < head * 0.9:
        end -= 1
    left, right = [], []
    for i in range(end + 1):
        a, b = pts[max(0, i - 1)], pts[min(end, i + 1)]
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        half = width * (0.3 + 0.2 * i / end)
        nx, ny = -math.sin(ang) * half, math.cos(ang) * half
        left.append((pts[i][0] + nx, pts[i][1] + ny))
        right.append((pts[i][0] - nx, pts[i][1] - ny))
    d.polygon(left + right[::-1], fill=color)
    tip, base = pts[-1], pts[end]
    ang = math.atan2(tip[1] - base[1], tip[0] - base[0])
    nx, ny = -math.sin(ang) * width, math.cos(ang) * width
    d.polygon([(base[0] + nx, base[1] + ny), tip, (base[0] - nx, base[1] - ny)], fill=color)
    lay = sticker(lay, width * 0.16)
    off = (lay.width - (int(max(xs) - ox + pad))) / 2
    img.alpha_composite(lay, (int(ox - off), int(oy - off)))


def ring(d, box, width, color=(240, 30, 40)):
    """A hand-drawn style warning circle."""
    x0, y0, x1, y1 = box
    d.ellipse([x0 - width * 0.3, y0 - width * 0.3, x1 + width * 0.3, y1 + width * 0.3], outline=(255, 255, 255), width=int(width * 1.6))
    d.ellipse(box, outline=color, width=int(width))


def lava(img, top, glow_up=True):
    """Bubbling lava across the bottom of img from y = top."""
    w, h = img.size
    sea = gradient((w, int(h - top) + 1), LAVA_TOP, LAVA_BOTTOM).convert("RGBA")
    mask = Image.new("L", sea.size, 0)
    md = ImageDraw.Draw(mask)
    wave = [(0, sea.height)]
    for i in range(0, 41):
        x = w * i / 40
        wave.append((x, h * 0.012 * (1 + math.sin(i * 1.3))))
    wave.append((w, sea.height))
    md.polygon(wave, fill=255)
    if glow_up:
        g = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(g).rectangle([0, top - h * 0.04, w, h], fill=(255, 120, 30, 170))
        img.alpha_composite(g.filter(ImageFilter.GaussianBlur(h * 0.05)))
    img.paste(sea, (0, int(top)), mask)
    d = ImageDraw.Draw(img)
    for _ in range(int(w / 90)):
        x = random.uniform(0, w)
        y = random.uniform(top + h * 0.03, h)
        r = random.uniform(h * 0.006, h * 0.02)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 230, 120), outline=(255, 120, 40), width=max(2, int(r * 0.25)))


def pop(fig, rim=None):
    """A figure with a white sticker rim so it stands out."""
    return sticker(fig, rim or max(4, fig.width * 0.025))


def runner(size, shirt, pose="run", mood="happy", angle=0, flip=False):
    fig = brawler(size, shirt=shirt, pose=pose, face=mood)
    if flip:
        fig = fig.transpose(Image.FLIP_LEFT_RIGHT)
    if angle:
        fig = fig.rotate(angle, resample=Image.BICUBIC, expand=True)
    return pop(fig)


def sparkles(d, cx, cy, r, count, color=(255, 255, 230), size=0.06):
    for i in range(count):
        a = random.uniform(0, math.pi * 2)
        rr = random.uniform(r * 0.6, r * 1.15)
        star(d, cx + math.cos(a) * rr, cy + math.sin(a) * rr, r * size * random.uniform(0.7, 1.4), color, points=4, inner=0.3)


def glowing_crown(img, cx, cy, size, tilt=0, halo=True):
    if halo:
        glow(img, cx, cy, size * 0.75, (255, 240, 140), 255)
    crown = big_crown(size)
    if tilt:
        crown = crown.rotate(tilt, resample=Image.BICUBIC, expand=True)
    paste_center(img, sticker(crown, size * 0.02, (255, 250, 210)), cx, cy)
    sparkles(ImageDraw.Draw(img), cx, cy, size * 0.62, 9, size=0.1)


def pill(img, cx, cy, text, size, fill=(235, 30, 45), color=(255, 255, 255), angle=0):
    """A bold label on a rounded tag."""
    fnt = font(FONT_POSTER, size)
    box = fnt.getbbox(text)
    tw, th = box[2] - box[0], box[3] - box[1]
    pw, ph = tw + size * 1.0, th + size * 0.7
    lay = Image.new("RGBA", (int(pw), int(ph)), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    d.rounded_rectangle([0, 0, pw - 1, ph - 1], radius=int(ph * 0.3), fill=fill, outline=INK, width=max(3, int(size * 0.07)))
    d.text((pw / 2 - box[0] - tw / 2, ph / 2 - box[1] - th / 2), text, font=fnt, fill=color, stroke_width=max(2, int(size * 0.05)), stroke_fill=INK)
    lay = sticker(lay, size * 0.08)
    if angle:
        lay = lay.rotate(angle, resample=Image.BICUBIC, expand=True)
    paste_center(img, lay, cx, cy)


def tiles(img, x0, x1, y0, y1, rows, cols, colors, holes=(), falling=(), cracked=()):
    """A floor of blocks seen from the front and a bit above. Returns the tile centres."""
    d = ImageDraw.Draw(img)
    centres = {}
    for r in range(rows):
        t0, t1 = r / rows, (r + 1) / rows
        # rows further back are narrower (perspective)
        def edge(t):
            k = 0.78 + 0.22 * t
            mid = (x0 + x1) / 2
            return mid - (x1 - x0) / 2 * k, mid + (x1 - x0) / 2 * k

        ya, yb = y0 + (y1 - y0) * t0, y0 + (y1 - y0) * t1
        la, ra = edge(t0)
        lb, rb = edge(t1)
        thick = (yb - ya) * 0.35
        for c in range(cols):
            if (r, c) in holes:
                continue
            ca, cb = c / cols, (c + 1) / cols
            gap = (rb - lb) / cols * 0.04
            top = [(la + (ra - la) * ca + gap, ya), (la + (ra - la) * cb - gap, ya), (lb + (rb - lb) * cb - gap, yb - gap), (lb + (rb - lb) * ca + gap, yb - gap)]
            color = colors[(r + c) % len(colors)]
            drop = 0
            if (r, c) in falling:
                drop = (yb - ya) * 1.2
                top = [(x + (yb - ya) * 0.15 * (1 if i in (1, 2) else -1) * 0.5, y + drop + (i % 2) * (yb - ya) * 0.25) for i, (x, y) in enumerate(top)]
            front = [top[3], top[2], (top[2][0], top[2][1] + thick), (top[3][0], top[3][1] + thick)]
            d.polygon(front, fill=shade(color, -70), outline=INK, width=max(2, int(thick * 0.08)))
            d.polygon(top, fill=color, outline=INK, width=max(2, int(thick * 0.08)))
            cx = sum(p[0] for p in top) / 4
            cy = sum(p[1] for p in top) / 4
            centres[(r, c)] = (cx, cy, top[2][0] - top[3][0], yb - ya)
            if (r, c) in cracked:
                tw = top[2][0] - top[3][0]
                zz = [(cx - tw * 0.35, cy - (yb - ya) * 0.1), (cx - tw * 0.1, cy + (yb - ya) * 0.15), (cx + tw * 0.05, cy - (yb - ya) * 0.15), (cx + tw * 0.3, cy + (yb - ya) * 0.12)]
                d.line(zz, fill=INK, width=max(3, int(thick * 0.18)), joint="curve")
    return centres


def thumb_crown(size):
    """WIN THE CROWN: the crown on a high block, rivals bonked and falling into lava."""
    w, h = size
    img = sunburst(size, w * 0.66, h * 0.42, (255, 150, 40), (255, 190, 70), count=22, edge=(150, 30, 60))
    lava(img, h * 0.86)
    glow(img, w * 0.665, h * 0.43, h * 0.38 * 0.75, (255, 240, 140), 255)
    d = ImageDraw.Draw(img)
    # the winner's block and two lower blocks
    platform(d, w * 0.53, w * 0.8, h * 0.66, (255, 215, 80), depth=h * 0.08)
    platform(d, w * 0.83, w * 1.02, h * 0.79, (255, 120, 190), depth=h * 0.07)
    platform(d, w * 0.33, w * 0.48, h * 0.79, (120, 220, 255), depth=h * 0.07)
    glowing_crown(img, w * 0.665, h * 0.43, h * 0.38, tilt=6, halo=False)
    # a runner leaping for it, a rival bonked away, two dropping into the lava
    paste_center(img, runner(h * 0.34, SHIRTS[2], "cheer", angle=-22), w * 0.5, h * 0.52)
    paste_center(img, runner(h * 0.26, SHIRTS[4], "fly", "dizzy", angle=35), w * 0.92, h * 0.36)
    paste_center(img, pop(hammer(h * 0.3, angle=-60)), w * 0.79, h * 0.6)
    paste_center(img, burst(h * 0.22, text="BONK!"), w * 0.88, h * 0.47)
    paste_center(img, runner(h * 0.2, SHIRTS[3], "fly", "dizzy", angle=160), w * 0.42, h * 0.9)
    paste_center(img, runner(h * 0.18, SHIRTS[5], "fly", "dizzy", angle=-150), w * 0.74, h * 0.93)
    d = ImageDraw.Draw(img)
    motion_lines(d, w * 0.4, h * 0.7, w * 0.07, 215, color=(255, 255, 255), count=3, spacing=h * 0.03, width=int(h * 0.01))
    # the big shocked face in the corner
    paste_center(img, sticker(face(h * 0.62, shirt=SHIRTS[1], look=(0.9, -0.5)), h * 0.015), w * 0.17, h * 0.72)
    curved_arrow(img, (w * 0.36, h * 0.3), (w * 0.5, h * 0.14), (w * 0.57, h * 0.33), h * 0.05)
    paste_center(img, headline("WIN THE CROWN!", int(h * 0.16), (255, 245, 120), (255, 170, 20), angle=3), w * 0.5, h * 0.12)
    pill(img, w * 0.87, h * 0.9, "12 PLAYERS, 1 WINNER", int(h * 0.045), angle=-4)
    return img


def thumb_survive(size):
    """DON'T FALL: the floor drops away into lava under the players."""
    w, h = size
    img = gradient(size, (70, 20, 90), (200, 60, 50)).convert("RGBA")
    glow(img, w * 0.5, h * 0.95, h * 0.8, (255, 120, 40), 200)
    lava(img, h * 0.78)
    d = ImageDraw.Draw(img)
    for _ in range(40):
        x, y = random.uniform(0, w), random.uniform(0, h * 0.5)
        r = random.uniform(2, h * 0.004)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 210, 160))
    holes = {(0, 1), (1, 4), (2, 2), (3, 0), (3, 5), (1, 0)}
    falling = {(2, 4), (3, 2)}
    centres = tiles(img, w * 0.24, w * 0.98, h * 0.42, h * 0.8, 4, 6, [(130, 230, 255), (255, 140, 200), (255, 225, 90), (150, 255, 170)], holes=holes, falling=falling, cracked={(2, 3), (1, 2)})
    # players hopping between the tiles that are left
    for (r, c), shirt, pose in (((0, 4), SHIRTS[0], "run"), ((1, 1), SHIRTS[2], "cheer"), ((2, 3), SHIRTS[3], "run"), ((1, 5), SHIRTS[5], "stand")):
        cx, cy, tw, th = centres[(r, c)]
        fig = runner(th * 2.6, shirt, pose, flip=c > 3)
        img.alpha_composite(fig, (int(cx - fig.width / 2), int(cy - fig.height * 0.92)))
    cx, cy, tw, th = centres[(3, 2)]
    paste_center(img, runner(th * 2.4, SHIRTS[4], "fly", "dizzy", angle=25), cx, cy + th * 1.2)
    cx, cy, tw, th = centres[(2, 3)]
    ring(ImageDraw.Draw(img), [cx - tw * 0.85, cy - th * 2.8, cx + tw * 0.85, cy + th * 0.9], h * 0.014)
    paste_center(img, sticker(face(h * 0.62, shirt=SHIRTS[0], look=(0.8, 0.6)), h * 0.015), w * 0.15, h * 0.68)
    curved_arrow(img, (w * 0.33, h * 0.33), (w * 0.43, h * 0.24), (cx - tw * 0.95, cy - th * 1.6), h * 0.045)
    paste_center(img, headline("DON'T FALL!", int(h * 0.19), (255, 250, 150), (255, 80, 40), angle=-3), w * 0.62, h * 0.15)
    pill(img, w * 0.84, h * 0.9, "LAST ONE STANDING", int(h * 0.045), angle=3)
    return img


def thumb_bonk(size):
    """BONK THEM OFF: a giant foam hammer launches a rival off the arena."""
    w, h = size
    img = sunburst(size, w * 0.62, h * 0.5, (70, 160, 255), (110, 195, 255), count=24, edge=(25, 40, 120))
    d = ImageDraw.Draw(img)
    for cx, cy, r in ((0.08, 0.86, 0.07), (0.95, 0.88, 0.06), (0.5, 0.97, 0.06)):
        cloud(d, w * cx, h * cy, h * r)
    island(d, w * 0.55, h * 0.66, w * 0.3, (255, 220, 90), depth=h * 0.32)
    # rivals on the arena and one flying off
    paste_center(img, runner(h * 0.26, SHIRTS[2], "run", flip=True), w * 0.66, h * 0.55)
    flyer = runner(h * 0.34, SHIRTS[4], "fly", "dizzy", angle=-40)
    paste_center(img, flyer, w * 0.86, h * 0.3)
    d = ImageDraw.Draw(img)
    motion_lines(d, w * 0.8, h * 0.36, w * 0.12, -25, count=4, spacing=h * 0.035, width=int(h * 0.011))
    for k in range(5):
        star(d, w * (0.9 + 0.05 * math.cos(k * 1.25)), h * (0.15 + 0.03 * math.sin(k * 1.25)), h * 0.025, (255, 240, 80), points=5, inner=0.45, outline=INK, width=3)
    paste_center(img, burst(h * 0.34, text="BONK!"), w * 0.7, h * 0.36)
    # the smug hammer swinger up front
    big_hammer = pop(hammer(h * 0.7, angle=-50, sparkle=True), h * 0.012)
    paste_center(img, big_hammer, w * 0.3, h * 0.48)
    paste_center(img, sticker(face(h * 0.6, shirt=SHIRTS[0], mood="smug", look=(0.8, 0)), h * 0.015), w * 0.15, h * 0.72)
    paste_center(img, headline("BONK THEM OFF!", int(h * 0.16), (255, 245, 120), (255, 150, 20), angle=2), w * 0.5, h * 0.12)
    pill(img, w * 0.84, h * 0.9, "FOAM HAMMERS!", int(h * 0.045), fill=(255, 140, 20), angle=-3)
    return img


def thumb_obbies(size):
    """30 CRAZY OBBIES: a leap across lava past all five worlds, three stars to win."""
    w, h = size
    img = Image.new("RGBA", size, (0, 0, 0, 255))
    d = ImageDraw.Draw(img)
    # five slanted stripes, one per world
    keys = ("candy", "jungle", "frost", "lava", "space")
    skies = {"candy": (255, 170, 215), "jungle": (120, 200, 120), "frost": (170, 215, 255), "lava": (255, 120, 50), "space": (110, 80, 200)}
    slant = w * 0.12
    for i, key in enumerate(keys):
        xa, xb = w * i / 5 - slant, w * (i + 1) / 5 + slant * 0.0
        d.polygon([(xa, h), (xb, h), (xb + slant, 0), (xa + slant, 0)], fill=skies[key])
        d.line([(xb, h), (xb + slant, 0)], fill=(255, 255, 255), width=int(h * 0.008))
    glow(img, w * 0.5, h * 0.45, h * 0.55, (255, 255, 230), 120)
    lava(img, h * 0.86)
    d = ImageDraw.Draw(img)
    # stepping stones across the worlds, one per world colour
    stones = [(0.05, 0.2, 0.72), (0.27, 0.38, 0.62), (0.46, 0.56, 0.7), (0.64, 0.74, 0.58), (0.82, 0.98, 0.66)]
    for (x0, x1, top), key in zip(stones, keys):
        platform(d, w * x0, w * x1, h * top, WORLDS[key][2], depth=h * 0.06)
    # gems over the gaps
    for gx, gy in ((0.235, 0.5), (0.42, 0.45), (0.6, 0.48), (0.78, 0.44)):
        x, y, r = w * gx, h * gy, h * 0.035
        d.polygon([(x, y - r * 1.3), (x + r, y), (x, y + r * 1.3), (x - r, y)], fill=(80, 235, 255), outline=INK, width=4)
        d.polygon([(x, y - r * 1.3), (x + r * 0.35, y), (x, y + r * 0.3), (x - r * 0.35, y)], fill=(210, 250, 255))
    paste_center(img, runner(h * 0.32, SHIRTS[0], "cheer", angle=-20), w * 0.53, h * 0.47)
    paste_center(img, runner(h * 0.24, SHIRTS[1], "run"), w * 0.33, h * 0.52)
    d = ImageDraw.Draw(img)
    d.arc([w * 0.36, h * 0.36, w * 0.72, h * 0.9], 200, 300, fill=(255, 255, 255), width=int(h * 0.01))
    # three big stars to earn
    for k, (sx, sy, r) in enumerate(((0.73, 0.3, 0.07), (0.83, 0.24, 0.09), (0.93, 0.3, 0.07))):
        glow(img, w * sx, h * sy, h * r * 1.3, (255, 250, 210), 170)
        d = ImageDraw.Draw(img)
        star(d, w * sx, h * sy, h * r, (255, 220, 40), points=5, inner=0.45, outline=INK, width=int(h * 0.008))
    paste_center(img, sticker(face(h * 0.5, shirt=SHIRTS[3], look=(0.9, -0.6), hands=False), h * 0.014), w * 0.12, h * 0.8)
    paste_center(img, headline("30 CRAZY OBBIES!", int(h * 0.15), (255, 250, 150), (255, 170, 20), angle=-2), w * 0.42, h * 0.13)
    pill(img, w * 0.83, h * 0.55, "GET ALL 3 STARS?", int(h * 0.045), fill=(130, 60, 230), angle=3)
    return img


def clickbait_icon(s):
    """The square game icon: a shocked runner and a giant glowing crown."""
    img = sunburst((s, s), s * 0.5, s * 0.3, (255, 140, 30), (255, 190, 60), count=16, edge=(170, 30, 70))
    glowing_crown(img, s * 0.5, s * 0.27, s * 0.5, tilt=-8)
    paste_center(img, sticker(face(s * 0.8, shirt=SHIRTS[1], look=(0, -0.95)), s * 0.018), s * 0.5, s * 0.72)
    paste_center(img, headline("CROWN RUSH", int(s * 0.115), (255, 250, 150), (255, 170, 20), angle=0), s * 0.5, s * 0.92)
    return img


def main():
    random.seed(7)

    # The uploaded icon and thumbnails are Rk's AI-generated versions in store/;
    # these drawn ones go to store/drawn/ for comparison.
    save(clickbait_icon(1536), "drawn/game_icon_512.png", (512, 512))
    for k, draw in enumerate((thumb_crown, thumb_survive, thumb_bonk, thumb_obbies), 1):
        random.seed(k)
        save(draw((3840, 2160)), "drawn/thumbnail_%d_1920x1080.png" % k, (1920, 1080))

    random.seed(7)
    def vip(img, d, s):
        paste_center(img, big_crown(s * 0.62), s / 2, s * 0.42)

    save(badge((255, 210, 80), (200, 120, 20), vip, "VIP"), "pass_vip.png", (512, 512))

    trail_bg = ((80, 160, 255), (30, 50, 130))
    cel_bg = ((120, 90, 230), (40, 25, 100))
    hammers_bg = ((235, 90, 90), (120, 30, 40))
    title_bg = ((90, 110, 160), (30, 36, 60))
    products = [
        ("product_trail_rainbow.png", trail_bg, trail_icon([(255, 0, 0), (255, 255, 0), (0, 255, 0), (0, 120, 255), (200, 0, 255)]), "RAINBOW"),
        ("product_trail_fire.png", trail_bg, trail_icon([(255, 220, 0), (255, 120, 0), (255, 40, 0)]), "FIRE"),
        ("product_trail_stars.png", trail_bg, trail_icon([(255, 255, 200), (180, 140, 255), (90, 70, 200)]), "STAR DUST"),
        ("product_trail_bubblepop.png", trail_bg, trail_icon([(255, 150, 220), (255, 210, 240)]), "BUBBLEGUM"),
        ("product_trail_lightning.png", trail_bg, trail_icon([(140, 220, 255), (255, 255, 255)]), "LIGHTNING"),
        ("product_cel_confetti.png", cel_bg, confetti, "CONFETTI"),
        ("product_cel_star.png", cel_bg, cartoon_star, "STAR"),
        ("product_cel_fireworks.png", cel_bg, fireworks, "FIREWORKS"),
        ("product_cel_lightning.png", cel_bg, lightning, "LIGHTNING"),
        ("product_hammer_golden.png", hammers_bg, hammer_icon((255, 190, 30), (255, 230, 120)), "GOLDEN"),
        ("product_hammer_neon.png", hammers_bg, hammer_icon((255, 60, 200), (60, 255, 230)), "NEON"),
        ("product_hammer_chicken.png", hammers_bg, hammer_icon((255, 225, 60), (255, 150, 40), "chicken"), "CHICKEN"),
        ("product_hammer_fish.png", hammers_bg, hammer_icon((80, 170, 220), (240, 120, 60), "fish"), "BIG FISH"),
        ("product_title_obbymaster.png", title_bg, title_icon("Obby Master", (120, 200, 255)), "TITLE"),
        ("product_title_speeddemon.png", title_bg, title_icon("Speed Demon", (255, 90, 90)), "TITLE"),
        ("product_title_royalty.png", title_bg, title_icon("Crown Royalty", (255, 200, 60)), "TITLE"),
    ]
    for name, (top, bottom), fn, label in products:
        save(badge(top, bottom, fn, label), name, (512, 512))


if __name__ == "__main__":
    main()
