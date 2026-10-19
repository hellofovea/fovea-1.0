#!/usr/bin/env python3
"""Fovea's app icon artwork: the highlighter loop pressed into cotton paper (Oct 13).

The loop and its dot are a blind deboss: no ink, only the paper and the light on it, from the top
left. Where the pen closes the loop over its start (the top centre, where the notch is) it pressed
twice, so the press is deeper there, landing and lifting like a pen, and that second pass is the
only ink: black, its ends cut on a chisel's slant. The loop is the old highlighter icon's, drawn
in the same 160-unit sketch.

Writes two full-bleed 1024 squares (the tile's content filling the canvas, as an Icon Composer
layer takes it) into Sources/FoveaCore/Resources/Brand/Source/:
  fovea-pressed-loop.png         the icon, 64 px and up
  fovea-pressed-loop-small.png   drawn for 16 and 32 px: a heavier loop and dot in a light graphite,
                                 since a blind press vanishes at those sizes
`swift scripts/fovea-icon.swift` builds every export from these. Needs numpy:
  python3 scripts/fovea-pressed-loop.py
"""
import os
import struct
import zlib

import numpy as np

N = 1024
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Sources/FoveaCore/Resources/Brand/Source")

# The drawing was tuned on Apple's grid (an 824 tile 100 in from the edge); `k` keeps every length
# in pixels the same relative to the tile when it fills the whole canvas.
T0, TS = 0.0, 1024.0
k = TS / 824
yy, xx = np.mgrid[0:N, 0:N].astype(np.float64) + 0.5
U, V = (xx - T0) / TS, (yy - T0) / TS


def px(sx, sy):
    """The sketch's units (a 160 square, its tile 144 square at (8, 8)) to pixels."""
    return T0 + (sx - 8) * TS / 144, T0 + (sy - 8) * TS / 144


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# MARK: - Noise and blur

def upsample(g):
    h, w = g.shape
    y = np.linspace(0, h - 1.001, N); x = np.linspace(0, w - 1.001, N)
    y0, x0 = y.astype(int), x.astype(int)
    fy, fx = (y - y0)[:, None], (x - x0)[None, :]
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a = g[np.ix_(y0, x0)]; b = g[np.ix_(y0, x0 + 1)]; c = g[np.ix_(y0 + 1, x0)]; d = g[np.ix_(y0 + 1, x0 + 1)]
    return a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy


def fbm(scales, seed):
    r = np.random.default_rng(seed)
    out = np.zeros((N, N))
    for s, amp in scales:
        out += amp * upsample(r.standard_normal((s + 2, s + 2)))
    return out


def box(a, r):
    if r < 1:
        return a
    r = int(r); w = 2 * r + 1
    p = np.pad(a, ((0, 0), (r + 1, r)), mode="edge"); c = np.cumsum(p, axis=1); a = (c[:, w:] - c[:, :-w]) / w
    p = np.pad(a, ((r + 1, r), (0, 0)), mode="edge"); c = np.cumsum(p, axis=0)
    return (c[w:, :] - c[:-w, :]) / w


def blur(a, r):
    """Three box passes: close to a Gaussian of radius `r` pixels."""
    return box(box(box(a, r / 1.7), r / 1.7), r / 1.7)


# MARK: - The drawing, rasterized

AROUND = [(56, 45), (70, 37.5, 92, 36, 108, 41), (123, 47, 131, 63, 128, 85), (126, 106, 109, 124, 84, 127),
          (60, 130, 39, 115, 36, 92), (33, 71, 42, 54, 63, 43.4)]    # once round; its end runs past its start
CLOSING = [(58, 47), (72, 41.5, 90, 41, 104, 44.5)]                   # the pen's second pass along the top
DOT = (97, 99)


def polyline(path, steps=180):
    pts = [px(*path[0])]
    x0, y0 = path[0]
    for (c1x, c1y, c2x, c2y, x1, y1) in path[1:]:
        for i in range(1, steps + 1):
            t = i / steps; u = 1 - t
            pts.append(px(u ** 3 * x0 + 3 * u * u * t * c1x + 3 * u * t * t * c2x + t ** 3 * x1,
                          u ** 3 * y0 + 3 * u * u * t * c1y + 3 * u * t * t * c2y + t ** 3 * y1))
        x0, y0 = x1, y1
    return pts


