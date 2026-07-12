#!/usr/bin/env python3
"""Generate the Project Whisper macOS app icon (.icns) with NO third-party deps.

Why this exists
---------------
The build host has no Pillow / cairosvg / png2icns / iconutil (iconutil is macOS
only), and the shipped Godot export carried only Godot's *default* placeholder
icon (an old-format .icns whose largest real bitmap is 256px — no Retina 512/1024
slices, which the App Store / a crisp Dock presence wants). This script renders a
custom icon that matches the game's visual identity — a night scene: glowing moon,
a purple "whisper" wisp, a star, over a dark forest-blue rounded field — entirely
with the Python stdlib (`struct` + `zlib`), then packs a modern PNG-based .icns.

It produces, under <out-dir> (default: <repo>/assets-src/appicon/):
    icon_1024.png                 the 1024x1024 master
    iconset/icon_{16,32,...}.png  every size 16..1024 (@1x and @2x names)
    ProjectWhisper.icns           PNG-backed icns (ic07..ic10 + ic11..ic14)

The .icns embeds PNG streams (Apple has supported PNG-in-icns since 10.7), so we
never need the legacy RLE-packed RGB formats. Each icon "size class" points at the
matching PNG we already rendered.

Usage:
    tools/make_app_icon.py [out_dir]

Design is fully procedural + deterministic (no RNG seed drift), so re-running
byte-reproduces the same icon.
"""

import math
import os
import struct
import sys
import zlib

# ---------------------------------------------------------------------------
# Tiny RGBA canvas + PNG writer (stdlib only)
# ---------------------------------------------------------------------------


class Canvas:
    __slots__ = ("w", "h", "px")

    def __init__(self, w, h):
        self.w = w
        self.h = h
        # flat RGBA float buffer, premultiply-free straight alpha
        self.px = bytearray(w * h * 4)

    def _idx(self, x, y):
        return (y * self.w + x) * 4

    def set(self, x, y, r, g, b, a=255):
        if 0 <= x < self.w and 0 <= y < self.h:
            i = self._idx(x, y)
            self.px[i] = r & 255
            self.px[i + 1] = g & 255
            self.px[i + 2] = b & 255
            self.px[i + 3] = a & 255

    def blend(self, x, y, r, g, b, a):
        """Alpha-over a straight-alpha source pixel onto the canvas."""
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        if a <= 0:
            return
        i = self._idx(x, y)
        dr, dg, db, da = self.px[i], self.px[i + 1], self.px[i + 2], self.px[i + 3]
        sa = a / 255.0
        da_f = da / 255.0
        out_a = sa + da_f * (1 - sa)
        if out_a <= 0:
            self.px[i] = self.px[i + 1] = self.px[i + 2] = self.px[i + 3] = 0
            return
        inv = da_f * (1 - sa)
        self.px[i] = int(round((r * sa + dr * inv) / out_a))
        self.px[i + 1] = int(round((g * sa + dg * inv) / out_a))
        self.px[i + 2] = int(round((b * sa + db * inv) / out_a))
        self.px[i + 3] = int(round(out_a * 255))

    def to_png(self):
        raw = bytearray()
        stride = self.w * 4
        for y in range(self.h):
            raw.append(0)  # filter type 0 (None)
            start = y * stride
            raw.extend(self.px[start:start + stride])
        comp = zlib.compress(bytes(raw), 9)

        def chunk(tag, data):
            out = struct.pack(">I", len(data)) + tag + data
            crc = zlib.crc32(tag + data) & 0xFFFFFFFF
            return out + struct.pack(">I", crc)

        sig = b"\x89PNG\r\n\x1a\n"
        ihdr = struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0)
        return sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", comp) + chunk(b"IEND", b"")


# ---------------------------------------------------------------------------
# Drawing helpers (all supersampled at render time, then downscaled)
# ---------------------------------------------------------------------------


def _lerp(a, b, t):
    return a + (b - a) * t


