extends Node
## GameState — global autoload singleton.
## Holds game time (day/night cycle) and declares signals used across milestones.

signal game_time_changed(new_time: float)
## Fired when the time-of-day phase changes (M4 day/night cycle).
## phase ∈ {"day", "evening", "night", "dawn"}.
signal day_phase_changed(phase: String)
signal item_gathered(item_id: String)    ## M2 gathering: fired when an item is gathered
signal recipe_discovered(recipe_id: String)  ## M3 fusion
## (v0.4.0-C) Fired on EVERY successful fuse (unlike recipe_discovered which fires only
## the first time a recipe is found). `output` = canonical crafted item id. Quests count
## crafts against this so Q2/Q3/Q8 advance on repeat crafts too.
signal item_crafted(output_id: String, recipe_id: String)
## (v0.4.0-C) Fired when the player enters a tagged Area2D region (Q6 world-tree area).
## `area_id` identifies the region.
signal player_entered_area(area_id: String)
## (v0.5.0 phase C) Fired when the player reaches/interacts a portal on the home island.
## `layer` = the portal's world layer. Quest P1 ("들어가 봐") advances on this.
signal portal_reached(layer: String)

## M2 placement/use framework signals.
## Emitted when D22 (어린 세계수) is placed on a T0 VOID tile — the MVP clear
## condition. M4 hooks the clear cutscene here.
signal world_tree_planted(cell: Vector2i)
## Emitted when a `usable_on` item is used on a matching object (e.g. I7 water on
## a `bush_dry`).
signal item_used_on_object(item_id: String, object: Node)
## Emitted when D14 (디딤돌) makes a water tile walkable, for later SFX / audit.
signal stepping_stone_placed(cell: Vector2i)

## (L2-3) Emitted when a 전력 노드 (배전반 K / 발전기 e / 관제탑 코어) is energized — the
## Layer-2 SF counterpart to `stepping_stone_placed`. `node_id` ∈ {"bridge","gen_sub",
## "control_core", …}. G1 브리지 walkable-swap and G4 정화 컷신 listen here; QuestManager
## routes L2-Q3/Q7 off it. The energized set is mirrored into `powered_nodes` (saved).
signal power_node_energized(node_id: String)
## (L2-3) Set of energized power-node ids (node_id -> true). Saved by SaveManager the same
## way `portal_states` is, so a re-entered/restored station keeps its bridge lit / door open.
var powered_nodes: Dictionary = {}
## (L2-3) Emitted when the 관제탑 재가동 (G4) completes the Layer-2 정화 컷신. Carries the
## purified layer id ("science"). The session hooks return-to-home; the flag persists.
signal layer2_purified(layer: String)
## (L2-3) True once Layer 2 (science) is 정화된 (관제탑 재가동 완료). Saved; drives the next
## portal (machine) opening in later layers, mirroring the Layer-1 `cleared` flag.
var layer2_purified_flag: bool = false

## (L3-3) Emitted when the 대시계 재가동 (G4) completes the Layer-3 정화 컷신. Carries the
## purified layer id ("machine"). The ClockworkCity session hooks return-to-home + the next
## portal (magic) opening; the flag persists.
signal layer3_purified(layer: String)
## (L3-3) True once Layer 3 (machine) is 정화된 (대시계 재가동 완료). Saved; drives the magic
## portal opening, mirroring layer2_purified_flag.
var layer3_purified_flag: bool = false

## (L4-3) Emitted when the 최심부 봉인 재구축 (G4) completes the Layer-4 정화 컷신. Carries the
## purified layer id ("magic"). The MageTower session hooks return-to-home + the next portal
## (divinity) opening; the flag persists. NOTE: L4 정화 = "풀려난 것을 다시 봉인함" (§A-1).
signal layer4_purified(layer: String)
## (L4-3) True once Layer 4 (magic) is 정화된 (최심부 봉인 재구축 완료). Saved; drives the divinity
## portal opening, mirroring layer3_purified_flag.
var layer4_purified_flag: bool = false

