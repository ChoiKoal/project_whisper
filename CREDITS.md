# Project Whisper — Third-Party Asset Credits

All third-party assets used in Project Whisper are **CC0 (Public Domain, no attribution
required)**. We credit the creators here voluntarily, as good practice. Nothing in this
list imposes an attribution or share-alike obligation on the game.

Verify each source page's license before updating this file — only CC0 sources belong here.

---

## Music / Audio (BGM)

The day/night background music are CC0 ambient loops from OpenGameArt.org. They replaced
the earlier placeholder synth WAVs (deleted in v0.5b).

| In-game file | Track | Author | Source | License |
|---|---|---|---|---|
| `assets/audio/bgm_day.ogg` | "Ambient Relaxing Loop" (day soundscape) | **isaiah658** | https://opengameart.org/content/ambient-relaxing-loop | CC0 |
| `assets/audio/bgm_night.ogg` | Cathedral / forest ambient (night soundscape) | **congusbongus** | OpenGameArt.org (author profile: https://opengameart.org/users/congusbongus) | CC0 |

Source copies retained in `assets-src/music/`:
- `day_ambient_relaxing_isaiah658.ogg`
- `night_cathedral_forest_congusbongus.ogg`

> Note: the day track URL is verified. The night track was sourced from OpenGameArt under
> CC0 (author handle preserved in the source filename); confirm the exact content URL on
> the author's OpenGameArt profile if an explicit link is required for distribution.

### SFX
All sound effects (`gather_pop`, `place_thud`, `fuse_*`, `ui_*`, `footstep_grass*`,
`bush_bloom`, `clear_fanfare`, `quest_advance`) are **procedurally synthesized in-house**
by `tools_gen_audio.py` — no third-party source, no license obligation.

---

## Tiles / Terrain / Object art (grassland + trees)

The v0.5 terrain tileset (grass/dirt/water/mud/cliff diamonds), the CC0 iso trees, and the
source rock/bush/foliage sheets are sliced from **rubberduck's** CC0 isometric asset packs
on OpenGameArt.org. Source sheets are retained in `assets-src/grassland/` and
`assets-src/trees/`.

| Asset group | Author | Source | License |
|---|---|---|---|
| Isometric grassland tileset (grass/dirt/water/mud/cliff sheets, rock + foliage props) | **rubberduck** | OpenGameArt.org (rubberduck CC0 isometric packs) | CC0 |
| Isometric trees (`isometric_trees_01.png`) | **rubberduck** | OpenGameArt.org (rubberduck CC0 isometric packs) | CC0 |

Sliced/derived in-game files (all CC0-derived): `assets/tiles/*` (t1–t5, cliff faces,
ridge rock, edge overlays) and `assets/objects/tree_a/b/c.png`, `young_tree.png`,
`world_tree.png`, `bush_dry.png`.

> The grassland/tree source packs are rubberduck's CC0 isometric sets on OpenGameArt.
> Confirm the specific pack URLs on rubberduck's OpenGameArt profile before shipping if an
> explicit per-pack link is required.

---

## Fully in-house (no third-party source)

Generated procedurally by the project's own tools — listed for completeness, no credit owed:
- Character sheet + portrait (`tools_gen_char_v050b.js`, the 방랑자/wanderer).
- Small ground-object repaints: rock, stone, grass tuft, green/bloom bush, flowers,
  cauldron, rest stump (`tools_gen_objart_v050b.js`).
- Programmatic cliff aprons / AO seats / ramps (`scripts/world/cliff_gen.gd`).
- All UI, icons, light-pool decals, night buds, mystic-water glow.
