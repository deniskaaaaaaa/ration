"""Иконка «Рациона»: кольцо Б/Ж/У на тёплом тёмном фоне, в центре — оранжевая «тарелка»."""
import math, sys
from PIL import Image, ImageDraw, ImageFilter

S = 4096
out = sys.argv[1] if len(sys.argv) > 1 else "AppIcon-1024.png"

def radial(size, center, radius, color, alpha):
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 120
    for i in range(steps, 0, -1):
        r = radius * i / steps
        a = int(alpha * (1 - i / steps) ** 1.6)
        d.ellipse([center[0] - r, center[1] - r, center[0] + r, center[1] + r], fill=color + (a,))
    return layer

bg = Image.new("RGBA", (S, S), (0, 0, 0, 255))
d = ImageDraw.Draw(bg)
for y in range(0, S, 8):
    t = y / S
    c = (int(30 - 17 * t), int(29 - 17 * t), int(26 - 16 * t))
    d.rectangle([0, y, S, y + 8], fill=c + (255,))
bg = Image.alpha_composite(bg, radial(S, (int(S * 0.86), int(S * 0.08)), S * 0.75, (255, 106, 61), 120))
bg = Image.alpha_composite(bg, radial(S, (int(S * 0.08), int(S * 0.95)), S * 0.6, (143, 169, 255), 55))

cx, cy = S / 2, S / 2
R = S * 0.305
W = S * 0.092
segs = [(0.32, (143, 169, 255)), (0.27, (244, 207, 85)), (0.41, (86, 216, 226))]
gap = 0.075

def arc_layer(start, end, color, width):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    a0 = -90 + start * 360
    a1 = -90 + end * 360
    box = [cx - R, cy - R, cx + R, cy + R]
    d.arc(box, a0, a1, fill=color + (255,), width=int(width))
    for a in (a0, a1):
        rad = math.radians(a)
        x = cx + (R - width / 2) * math.cos(rad)
        y = cy + (R - width / 2) * math.sin(rad)
        r = width / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=color + (255,))
    return layer

track = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(track).ellipse([cx - R, cy - R, cx + R, cy + R], outline=(255, 246, 230, 22), width=int(W))
bg = Image.alpha_composite(bg, track)

pos = 0.0
rings = Image.new("RGBA", (S, S), (0, 0, 0, 0))
for frac, color in segs:
    a, b = pos + gap / 2, pos + frac - gap / 2
    rings = Image.alpha_composite(rings, arc_layer(a, b, color, W))
    pos += frac
glow = rings.filter(ImageFilter.GaussianBlur(S * 0.03))
glow.putalpha(glow.getchannel("A").point(lambda v: int(v * 0.55)))
bg = Image.alpha_composite(bg, glow)
bg = Image.alpha_composite(bg, rings)

# тарелка в центре
plate_r = S * 0.13
plate = Image.new("RGBA", (S, S), (0, 0, 0, 0))
pd = ImageDraw.Draw(plate)
for i in range(200, 0, -1):
    t = i / 200
    r = plate_r * t
    col = (int(255 - 0 * t), int(162 - 56 * t), int(96 - 35 * t))
    pd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col + (255,))
pglow = plate.filter(ImageFilter.GaussianBlur(S * 0.035))
pglow.putalpha(pglow.getchannel("A").point(lambda v: int(v * 0.6)))
bg = Image.alpha_composite(bg, pglow)
bg = Image.alpha_composite(bg, plate)
hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(hl).ellipse([cx - plate_r * 0.62, cy - plate_r * 0.78, cx + plate_r * 0.1, cy - plate_r * 0.2], fill=(255, 255, 255, 70))
bg = Image.alpha_composite(bg, hl.filter(ImageFilter.GaussianBlur(S * 0.012)))

bg.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(out)
print("saved", out)
