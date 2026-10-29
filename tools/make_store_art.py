"""Draws the Roblox store art for Crown Rush into store/:
game icon, thumbnails, the VIP pass icon and developer product icons.

Usage: python3 tools/make_store_art.py
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFont

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
    os.makedirs(OUT, exist_ok=True)
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


def scene(size, title=True, tagline=None):
    """A sky obstacle course: runners race up past a spinner to a giant crown."""
    w, h = size
    img = gradient(size, SKY_TOP, SKY_BOTTOM).convert("RGBA")
    d = ImageDraw.Draw(img)
    for cx, cy, r in ((0.12, 0.7, 0.06), (0.88, 0.78, 0.07), (0.3, 0.93, 0.05), (0.66, 0.95, 0.06), (0.55, 0.25, 0.04)):
        cloud(d, w * cx, h * cy, h * r)
    pink, mint, lilac = WORLDS["candy"][1], (130, 230, 190), (180, 150, 255)
    # A staircase of blocks rising left to right, the crown on the top one
    steps = [(0.02, 0.24, 0.82, pink), (0.27, 0.42, 0.7, mint), (0.45, 0.6, 0.58, lilac), (0.63, 0.78, 0.47, pink), (0.8, 0.98, 0.36, (255, 220, 90))]
    for x0, x1, top, color in steps:
        platform(d, w * x0, w * x1, h * top, color, depth=h * 0.05)
    # a spinner bar on the middle block
    cx, top = w * 0.525, h * 0.58
    d.rectangle([cx - 8, top - h * 0.12, cx + 8, top - h * 0.02], fill=(90, 90, 110))
    d.rounded_rectangle([cx - w * 0.1, top - h * 0.14, cx + w * 0.1, top - h * 0.11], radius=8, fill=(255, 70, 90), outline=(120, 20, 40), width=4)
    d.arc([cx - w * 0.12, top - h * 0.2, cx + w * 0.12, top - h * 0.05], 200, 250, fill=(255, 255, 255), width=8)
    # the crown, glowing
    gx, gy = w * 0.89, h * 0.36 - h * 0.13
    for r, a in ((h * 0.2, 35), (h * 0.15, 55)):
        glow = layer(r * 2)
        ImageDraw.Draw(glow).ellipse([0, 0, r * 2, r * 2], fill=(255, 240, 150, a))
        paste_center(img, glow, gx, gy)
    paste_center(img, big_crown(h * 0.26), gx, gy)
    # runners: one leaping for the crown, one on each step, one bounced off by the spinner
    paste_center(img, brawler(h * 0.3, shirt=SHIRTS[0], pose="cheer").rotate(-15, resample=Image.BICUBIC, expand=True), w * 0.75, h * 0.29)
    paste_center(img, brawler(h * 0.24, shirt=SHIRTS[1], pose="run"), w * 0.68, h * 0.38)
    paste_center(img, brawler(h * 0.24, shirt=SHIRTS[2], pose="run"), w * 0.36, h * 0.6)
    paste_center(img, brawler(h * 0.24, shirt=SHIRTS[3], pose="run"), w * 0.13, h * 0.72)
    paste_center(img, brawler(h * 0.22, shirt=SHIRTS[4], pose="fly", face="dizzy").rotate(30, resample=Image.BICUBIC, expand=True), w * 0.46, h * 0.31)
    d = ImageDraw.Draw(img)
    motion_lines(d, w * 0.63, h * 0.39, w * 0.07, 0, count=3, spacing=h * 0.025, width=max(4, int(h * 0.007)))
    motion_lines(d, w * 0.31, h * 0.61, w * 0.06, 0, count=3, spacing=h * 0.025, width=max(4, int(h * 0.007)))
    if title:
        outlined_text(d, (w * 0.4, h * 0.13), "CROWN RUSH", font(FONT_BOLD, int(h * 0.14)), (255, 215, 60), outline=(110, 30, 90), width=max(4, int(h * 0.012)))
    if tagline:
        d.rounded_rectangle([w * 0.08, h * 0.86, w * 0.92, h * 0.95], radius=int(h * 0.03), fill=(20, 20, 40, 200))
        outlined_text(d, (w * 0.5, h * 0.905), tagline, font(FONT_SEMI, int(h * 0.04)), (255, 255, 255), width=max(2, int(h * 0.004)))
    return img


def icon_art(s):
    """The square game icon: a runner leaping for a giant crown."""
    img = gradient((s, s), (255, 140, 200), (255, 210, 120)).convert("RGBA")
    d = ImageDraw.Draw(img)
    for i in range(18):
        a0 = math.pi * 2 / 18 * i
        a1 = a0 + math.pi / 18
        cx, cy, r = s * 0.62, s * 0.5, s * 1.2
        d.polygon([(cx, cy), (cx + math.cos(a0) * r, cy + math.sin(a0) * r), (cx + math.cos(a1) * r, cy + math.sin(a1) * r)], fill=(255, 175, 200))
    cloud(d, s * 0.14, s * 0.92, s * 0.09)
    cloud(d, s * 0.9, s * 0.9, s * 0.08)
    platform(d, s * 0.5, s * 1.02, s * 0.74, (255, 220, 90), depth=s * 0.08)
    platform(d, -s * 0.02, s * 0.36, s * 0.9, (150, 110, 255), depth=s * 0.08)
    paste_center(img, big_crown(s * 0.46), s * 0.72, s * 0.52)
    paste_center(img, brawler(s * 0.5, shirt=(60, 140, 255), pose="cheer").rotate(-25, resample=Image.BICUBIC, expand=True), s * 0.33, s * 0.6)
    d = ImageDraw.Draw(img)
    motion_lines(d, s * 0.16, s * 0.72, s * 0.14, 215, count=3, spacing=s * 0.035, width=12)
    outlined_text(d, (s * 0.5, s * 0.11), "CROWN", font(FONT_BOLD, int(s * 0.19)), (255, 225, 70), outline=(110, 30, 90), width=14)
    outlined_text(d, (s * 0.5, s * 0.26), "RUSH", font(FONT_BOLD, int(s * 0.16)), (255, 255, 255), outline=(110, 30, 90), width=12)
    return img


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


def card_scene(kind, size):
    """A small picture for each kind of tournament round."""
    w, h = size
    sky = gradient(size, SKY_TOP, SKY_BOTTOM).convert("RGBA")
    d = ImageDraw.Draw(sky)
    if kind == "RACE":
        platform(d, 10, w - 10, h * 0.72, (255, 170, 210), depth=40)
        d.rectangle([w * 0.82, h * 0.3, w * 0.86, h * 0.72], fill=(60, 60, 70))
        for k in range(4):
            d.rectangle([w * 0.86, h * (0.3 + k * 0.05), w * 0.96, h * (0.35 + k * 0.05)], fill=(255, 255, 255) if k % 2 == 0 else (30, 30, 30))
        for i, x in enumerate((0.22, 0.45, 0.66)):
            paste_center(sky, brawler(h * 0.42, shirt=SHIRTS[i], pose="run"), w * x, h * 0.53)
    elif kind == "SURVIVAL":
        d.rectangle([0, h * 0.78, w, h], fill=(255, 110, 30))
        for k in range(5):
            d.polygon([(k * w / 4.0 - 30, h * 0.78), (k * w / 4.0, h * 0.7), (k * w / 4.0 + 30, h * 0.78)], fill=(255, 170, 60))
        for k, (x, top) in enumerate(((0.2, 0.62), (0.5, 0.48), (0.8, 0.34))):
            platform(d, w * (x - 0.12), w * (x + 0.12), h * top, (175, 220, 250), depth=24)
        paste_center(sky, brawler(h * 0.34, shirt=SHIRTS[3], pose="cheer"), w * 0.8, h * 0.2)
        paste_center(sky, brawler(h * 0.3, shirt=SHIRTS[1], pose="run"), w * 0.5, h * 0.36)
    elif kind == "FIGHT":
        island(d, w / 2, h * 0.7, w * 0.42, (255, 220, 90), depth=h * 0.25)
        paste_center(sky, brawler(h * 0.42, shirt=SHIRTS[0], pose="swing"), w * 0.36, h * 0.5)
        paste_center(sky, hammer(h * 0.36, angle=-75), w * 0.46, h * 0.38)
        paste_center(sky, brawler(h * 0.34, shirt=SHIRTS[1], pose="fly", face="dizzy").rotate(-35, resample=Image.BICUBIC, expand=True), w * 0.78, h * 0.3)
    else:  # TEAM
        island(d, w / 2, h * 0.74, w * 0.45, (130, 230, 190), depth=h * 0.22)
        d.ellipse([w * 0.38, h * 0.38, w * 0.62, h * 0.72], fill=(255, 220, 90), outline=(150, 100, 0), width=6)
        paste_center(sky, brawler(h * 0.36, shirt=(235, 70, 70), pose="run"), w * 0.24, h * 0.56)
        paste_center(sky, brawler(h * 0.36, shirt=(60, 140, 255), pose="run").transpose(Image.FLIP_LEFT_RIGHT), w * 0.78, h * 0.56)
    return sky


def cards_thumbnail(title, subtitle, cards, bg_top, bg_bottom):
    t = gradient((1920, 1080), bg_top, bg_bottom).convert("RGBA")
    d = ImageDraw.Draw(t)
    outlined_text(d, (960, 110), title, font(FONT_BOLD, 112), (255, 215, 60), outline=(110, 30, 90), width=10)
    d.text((960, 210), subtitle, font=font(FONT_SEMI, 46), fill=(235, 235, 255), anchor="mm")
    width = 1820 // len(cards)
    left = (1920 - (len(cards) * width - 40)) // 2
    for i, (head, sub, color, picture) in enumerate(cards):
        x0 = left + i * width
        d.rounded_rectangle([x0, 290, x0 + width - 40, 990], radius=36, fill=(25, 28, 55), outline=color, width=10)
        pic = picture((width - 80, 380))
        mask = Image.new("L", pic.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, pic.width, pic.height], radius=24, fill=255)
        t.paste(pic, (x0 + 20, 310), mask)
        d = ImageDraw.Draw(t)
        cx = x0 + (width - 40) / 2
        outlined_text(d, (cx, 790), head, font(FONT_BOLD, 50 if len(cards) <= 4 else 36), color, width=4)
        d.text((cx, 870), sub, font=font(FONT_SEMI, 28 if len(cards) <= 4 else 24), fill=(220, 225, 255), anchor="mm")
    return t


def world_scene(key):
    name, floor, accent = WORLDS[key]
    def picture(size):
        w, h = size
        tops = {"candy": ((150, 200, 255), (255, 215, 235)), "jungle": ((140, 200, 170), (170, 210, 160)), "frost": ((190, 220, 245), (225, 240, 255)), "lava": ((90, 50, 40), (200, 90, 40)), "space": ((20, 15, 45), (60, 40, 110))}
        img = gradient(size, *tops[key]).convert("RGBA")
        d = ImageDraw.Draw(img)
        if key == "space":
            for _ in range(40):
                x, y = random.uniform(0, w), random.uniform(0, h * 0.7)
                d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(255, 255, 255))
        if key == "candy":
            for cx, cy in ((0.25, 0.25), (0.8, 0.85)):
                cloud(d, w * cx, h * cy, h * 0.06)
        elif key == "jungle":
            for k in range(5):
                x = w * (0.1 + k * 0.2)
                d.line([x, 0, x + 10, h * random.uniform(0.15, 0.35)], fill=(60, 120, 60), width=6)
                d.ellipse([x - 4, h * 0.3 - 12, x + 22, h * 0.3 + 6], fill=(80, 160, 80))
        elif key == "frost":
            for _ in range(30):
                x, y = random.uniform(0, w), random.uniform(0, h)
                d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(255, 255, 255))
        elif key == "lava":
            d.rectangle([0, h * 0.88, w, h], fill=(255, 110, 30))
        platform(d, w * 0.02, w * 0.36, h * 0.78, floor, depth=30)
        platform(d, w * 0.64, w * 0.98, h * 0.55, floor, depth=30)
        # a gem floating over the gap, and a star
        gx, gy = w * 0.5, h * 0.42
        d.polygon([(gx, gy - 26), (gx + 20, gy), (gx, gy + 26), (gx - 20, gy)], fill=(80, 230, 255), outline=(20, 110, 150), width=4)
        star(d, w * 0.82, h * 0.2, 26, (255, 225, 60), points=5, inner=0.45, outline=(160, 100, 0), width=3)
        jumper = brawler(h * 0.34, shirt=random.choice(SHIRTS), pose="cheer").rotate(-20, resample=Image.BICUBIC, expand=True)
        paste_center(img, jumper, w * 0.3, h * 0.5)
        d = ImageDraw.Draw(img)
        d.arc([w * 0.1, h * 0.35, w * 0.9, h * 1.0], 200, 290, fill=(255, 255, 255), width=5)
        return img
    return name, picture


def main():
    random.seed(7)

    save(icon_art(1024), "game_icon_512.png", (512, 512))

    save(scene((1920, 1080), tagline="Race, survive and bonk your way to the crown  -  30 courses  -  15 rounds"), "thumbnail_1_1920x1080.png")

    save(
        cards_thumbnail(
            "TOURNAMENTS",
            "12 runners  -  4 rounds  -  1 crown",
            [
                ("RACE", "First over the line wins", (60, 170, 255), lambda size: card_scene("RACE", size)),
                ("SURVIVAL", "Stay on as the floor falls", (255, 140, 60), lambda size: card_scene("SURVIVAL", size)),
                ("FIGHT", "Bonk rivals off the ring", (230, 80, 80), lambda size: card_scene("FIGHT", size)),
                ("TEAM", "Eggs, balls and teamwork", (150, 110, 255), lambda size: card_scene("TEAM", size)),
            ],
            (40, 50, 110),
            (20, 24, 60),
        ),
        "thumbnail_2_1920x1080.png",
    )

    worlds = []
    for key in ("candy", "jungle", "frost", "lava", "space"):
        name, picture = world_scene(key)
        worlds.append((name, "6 courses", WORLDS[key][2], picture))
    save(cards_thumbnail("ADVENTURE", "30 courses in 5 worlds  -  stars, gems and ghosts", worlds, (60, 40, 110), (25, 20, 55)), "thumbnail_3_1920x1080.png")

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