## (L5-3) Emitted when the 대제단 봉헌=응답 (G4) completes the Layer-5 정화 컷신. Carries the
## purified layer id ("divinity"). The Cathedral session hooks divinity 포탈 open + 다섯 포탈 전점등
## (빛의 문 예고); the flag persists. NOTE: L5 정화 = "응답 없는 세계에 대답함" (§A-1).
signal layer5_purified(layer: String)
## (L5-3) True once Layer 5 (divinity) is 정화된 (대제단 응답 완료). Saved; 5레이어 전부 개방·다섯 포탈
## 완결의 최종 플래그. Mirrors layer4_purified_flag.
var layer5_purified_flag: bool = false


## (L2-3) Mark a power node energized (idempotent). Records it in `powered_nodes` and announces
## it so gate listeners (bridge swap / clear cutscene) and quests react. No signal if already on.
func energize_power_node(node_id: String) -> void:
	if powered_nodes.get(node_id, false):
		return
	powered_nodes[node_id] = true
	power_node_energized.emit(node_id)


## (L2-3) True if a given power node has been energized.
func is_power_node_energized(node_id: String) -> bool:
	return bool(powered_nodes.get(node_id, false))


## (L2-3) Reset Layer-2 power/purification state to the new-game baseline (nothing energized,
## not purified). Called by new game / NG+ alongside reset_portals.
func reset_layer2() -> void:
	powered_nodes.clear()
	layer2_purified_flag = false


## (L3-3) Reset Layer-3 power/purification state to the new-game baseline. Called by new game /
## NG+. Note: powered_nodes is a shared set (L2 + L3 node ids); reset_layer2 already clears it,
## so this only clears the L3 purified flag. Kept as a distinct call for clarity/parity.
func reset_layer3() -> void:
	layer3_purified_flag = false

## (L4-5) Reset Layer-4 purification state to the new-game baseline. Called by new game / NG+.
## Note: powered_nodes is a shared set (L2 + L3 + L4 seal-node ids); reset_layer2 already clears
## it, so this only clears the L4 purified flag. Kept distinct for clarity/parity with L2/L3.
func reset_layer4() -> void:
	layer4_purified_flag = false

## (L5-5) Reset Layer-5 purification state to the new-game baseline. Called by new game / NG+.
## powered_nodes is shared (L2~L5 node ids); reset_layer2 clears it, so this only clears the L5
## purified flag. Kept distinct for clarity/parity with L2/L3/L4.
func reset_layer5() -> void:
	layer5_purified_flag = false
	# (L5-5) the 빛의 문 예고 is re-earned each run — clear it alongside the L5 purified flag.
	light_gate_previewed_flag = false

## (v0.4.0-C) Emitted when a structure/decor item is PLACED into the world (persistent
## PlacedObject). `item_id` = the placed item, `cell` = its tile. Quests/audio hook here.
signal placed_object_placed(item_id: String, cell: Vector2i)
## (v0.4.0-C) Emitted when a placed object is RECALLED (returned to inventory).
signal placed_object_recalled(item_id: String, cell: Vector2i)
## (v0.3.1 Fix 4) Emitted when gathering an interior tile turns it into a walkable
## HOLLOW (빈 자국). The pathfinding grid rebuilds its solids so tap-to-move crosses
## the emptied spot; before this the gathered cell was VOID (non-walkable to AStar)
## but had no physics wall — the "swiss-cheese" WASD/tap inconsistency the owner hit.
signal tile_walkable_changed(cell: Vector2i)

# ---- Day/night cycle (M4) -------------------------------------------------
## One full game day = 900s real (확정 스펙: 낮 540s / 저녁~새벽 360s).
## Phases as fractions of the day cycle:
##   day    0.00 .. 0.60  (540s)
##   evening0.60 .. 0.7333(120s ramp 갈→보라)
##   night  0.7333.. 0.9333(180s 어둠)
##   dawn   0.9333.. 1.00  (60s → day)
const DAY_LENGTH: float = 900.0
const DAY_END: float = 0.60      # 540s
const EVENING_END: float = 0.7333  # +120s = 660s
const NIGHT_END: float = 0.9333    # +180s = 840s
# dawn runs NIGHT_END..1.0 (60s), then wraps to day.

