#!/usr/bin/env python3
"""Verification harness for the v0.3.1 base-recipe integration (owner CSV + Kana rewires).

Checks, all against data/items.json + data/recipes.json (source of truth):
  1. structural: every recipe has 2 inputs + 1 output; unique recipe ids.
  2. no duplicate UNORDERED input pairs (the engine's find_recipe is order-independent,
     so two recipes with the same {a,b} would make one unreachable).
  3. all input/output ids resolve to a known item (through alias_of).
  4. reachability: every craftable output is reachable from the gatherable seed set via
     forward closure (BFS over recipes whose inputs are all reachable).
  5. G1 chain (디딤돌 D14) solvable from gatherables.
  6. G4 clear chain (세계수 정수 → 생명수 → 빛나는 새싹 → 어린 세계수) solvable.
  7. no item is orphaned (an item that is neither gatherable, nor a recipe output, nor
     used as any recipe input — i.e. dead content). 석기 D11 must be fully gone.

Exit code = number of failed checks (0 = all green).
"""
import json, os, sys

ROOT = os.path.dirname(os.path.abspath(__file__))
items = json.load(open(os.path.join(ROOT, "data/items.json"), encoding="utf-8"))["items"]
recipes = json.load(open(os.path.join(ROOT, "data/recipes.json"), encoding="utf-8"))["recipes"]

# ---- item registry (alias-aware) ----
alias = {}            # id -> canonical
canonical = set()     # canonical ids
name = {}
category = {}
for rec in items:
    i = rec["id"]
    if "alias_of" in rec:
        alias[i] = rec["alias_of"]
    else:
        canonical.add(i)
        name[i] = rec["name"]
        category[i] = rec.get("category", "")

def resolve(i):
    return alias.get(i, i)

# gatherable seed set: all category=="gather" canonical ids that come from the world.
# I9 (세계수 정수) is unique but gatherable (world tree). I3 진흙 is also tile-gatherable
# per the brief, in addition to being craftable.
GATHERABLES = sorted([i for i in canonical if category.get(i) == "gather"])

fails = []
def check(label, cond, detail=""):
    tag = "PASS" if cond else "FAIL"
    print("[%s] %s%s" % (tag, label, ("  — " + detail) if detail else ""))
    if not cond:
        fails.append(label)

print("=== RECIPE/ITEM GRAPH VERIFICATION (v0.3.1 base-recipe integration) ===")
print("items: %d records (%d canonical + %d alias) | recipes: %d | gatherables: %d" % (
    len(items), len(canonical), len(alias), len(recipes), len(GATHERABLES)))

# 1. structural
bad_struct = [r["id"] for r in recipes if len(r.get("inputs", [])) != 2 or not r.get("output")]
check("every recipe has 2 inputs + 1 output", not bad_struct, "bad=%s" % bad_struct)
ids = [r["id"] for r in recipes]
check("recipe ids are unique", len(ids) == len(set(ids)))
check("recipe ids sequential R01..R%02d" % len(recipes),
      ids == ["R%02d" % n for n in range(1, len(recipes) + 1)])

# 2. no duplicate unordered pairs
seen = {}
dups = []
for r in recipes:
    a, b = resolve(r["inputs"][0]), resolve(r["inputs"][1])
    k = "|".join(sorted([a, b]))
    if k in seen:
        dups.append((r["id"], seen[k], k))
    seen[k] = r["id"]
check("no duplicate unordered input pairs", not dups, "dups=%s" % dups)

# 3. all ids resolve
unknown = set()
for r in recipes:
    for i in r["inputs"] + [r["output"]]:
        if resolve(i) not in canonical:
            unknown.add(i)
check("all recipe input/output ids resolve to a known item", not unknown, "unknown=%s" % sorted(unknown))

# 4. reachability (forward closure from gatherables)
reachable = set(GATHERABLES)
changed = True
while changed:
    changed = False
    for r in recipes:
        a, b = resolve(r["inputs"][0]), resolve(r["inputs"][1])
        out = resolve(r["output"])
        if a in reachable and b in reachable and out not in reachable:
            reachable.add(out)
            changed = True

