# Capture provenance — diagnostics are not normal input

The early map1_trench_capture inherited `_runtime_record` from l1_gameplay_capture. In `terrain-red` and `terrain-green1/2`, the stored generic capture_kind/test_state_injection strings incorrectly refer to title/Opening/Home/apron behavior. That behavior was NOT executed by this diagnostic. The actual override `_run` selected fresh l1-v2, dispatched StartingGrove directly, placed the player at specified cells and set game time to day0.30. The phase is explicitly DIAGNOSTIC. Original receipts remain unchanged; this erratum controls their interpretation.

All three early BEFORE frames are real root-viewport game renders, not SubViewport or a forensic overlay. They are staged diagnostics, NOT a normal-input journey. The actual before harness source and exact production/assets are hashed in terrain-red/source-hashes.json; the stage instructions are in the retained source lineage and logs.

Framing at production zoom1, 1600x900 pixels:
- bands: camera/player world (2880,416)
- left-mouth: (2112,416)
- right-mouth: (4160,416)
- day tint f1ead7ff

Later captures override metadata correctly as diagnostic_normal_root_injected_scene_position_day, add l1-v2 and actual time, and retain the same framing/tint. Matched final frames are pixels-final3. PNG timing can change animation frames; there is no image repainting, recoloring or synthetic AFTER.

Movement fixtures separately inject starting endpoints, phase time and one I7 water unit. Every crossing thereafter uses real Input actions or Touch.move_to with CharacterBody physics; no in-route position assignment. They are not normal quest progression.

normal-final-v2 and normal-final-legacy inherit the complete existing harvest_progression_capture normal route. No player/time/inventory/gate/quest/clear injection there; v2 selection occurs explicitly before Home construction. Opening skip handler, public touch APIs, Fusion callbacks and keyboard/native-touch dialogue are disclosed automation seams. Passive MAP1 observation does not alter state. Normal route captures and diagnostic captures must never be combined under one 'normal play' label.

The owner's original screenshot buildSHA remains unknown. The parent forensic overlay is diagnostic alignment only, never a game AFTER image.