## In-game elapsed time in seconds (monotonic). Advanced by _process each frame.
var game_time: float = 0.0

## Whether time should advance (paused menus / cutscenes can toggle this).
var time_running: bool = true

# ---- v0.4.0-B B3: modal UI input lock -------------------------------------
## (B3.1) "조합 떠있을때 움직일수 있으면 이상하잖아" — while ANY window is open
## (fusion / inventory / codex / character / pause), the player must not move or
## interact with the world (keyboard AND click-to-move). Windows push/pop a stable
## key here; the world reads `ui_modal_open()` before acting.
var _modal_keys: Dictionary = {}
## Emitted whenever the set of open modals transitions empty↔non-empty.
signal ui_modal_changed(open: bool)

## Register a modal window as open by a stable key (e.g. "fusion", "inventory").
func push_modal(key: String) -> void:
	var was := ui_modal_open()
	_modal_keys[key] = true
	if not was:
		ui_modal_changed.emit(true)

## Unregister a modal window (idempotent).
func pop_modal(key: String) -> void:
	if not _modal_keys.has(key):
		return
	_modal_keys.erase(key)
	if not ui_modal_open():
		ui_modal_changed.emit(false)

## True while at least one modal window is open — the world input lock.
func ui_modal_open() -> bool:
	return not _modal_keys.is_empty()

# ---- v0.5.1 BUG2: cutscene / scripted control lock ------------------------
## (BUG2a) Cutscenes (opening, portal travel, CS-05) freeze player control. Unlike the modal
## windows above, they don't push a modal key — they pause GameState.time_running. To make the
## "release move keys on lock AND unlock" contract fire for cutscenes too, cutscenes call
## set_control_lock(true/false); the Player listens to control_lock_changed and releases the
## four move actions + clears its path on BOTH edges, so a key held (and its RELEASE swallowed)
## during a cutscene can never leave the player auto-walking after the scene resumes.
signal control_lock_changed(locked: bool)
var _control_locked: bool = false

func set_control_lock(locked: bool) -> void:
	if _control_locked == locked:
		# Still announce a lock→lock re-entry as an unlock-then-lock is not needed; but on the
		# same value do nothing (idempotent).
		return
	_control_locked = locked
	control_lock_changed.emit(locked)

func control_locked() -> bool:
	return _control_locked

var _phase: String = "day"

# ---- v0.5.0 phase C: portal states (제0세계 문 다섯) ------------------------
## Per-layer portal state, keyed by layer id ("nature"/"science"/"machine"/"magic"/
## "divinity") → one of "dormant" / "flickering" / "open". Saved by SaveManager.
## Layer 1 (nature) starts flickering; the rest dormant. CS-05 opens nature and sets
## science flickering. Portal world objects poll this dict + listen to portal_state_changed.
signal portal_state_changed(layer: String, state: String)
const PORTAL_DORMANT := "dormant"
const PORTAL_FLICKERING := "flickering"
const PORTAL_OPEN := "open"
var portal_states: Dictionary = {}

## Reset the portal line to its NEW-GAME baseline (nature flickering, rest dormant).
func reset_portals() -> void:
	portal_states = {
		"nature": PORTAL_FLICKERING,
		"science": PORTAL_DORMANT,
		"machine": PORTAL_DORMANT,
		"magic": PORTAL_DORMANT,
		"divinity": PORTAL_DORMANT,
	}

## Set a portal's state and announce it (idempotent — no signal if unchanged).
func set_portal_state(layer: String, state: String) -> void:
	if portal_states.get(layer, "") == state:
		return
	portal_states[layer] = state
	portal_state_changed.emit(layer, state)

