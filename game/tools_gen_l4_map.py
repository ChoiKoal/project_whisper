#!/usr/bin/env python3
# L4-2 — Layer-4 「봉인이 풀린 마탑」 40×40 map generator. Emits, byte-identical to design
# doc §A-2, the layout + a parallel height file (O chamber=2, H neck=2, M floating shard=1,
# /=ramp, else 0). No hand-typing at runtime: the layout is stored here as the authoritative
# 40-row block (transcribed once from the design ASCII, ruler stripped) and written verbatim so
# the loader ingests exactly the BFS-verified map. Run: python3 tools_gen_l4_map.py
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")

# ---- Authoritative 40×40 layout (design §A-2, ruler/row-numbers removed). ----
# row 0 = 북(최심부 봉인실, +2), row 39 = 남(스폰 포탈 착지). Each row is exactly 40 chars.
LAYOUT = [
    "VVVVVVVVVVVVVOOOOOOOOOOOOOOVVVVVVVVVVVVV",  # 0
    "VVVVVVVVVVVVVOOOOOO1OOOOOOOVVVVVVVVVVVVV",  # 1
    "VVVVVVVVVVVVVOOOOOOOOOOOOOOVVVVVVVVVVVVV",  # 2
    "VVVVVVVVVVVVVOOOOO//OOOOOOOVVVVVVVVVVVVV",  # 3
    "VVVVVVVVVVVVVVVVVVHHVVVVVVVVVVVVVVVVVVVV",  # 4
    "VVVVVVVVVVVVVVVVVV//VVVVVVVVVVVVVVVVVVVV",  # 5
    "VVVVVVVVMMMMMMMMMMMMMMMMMMMMMMMMVVVVVVVV",  # 6
    "VVVVVVVVMMMMMqdMMMMMMMMMMdqMMMMMVVVVVVVV",  # 7
    "VVVVVVVVMMMMMMMMmMMdMMMmMMMMMMMMVVVVVVVV",  # 8
    "VVVVVVVVMMMMMMMMMMMMMMMMMMMMMMMMVVVVVVVV",  # 9
    "VVVVVVVVVVVVVVVVVVLLVVVVVVVVVVVVVVVVVVVV",  # 10
    "VVVVVVVVVVVVVVVVVCLLV3VVVVVVVVVVVVVVVVVV",  # 11
    "VVVVVVVVMMMMMMMMMMMoMMMMMMMMMMMMVVVVVVVV",  # 12
    "VVVVVVVVMMMMzMMMMMMMMMMMMMMzMMMMVVVVVVVV",  # 13
    "VVVVVVVVMMMMMMmMMMMMMMMMMmMMMMMMVVVVVVVV",  # 14
    "VVVVVVVVMMMxMMMMMMMMMMMMMMMMxMMMVVVVVVVV",  # 15
    "VVVVVVVVMMMMMoMMMMMmMMMMMMoMMMMMVVVVVVVV",  # 16
    "VVVVVVVVMMMMMMMzMMMoMMMMzMMMMMMMVVVVVVVV",  # 17
    "VVVVVVVVMMMMMMMMMM//MMMMMMMMMMMMVVVVVVVV",  # 18
    "VVVVVVVVVVVVVVVVVEvvV2VVVVVVVVVVVVVVVVVV",  # 19
    "VVVVVVVVVVVVVVVVVVvvVVVVVVVVVVVVVVVVVVVV",  # 20
    "VVVVVVVVRRRRRRRRRRRmRRRRRRRRRRRRVVVVVVVV",  # 21
    "VVVVVVVVRRRRqRRRRRRRRRRRRRRqRRRRVVVVVVVV",  # 22
    "VVVVVVVVRRRRRRmRRRRRRRRRRmRRRRRRVVVVVVVV",  # 23
    "VVVVVVVVRRRRxRRRRRRRRRRRRRRxRRRRVVVVVVVV",  # 24
    "VVVVVVVVRRRRRRRRsRRRRRRsRRRRRRRRVVVVVVVV",  # 25
    "VVVVVVVVRRRmRRRRRRRqRRRRRRRRmRRRVVVVVVVV",  # 26
    "VVVVVVVVRRRRRRRRRRRRRRRRRRRRRRRRVVVVVVVV",  # 27
    "VVVVVVVVRRRRRRRRRRRmRRRRRRRRRRRRVVVVVVVV",  # 28
    "VVVVVVVVVVVVVVVVVVggVVVVVVVVVVVVVVVVVVVV",  # 29
    "VVVVVVVVVVVVVVVVVVggVVVVVVVVVVVVVVVVVVVV",  # 30
    "VVVVVVVVAAAAAAAAAAAAAAAAAAAAAAAAVVVVVVVV",  # 31
    "VVVVVVVVAAAqAsdAAAAAAAAAAdsAqAAAVVVVVVVV",  # 32
    "VVVVVVVVAAAAAAAqAAAAAAAAqAAAAAAAVVVVVVVV",  # 33
    "VVVVVVVVAAAAAAxAAAdAAdAAAxAAAAAAVVVVVVVV",  # 34
    "VVVVVVVVAAsAAAAAAAAAAAAAAAAAAsAAVVVVVVVV",  # 35
    "VVVVVVVVAAAAqAAAyAAAAAAyAAAAAAAAVVVVVVVV",  # 36
    "VVVVVVVVAAAAAAAAAAASA4AAAAAAAAAAVVVVVVVV",  # 37
    "VVVVVVVVAAAyAAAAAAAqAAAAAAAAyAAAVVVVVVVV",  # 38
    "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",  # 39
]


def build_height(layout):
    """§A-3 elevation by ROW BAND so gather objects embedded in a raised band inherit its
    height (no sunken holes in the platform/chamber):
      rows 0-3  최심부 봉인실/코어 (O)  → +2
      rows 4-5  봉인 목 (H)            → +2
      rows 6-9  부유 파편 정원 (M)     → +1
      rows 12-18 상부 룬 회랑 (M)      → +1
      else                              → 0
    '/' ramp chars are preserved as the ramp marker. Void (V) cells stay 0."""
    rows = []
    for r, row in enumerate(layout):
        out = []
        for c, ch in enumerate(row):
            if ch == "/":
                out.append("/")
            elif ch == "V":
                out.append("0")
            elif r <= 5:
                out.append("2")   # chamber core (0-3) + seal neck (4-5)
            elif 6 <= r <= 9:
                out.append("1")   # lower floating fragment garden
            elif 12 <= r <= 18:
                out.append("1")   # upper floating rune corridor
            else:
                out.append("0")
        rows.append("".join(out))
    return rows


def main():
    assert len(LAYOUT) == 40, "layout must be 40 rows, got %d" % len(LAYOUT)
    for r, row in enumerate(LAYOUT):
        assert len(row) == 40, "row %d len %d (want 40)" % (r, len(row))

    layout_path = os.path.join(OUT, "l4_map_layout.txt")
    height_path = os.path.join(OUT, "l4_map_height.txt")
    with open(layout_path, "w") as f:
        f.write("\n".join(LAYOUT) + "\n")
    heights = build_height(LAYOUT)
    with open(height_path, "w") as f:
        f.write("\n".join(heights) + "\n")

    counts = {}
    for row in LAYOUT:
        for ch in row:
            counts[ch] = counts.get(ch, 0) + 1
    print("wrote", layout_path)
    print("wrote", height_path)
    print("char inventory:", dict(sorted(counts.items())))
    for r, row in enumerate(LAYOUT):
        if "S" in row:
            print("spawn S at (col,row) = (%d,%d)" % (row.index("S"), r))


if __name__ == "__main__":
    main()
