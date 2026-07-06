#!/usr/bin/env python3
# L5-2 — Layer-5 「응답 없는 대성당」 40×40 map generator. Emits, byte-identical to design
# doc §A-2, the layout + a parallel height file (O 대제단=2, H 봉헌 목=2, C 상부 성가 회랑=1,
# Q 침묵의 회랑=1, /=ramp, else 0). No hand-typing at runtime: the layout is stored here as the
# authoritative 40-row block (transcribed once from the design ASCII, ruler stripped) and written
# verbatim so the loader ingests exactly the BFS-verified map. Run: python3 tools_gen_l5_map.py
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")

# ---- Authoritative 40×40 layout (design §A-2, ruler/row-numbers removed). ----
# row 0 = 북(대제단, +2), row 39 = 남(스폰 포탈 착지). Each row is exactly 40 chars.
LAYOUT = [
    "VVVVVVVVVVVVVOOOOOOOOOOOOOOVVVVVVVVVVVVV",  # 0
    "VVVVVVVVVVVVVOOOOOO1OOOOOOOVVVVVVVVVVVVV",  # 1
    "VVVVVVVVVVVVVOOkOOOOOOOOkOOVVVVVVVVVVVVV",  # 2
    "VVVVVVVVVVVVVOOOOO//OOOOOOOVVVVVVVVVVVVV",  # 3
    "VVVVVVVVVVVVVVVVVVHHVVVVVVVVVVVVVVVVVVVV",  # 4
    "VVVVVVVVVVVVVVVVVV//VVVVVVVVVVVVVVVVVVVV",  # 5
    "VVVVVVVVCCCCCCCCCCkCCCCCCCCCCCCCVVVVVVVV",  # 6
    "VVVVVVVVCCCrCkCCCCCCCCCCCCCCrCCCVVVVVVVV",  # 7
    "VVVVVVVVCCCCCCCCCCCCCCkCrCCCCCCCVVVVVVVV",  # 8
    "VVVVVVVVCCCCCCCCCCCCCCCCkCCCCCCCVVVVVVVV",  # 9  (doc §A-2 row 9 was 39ch typo; C-block col8..31 aligned to rows 6-8, k preserved)
    "VVVVVVVVVVVVVVVVVVYYVVVVVVVVVVVVVVVVVVVV",  # 10
    "VVVVVVVVVVVVVVVVVVYYV3VVVVVVVVVVVVVVVVVV",  # 11
    "VVVVVVVVQQQQQnQQQWQQQQQQQQQQQQQQVVVVVVVV",  # 12
    "VVVVVVVVQQQQAQQpQQQQQQQQQQQBQQQQVVVVVVVV",  # 13
    "VVVVVVVVQQbnQQwQQpQQQQQQQQQQQQQQVVVVVVVV",  # 14
    "VVVVVVVVQQQQQQQQQQQQQQQQpQQQQbQQVVVVVVVV",  # 15
    "VVVVVVVVQQQQQQQQQQQQpQQQQQbQQQQQVVVVVVVV",  # 16
    "VVVVVVVVQQQQQbQQQQQQQQQQwQQQQnQQVVVVVVVV",  # 17
    "VVVVVVVVQQQQQQQQQQ//QQQQQQQQQQQQVVVVVVVV",  # 18
    "VVVVVVVVVVVVVVVVVEeeVVVVVVVVVVVVVVVVVVVV",  # 19
    "VVVVVVVVVVVVVVVVVVeeVVVVVVVVVVVVVVVVVVVV",  # 20
    "VVVVVVVVLLLLLLLLLLL2LLLLLLLLLLLLVVVVVVVV",  # 21
    "VVVVVVVVLLLLLwLnLLLLLLhLLLLLLLLLVVVVVVVV",  # 22
    "VVVVVVVVLLLpLLLhLLLLwLLLLLLLLLLLVVVVVVVV",  # 23
    "VVVVVVVVLLLLhLLLLpLLLLLLLLLLLLLLVVVVVVVV",  # 24
    "VVVVVVVVLLLLLLLLLLLLLLLLpLLhLLLLVVVVVVVV",  # 25
    "VVVVVVVVLLLLLLLLwLLLLLLLLLLLLpLLVVVVVVVV",  # 26
    "VVVVVVVVLLLLLLLLLLLLLLLLLLwLLLLLVVVVVVVV",  # 27
    "VVVVVVVVLLLLLLLLLLLLLLLLLLLLLLLLVVVVVVVV",  # 28
    "VVVVVVVVVVVVVVVVVVggVVVVVVVVVVVVVVVVVVVV",  # 29
    "VVVVVVVVVVVVVVVVVVggVVVVVVVVVVVVVVVVVVVV",  # 30
    "VVVVVVVVPPPPPPPPPXPPPPPPPPPPPPPPVVVVVVVV",  # 31
    "VVVVVVVVPPPPPrPPPPPnPPPPPPbPPPPPVVVVVVVV",  # 32
    "VVVVVVVVPPPkPPPhPbPPPPPPPPPPPPPPVVVVVVVV",  # 33
    "VVVVVVVVPPrPPnPPPPPPhPPPPPPPPPPPVVVVVVVV",  # 34
    "VVVVVVVVPPPhPPPPPPPPPPPPPPPPrPPPVVVVVVVV",  # 35
    "VVVVVVVVPPPPnPbPPPPPPPPPhPPPkPPPVVVVVVVV",  # 36
    "VVVVVVVVPPPPPPPPPPPSP4PPPPPnPPPPVVVVVVVV",  # 37
    "VVVVVVVVPPPPPPPPbPPPkPrPPPPPPPPPVVVVVVVV",  # 38
    "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",  # 39
]


def build_height(layout):
    """§A-3 elevation by ROW BAND so gather objects embedded in a raised band inherit its
    height (no sunken holes in the corridor/altar):
      rows 0-3  대제단 / 신의 잔불 (O)  → +2
      rows 4-5  봉헌 목 (H)            → +2
      rows 6-9  상부 성가 회랑 (C)     → +1
      rows 12-18 침묵의 회랑 (Q)       → +1
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
                out.append("2")   # 대제단 core (0-3) + 봉헌 목 (4-5)
            elif 6 <= r <= 9:
                out.append("1")   # 상부 성가 회랑
            elif 12 <= r <= 18:
                out.append("1")   # 침묵의 회랑
            else:
                out.append("0")
        rows.append("".join(out))
    return rows


def main():
    assert len(LAYOUT) == 40, "layout must be 40 rows, got %d" % len(LAYOUT)
    for r, row in enumerate(LAYOUT):
        assert len(row) == 40, "row %d len %d (want 40)" % (r, len(row))

    layout_path = os.path.join(OUT, "l5_map_layout.txt")
    height_path = os.path.join(OUT, "l5_map_height.txt")
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
