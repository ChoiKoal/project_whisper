#!/usr/bin/env python3
"""Generate store-listing screenshots for EVERY platform format, pure-stdlib.

Project Whisper is a landscape (horizontal) isometric game. This script builds a
complete, valid-resolution screenshot set for every store we target, from the
repo's REAL rendered frames — no Pillow, no external deps (the build host has no
Pillow; we decode/encode PNG with zlib + struct only).

Formats produced (all LANDSCAPE, 5 shots each unless noted):

    ios-6.9         2868 x 1320   iPhone 6.9"  (16:9-ish, landscape)
    ios-6.5         2778 x 1284   iPhone 6.5"  (landscape)
    ipad-13         2732 x 2048   iPad 13"     (4:3 landscape — crop-center reframed)
    android-phone   1920 x 1080   Google Play phone (16:9)
    android-tablet  2560 x 1600   Google Play tablet (16:10)
    mas             2880 x 1800   Mac App Store (16:10)
    feature-graphic 1024 x  500   Google Play feature graphic (1 image, logo-centric)

Source frames (all REAL renders committed in the repo):
    * game/preview-title-v040b.png   — title screen (1280x720)
    * ../preview-home.png            — home-island overview render (1600x824)
    * render_in_context.png          — 5-biome iso strip (2056x348): the cells map
                                       1:1 to the game's level themes, so we crop
                                       each cell for a per-level shot:
                                         CAULDRON -> home/L1 world-tree ground
                                         GEAR     -> L3 mine
                                         RUNE     -> L4 archive/library
                                         STATUE   -> L5 belfry/summit

Recommended 5-shot story per format:
    01 home     — home arch / island overview       (preview-home)
    02 worldtree— L1 world-tree ground (grass cell)  (context: CAULDRON cell)
    03 mine     — L3 mine (gear cell)                (context: GEAR cell)
    04 archive  — L4 archive/library (rune cell)     (context: RUNE cell)
    05 belfry   — L5 belfry/summit (statue cell)     (context: STATUE cell)

These are on-brand, valid-resolution STAND-INS the owner can upload immediately or
replace with live capture on a real Mac/device (recommended — see README).

Resampling: separable Lanczos-3 for upscales (crisp), area-average for downscales
(no aliasing). Deterministic; no randomness.

Usage:
    python3 tools/make_store_screenshots.py [OUT_ROOT]
    # OUT_ROOT default: dist/apple-ready/screenshots
"""

import math
import os
import struct
import sys
import zlib

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.dirname(_HERE)


# ---------------------------------------------------------------------------
# PNG read / write (stdlib). Sources here are all 8-bit RGBA (colortype 6).
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
        pos += 12 + length
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
        elif ftype == 1:
            for i in range(4, stride):
                line[i] = (line[i] + line[i - 4]) & 255
        elif ftype == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif ftype == 3:
            for i in range(stride):
                a = line[i - 4] if i >= 4 else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif ftype == 4:
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


class Img:
    """Tiny RGBA image wrapper (bytearray, row-major, 4 bytes/px)."""
    __slots__ = ("w", "h", "px")

    def __init__(self, w, h, px=None):
        self.w = w
        self.h = h
        self.px = px if px is not None else bytearray(w * h * 4)

    @classmethod
    def load(cls, path):
        w, h, px = read_png(path)
        return cls(w, h, px)

    def get(self, x, y):
        i = (y * self.w + x) * 4
        p = self.px
        return p[i], p[i + 1], p[i + 2], p[i + 3]

    def crop(self, x0, y0, cw, ch):
        cw = max(1, min(cw, self.w - x0))
        ch = max(1, min(ch, self.h - y0))
        out = Img(cw, ch)
        for y in range(ch):
            si = ((y0 + y) * self.w + x0) * 4
            di = y * cw * 4
            out.px[di:di + cw * 4] = self.px[si:si + cw * 4]
        return out


# ---------------------------------------------------------------------------
# Resampling. Separable: resize X then Y. Lanczos-3 for upscale, box-average
# for downscale (per axis, chosen independently).
# ---------------------------------------------------------------------------
def _lanczos(x, a=3):
    if x == 0:
        return 1.0
    if x <= -a or x >= a:
        return 0.0
    px = math.pi * x
    return (a * math.sin(px) * math.sin(px / a)) / (px * px)