## Current state of a portal layer ("dormant" if unknown).
func portal_state(layer: String) -> String:
	return String(portal_states.get(layer, PORTAL_DORMANT))

## Portal states ordered by "unlockedness" so reconcile can UPGRADE (never downgrade).
const _PORTAL_RANK := {PORTAL_DORMANT: 0, PORTAL_FLICKERING: 1, PORTAL_OPEN: 2}

## (v1.3.1) Reconcile the portal line against the authoritative progression flags
## (SaveManager.cleared for L1, layer2~5_purified_flag for L2~L5) and UPGRADE each portal to at
## least the state that progression guarantees. This is the single source-of-truth recompute that
## makes the portal line self-healing: it runs on every world boot (after load / on re-entry) so a
## stale or already-corrupted snapshot can never leave a purified world's portal re-locked.
##
## Rule (mirrors the CS-05 / *_purified cutscene hand-offs; each cleared layer OPENs its own portal
## and at minimum FLICKERs the next):
##   nature   : always ≥ flickering (the one live gate); OPEN once L1 cleared
##   science  : ≥ flickering once L1 cleared; OPEN once L2 purified
##   machine  : ≥ flickering once L2 purified; OPEN once L3 purified
##   magic    : ≥ flickering once L3 purified; OPEN once L4 purified
##   divinity : ≥ flickering once L4 purified; OPEN once L5 purified
## Only ever raises a portal's state (an OPEN portal is never pushed back to flickering/dormant),
## so it is safe to call unconditionally and idempotent.
func reconcile_portal_line() -> void:
	if portal_states.is_empty():
		reset_portals()
	var l1_cleared := typeof(SaveManager) != TYPE_NIL and bool(SaveManager.cleared)
	# floor state each layer must be AT LEAST in, given the progression flags.
	var floor := {
		"nature": PORTAL_OPEN if l1_cleared else PORTAL_FLICKERING,
		"science": PORTAL_OPEN if layer2_purified_flag else (PORTAL_FLICKERING if l1_cleared else PORTAL_DORMANT),
		"machine": PORTAL_OPEN if layer3_purified_flag else (PORTAL_FLICKERING if layer2_purified_flag else PORTAL_DORMANT),
		"magic": PORTAL_OPEN if layer4_purified_flag else (PORTAL_FLICKERING if layer3_purified_flag else PORTAL_DORMANT),
		"divinity": PORTAL_OPEN if layer5_purified_flag else (PORTAL_FLICKERING if layer4_purified_flag else PORTAL_DORMANT),
	}
	for layer in floor:
		var want: String = floor[layer]
		var cur := portal_state(layer)
		if int(_PORTAL_RANK.get(want, 0)) > int(_PORTAL_RANK.get(cur, 0)):
			set_portal_state(layer, want)   # upgrade only (emits so live portal nodes refresh)

# ---- (L5-5) 다섯 포탈 완결 → 빛의 문 예고 (§C-4) ---------------------------
## The five world layers, in portal order. Layer 1 (nature) clears via SaveManager.cleared;
## Layers 2~5 via their *_purified_flag. 진행 순서 무관 — the AND below only cares that all five
## are done.
const PORTAL_LAYERS := ["nature", "science", "machine", "magic", "divinity"]

## (L5-5) Emitted ONCE when the fifth (final) layer is purified and all five layers are complete:
## the divinity 정화 컷신 lights every portal (set_all_portals(OPEN)) and previews the 빛의 문 at
## the home island's centre. Carries nothing — the Cathedral cutscene shows the text card; the
## home island (엔딩 마일스톤) will spawn the real gate. `light_gate_previewed_flag` persists so
## the preview state round-trips a save.
signal five_portals_lit()
## (L5-5) True once the 다섯 포탈 전점등 + 빛의 문 예고 has fired. Saved; drives the 홈 섬 빛의 문
## 예고 visual on reload. Set only by _maybe_light_five_portals (idempotent).
var light_gate_previewed_flag: bool = false

