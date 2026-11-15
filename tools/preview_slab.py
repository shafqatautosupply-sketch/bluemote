#!/usr/bin/env python3
"""Pixel-accurate preview of BTDrawPanel (UIHelpers.m): same constants, same LCG, same drawing order.
Only used to tune the look off-device; the app draws the real thing with Core Graphics."""
import numpy as np, sys
from PIL import Image, ImageDraw, ImageFilter

def lcg(seed):
    s = [seed]
    def rnd():
        s[0] = (s[0] * 1664525 + 1013904223) & 0xFFFFFFFF
        return ((s[0] >> 8) & 0xFFFF) / 65535.0
    return rnd

def rrect_mask(w, h, r, rect, scale):
    S = 4
    m = Image.new("L", (int(w*scale)*S, int(h*scale)*S), 0)
    d = ImageDraw.Draw(m)
    x0, y0, x1, y1 = [v*scale*S for v in (rect[0], rect[1], rect[0]+rect[2], rect[1]+rect[3])]
    d.rounded_rectangle([x0, y0, x1-1, y1-1], radius=r*scale*S, fill=255)
    return np.asarray(m.resize((int(w*scale), int(h*scale)), Image.LANCZOS), dtype=np.float32)/255.0

def grad(stops, t):
    ts = [s[0] for s in stops]
    return np.stack([np.interp(t, ts, [s[1][i] for s in stops]) for i in range(3)], -1)

def slab(w, h, radius=14.0, scale=2.0):
    W, H = int(w*scale), int(h*scale)
    px = 1.0/scale
    rx, ry, rw, rh = 2.0, 2.0, w-4.0, h-5.0
    mask = rrect_mask(w, h, radius, (rx, ry, rw, rh), scale)
    out = np.zeros((H, W, 4), np.float32)
    # drop shadow
    sh = Image.fromarray((mask*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.0*scale))
    sh = np.roll(np.asarray(sh, np.float32)/255.0, int(1.5*scale), axis=0)
    out[..., 3] = sh*0.45
    # base gradient (clipped later)
    y = (np.arange(H)[:, None]/scale - ry)/rh
    t = np.clip(y, 0, 1)
    base = grad([(0, (.90,.91,.93)), (.22, (.97,.97,.985)), (.52, (.80,.81,.84)), (1, (.66,.67,.71))], t[:, 0])
    tex = np.repeat(base[:, None, :], W, axis=1).copy()
    def blend(x0, y0, ww, hh, col, a):
        ix0, ix1 = max(int(round(x0*scale)), 0), min(int(round((x0+ww)*scale)), W)
        iy0, iy1 = max(int(round(y0*scale)), 0), min(int(round((y0+hh)*scale)), H)
        if ix1 <= ix0 or iy1 <= iy0: return
        tex[iy0:iy1, ix0:ix1] = tex[iy0:iy1, ix0:ix1]*(1-a) + np.array(col)*a
    rnd = lcg(0x5EED1234)
    yy = ry
    while yy < ry+rh:
        v = rnd()*2-1
        if v > 0: blend(rx, yy, rw, px, (1,1,1), v*0.09)
        else:     blend(rx, yy, rw, px, (0,0,0), -v*0.07)
        yy += px
    n = int(rw*rh/60.0)
    for _ in range(n):
        tt = rnd(); ln = 8.0 + tt*tt*170.0
        x = rx - ln*0.5 + rnd()*(rw+ln*0.5)
        yv = ry + np.floor(rnd()*rh*scale)*px
        a = 0.04 + rnd()*0.09
        col = (1,1,1) if rnd() > 0.5 else (0,0,0)
        blend(x, yv, ln, px, col, a)
    # edge falloff left/right, top highlight, bottom shade
    xs = np.arange(W)/scale
    e = np.clip(1 - (xs-rx)/22.0, 0, 1) + np.clip(1 - ((rx+rw)-xs)/22.0, 0, 1)
    tex *= (1 - 0.12*np.clip(e, 0, 1))[None, :, None]
    ys = np.arange(H)/scale
    hi = np.clip(1 - (ys-ry)/2.0, 0, 1)[:, None, None]*0.7
    tex = tex*(1-hi) + hi
    lo = np.clip(1 - ((ry+rh)-ys)/8.0, 0, 1)[:, None, None]*0.22
    tex = tex*(1-lo)
    a = mask[..., None]
    rgb = tex*a + out[..., :3]*(1-a)
    al = a[..., 0] + out[..., 3]*(1-a[..., 0])
    # outer 1px stroke 0.30
    edge = mask - np.asarray(Image.fromarray((mask*255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)), np.float32)/255.0
    rgb = rgb*(1-edge[..., None]*0.9) + 0.30*edge[..., None]*0.9
    return np.dstack([rgb, al])

def dpad(img, scale=2.0):
    H, W, _ = img.shape
    cx, cy = W/2, H/2
    R = min(W, H)*0.40
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.hypot(xx-cx, yy-cy)
    ring = np.clip(R-d+0.5, 0, 1)
    sh = Image.fromarray((ring*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3.5*scale))
    sh = np.roll(np.asarray(sh, np.float32)/255.0, int(3*scale), 0)*0.5
    rgb = img[..., :3]*(1-sh[..., None])
    t = np.clip((yy-(cy-R))/(2*R), 0, 1)
    body = np.stack([.99+(.66-.99)*t, .99+(.68-.99)*t, 1.0+(.72-1.0)*t], -1)
    rgb = rgb*(1-ring[..., None]) + body*ring[..., None]
    img = img.copy(); img[..., :3] = rgb
    return img

if __name__ == "__main__":
    w, h = 310.0, 330.0
    s = slab(w, h)
    bg = np.ones_like(s[..., :3])*np.array([.55, .58, .64])
    comp = lambda a: (np.clip(a[..., :3]*a[..., 3:4] + bg*(1-a[..., 3:4]), 0, 1)*255).astype(np.uint8)
    left = comp(s); right = comp(dpad(s))
    Image.fromarray(np.hstack([left, np.full((left.shape[0], 20, 3), 140, np.uint8), right])).save(sys.argv[1] if len(sys.argv) > 1 else "/tmp/slab_preview.png")
