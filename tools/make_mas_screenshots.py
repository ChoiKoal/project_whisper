#!/usr/bin/env python3
"""Generate Mac App Store screenshot CANDIDATES from existing preview PNGs.

Mac App Store macOS screenshots must be exactly one of:
    1280x800, 1440x900, 2560x1600, 2880x1800   (16:10)
minimum 1 image, up to 10; App Store Connect wants at least 1, we produce 5.

The build host has NO Pillow. This script:
  * decodes the repo's existing preview PNGs with the stdlib only
    (zlib + a minimal PNG reader: 8-bit RGBA / colortype 6, the format every
     preview here already uses),
  * composits each onto a 1280x800 branded canvas (dark night-scene gradient,
    matching the app icon), letterboxed with an aspect-preserving fit so nothing
    is stretched, plus a small caption band,
  * writes 5 candidates to dist/apple-ready/screenshots/.

These are CANDIDATES for the store listing — final marketing shots are best taken
live from the game, but these are valid-resolution, on-brand stand-ins the owner
can upload immediately or replace. Deterministic (no randomness).

Usage:
    python3 tools/make_mas_screenshots.py [OUT_DIR]
"""

import os
import struct
import sys
import zlib

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.dirname(_HERE)

MAS_W, MAS_H = 1280, 800


# ---------------------------------------------------------------------------
# Minimal PNG reader (stdlib) — 8-bit, colortype 6 (RGBA). Enough for every
# preview PNG in this repo (all verified colortype=6, bitdepth=8).
# ---------------------------------------------------------------------------
def read_png(path):
    with open(path, "rb") as f:
        data = f.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG: %s" % path
    pos = 8
    width = height = bit_depth = color_type = None
    idat = bytearray()
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        tag = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length  # len + tag + data + crc
        if tag == b"IHDR":
            width, height, bit_depth, color_type = struct.unpack(">IIBB", chunk[:10])
        elif tag == b"IDAT":
            idat.extend(chunk)
        elif tag == b"IEND":
            break
    if bit_depth != 8 or color_type != 6:
        raise ValueError("unsupported PNG (need 8-bit RGBA): %s (bd=%s ct=%s)"
                         % (path, bit_depth, color_type))
    raw = zlib.decompress(bytes(idat))
    stride = width * 4
    out = bytearray(width * height * 4)
    prev = bytearray(stride)
    rp = 0
    for y in range(height):
        ftype = raw[rp]; rp += 1
        line = bytearray(raw[rp:rp + stride]); rp += stride
        if ftype == 0:
            pass
        elif ftype == 1:  # Sub
            for i in range(4, stride):
                line[i] = (line[i] + line[i - 4]) & 255
        elif ftype == 2:  # Up
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif ftype == 3:  # Average
            for i in range(stride):
                a = line[i - 4] if i >= 4 else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif ftype == 4:  # Paeth
            for i in range(stride):
                a = line[i - 4] if i >= 4 else 0
                b = prev[i]
                c = prev[i - 4] if i >= 4 else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        else:
            raise ValueError("bad PNG filter %d" % ftype)
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return width, height, out


def write_png(path, w, h, px):
    raw = bytearray()
    stride = w * 4
    for y in range(h):
        raw.append(0)
        raw.extend(px[y * stride:(y + 1) * stride])
    comp = zlib.compress(bytes(raw), 9)

    def chunk(tag, d):
        out = struct.pack(">I", len(d)) + tag + d
        return out + struct.pack(">I", zlib.crc32(tag + d) & 0xFFFFFFFF)

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", comp) + chunk(b"IEND", b""))


def sample(src_w, src_h, src, sx, sy):
    """Nearest-neighbour RGBA sample from a source image (clamped)."""
    if sx < 0:
        sx = 0
    elif sx >= src_w:
        sx = src_w - 1
    if sy < 0:
        sy = 0
    elif sy >= src_h:
        sy = src_h - 1
    i = (sy * src_w + sx) * 4
    return src[i], src[i + 1], src[i + 2], src[i + 3]