## (L5-5) True iff every one of the five world layers is purified/cleared (진행 순서 무관, 5-AND).
## Layer 1 = SaveManager.cleared; Layers 2~5 = their purified flags.
func five_layers_purified() -> bool:
	var l1: bool = false
	if typeof(SaveManager) != TYPE_NIL:
		l1 = bool(SaveManager.cleared)
	return l1 and layer2_purified_flag and layer3_purified_flag \
		and layer4_purified_flag and layer5_purified_flag

## (L5-5) Force every portal to `state` and announce each (idempotent per portal). Used by the L5
## 정화 컷신 to light all five portals at once (다섯 포탈 완결).
func set_all_portals(state: String) -> void:
	for layer in PORTAL_LAYERS:
		set_portal_state(layer, state)

## (L5-5) If all five layers are purified, light every portal OPEN and preview the 빛의 문 — ONCE.
## Idempotent: re-entry after the flag is set is a no-op (no duplicate signal). Returns true iff
## it fired this call. Called from the L5 정화 컷신 (great_altar 봉헌) and on cathedral boot when a
## restored save is already fully purified.
func maybe_light_five_portals() -> bool:
	if light_gate_previewed_flag:
		return false
	if not five_layers_purified():
		return false
	set_all_portals(PORTAL_OPEN)
	light_gate_previewed_flag = true
	five_portals_lit.emit()
	return true

## (L5-5) Reset the 빛의 문 예고 flag (NG+ / new game). Portals + purified flags are reset by
## reset_portals / reset_layer*; this clears the preview so a fresh run re-earns it.
func reset_light_gate() -> void:
	light_gate_previewed_flag = false


# ---- (EG-2) 진상 조각 (Truth Shards) + (EG-1/EG-3) 엔딩 기록 -----------------
## (EG-2) Collected truth shards, keyed by shard id → true. The five shards are the L1~L5
## narrative investigation objects (world_tree / l2_last_log / stopped_robot / mage_ghost /
## petrified_pilgrim). Saved (v2, null-guarded migration). Reset each run on NG+ (QA 확정:
## truth_shards 리셋, endings_seen만 lifetime) so [돌아선다] must be re-earned per run.
var truth_shards: Dictionary = {}
## (EG-2) The five canonical truth-shard ids, in narrative (layer) order.
const TRUTH_SHARD_IDS := ["world_tree", "l2_last_log", "stopped_robot", "mage_ghost", "petrified_pilgrim"]
## (EG-2) True once the final 회수 카드 (§3.1) has been shown — this is what unlocks the light
## gate's [돌아선다]. Set when the 5th shard is collected; reset on NG+. Saved.
var truth_final_seen: bool = false
## (EG-2) Emitted when a truth shard is (first) collected. `shard_id` = the shard, `count` = new total.
signal truth_shard_collected(shard_id: String, count: int)
## (EG-2) Emitted once when the 5th shard completes the set (the final 회수 카드 beat).
signal truth_shards_complete()
## (v1.1.0 GP-4 §1) Emitted on EVERY 진상 조각 조사 (E-interact), including re-investigation of an
## already-collected shard. NPC 회고 quests listen to THIS (not truth_shard_collected) so a player
## who collected the shard BEFORE taking the quest can still complete it by looking again —
## 부록B #2: shards are never quest-gated; the quest only decorates the investigation.
signal truth_shard_investigated(shard_id: String)

## (EG-2) Collect a truth shard (idempotent). Records it, announces it, and — when this
## completes all five — sets truth_final_seen and fires truth_shards_complete. Returns true iff
## this call newly collected the shard.
func collect_truth_shard(shard_id: String) -> bool:
	if shard_id == "" or truth_shards.get(shard_id, false):
		return false
	truth_shards[shard_id] = true
	var n := truth_shard_count()
	truth_shard_collected.emit(shard_id, n)
	if n >= TRUTH_SHARD_IDS.size() and not truth_final_seen:
		truth_final_seen = true
		truth_shards_complete.emit()
	return true

