#!/usr/bin/env python3
# L3-2 — Layer-3 「태엽이 멈춘 도시」 40×40 map generator. Emits, byte-identical to design
# doc §A-2, the layout + a parallel height file (O core=2, H neck=2, M platform=1, /=ramp,
# else 0). No hand-typing of the grid: the layout is stored here as the authoritative 40-row
# block (transcribed once from the design ASCII, ruler stripped) and written verbatim so the
# loader ingests exactly the BFS-verified map. Run: python3 tools_gen_l3_map.py
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")

# ---- Authoritative 40×40 layout (design §A-2, ruler/row-numbers removed). ----
# row 0 = 북(대시계 광장, +2), row 39 = 남(스폰 포탈 착지). Each row is exactly 40 chars.
LAYOUT = [
    "VVVVVVVVVVVVVOOOOOOOOOOOOOOVVVVVVVVVVVVV",  # 0
    "VVVVVVVVVVVVVOOOOOOOOOOOOOOVVVVVVVVVVVVV",  # 1
    "VVVVVVVVVVVVVOOOOO1KOOOOOOOVVVVVVVVVVVVV",  # 2
    "VVVVVVVVVVVVVOOOOO//OOOOOOOVVVVVVVVVVVVV",  # 3
    "VVVVVVVVVVVVVVVVVVHHVVVVVVVVVVVVVVVVVVVV",  # 4
    "VVVVVVVVVVVVVVVVVVHHVVVVVVVVVVVVVVVVVVVV",  # 5
    "VVVVVVVVVVVVMMMMMtMMfMtMMMMMVVVVVVVVVVVV",  # 6
    "VVVVVVVVVVVVMMtMMMMfMMMMMtMMVVVVVVVVVVVV",  # 7
    "VVVVVVVVVVVVMbMMMMMMMMMMMMbMVVVVVVVVVVVV",  # 8
    "VVVVVVVVVVVVMMMMMM//MMMMMMMMVVVVVVVVVVVV",  # 9
    "VVVVVVVVVVVVVVVVVVLLVVVVVVVVVVVVVVVVVVVV",  # 10
    "VVVVVVVVVVVVVVVVVCLLVV3VVVVVVVVVVVVVVVVV",  # 11
    "VVVVVVVVGGGGGGGGGGGGGGGGGGGGGGGGVVVVVVVV",  # 12
    "VVVVVVVVGGGGGbGGGGGGGGGGGGbGGGGGVVVVVVVV",  # 13
    "VVVVVVVVGGGGGGGGGrGGGGrGGGGGGGGGVVVVVVVV",  # 14
    "VVVVVVVVGGGlGGGGGGGGGGGGGGGGlGGGVVVVVVVV",  # 15
    "VVVVVVVVGGGGrGGGGGGGGGGGGGGrGGGGVVVVVVVV",  # 16
    "VVVVVVVVGGGGGGlGGGGGGGGGGlGGGGGGVVVVVVVV",  # 17
    "VVVVVVVVGGGGGGGGGGGGGGGGGGGGGGGGVVVVVVVV",  # 18
    "VVVVVVVVVVVVVVVVVEvvVV2VVVVVVVVVVVVVVVVV",  # 19
    "VVVVVVVVVVVVVVVVVVvvVVVVVVVVVVVVVVVVVVVV",  # 20
    "VVVVVVVVGGGGGGGGGGGGGGGGGGGGGGGGVVVVVVVV",  # 21
    "VVVVVVVVGGGGlGGGGkGGGGkGGGGlGGGGVVVVVVVV",  # 22
    "VVVVVVVVGGwGGGGGGGGGGGGGGGGGGwGGVVVVVVVV",  # 23
    "VVVVVVVVGGGkGGGGGGGGGGGGGGGGkGGGVVVVVVVV",  # 24
    "VVVVVVVVGGGGGwGGGGGGGGGGGGwGGGGGVVVVVVVV",  # 25
    "VVVVVVVVGGGGGGGGlGGGGGGlGGGGGGGGVVVVVVVV",  # 26
    "VVVVVVVVGGGGGGkGGGGGGGGGGkGGGGGGVVVVVVVV",  # 27
    "VVVVVVVVGGGGGGGGGGXGGGGGGGGGGGGGVVVVVVVV",  # 28
    "VVVVVVVVVVVVVVVVVVggVVVVVVVVVVVVVVVVVVVV",  # 29
    "VVVVVVVVVVVVVVVVVVggVVVVVVVVVVVVVVVVVVVV",  # 30
    "VVVVVVVVBBBBBBBBBBBBBBBBBBBBBBBBVVVVVVVV",  # 31
    "VVVVVVVVBBBtBBBBBBBBBBBBBBBBtBBBVVVVVVVV",  # 32
    "VVVVVVVVBBBBBBrBBBBBBBBBrBBBBBBBVVVVVVVV",  # 33
    "VVVVVVVVBBbBBBBBBBBBBBBBBBBBBBbBVVVVVVVV",  # 34
    "VVVVVVVVppppptpppppppppppptpppppVVVVVVVV",  # 35
    "VVVVVVVVBBBrBBBBBfBBBBfBBBBrBBBBVVVVVVVV",  # 36
    "VVVVVVVVBBBBBBBbBBBSBB4BbBBBBBBBVVVVVVVV",  # 37
    "VVVVVVVVBBrBBfBBBBBBBBBBBBfBBrBBVVVVVVVV",  # 38
    "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",  # 39
]


def build_height(layout):
    """§A-3 elevation by ROW BAND so gather objects embedded in a raised band inherit its
    height (no sunken holes in the platform/plaza):
      rows 0-3  대시계 광장/코어 (O)  → +2
      rows 4-5  대시계 목 (H)          → +2
      rows 6-9  상부 플랫폼 (M)        → +1
      else                              → 0
    '/' ramp chars are preserved as the ramp marker. Void (V) cells stay 0 (they carry no
    height anyway; the loader only lifts non-void ground)."""
    rows = []
    for r, row in enumerate(layout):
        out = []
        for c, ch in enumerate(row):
            if ch == "/":
                out.append("/")
            elif ch == "V":
                out.append("0")
            elif r <= 5:
                out.append("2")   # plaza core (0-3) + clock neck (4-5)
            elif 6 <= r <= 9:
                out.append("1")   # upper platform
            else:
                out.append("0")
        rows.append("".join(out))
    return rows


def main():
    # sanity: 40×40
    assert len(LAYOUT) == 40, "layout must be 40 rows, got %d" % len(LAYOUT)
    for r, row in enumerate(LAYOUT):
        assert len(row) == 40, "row %d len %d (want 40)" % (r, len(row))

    layout_path = os.path.join(OUT, "l3_map_layout.txt")
    height_path = os.path.join(OUT, "l3_map_height.txt")
    with open(layout_path, "w") as f:
        f.write("\n".join(LAYOUT) + "\n")
    heights = build_height(LAYOUT)
    with open(height_path, "w") as f:
        f.write("\n".join(heights) + "\n")

    # report a char inventory for the harness expectation table
    counts = {}
    for row in LAYOUT:
        for ch in row:
            counts[ch] = counts.get(ch, 0) + 1
    print("wrote", layout_path)
    print("wrote", height_path)
    print("char inventory:", dict(sorted(counts.items())))
    # spawn S
    for r, row in enumerate(LAYOUT):
        if "S" in row:
            print("spawn S at (col,row) = (%d,%d)" % (row.index("S"), r))


if __name__ == "__main__":
    main()