def draw(size):
    """Render the icon at `size`x`size` using 2x supersampling for smoothness."""
    ss = 2
    S = size * ss
    c = Canvas(S, S)

    # macOS icon grid: art sits on a rounded square with a small margin so the
    # corners aren't clipped by the system mask. Use ~10% margin, ~22% corner r.
    margin = int(S * 0.055)
    x0, y0 = margin, margin
    x1, y1 = S - margin, S - margin
    rad = int((x1 - x0) * 0.225)

    # --- rounded-rect background: vertical night gradient (deep indigo -> violet)
    top = (24, 20, 46)      # #18142e deep night indigo
    bot = (46, 34, 78)      # #2e224e violet-navy
    for y in range(y0, y1):
        t = (y - y0) / (y1 - y0)
        r = int(_lerp(top[0], bot[0], t))
        g = int(_lerp(top[1], bot[1], t))
        b = int(_lerp(top[2], bot[2], t))
        for x in range(x0, x1):
            # rounded-corner test
            cx = min(max(x, x0 + rad), x1 - rad)
            cy = min(max(y, y0 + rad), y1 - rad)
            dx = x - cx
            dy = y - cy
            d = math.hypot(dx, dy)
            if d <= rad:
                c.set(x, y, r, g, b, 255)
            elif d <= rad + 1.2:  # 1px feather
                a = int(255 * (1 - (d - rad) / 1.2))
                c.blend(x, y, r, g, b, max(0, a))

    def in_rect(x, y):
        cx = min(max(x, x0 + rad), x1 - rad)
        cy = min(max(y, y0 + rad), y1 - rad)
        return math.hypot(x - cx, y - cy) <= rad

    # --- soft central glow (the "whisper" ambience) ------------------------
    gx, gy = S * 0.5, S * 0.52
    gr = S * 0.42
    for y in range(y0, y1):
        for x in range(x0, x1):
            d = math.hypot(x - gx, y - gy) / gr
            if d < 1.0 and in_rect(x, y):
                a = int(70 * (1 - d) ** 2)
                if a > 0:
                    c.blend(x, y, 150, 120, 235, a)  # #9678eb violet glow

    # --- stars: deterministic scatter -------------------------------------
    star_pts = [
        (0.20, 0.22), (0.32, 0.15), (0.72, 0.20), (0.80, 0.32),
        (0.66, 0.13), (0.14, 0.40), (0.86, 0.48), (0.25, 0.60),
        (0.78, 0.66), (0.40, 0.24), (0.58, 0.18), (0.90, 0.24),
    ]
    for (fx, fy) in star_pts:
        sx, sy = fx * S, fy * S
        srad = S * 0.006
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                px, py = int(sx + dx), int(sy + dy)
                d = math.hypot(dx, dy)
                if d <= srad + 2 and in_rect(px, py):
                    a = int(220 * max(0, 1 - d / (srad + 2)))
                    c.blend(px, py, 230, 226, 250, a)

    # --- the moon: warm ivory disc, upper-left, with a halo ---------------
    mx, my = S * 0.34, S * 0.34
    mr = S * 0.135
    # halo
    for y in range(int(my - mr * 3), int(my + mr * 3)):
        for x in range(int(mx - mr * 3), int(mx + mr * 3)):
            d = math.hypot(x - mx, y - my)
            if mr < d < mr * 2.6 and in_rect(x, y):
                a = int(90 * (1 - (d - mr) / (mr * 1.6)) ** 2)
                if a > 0:
                    c.blend(x, y, 210, 200, 240, a)
    # disc (subtle top-to-bottom warmth)
    for y in range(int(my - mr - 2), int(my + mr + 2)):
        for x in range(int(mx - mr - 2), int(mx + mr + 2)):
            d = math.hypot(x - mx, y - my)
            if d <= mr:
                t = (y - (my - mr)) / (2 * mr)
                r = int(_lerp(248, 226, t))
                g = int(_lerp(244, 216, t))
                b = int(_lerp(224, 198, t))
                c.set(x, y, r, g, b, 255)
            elif d <= mr + 1.5:
                a = int(255 * (1 - (d - mr) / 1.5))
                c.blend(x, y, 240, 232, 210, max(0, a))

    # --- forest silhouette: layered pine ridge along the bottom -----------
    horizon = S * 0.72
    ridge = (18, 15, 34)      # near-black indigo pines
    ntree = 9
    for i in range(ntree):
        base_x = x0 + (i + 0.5) * (x1 - x0) / ntree
        th = S * (0.10 + 0.05 * ((i * 37) % 5) / 4.0)
        tw = (x1 - x0) / ntree * 0.62
        apex_y = horizon - th
        for y in range(int(apex_y), int(horizon)):
            frac = (y - apex_y) / th
            half = tw * frac / 2
            for x in range(int(base_x - half), int(base_x + half) + 1):
                if in_rect(x, y):
                    c.blend(x, y, ridge[0], ridge[1], ridge[2], 255)

    # --- ground: darker foreground hill -----------------------------------
    for y in range(int(horizon), y1):
        # a gentle curve
        for x in range(x0, x1):
            curve = horizon + (S * 0.04) * math.sin((x - x0) / (x1 - x0) * math.pi)
            if y >= curve and in_rect(x, y):
                c.blend(x, y, 12, 10, 24, 255)

    # --- the lone round-canopy tree (game motif), right side --------------
    tx = S * 0.70
    trunk_top = horizon - S * 0.02
    trunk_bot = horizon + S * 0.10
    trunk_w = S * 0.012
    for y in range(int(trunk_top), int(trunk_bot)):
        for x in range(int(tx - trunk_w), int(tx + trunk_w) + 1):
            if in_rect(x, y):
                c.blend(x, y, 14, 11, 26, 255)
    canopy_r = S * 0.075
    cy = trunk_top - canopy_r * 0.7
    for y in range(int(cy - canopy_r - 2), int(cy + canopy_r + 2)):
        for x in range(int(tx - canopy_r - 2), int(tx + canopy_r + 2)):
            d = math.hypot(x - tx, y - cy)
            if d <= canopy_r and in_rect(x, y):
                c.blend(x, y, 16, 13, 30, 255)
            elif d <= canopy_r + 1.5 and in_rect(x, y):
                a = int(255 * (1 - (d - canopy_r) / 1.5))
                c.blend(x, y, 16, 13, 30, max(0, a))

    # --- the "whisper" wisp: a rising violet spiral of light --------------
    # A tapering luminous curl from the ground toward the moon — the game's
    # firefly/spirit. Drawn as a stroked parametric curve with glow.
    wx0, wy0 = S * 0.50, horizon + S * 0.02
    pts = []
    N = 240
    for k in range(N):
        t = k / (N - 1)
        # upward sweep with a gentle S-curl
        yy = wy0 - t * (S * 0.30)
        xx = wx0 + math.sin(t * math.pi * 2.1) * (S * 0.05) * (1 - t) + t * (S * 0.02)
        pts.append((xx, yy, t))
    for (xx, yy, t) in pts:
        thick = max(1.0, (1 - t) * S * 0.016 + S * 0.004)
        # glow halo
        gh = thick * 3
        for dy in range(int(-gh), int(gh) + 1):
            for dx in range(int(-gh), int(gh) + 1):
                d = math.hypot(dx, dy)
                px, py = int(xx + dx), int(yy + dy)
                if not in_rect(px, py):
                    continue
                if d <= thick:
                    # bright core: lavender -> white toward the tip
                    r = int(_lerp(180, 240, t))
                    g = int(_lerp(150, 236, t))
                    b = int(_lerp(245, 250, t))
                    c.blend(px, py, r, g, b, 255)
                elif d <= gh:
                    a = int(120 * (1 - (d - thick) / (gh - thick)) ** 2)
                    if a > 0:
                        c.blend(px, py, 160, 130, 240, a)

    # --- downscale supersample -> final size ------------------------------
    if ss == 1:
        return c
    out = Canvas(size, size)
    for y in range(size):
        for x in range(size):
            r = g = b = a = 0
            for oy in range(ss):
                for ox in range(ss):
                    i = ((y * ss + oy) * S + (x * ss + ox)) * 4
                    r += c.px[i]
                    g += c.px[i + 1]
                    b += c.px[i + 2]
                    a += c.px[i + 3]
            n = ss * ss
            oi = (y * size + x) * 4
            out.px[oi] = r // n
            out.px[oi + 1] = g // n
            out.px[oi + 2] = b // n
            out.px[oi + 3] = a // n
    return out