def _axis_weights(dst_n, src_n):
    """Return list of (start_index, [weights]) mapping dst pixel -> src range."""
    scale = dst_n / src_n
    out = []
    if scale >= 1.0:  # upscale -> Lanczos-3
        support = 3.0
        inv = 1.0 / scale
        for i in range(dst_n):
            center = (i + 0.5) * inv - 0.5
            left = int(math.floor(center - support)) + 1
            right = int(math.floor(center + support))
            idxs = []
            wts = []
            s = 0.0
            for k in range(left, right + 1):
                w = _lanczos(center - k)
                if w == 0.0:
                    continue
                kk = 0 if k < 0 else (src_n - 1 if k >= src_n else k)
                idxs.append(kk)
                wts.append(w)
                s += w
            wts = [w / s for w in wts]
            out.append((idxs, wts))
    else:  # downscale -> box average over the source span
        inv = 1.0 / scale
        for i in range(dst_n):
            start = i * inv
            end = (i + 1) * inv
            a = int(math.floor(start))
            b = int(math.ceil(end))
            idxs = []
            wts = []
            s = 0.0
            for k in range(a, b):
                lo = max(start, k)
                hi = min(end, k + 1)
                w = hi - lo
                if w <= 0:
                    continue
                kk = 0 if k < 0 else (src_n - 1 if k >= src_n else k)
                idxs.append(kk)
                wts.append(w)
                s += w
            wts = [w / s for w in wts]
            out.append((idxs, wts))
    return out


def resize(img, dw, dh):
    if dw == img.w and dh == img.h:
        return Img(img.w, img.h, bytearray(img.px))
    # X pass: img.w -> dw, same height
    xw = _axis_weights(dw, img.w)
    tmp = Img(dw, img.h)
    src = img.px
    sw = img.w
    for y in range(img.h):
        base = y * sw * 4
        di = y * dw * 4
        for x in range(dw):
            idxs, wts = xw[x]
            r = g = b = a = 0.0
            for k, wv in zip(idxs, wts):
                si = base + k * 4
                r += src[si] * wv
                g += src[si + 1] * wv
                b += src[si + 2] * wv
                a += src[si + 3] * wv
            tmp.px[di] = _clamp(r); tmp.px[di + 1] = _clamp(g)
            tmp.px[di + 2] = _clamp(b); tmp.px[di + 3] = _clamp(a)
            di += 4
    # Y pass: img.h -> dh
    yw = _axis_weights(dh, img.h)
    out = Img(dw, dh)
    tsrc = tmp.px
    for y in range(dh):
        idxs, wts = yw[y]
        di = y * dw * 4
        for x in range(dw):
            r = g = b = a = 0.0
            xoff = x * 4
            for k, wv in zip(idxs, wts):
                si = k * dw * 4 + xoff
                r += tsrc[si] * wv
                g += tsrc[si + 1] * wv
                b += tsrc[si + 2] * wv
                a += tsrc[si + 3] * wv
            out.px[di] = _clamp(r); out.px[di + 1] = _clamp(g)
            out.px[di + 2] = _clamp(b); out.px[di + 3] = _clamp(a)
            di += 4
    return out


def _clamp(v):
    v = int(round(v))
    return 0 if v < 0 else (255 if v > 255 else v)


# ---------------------------------------------------------------------------
# Compositing helpers
# ---------------------------------------------------------------------------
def bg_gradient(w, h):
    """Deep-indigo night gradient matching the app icon / title mood."""
    out = Img(w, h)
    for y in range(h):
        t = y / (h - 1) if h > 1 else 0.0
        r = int(round(28 + (12 - 28) * t))
        g = int(round(24 + (12 - 24) * t))
        b = int(round(48 + (26 - 48) * t))
        row = y * w * 4
        for x in range(w):
            i = row + x * 4
            out.px[i] = r; out.px[i + 1] = g; out.px[i + 2] = b; out.px[i + 3] = 255
    return out


