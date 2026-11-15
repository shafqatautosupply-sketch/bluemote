#!/usr/bin/env python3
"""Bluemote icon, iOS 6 skeuomorphic style (pre-rendered: gloss, bevels and rounded corners are baked in).
Usage: python3 tools/make_icon.py [outdir]     -> Icon.png 57, Icon@2x.png 114, Icon-Small.png 29, Icon-Small@2x.png 58, icon_1024.png
Needs: pillow, numpy, scipy."""
import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter, gaussian_filter1d

N = 1024
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
rng = np.random.default_rng(7)

def lerp(a, b, t): return a + (b - a) * t
def vgrad(stops, y0, y1):
    t = np.clip((yy - y0) / (y1 - y0), 0, 1)
    ts = [s[0] for s in stops]
    return np.stack([np.interp(t, ts, [s[1][i] for s in stops]) for i in range(3)], -1)
def circle_a(cx, cy, r):  return np.clip(r - np.hypot(xx - cx, yy - cy) + 0.5, 0, 1)
def blur(a, s):           return gaussian_filter(a, s)
def over(dst, col, a):
    a = a[..., None]
    col = np.asarray(col, np.float32)
    return dst * (1 - a) + col * a
def pil_mask(draw_fn, ss=2):
    m = Image.new("L", (N * ss, N * ss), 0)
    draw_fn(ImageDraw.Draw(m), ss)
    return np.asarray(m.resize((N, N), Image.LANCZOS), np.float32) / 255.0

# ---------- 1. solid, vertically brushed aluminium background ----------
norm = lambda a: a / (a.std() + 1e-6)
def brushed_v(seed_rng):
    """Vertical brushing at several scales. The 1024 master is shrunk up to 18x for the home-screen icon, so a 1 px grain
    vanishes; the wide / medium streaks (sigma_x 3..18 px) are what is still visible at 57 / 29 px."""
    def layer(sy, sx):
        n = seed_rng.standard_normal((N, N)).astype(np.float32)
        return norm(gaussian_filter(n, (sy, sx)))
    fine   = layer(60, 0.9)       # 1 px hairlines
    medium = layer(110, 3.0)      # visible at 114 px
    wide   = layer(240, 9.0)      # visible at 57 px
    broad  = layer(420, 22.0)     # visible at 29 px
    return 0.40 * fine + 0.60 * medium + 0.55 * wide + 0.22 * broad
bg_base = 0.80 + 0.04 * np.exp(-(((xx - 512) / 700) ** 2))          # flat, very slight centre lift (solid look)
bg_metal = np.clip(bg_base + brushed_v(rng) * 0.085, 0, 1)
img = np.stack([bg_metal * 0.985, bg_metal * 0.99, bg_metal * 1.0], -1).astype(np.float32)

# ---------- 2. brushed aluminium D-pad disc ----------
cx, cy, R = 512, 512, 372
disc = circle_a(cx, cy, R)
shadow = np.roll(blur(disc, 22), 26, axis=0) * 0.62
img = over(img, (0.05, 0.05, 0.06), shadow)

t = np.clip((yy - (cy - R)) / (2 * R), 0, 1)
base = np.stack([np.interp(t, [0, .25, .5, .75, 1], v) for v in
                 ([.93, 1.0, .86, .78, .70], [.94, 1.0, .87, .79, .71], [.96, 1.0, .90, .82, .75])], -1)
metal = np.clip(base, 0, 1)            # ring is smooth polished metal: no brushing (the background keeps it)
img = over(img, metal.reshape(N, N, 3), disc)