def stroke(path, width):
    """Coverage of a stroke `width` sketch units wide: flat ends (a chisel's), round where it turns."""
    hw = width * TS / 144 / 2
    pts = polyline(path)
    m = np.zeros((N, N))
    for i in range(len(pts) - 1):
        (ax, ay), (bx, by) = pts[i], pts[i + 1]
        x0, x1 = int(max(min(ax, bx) - hw - 2, 0)), int(min(max(ax, bx) + hw + 3, N))
        y0, y1 = int(max(min(ay, by) - hw - 2, 0)), int(min(max(ay, by) + hw + 3, N))
        X, Y = xx[y0:y1, x0:x1], yy[y0:y1, x0:x1]
        dx, dy = bx - ax, by - ay
        t = ((X - ax) * dx + (Y - ay) * dy) / (dx * dx + dy * dy)
        d = np.hypot(X - (ax + np.clip(t, 0, 1) * dx), Y - (ay + np.clip(t, 0, 1) * dy))
        if i == 0:
            d = np.where(t < 0, np.inf, d)
        if i == len(pts) - 2:
            d = np.where(t > 1, np.inf, d)
        m[y0:y1, x0:x1] = np.maximum(m[y0:y1, x0:x1], np.clip(hw - d + 0.5, 0, 1))
    return m


def disc(sx, sy, r):
    cx, cy = px(sx, sy)
    return np.clip(r * TS / 144 - np.hypot(xx - cx, yy - cy) + 0.5, 0, 1)


# MARK: - Paper, press and light

LIGHT = np.array([-0.55, -0.62, 0.56]); LIGHT /= np.linalg.norm(LIGHT)
PAPER = hexc("#EEEAE2")
INK = hexc("#1A1918")
GRAPHITE = hexc("#8A8680")


def surface(rng, seed):
    """Cotton paper: a soft fall of light across it, fine grain, faint fibres."""
    fall = 1 + 0.06 * (0.5 - smooth(0, 1.4, np.hypot(U - 0.25, V - 0.15)))
    g = rng.standard_normal((N, N)) * 0.010 + fbm([(150, 1.0)], seed) * 0.006
    return PAPER * fall[..., None] + g[..., None]


def shade(h, strength=1.0, occl=0.0):
    """Lambert on the press's normals, 1 where the paper is flat. Paper takes shadow to about a third
    darker but brightens only a tenth."""
    gy, gx = np.gradient(h)
    nz = 1 / np.sqrt(1 + gx * gx + gy * gy)
    d = (-gx * nz * LIGHT[0] - gy * nz * LIGHT[1] + nz * LIGHT[2]) / LIGHT[2]
    x = (d - 1) * strength
    s = 1 + np.where(x > 0, 0.10 * np.tanh(x / 0.10), 0.30 * np.tanh(x / 0.30))
    if occl:
        s = s * (1 - occl * np.clip(-h / (np.abs(h).max() + 1e-9), 0, 1))
    return s


def render(small):
    rng = np.random.default_rng(3 if not small else 4)
    w, dot_r = (21, 10.5) if small else (15, 7.8)
    a, c, d = stroke(AROUND, w), stroke(CLOSING, w), disc(*DOT, dot_r)
    x0, x1 = px(58, 0)[0], px(104, 0)[0]
    # The second pass lands and lifts like a pen: its press fades in and out along its length.
    c_press = c * (smooth(x0, x0 + 110 * k, xx) * (1 - smooth(x1 - 110 * k, x1, xx)))
    depth, bevel = 5.0 * k, 4.5 * k
    h = -depth * blur(a, bevel) - depth * blur(c_press, bevel) - depth * 1.4 * blur(d, bevel * 0.8)
    # The ink: the closing pass's overlap with the loop, both ends cut on a chisel's slant.
    slant = xx + 0.9 * (yy - (T0 + (312 - 100) / 824 * TS))
    c_ink = c * (smooth(x0 + 22 * k, x0 + 34 * k, slant) * (1 - smooth(x1 - 34 * k, x1 - 22 * k, slant)))
    overlap = np.clip(a * c_ink * 1.6, 0, 1)
    tooth = 0.95 + 0.05 * np.clip(0.5 + fbm([(380, 1.0)], 41) * 1.2, 0, 1)
    img = surface(rng, 1 if not small else 2) * shade(h, 1.0, occl=0.03)[..., None]
    if small:
        body = np.clip(np.maximum(np.maximum(a, c), d), 0, 1)
        col = GRAPHITE * (1 - overlap[..., None]) + INK * overlap[..., None]
        amt = np.clip(body * 0.45 + overlap * 0.55, 0, 1)
    else:
        col, amt = np.broadcast_to(INK, (N, N, 3)), np.clip(overlap * 0.92 * tooth, 0, 1)
    img = img * (1 - amt[..., None]) + col * amt[..., None] * shade(h, 0.35)[..., None]
    return img


def write_png(path, rgb):
    raw = (np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)
    rows = b"".join(b"\x00" + raw[y].tobytes() for y in range(N))

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", N, N, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write_png(os.path.join(OUT, "fovea-pressed-loop.png"), render(small=False))
    write_png(os.path.join(OUT, "fovea-pressed-loop-small.png"), render(small=True))
    print("wrote Brand/Source/fovea-pressed-loop.png and fovea-pressed-loop-small.png")
