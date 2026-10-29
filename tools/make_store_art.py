"""Draws the Roblox store art for Bonk Arena into store/:
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
ARENAS = {
    "ice": (150, 220, 255),
    "spin": (255, 170, 60),
    "lava": (255, 90, 40),
    "bounce": (255, 110, 200),
}


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
    if pose == "fly":
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


def scene(size, title=True, tagline=None):
    """A floating arena in the sky: one brawler bonks another off the edge."""
    w, h = size
    img = gradient(size, SKY_TOP, SKY_BOTTOM).convert("RGBA")
    d = ImageDraw.Draw(img)
    d.ellipse([w * 0.83, h * 0.05, w * 0.83 + h * 0.15, h * 0.2], fill=(255, 240, 150))
    for cx, cy, r in ((0.1, 0.62, 0.06), (0.9, 0.7, 0.07), (0.22, 0.9, 0.05), (0.7, 0.93, 0.06)):
        cloud(d, w * cx, h * cy, h * r)
    # far arenas
    island(d, w * 0.1, h * 0.46, w * 0.07, ARENAS["ice"])
    island(d, w * 0.92, h * 0.66, w * 0.055, ARENAS["bounce"])
    # main arena
    top = h * 0.72
    island(d, w * 0.47, top, w * 0.3, ARENAS["spin"], depth=h * 0.26)
    d = ImageDraw.Draw(img)
    for i in range(8):
        a = math.pi * 2 / 8 * i
        d.line([w * 0.47, top, w * 0.47 + math.cos(a) * w * 0.27, top + math.sin(a) * w * 0.04], fill=shade(ARENAS["spin"], -25), width=4)
    # the hitter and the flying victim
    paste_center(img, brawler(h * 0.4, shirt=(230, 60, 60), pose="swing"), w * 0.38, top - h * 0.19)
    paste_center(img, hammer(h * 0.36, angle=-75), w * 0.47, top - h * 0.3)
    paste_center(img, brawler(h * 0.32, shirt=(60, 140, 255), pose="fly", face="dizzy").rotate(-35, resample=Image.BICUBIC, expand=True), w * 0.78, top - h * 0.31)
    d = ImageDraw.Draw(img)
    motion_lines(d, w * 0.7, top - h * 0.24, w * 0.08, 200, count=3, spacing=h * 0.03, width=max(4, int(h * 0.008)))
    paste_center(img, burst(h * 0.26), w * 0.59, top - h * 0.28)
    d = ImageDraw.Draw(img)
    outlined_text(d, (w * 0.89, top - h * 0.48), "142%", font(FONT_BOLD, int(h * 0.075)), (255, 70, 50), outline=(255, 255, 255), width=max(3, int(h * 0.006)))
    # a third brawler waiting their turn
    paste_center(img, brawler(h * 0.26, shirt=(90, 200, 90), pose="cheer"), w * 0.22, top - h * 0.12)
    d = ImageDraw.Draw(img)
    if title:
        outlined_text(d, (w * 0.5, h * 0.12), "BONK ARENA", font(FONT_BOLD, int(h * 0.13)), (255, 215, 60), outline=(120, 20, 20), width=max(4, int(h * 0.012)))
    if tagline:
        d.rounded_rectangle([w * 0.08, h * 0.86, w * 0.92, h * 0.95], radius=int(h * 0.03), fill=(20, 20, 40, 200))
        outlined_text(d, (w * 0.5, h * 0.905), tagline, font(FONT_SEMI, int(h * 0.045)), (255, 255, 255), width=max(2, int(h * 0.004)))
    return img


def icon_art(s):
    """The square game icon: a giant foam hammer bonking a flying brawler."""
    img = gradient((s, s), (80, 160, 255), (180, 225, 255)).convert("RGBA")
    d = ImageDraw.Draw(img)
    # rays behind the action
    for i in range(16):
        a0 = math.pi * 2 / 16 * i
        a1 = a0 + math.pi / 16
        cx, cy, r = s * 0.55, s * 0.55, s
        d.polygon([(cx, cy), (cx + math.cos(a0) * r, cy + math.sin(a0) * r), (cx + math.cos(a1) * r, cy + math.sin(a1) * r)], fill=(120, 190, 255))
    cloud(d, s * 0.15, s * 0.9, s * 0.08)
    cloud(d, s * 0.88, s * 0.82, s * 0.07)
    island(d, s * 0.45, s * 0.83, s * 0.36, ARENAS["spin"], depth=s * 0.25)
    paste_center(img, burst(s * 0.4, text=None), s * 0.6, s * 0.5)
    paste_center(img, brawler(s * 0.46, shirt=(60, 140, 255), pose="fly", face="dizzy").rotate(-30, resample=Image.BICUBIC, expand=True), s * 0.77, s * 0.52)
    paste_center(img, hammer(s * 0.6, angle=-50), s * 0.36, s * 0.6)
    d = ImageDraw.Draw(img)
    outlined_text(d, (s * 0.5, s * 0.12), "BONK", font(FONT_BOLD, int(s * 0.21)), (255, 215, 60), outline=(120, 20, 20), width=14)
    outlined_text(d, (s * 0.5, s * 0.27), "ARENA", font(FONT_BOLD, int(s * 0.13)), (255, 255, 255), outline=(120, 20, 20), width=11)
    return img


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


def crown(img, d, s):
    cx, cy, r = s / 2, s * 0.42, s * 0.3
    pts = [(cx - r, cy + r * 0.5), (cx - r, cy - r * 0.4), (cx - r * 0.5, cy), (cx, cy - r * 0.7), (cx + r * 0.5, cy), (cx + r, cy - r * 0.4), (cx + r, cy + r * 0.5)]
    d.polygon(pts, fill=GOLD, outline=(150, 100, 0), width=12)
    d.rectangle([cx - r, cy + r * 0.45, cx + r, cy + r * 0.7], fill=(230, 170, 20))
    for x in (cx - r * 0.5, cx, cx + r * 0.5):
        d.ellipse([x - 28, cy + r * 0.12, x + 28, cy + r * 0.12 + 56], fill=(220, 40, 90))
    paste_center(img, hammer(s * 0.36, head=(255, 200, 40), handle=(150, 20, 60), angle=-40), s * 0.78, s * 0.62)


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


def dance_icon(kind):
    def draw(img, d, s):
        pose = "cheer" if kind == "heli" else "stand"
        guy = brawler(s * 0.5, shirt=(255, 140, 60), pose=pose)
        if kind == "flip":
            guy = guy.rotate(150, resample=Image.BICUBIC, expand=True)
        paste_center(img, guy, s / 2, s * 0.44)
        d = ImageDraw.Draw(img)
        white = (255, 255, 255)
        if kind == "spin":
            d.arc([s * 0.16, s * 0.52, s * 0.84, s * 0.74], 200, 340, fill=white, width=22)
            d.arc([s * 0.16, s * 0.52, s * 0.84, s * 0.74], 20, 160, fill=white, width=22)
            d.polygon([(s * 0.84, s * 0.6), (s * 0.9, s * 0.68), (s * 0.78, s * 0.68)], fill=white)
            d.polygon([(s * 0.16, s * 0.66), (s * 0.1, s * 0.58), (s * 0.22, s * 0.58)], fill=white)
        elif kind == "hop":
            for x in (0.44, 0.56):
                d.ellipse([s * (x - 0.03), s * 0.2, s * (x + 0.03), s * 0.33], fill=(255, 255, 255), outline=(200, 120, 150), width=8)
            for i in range(3):
                x = s * (0.12 + i * 0.27)
                d.arc([x, s * 0.62, x + s * 0.24, s * 0.82], 180, 360, fill=white, width=14)
        elif kind == "flip":
            d.arc([s * 0.16, s * 0.12, s * 0.84, s * 0.78], 210, 30, fill=white, width=22)
            d.polygon([(s * 0.8, s * 0.6), (s * 0.9, s * 0.52), (s * 0.84, s * 0.68)], fill=white)
        elif kind == "heli":
            d.rectangle([s * 0.49, s * 0.12, s * 0.51, s * 0.25], fill=(60, 60, 70))
            d.ellipse([s * 0.14, s * 0.08, s * 0.86, s * 0.16], fill=(200, 210, 230), outline=(60, 60, 70), width=8)
            for i in range(3):
                d.arc([s * (0.1 - i * 0.03), s * (0.04 - i * 0.02), s * (0.9 + i * 0.03), s * (0.2 + i * 0.02)], 160, 200, fill=white, width=8)
                d.arc([s * (0.1 - i * 0.03), s * (0.04 - i * 0.02), s * (0.9 + i * 0.03), s * (0.2 + i * 0.02)], 340, 20, fill=white, width=8)
    return draw


def title_icon(text, color):
    def draw(img, d, s):
        d.rounded_rectangle([s * 0.06, s * 0.3, s * 0.94, s * 0.6], radius=60, fill=NAVY, outline=color, width=16)
        size = 150 if len(text) < 10 else 116
        outlined_text(d, (s / 2, s * 0.45), text, font(FONT_BOLD, size), color, outline=(10, 15, 25), width=6)
    return draw


def main():
    random.seed(7)

    save(icon_art(1024), "game_icon_512.png", (512, 512))

    save(scene((1920, 1080), tagline="Bonk your friends off the arena  -  2 to 4 players  -  4 crazy arenas"), "thumbnail_1_1920x1080.png")

    # Thumbnail 2: the four arenas
    t2 = gradient((1920, 1080), (40, 50, 110), (20, 24, 60)).convert("RGBA")
    d = ImageDraw.Draw(t2)
    outlined_text(d, (960, 110), "BONK ARENA", font(FONT_BOLD, 120), (255, 215, 60), outline=(120, 20, 20), width=10)
    d.text((960, 210), "A new arena every round", font=font(FONT_SEMI, 44), fill=(220, 225, 255), anchor="mm")
    cards = [
        ("ICE FLOE", "Slippery tiles crack away", ARENAS["ice"]),
        ("SPIN CYCLE", "Jump the sweeper bar", ARENAS["spin"]),
        ("LAVA RISE", "Climb before it reaches you", ARENAS["lava"]),
        ("BOUNCE HOUSE", "Bouncy walls fall one by one", ARENAS["bounce"]),
    ]
    for i, (head, sub, color) in enumerate(cards):
        x0 = 70 + i * 455
        d.rounded_rectangle([x0, 290, x0 + 415, 990], radius=36, fill=(25, 28, 55), outline=color, width=10)
        sky = gradient((375, 380), SKY_TOP, SKY_BOTTOM).convert("RGBA")
        sd = ImageDraw.Draw(sky)
        if head == "LAVA RISE":
            sd.rectangle([0, 300, 375, 380], fill=(255, 110, 30))
            for k, (rx, top) in enumerate(((150, 250), (110, 200), (70, 150), (36, 100))):
                sd.rectangle([187 - rx, top, 187 + rx, 300], fill=shade((120, 95, 80), k * 12), outline=(70, 55, 45), width=3)
        elif head == "ICE FLOE":
            island(sd, 187, 230, 150, color, depth=110)
            for k in range(-5, 6):
                sd.line([187 + k * 26, 210, 187 + k * 26, 250], fill=shade(color, -40), width=2)
            sd.polygon([(60, 230), (90, 226), (80, 250)], fill=SKY_BOTTOM)
        elif head == "SPIN CYCLE":
            island(sd, 187, 240, 150, color, depth=110)
            sd.rounded_rectangle([60, 222, 314, 236], radius=6, fill=(230, 50, 50), outline=(110, 20, 20), width=3)
            sd.arc([40, 200, 334, 280], 200, 250, fill=(255, 255, 255), width=8)
        else:
            island(sd, 187, 250, 150, color, depth=110)
            for wx in (50, 300):
                sd.rounded_rectangle([wx, 150, wx + 26, 250], radius=10, fill=shade(color, 30), outline=shade(color, -70), width=4)
        paste_center(sky, brawler(150, shirt=random.choice([(230, 60, 60), (60, 140, 255), (90, 200, 90), (255, 170, 40)]), pose="swing"), 160, 160)
        mask = Image.new("L", sky.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, sky.width, sky.height], radius=24, fill=255)
        t2.paste(sky, (x0 + 20, 310), mask)
        d = ImageDraw.Draw(t2)
        outlined_text(d, (x0 + 207, 790), head, font(FONT_BOLD, 50 if len(head) < 11 else 42), color, width=4)
        d.text((x0 + 207, 870), sub, font=font(FONT_SEMI, 28), fill=(220, 225, 255), anchor="mm")
    save(t2, "thumbnail_2_1920x1080.png")

    save(badge((255, 210, 80), (200, 120, 20), crown, "VIP"), "pass_vip.png", (512, 512))

    hammers_bg = ((235, 90, 90), (120, 30, 40))
    ko_bg = ((120, 90, 230), (40, 25, 100))
    dance_bg = ((70, 200, 160), (20, 90, 80))
    title_bg = ((90, 110, 160), (30, 36, 60))
    products = [
        ("product_hammer_golden.png", hammers_bg, hammer_icon((255, 190, 30), (255, 230, 120)), "GOLDEN"),
        ("product_hammer_neon.png", hammers_bg, hammer_icon((255, 60, 200), (60, 255, 230)), "NEON"),
        ("product_hammer_galaxy.png", hammers_bg, hammer_icon((110, 60, 255), (30, 20, 60)), "GALAXY"),
        ("product_hammer_chicken.png", hammers_bg, hammer_icon((255, 225, 60), (255, 150, 40), "chicken"), "CHICKEN"),
        ("product_hammer_fish.png", hammers_bg, hammer_icon((80, 170, 220), (240, 120, 60), "fish"), "BIG FISH"),
        ("product_ko_confetti.png", ko_bg, confetti, "CONFETTI"),
        ("product_ko_star.png", ko_bg, cartoon_star, "STAR"),
        ("product_ko_fireworks.png", ko_bg, fireworks, "FIREWORKS"),
        ("product_ko_lightning.png", ko_bg, lightning, "LIGHTNING"),
        ("product_dance_spin.png", dance_bg, dance_icon("spin"), "SPIN"),
        ("product_dance_hop.png", dance_bg, dance_icon("hop"), "BUNNY HOP"),
        ("product_dance_flip.png", dance_bg, dance_icon("flip"), "BACKFLIP"),
        ("product_dance_heli.png", dance_bg, dance_icon("heli"), "HELICOPTER"),
        ("product_title_hammertime.png", title_bg, title_icon("Hammer Time", (120, 200, 255)), "TITLE"),
        ("product_title_unbonkable.png", title_bg, title_icon("Unbonkable", (160, 255, 160)), "TITLE"),
        ("product_title_bonkmaster.png", title_bg, title_icon("Bonk Master", (255, 170, 60)), "TITLE"),
    ]
    for name, (top, bottom), fn, label in products:
        save(badge(top, bottom, fn, label), name, (512, 512))


if __name__ == "__main__":
    main()