## (EG-2) True if a given shard has been collected.
func has_truth_shard(shard_id: String) -> bool:
	return bool(truth_shards.get(shard_id, false))

## (EG-2) How many of the five truth shards are collected.
func truth_shard_count() -> int:
	var n := 0
	for sid in TRUTH_SHARD_IDS:
		if truth_shards.get(sid, false):
			n += 1
	return n

## (EG-2) True once all five truth shards are collected (the [돌아선다] gate).
func truth_shards_all() -> bool:
	return truth_shard_count() >= TRUTH_SHARD_IDS.size()

## (EG-2) Reset the run's truth shards (NG+ / new game). The endings_seen honor record is
## NOT touched here (it is lifetime). Called from start_ng_plus / new_game.
func reset_truth_shards() -> void:
	truth_shards.clear()
	truth_final_seen = false

## (EG-1/EG-3) Lifetime honor record of endings seen (E1/E2 → true). NOT reset on NG+ — it
## rides alongside lifetime_recipes. Saved.
var endings_seen: Dictionary = {}
## (EG) Emitted when an ending is first recorded.
signal ending_recorded(ending_id: String)

## (EG-1/EG-3) Record an ending as seen (idempotent, lifetime). `ending_id` ∈ {"E1","E2"}.
func record_ending(ending_id: String) -> void:
	if ending_id == "" or endings_seen.get(ending_id, false):
		return
	endings_seen[ending_id] = true
	ending_recorded.emit(ending_id)

## (EG) True if an ending has ever been seen (lifetime).
func has_ending(ending_id: String) -> bool:
	return bool(endings_seen.get(ending_id, false))


func _ready() -> void:
	_phase = _phase_for(game_time)
	if portal_states.is_empty():
		reset_portals()


func _process(delta: float) -> void:
	if not time_running:
		return
	game_time += delta
	game_time_changed.emit(game_time)
	var p := _phase_for(game_time)
	if p != _phase:
		_phase = p
		day_phase_changed.emit(p)


# ---- time queries ---------------------------------------------------------

## Fraction 0.0..1.0 through the current day cycle.
func day_fraction() -> float:
	return fposmod(game_time, DAY_LENGTH) / DAY_LENGTH


## Integer day count (0-based) since start.
func day_index() -> int:
	return int(floor(game_time / DAY_LENGTH))


## Phase for a given absolute time.
func _phase_for(t: float) -> String:
	var f := fposmod(t, DAY_LENGTH) / DAY_LENGTH
	if f < DAY_END:
		return "day"
	elif f < EVENING_END:
		return "evening"
	elif f < NIGHT_END:
		return "night"
	return "dawn"


## Current phase string.
func phase() -> String:
	return _phase


## True during evening~dawn (the "밤" window when G3 night path is open and the
## world-tree area glows). Day is the only closed window.
func is_night_window() -> bool:
	return _phase != "day"


# ---- Rest Stump time skip -------------------------------------------------

## Jump game_time forward to the start of the NEXT evening (확정 스펙: Rest Stump
## skips to next evening, not next day). If we are already before this day's
## evening, jump to this day's evening; otherwise to the next day's evening.
func skip_to_next_evening() -> void:
	var day_start: float = floor(game_time / DAY_LENGTH) * DAY_LENGTH
	var evening_start: float = day_start + DAY_END * DAY_LENGTH
	if game_time < evening_start:
		game_time = evening_start
	else:
		game_time = evening_start + DAY_LENGTH
	var p := _phase_for(game_time)
	if p != _phase:
		_phase = p
		day_phase_changed.emit(p)
	game_time_changed.emit(game_time)


## Directly set game_time (harness / debug / M5 load) and re-emit phase.
func set_game_time(t: float) -> void:
	game_time = t
	var p := _phase_for(game_time)
	if p != _phase:
		_phase = p
		day_phase_changed.emit(p)
	game_time_changed.emit(game_time)