def blit(dst, src, ox, oy, frame=True):
    """Alpha-composite src onto dst at (ox, oy). Optional 2px accent frame."""
    for y in range(src.h):
        py = oy + y
        if py < 0 or py >= dst.h:
            continue
        for x in range(src.w):
            px = ox + x
            if px < 0 or px >= dst.w:
                continue
            r, g, b, a = src.get(x, y)
            di = (py * dst.w + px) * 4
            if a >= 250:
                dst.px[di] = r; dst.px[di + 1] = g; dst.px[di + 2] = b; dst.px[di + 3] = 255
            elif a == 0:
                continue
            else:
                sa = a / 255.0
                dst.px[di] = _clamp(r * sa + dst.px[di] * (1 - sa))
                dst.px[di + 1] = _clamp(g * sa + dst.px[di + 1] * (1 - sa))
                dst.px[di + 2] = _clamp(b * sa + dst.px[di + 2] * (1 - sa))
                dst.px[di + 3] = 255
    if frame:
        _draw_frame(dst, ox, oy, src.w, src.h, (120, 110, 150))


def _draw_frame(dst, ox, oy, w, h, col, t=2):
    r, g, b = col
    for k in range(t):
        for x in range(ox - k, ox + w + k):
            for yy in (oy - 1 - k, oy + h + k):
                if 0 <= x < dst.w and 0 <= yy < dst.h:
                    i = (yy * dst.w + x) * 4
                    dst.px[i] = r; dst.px[i + 1] = g; dst.px[i + 2] = b; dst.px[i + 3] = 255
        for y in range(oy - k, oy + h + k):
            for xx in (ox - 1 - k, ox + w + k):
                if 0 <= xx < dst.w and 0 <= y < dst.h:
                    i = (y * dst.w + xx) * 4
                    dst.px[i] = r; dst.px[i + 1] = g; dst.px[i + 2] = b; dst.px[i + 3] = 255