# Every craftable OUTPUT must be reachable.
outputs = set(resolve(r["output"]) for r in recipes)
unreachable_outputs = sorted(outputs - reachable)
check("every recipe output is reachable from the gatherable seed set",
      not unreachable_outputs, "unreachable=%s" % unreachable_outputs)

# every canonical craft item (non-alias, category craft) should be reachable, else it is
# dead content (no way to obtain it).
craft_items = set(i for i in canonical if category.get(i) == "craft")
unreachable_crafts = sorted(craft_items - reachable)
check("every craft item is obtainable (reachable)", not unreachable_crafts,
      "unreachable craft items=%s" % unreachable_crafts)

# 5. G1: 디딤돌 D14 reachable + verify the exact intended path
check("G1: 디딤돌 (D14) reachable", "D14" in reachable)
# 흙+바위->자갈(D52), 바위+돌->암석(D61), 암석+자갈->디딤돌(D14)
def has_recipe(a, b, out):
    ra, rb, ro = resolve(a), resolve(b), resolve(out)
    for r in recipes:
        if resolve(r["output"]) == ro and \
           sorted([resolve(r["inputs"][0]), resolve(r["inputs"][1])]) == sorted([ra, rb]):
            return True
    return False
check("G1 path 흙+바위=자갈 (I1+I6=D52)", has_recipe("I1", "I6", "D52"))
check("G1 path 바위+돌=암석 (I6+I8=D61)", has_recipe("I6", "I8", "D61"))
check("G1 path 암석+자갈=디딤돌 (D61+D52=D14)", has_recipe("D61", "D52", "D14"))

# 6. G4 clear chain
check("G4: 생명수 (D19) reachable", "D19" in reachable)
check("G4: 빛나는 새싹 (D20) reachable", "D20" in reachable)
check("G4: 어린 세계수 (D22) reachable", "D22" in reachable)
check("G4 path 정수+물=생명수 (I9+I7=D19)", has_recipe("I9", "I7", "D19"))
check("G4 path 생명수+새싹=빛나는새싹 (D19+D04=D20)", has_recipe("D19", "D04", "D20"))
check("G4 path 새싹 via 흙+나무 (I1+I4=D04)", has_recipe("I1", "I4", "D04"))
check("G4 path 빛나는새싹+흙=어린세계수 (D20+I1=D22)", has_recipe("D20", "I1", "D22"))

# 7. orphan check + 석기 fully removed
D11_refs = []
for r in recipes:
    for i in r["inputs"] + [r["output"]]:
        if i == "D11":
            D11_refs.append(r["id"])
check("석기 D11 not referenced by any recipe", not D11_refs, "refs=%s" % D11_refs)
check("석기 D11 not an item", "D11" not in canonical and "D11" not in alias)

# an item is "used" if it is gatherable, a recipe output, or a recipe input.
used_as_input = set()
for r in recipes:
    used_as_input.add(resolve(r["inputs"][0]))
    used_as_input.add(resolve(r["inputs"][1]))
orphans = []
for i in canonical:
    is_seed = category.get(i) == "gather"
    is_output = i in outputs
    is_input = i in used_as_input
    if not (is_seed or is_output or is_input):
        orphans.append(i)
# Terminal craft items (outputs never used as an input) are allowed — they're the goal
# products. A true orphan is an item that is neither obtainable nor used anywhere.
check("no orphaned items (every item is gatherable, an output, or an input)",
      not orphans, "orphans=%s" % [(i, name.get(i, "?")) for i in orphans])

# input-only-of-removed-recipes: every item used as an input must itself be reachable,
# else it can never actually be supplied to that recipe.
input_unreachable = sorted(i for i in used_as_input if i not in reachable)
check("every recipe input is itself reachable (no stranded inputs)",
      not input_unreachable, "stranded=%s" % input_unreachable)

# 12 new items all reachable + present
new_ids = ["D%02d" % n for n in range(50, 62)]
missing_new = [i for i in new_ids if i not in canonical]
check("all 12 new items (D50-D61) exist", not missing_new, "missing=%s" % missing_new)
unreachable_new = [i for i in new_ids if i not in reachable]
check("all 12 new items reachable", not unreachable_new, "unreachable=%s" % unreachable_new)

print("=== RESULT: %s (%d failures) ===" % ("PASS" if not fails else "FAIL", len(fails)))
sys.exit(len(fails))