d = np.hypot(xx - cx, yy - cy)
rim_w = 26
rim_a = disc * np.clip(d - (R - rim_w) + 0.5, 0, 1)
ny = np.clip((cy - yy) / np.maximum(d, 1), -1, 1)
rim_v = 0.50 + 0.47 * (0.5 + 0.5 * ny)                     # bright on top, dark underneath
img = over(img, np.stack([rim_v * 0.97, rim_v * 0.98, rim_v], -1).reshape(N, N, 3), rim_a)
img = over(img, (0.12, 0.14, 0.2), np.exp(-((d - (R - rim_w)) / 1.6) ** 2) * 0.35 * disc)   # groove inside the rim
img = over(img, (1, 1, 1), np.exp(-((d - (R - rim_w - 3)) / 1.6) ** 2) * 0.30 * disc * (0.5 + 0.5 * ny))
img = over(img, (0.1, 0.12, 0.18), np.exp(-((d - (R - 1.5)) / 1.4) ** 2) * 0.55 * disc)     # outer edge line

# diagonal separators + engraved arrows (like the in-app D-pad)
def seps(dr, ss):
    for k in range(4):
        a = np.radians(45 + 90 * k)
        p0 = (cx + 190 * np.cos(a), cy + 190 * np.sin(a)); p1 = (cx + (R - rim_w - 8) * np.cos(a), cy + (R - rim_w - 8) * np.sin(a))
        dr.line([(p0[0] * ss, p0[1] * ss), (p1[0] * ss, p1[1] * ss)], fill=255, width=5 * ss)
sep = pil_mask(seps)
img = over(img, (1, 1, 1), np.roll(sep, 4, 0) * 0.75)
img = over(img, (0.28, 0.30, 0.36), sep * 0.75)

def arrows(dr, ss):
    rr, s = 262, 40
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        px_, py_ = cx + dx * rr, cy + dy * rr
        if dx == 0: pts = [(px_, py_ + dy * -s), (px_ - s * 1.05, py_ + dy * s * 0.75), (px_ + s * 1.05, py_ + dy * s * 0.75)]
        else:       pts = [(px_ + dx * -s, py_), (px_ + dx * s * 0.75, py_ - s * 1.05), (px_ + dx * s * 0.75, py_ + s * 1.05)]
        # pointing outwards: apex on the outer side
        if dx == 0: pts = [(px_, py_ + dy * s), (px_ - s * 1.05, py_ - dy * s * 0.75), (px_ + s * 1.05, py_ - dy * s * 0.75)]
        else:       pts = [(px_ + dx * s, py_), (px_ - dx * s * 0.75, py_ - s * 1.05), (px_ - dx * s * 0.75, py_ + s * 1.05)]
        dr.polygon([(x * ss, y * ss) for x, y in pts], fill=255)
arr = pil_mask(arrows)
img = over(img, (1, 1, 1), np.roll(arr, 4, 0) * 0.9)
img = over(img, (0.25, 0.27, 0.33), arr * 0.95)

# ---------- 3. glossy blue Bluetooth jewel ----------
jr = 132
well = circle_a(cx, cy, jr + 16)
wt = np.clip((yy - (cy - jr - 16)) / (2 * (jr + 16)), 0, 1)
wellc = np.stack([lerp(0.30, 0.98, wt)] * 3, -1) * np.array([0.97, 0.98, 1.0], np.float32)
img = over(img, wellc, well)                                # recessed: dark top edge, light bottom edge
img = over(img, (0.1, 0.12, 0.2), np.exp(-((np.hypot(xx - cx, yy - cy) - (jr + 16)) / 1.3) ** 2) * 0.5)
jew = circle_a(cx, cy, jr)
img = over(img, (0.0, 0.05, 0.2), np.roll(blur(jew, 6), 6, 0) * 0.45)
jcol = vgrad([(0, (0.48, 0.76, 1.0)), (0.5, (0.12, 0.45, 0.95)), (1, (0.02, 0.20, 0.70))], cy - jr, cy + jr)
img = over(img, jcol, jew)
bot = np.clip(1 - np.hypot(xx - cx, yy - (cy + jr * 1.05)) / (jr * 0.95), 0, 1) ** 1.5     # light pooling at the bottom
img = over(img, (0.55, 0.85, 1.0), bot * jew * 0.55)
# soft elliptical highlight on the top half of the jewel (fades out downwards, no hard edge)
hx, hy, ha, hb = cx, cy - jr * 0.46, jr * 0.80, jr * 0.50
hf = ((xx - hx) / ha) ** 2 + ((yy - hy) / hb) ** 2 - 1
hg_ = np.sqrt((2 * (xx - hx) / ha ** 2) ** 2 + (2 * (yy - hy) / hb ** 2) ** 2)
hl = np.clip(0.5 - hf / hg_ / 2.5, 0, 1)
hl_v = np.clip(1 - (yy - (hy - hb)) / (2 * hb), 0, 1) ** 1.2
img = over(img, (1, 1, 1), jew * hl * (0.10 + 0.62 * hl_v))
img = over(img, (0.0, 0.1, 0.4), np.exp(-((np.hypot(xx - cx, yy - cy) - (jr - 1)) / 1.5) ** 2) * 0.45 * jew)