# ---- minimal 5x7 bitmap font for captions (uppercase + a few glyphs) --------
_FONT = {
    " ": ["00000"] * 7,
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "11110", "10001", "10001", "10001", "11110"],
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "11110", "10000", "10000", "10000", "11111"],
    "F": ["11111", "10000", "11110", "10000", "10000", "10000", "10000"],
    "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01110"],
    "H": ["10001", "10001", "11111", "10001", "10001", "10001", "10001"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
    "K": ["10001", "10010", "11100", "10100", "11100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    ".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
    ":": ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
}


def draw_text(dst, text, x, y, scale, col=(235, 232, 245)):
    r, g, b = col
    cx = x
    for ch in text.upper():
        glyph = _FONT.get(ch, _FONT[" "])
        for gy in range(7):
            row = glyph[gy]
            for gx in range(5):
                if row[gx] == "1":
                    for sy in range(scale):
                        for sx in range(scale):
                            px = cx + gx * scale + sx
                            py = y + gy * scale + sy
                            if 0 <= px < dst.w and 0 <= py < dst.h:
                                i = (py * dst.w + px) * 4
                                dst.px[i] = r; dst.px[i + 1] = g
                                dst.px[i + 2] = b; dst.px[i + 3] = 255
        cx += (5 + 1) * scale
    return cx - x  # width drawn


def text_width(text, scale):
    return len(text) * (5 + 1) * scale


# ---------------------------------------------------------------------------
# Source registry (loaded lazily/cached)
# ---------------------------------------------------------------------------
_CACHE = {}


def src(rel):
    if rel not in _CACHE:
        _CACHE[rel] = Img.load(os.path.join(_REPO, rel))
    return _CACHE[rel]


def context_cell(n):
    """Crop one of the 5 biome cells from render_in_context.png (2056x348)."""
    strip = src("render_in_context.png")
    cw = strip.w // 5
    return strip.crop(n * cw, 0, cw, strip.h)


# Each shot: (short_name, caption, provider) -> provider returns an Img (RGBA).
SHOTS = [
    ("01-home",     "PROJECT WHISPER",       lambda: src("../preview-home.png")),
    ("02-worldtree", "L1  WORLD TREE",        lambda: context_cell(0)),
    ("03-mine",     "L3  THE MINE",          lambda: context_cell(2)),
    ("04-archive",  "L4  THE ARCHIVE",       lambda: context_cell(3)),
    ("05-belfry",   "L5  THE BELFRY",        lambda: context_cell(4)),
]

# Formats: name -> (width, height, ipad_crop). ipad 4:3 needs a reframed content
# box (taller), so we allow a per-format content-box ratio tweak.
FORMATS = [
    ("ios-6.9",       2868, 1320),
    ("ios-6.5",       2778, 1284),
    ("ipad-13",       2732, 2048),
    ("android-phone", 1920, 1080),
    ("android-tablet", 2560, 1600),
    ("mas",           2880, 1800),
]


def compose_shot(cw, ch, content_img, caption):
    """Place content_img (aspect-preserved) on a branded canvas of cw x ch, with
    a caption band. For tall (4:3) canvases the content box is larger vertically,
    so the shot stays framed rather than tiny."""
    canvas = bg_gradient(cw, ch)

    # margins scale with canvas size
    mx = int(cw * 0.035)
    top = int(ch * 0.05)
    cap_h = int(ch * 0.09)
    box_w = cw - 2 * mx
    box_h = ch - top - cap_h - int(ch * 0.03)

    sw, sh = content_img.w, content_img.h
    scale = min(box_w / sw, box_h / sh)
    dw = max(1, int(round(sw * scale)))
    dh = max(1, int(round(sh * scale)))
    scaled = resize(content_img, dw, dh)
    ox = (cw - dw) // 2
    oy = top + (box_h - dh) // 2
    blit(canvas, scaled, ox, oy, frame=True)

    # caption centered in the bottom band
    cap_scale = max(3, cw // 480)
    tw = text_width(caption, cap_scale)
    tx = (cw - tw) // 2
    ty = ch - cap_h + (cap_h - 7 * cap_scale) // 2
    draw_text(canvas, caption, tx, ty, cap_scale, col=(214, 202, 240))
    return canvas


def make_feature_graphic(cw=1024, ch=500):
    """Google Play feature graphic: logo/title-centric banner. Uses the title
    render (which contains the logo bar) fit to the banner, plus wordmark text."""
    canvas = bg_gradient(cw, ch)
    title = src("game/preview-title-v040b.png")
    # fit the title frame to fill height, crop-center horizontally (it's 16:9,
    # banner is ~2:1, so we crop the sides -> keeps the moon + logo bar centered).
    scale = ch / title.h
    dw = int(round(title.w * scale))
    dh = ch
    scaled = resize(title, dw, dh)
    ox = (cw - dw) // 2  # negative -> crops sides
    blit(canvas, scaled, ox, 0, frame=False)
    # wordmark overlay
    wm = "PROJECT WHISPER"
    s = 5
    tw = text_width(wm, s)
    draw_text(canvas, wm, (cw - tw) // 2, int(ch * 0.40), s, col=(236, 230, 248))
    return canvas


def main(argv):
    out_root = argv[1] if len(argv) > 1 else os.path.join(
        _REPO, "dist", "apple-ready", "screenshots")
    os.makedirs(out_root, exist_ok=True)

    manifest = []
    for fname, fw, fh in FORMATS:
        d = os.path.join(out_root, fname)
        os.makedirs(d, exist_ok=True)
        for sname, caption, provider in SHOTS:
            img = compose_shot(fw, fh, provider(), caption)
            dest = os.path.join(d, sname + ".png")
            write_png(dest, fw, fh, img.px)
            manifest.append((fname, sname, fw, fh))
            print("wrote %-18s %-14s %dx%d" % (fname + "/", sname + ".png", fw, fh))

    # feature graphic (single image)
    fg_dir = os.path.join(out_root, "feature-graphic")
    os.makedirs(fg_dir, exist_ok=True)
    fg = make_feature_graphic()
    fg_dest = os.path.join(fg_dir, "feature-graphic.png")
    write_png(fg_dest, 1024, 500, fg.px)
    manifest.append(("feature-graphic", "feature-graphic", 1024, 500))
    print("wrote %-18s %-14s %dx%d" % ("feature-graphic/", "feature-graphic.png", 1024, 500))

    print("\n%d image(s) across %d format group(s) in %s"
          % (len(manifest), len(FORMATS) + 1, out_root))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