# ---------------------------------------------------------------------------
# ICNS packing (PNG-backed)
# ---------------------------------------------------------------------------

# size -> icns OSType for PNG-encoded icons.
# Apple's PNG-capable types (10.7+): ic07(128) ic08(256) ic09(512) ic10(1024),
# and the @2x Retina family ic11(32) ic12(64) ic13(256) ic14(512).
ICNS_TYPES = [
    (16, b"icp4"),    # 16x16   (PNG ok since 10.7; sips writes it)
    (32, b"icp5"),    # 32x32
    (128, b"ic07"),   # 128x128
    (256, b"ic08"),   # 256x256
    (512, b"ic09"),   # 512x512
    (1024, b"ic10"),  # 1024x1024 (== 512@2x)
    (32, b"ic11"),    # 16x16@2x
    (64, b"ic12"),    # 32x32@2x
    (256, b"ic13"),   # 128x128@2x
    (512, b"ic14"),   # 256x256@2x
]


def build_icns(png_by_size):
    body = b""
    for size, ostype in ICNS_TYPES:
        png = png_by_size[size]
        body += ostype + struct.pack(">I", len(png) + 8) + png
    total = len(body) + 8
    return b"icns" + struct.pack(">I", total) + body


# The iconset PNG filenames Apple's `iconutil` expects (documentation + parity).
ICONSET_FILES = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]


def main(argv):
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.dirname(here)
    out_dir = argv[1] if len(argv) > 1 else os.path.join(repo, "assets-src", "appicon")
    iconset = os.path.join(out_dir, "iconset")
    os.makedirs(iconset, exist_ok=True)

    needed = sorted({s for s, _ in ICNS_TYPES} | {s for s, _ in ICONSET_FILES})
    print("rendering sizes:", needed)
    png_by_size = {}
    for s in needed:
        cv = draw(s)
        png_by_size[s] = cv.to_png()
        print("  rendered %dx%d (%d bytes)" % (s, s, len(png_by_size[s])))

    # master
    master = os.path.join(out_dir, "icon_1024.png")
    with open(master, "wb") as f:
        f.write(png_by_size[1024])
    print("wrote master:", master)

    # iconset PNGs
    for size, fn in ICONSET_FILES:
        with open(os.path.join(iconset, fn), "wb") as f:
            f.write(png_by_size[size])
    print("wrote iconset:", iconset, "(%d files)" % len(ICONSET_FILES))

    # icns
    icns = build_icns(png_by_size)
    icns_path = os.path.join(out_dir, "ProjectWhisper.icns")
    with open(icns_path, "wb") as f:
        f.write(icns)
    print("wrote icns: %s (%d bytes, %d icon types)" % (icns_path, len(icns), len(ICNS_TYPES)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