def rune(dr, ss):
    h, w = 78, 17
    P = [(-0.60, -0.50), (0.60, 0.50), (0.0, 1.0), (0.0, -1.0), (0.60, -0.50), (-0.60, 0.50)]
    pts = [((cx + px_ * h * 0.95) * ss, (cy + py_ * h) * ss) for px_, py_ in P]
    dr.line(pts, fill=255, width=w * ss, joint="curve")
    for x, y in pts: dr.ellipse([x - w * ss / 2, y - w * ss / 2, x + w * ss / 2, y + w * ss / 2], fill=255)
rn = pil_mask(rune, ss=3)
img = over(img, (0.0, 0.08, 0.35), np.roll(blur(rn, 4), 5, 0) * 0.55)
img = over(img, np.stack([vgrad([(0, (1, 1, 1)), (1, (0.80, 0.90, 1.0))], cy - 80, cy + 80)[..., i] for i in range(3)], -1), rn)

# ---------- 4. iOS 6 gloss, bevel, rounded corners ----------
def rrect_sdf(r):
    qx, qy = np.abs(xx - N / 2) - (N / 2 - r), np.abs(yy - N / 2) - (N / 2 - r)
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r
radius = N * 0.18
sdf = rrect_sdf(radius)
mask = np.clip(0.5 - sdf, 0, 1)

img = over(img, (0, 0, 0), np.clip((yy - 700) / 324, 0, 1) ** 1.6 * 0.20)          # slight darkening toward the bottom
ell_cx, ell_cy, ea, eb = 512, -250, 900, 770                                          # dome-shaped gloss, lower in the middle
f = ((xx - ell_cx) / ea) ** 2 + ((yy - ell_cy) / eb) ** 2 - 1
g = np.sqrt((2 * (xx - ell_cx) / ea ** 2) ** 2 + (2 * (yy - ell_cy) / eb ** 2) ** 2)
gloss_a = np.clip(0.5 - f / g, 0, 1)
gloss_v = 0.60 - 0.50 * np.clip(yy / 520, 0, 1)
img = over(img, (1, 1, 1), gloss_a * gloss_v)
top_rim = np.clip(1 - np.abs(sdf + 3.5) / 3.0, 0, 1) * np.clip(1 - yy / 360, 0, 1)    # bright inner rim along the top
img = over(img, (1, 1, 1), top_rim * 0.65)
img = over(img, (0, 0, 0), np.clip(1 - np.abs(sdf + 1.5) / 2.0, 0, 1) * 0.30)         # dark inner edge for definition

rgba = np.dstack([np.clip(img, 0, 1), mask])
master = Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA")

out = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(out, exist_ok=True)
master.save(os.path.join(out, "icon_1024.png"))
for name, px in (("Icon.png", 57), ("Icon@2x.png", 114), ("Icon-Small.png", 29), ("Icon-Small@2x.png", 58)):
    master.resize((px, px), Image.LANCZOS).save(os.path.join(out, name), optimize=True)
print("icons written to", out)