def bg_color(x, y):
    """Deterministic night-scene vertical gradient (matches the app icon mood)."""
    t = y / (MAS_H - 1)
    # deep indigo -> darker at the bottom, with a subtle purple 'whisper' tint.
    r = int(round(_lerp(28, 12, t)))
    g = int(round(_lerp(24, 12, t)))
    b = int(round(_lerp(48, 26, t)))
    return r, g, b


def _lerp(a, b, t):
    return a + (b - a) * t


def compose(candidate):
    """Render one 1280x800 screenshot from a source preview, letterboxed."""
    src_path = os.path.join(_REPO, candidate["src"])
    sw, sh, spx = read_png(src_path)

    out = bytearray(MAS_W * MAS_H * 4)
    # 1) fill branded background (opaque)
    for y in range(MAS_H):
        r, g, b = bg_color(0, y)
        row = y * MAS_W * 4
        for x in range(MAS_W):
            i = row + x * 4
            out[i] = r; out[i + 1] = g; out[i + 2] = b; out[i + 3] = 255

    # 2) aspect-preserving fit of the source into a content box (leave a caption
    #    band at the bottom + margins).
    margin_x = 80
    top = 60
    caption_h = 96
    box_w = MAS_W - 2 * margin_x
    box_h = MAS_H - top - caption_h - 40
    scale = min(box_w / sw, box_h / sh)
    dw = max(1, int(sw * scale))
    dh = max(1, int(sh * scale))
    ox = (MAS_W - dw) // 2
    oy = top + (box_h - dh) // 2

    # simple 1px frame around the image
    for dy in range(-2, dh + 2):
        for dx in range(-2, dw + 2):
            on_frame = dx < 0 or dy < 0 or dx >= dw or dy >= dh
            px_x = ox + dx
            px_y = oy + dy
            if not (0 <= px_x < MAS_W and 0 <= px_y < MAS_H):
                continue
            i = (px_y * MAS_W + px_x) * 4
            if on_frame:
                out[i] = 120; out[i + 1] = 110; out[i + 2] = 150; out[i + 3] = 255
            else:
                sx = int(dx / scale)
                sy = int(dy / scale)
                r, g, b, a = sample(sw, sh, spx, sx, sy)
                if a >= 250:
                    out[i] = r; out[i + 1] = g; out[i + 2] = b; out[i + 3] = 255
                elif a == 0:
                    pass  # keep background
                else:
                    sa = a / 255.0
                    out[i] = int(round(r * sa + out[i] * (1 - sa)))
                    out[i + 1] = int(round(g * sa + out[i + 1] * (1 - sa)))
                    out[i + 2] = int(round(b * sa + out[i + 2] * (1 - sa)))
                    out[i + 3] = 255
    return out


# Sources are chosen to be REAL rendered frames wherever possible (title screen +
# the headless home-island overview render), falling back to art-showcase renders.
# `../preview-home.png` is the committed home_overview_render.gd output (real scene).
CANDIDATES = [
    {"name": "01-title.png",   "src": "game/preview-title-v040b.png"},  # real title screen
    {"name": "02-island.png",  "src": "../preview-home.png"},           # real home-island render
    {"name": "03-world.png",   "src": "render_in_context.png"},         # iso art across biomes
    {"name": "04-context.png", "src": "render_before_after.png"},       # rendered scene context
    {"name": "05-art.png",     "src": "prev_grass_cliff.png"},          # tile/terrain art
]


def main(argv):
    out_dir = argv[1] if len(argv) > 1 else os.path.join(
        _REPO, "dist", "apple-ready", "screenshots")
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for cand in CANDIDATES:
        px = compose(cand)
        dest = os.path.join(out_dir, cand["name"])
        write_png(dest, MAS_W, MAS_H, px)
        written.append(dest)
        print("wrote %s (1280x800, from %s)" % (dest, cand["src"]))
    print("\n%d screenshot candidate(s) in %s" % (len(written), out_dir))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
