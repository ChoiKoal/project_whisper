# Representative art source provenance

This is a WIP representative remake, not final aesthetic approval.

- `source/workshop-concept.png`: generated concept reference (GPT Image 2, 1983x793). Not a game screenshot or runtime atlas.
- `source/traveler-concept.png`: generated five-view concept reference (GPT Image 2, 1983x793). Not an animation sheet.
- `source/trees-concept.png`: generated transparent tree concept reference (GPT Image 2, 1774x887).
- Runtime PNGs are produced by `tools_author_workshop.py`, `tools_author_ground.py`, `tools_author_traveler.py`, `tools_author_grove.py`: source segmentation/cropping, fixed palette/lattice, alpha cleanup, explicit pixel corrections, authored surface/stride frames. This is AI-assisted sprite reauthoring, not entirely hand-pixeled art.
- Authoring environment verified with Python3.11 / Pillow12.0.0. Reproduction of21 current PNGs was byte-identical in isolated `evidence/03-astra-art/repro-staging/game/`; see `artifact-manifest.json`.
- These scripts write their own game/assets folder. To stage safely, copy the scripts, art/source and original t0_void alpha input to another game-shaped directory as done by `evidence/03-astra-art/audit_artifacts.py`. Do not rerun legacy `tools_gen_home_maker.js`/`tools_gen_l1_tiles.js` over accepted candidates; those preserve the older primitive direction.
- Official SANABI screenshot viewed only for craftsmanship analysis: https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/1562700/ss_dc42526e8a4db7c389494d0a14d5c21da1974c51.1920x1080.jpg . No SANABI asset pixels are copied into these files. Its cyberpunk setting and side-scrolling projection are not Whisper's art direction.
- Current blockers: noisy fine clusters, backdrop/architecture consistency, two-pose walking and mirrored equipment, repetitive banks/cliffs, first-action hierarchy. Technical lattice/palette tests do not establish aesthetic quality.
