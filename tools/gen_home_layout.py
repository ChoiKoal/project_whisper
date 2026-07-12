#!/usr/bin/env python3
# Deterministic L0 home expansion 21x17 -> 31x25.
# Preserves EVERY original content cell (c,r) exactly. Only edits whitelisted cells,
# each guarded by an expected current symbol (V->D/decor, or D->decor for on-slab decor).

W_NEW, H_NEW = 31, 25
orig = open("/tmp/home_orig.txt").read().split("\n")
orig = [ln for ln in orig if ln]           # 17 rows, 21 wide
assert len(orig) == 17 and all(len(r) == 21 for r in orig), (len(orig), [len(r) for r in orig])

# Build grid: widen to 31, add rows to 25 (all pad = V).
grid = []
for r in range(H_NEW):
    if r < 17:
        row = list(orig[r]) + ["V"] * (W_NEW - 21)
    else:
        row = ["V"] * W_NEW
    grid.append(row)

CONTENT = set("12345SYCg")  # never overwrite these

def setc(c, r, new, expect="VD"):
    cur = grid[r][c]
    assert cur in expect, f"({c},{r}) expected one of {expect!r} got {cur!r}"
    assert cur not in CONTENT, f"({c},{r}) is content {cur!r} — refuse"
    grid[r][c] = new

# ---- 1. GROUND expansion (V->D). Grow the silhouette asymmetrically around the fixed core.
#      Listed as (row, [cols]) — every one must currently be V.
GROUND = {
    2:  [15],                                   # top ridge widen (right)
    3:  [5, 15, 16],                            # arch band flanks
    4:  [5, 15, 16],
    5:  [4, 5, 15, 16],                          # left promontory begins
    6:  [4, 5, 6, 15, 16, 17],                   # widen both flanks
    7:  [5, 6, 15, 16, 17, 18],                  # right terrace grows
    8:  [4, 5, 15, 16, 17, 18],
    9:  [4, 5, 15, 16, 17, 18],
    10: [3, 4, 5, 6, 15, 16, 17, 18, 19],        # widest belt (dais plaza)
    11: [4, 5, 15, 16, 17, 18, 19],              # (Y at 14 stays; terrace east of it)
    12: [3, 4, 5, 15, 16, 17, 18, 19],
    13: [4, 5, 6, 14, 15, 16, 17, 18],           # cauldron work zone / SE forecourt
    14: [5, 6, 14, 15, 16, 17],
    15: [6, 7, 12, 13, 14, 15, 16],              # forecourt taper
    16: [7, 8, 12, 13, 14, 15],
    17: [8, 9, 10, 11, 12, 13, 14],              # new rows: south forecourt
    18: [9, 10, 11, 12, 13, 14],
    19: [10, 11, 12, 13, 14],
    20: [11, 12, 13, 14],
    21: [12, 13],
    22: [13],
}
for r, cols in GROUND.items():
    for c in cols:
        cur = grid[r][c]
        assert cur in ("V", "D"), f"({c},{r}) ground target is {cur!r} (content?)"
        assert cur not in CONTENT
        grid[r][c] = "D"

# ---- 2. WORLD-LAYER DECOR in front of / beside each portal (motif props).
#      Portals: P1(7,5) P2(9,4) P3(10,3) P4(12,4) P5(13,5). Aprons (col,row+2) MUST stay D.
#      Aprons: (7,7)(9,6)(10,5)(12,6)(13,7). Decor avoids those cells.
#      p=leaf(nature) q=data(science) k=gear(machine) b=tome(magic) n=bell(divinity)
DECOR = [
    # nature (P1 @7,5, left) — moss stone / sprout, flanking below-left. apron (7,7) kept.
    (5, 6, "p"), (6, 7, "p"),
    # science (P2 @9,4) — data rune crystal, above-left + below-left. apron (9,6) kept.
    (8, 3, "q"), (8, 5, "q"),
    # machine (P3 @10,3, crown) — stopped-gear steles flanking above. apron (10,5) kept.
    (9, 2, "k"), (11, 2, "k"),
    # magic (P4 @12,4) — floating rune tome, above-right + below-right. apron (12,6) kept.
    (13, 3, "b"), (14, 5, "b"),
    # divinity (P5 @13,5, right) — stone bell / censer, above-right + below-right. apron (13,7) kept.
    (14, 4, "n"), (15, 6, "n"),
]
APRONS = {(7, 7), (9, 6), (10, 5), (12, 6), (13, 7)}
for c, r, sym in DECOR:
    assert (c, r) not in APRONS, f"decor on apron ({c},{r})"
    setc(c, r, sym)

# ---- 3. PROCEDURAL DENSITY scatter: o=light pool (low-contrast), x=rubble/stele (variant).
#      All on ground, away from apron cells and spawn.
SCATTER = [
    ("o", 14, 8), ("o", 11, 10), ("o", 16, 12), ("o", 9, 15), ("o", 13, 17),
    ("x", 8, 12), ("x", 6, 14), ("x", 15, 10), ("x", 11, 16), ("x", 12, 19),
]
for sym, c, r in SCATTER:
    assert (c, r) not in APRONS, f"scatter on apron ({c},{r})"
    # these land on cells we just set to D (or original D) — expect D.
    setc(c, r, sym)

# ---- 4. Plug interior V holes so the slab reads as a solid island (no stray ridge
#      pillars poking through). A V with >=3 island 4-neighbours is an interior hole; fill
#      with D. Iterate to fixpoint. Never touches content (only V cells).
def isl(c, r):
    return 0 <= r < H_NEW and 0 <= c < len(grid[r]) and grid[r][c] != "V"
changed = True
while changed:
    changed = False
    for r in range(H_NEW):
        for c in range(len(grid[r])):
            if grid[r][c] != "V":
                continue
            nb = isl(c + 1, r) + isl(c - 1, r) + isl(c, r + 1) + isl(c, r - 1)
            if nb >= 3:
                grid[r][c] = "D"
                changed = True

out = "\n".join("".join(row) for row in grid) + "\n"
open("/workspace/group/project-whisper/game/data/home_layout.txt", "w").write(out)
print(out)
print("OK rows=%d width=%d" % (len(grid), len(grid[0])))
