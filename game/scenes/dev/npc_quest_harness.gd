extends Node
## (v1.1.0 GP-4 §1 + 부록B) npc_quest_harness — the coverage the GP-4 remnant-NPC line demands.
##
## Modeled on interaction_fusion_harness. For each of the six layers it boots the LIVE scene, finds
## the QuestNPC that the session spawned into the gatherable group, and drives the WHOLE sub-chain
## through the REAL paths — never touching QuestManager's activation/advance API directly:
##
##   1. Boot the live scene; find the QuestNPC (gatherable group, not a Cauldron) the session spawned.
##   2. Park the player on a walkable cell ADJACENT to the NPC; run InteractionController._process and
##      assert the NPC IS the resolved E-target (it really joined the gatherable group).
##   3. Simulate E through InteractionController._do_interact() (the exact resolver real play uses) —
##      NOT QuestManager.activate_npc_line() — and assert the NPC's sub-chain went ACTIVE.
##   4. Complete every quest of the chain by emitting the AUTHENTIC gameplay signal it listens to
##      (GameState.item_crafted / placed_object_placed / truth_shard_investigated) — the same events
##      Fusion / placement / TruthShard emit in real play — and assert the pointer advances and the
##      reward is granted (recipe discovered / whisper credited / placeable unlocked / 회고 로그 기록).
##   5. Assert the chain FINISHES (no active id, npc_line_finished true) and re-interaction is a soft
##      no-op (idempotent — no re-activation).
##
## Plus two cross-cutting sub-tests on the home/echo chain:
##   SAVE: mid-chain to_dict()/from_dict() round-trip preserves n_active/n_progress/unlocked_placeables.
##   NG+ : reset() drops every sub-chain + unlocked_placeables to dormant, but 회고 로그(Codex lifetime)
##         survives (부록B #2 — 도감 기록은 run 리셋에도 보존).
##
## Assertions print [PASS]/[FAIL]; exit code = failure count. Reparents under the tree root so
## change_scene_to_file does not free the harness mid-run.

## npckey per layer + the 4-step chain's expected (signal, target) and reward assertion tag.
const LAYERS := [
	{"id": "home",  "path": "res://scenes/world/home_island.tscn",     "scene": "HomeIsland",     "wc": "home",             "key": "echo"},
	{"id": "grove", "path": "res://scenes/world/starting_grove.tscn",  "scene": "StartingGrove",  "wc": "grove",            "key": "oak"},
	{"id": "L2",    "path": "res://scenes/world/terminal_station.tscn","scene": "TerminalStation","wc": "terminal_station", "key": "robot"},
	{"id": "L3",    "path": "res://scenes/world/clockwork_city.tscn",  "scene": "ClockworkCity",  "wc": "clockwork_city",   "key": "guard"},
	{"id": "L4",    "path": "res://scenes/world/mage_tower.tscn",      "scene": "MageTower",      "wc": "mage_tower",       "key": "mage"},
	{"id": "L5",    "path": "res://scenes/world/cathedral.tscn",       "scene": "Cathedral",      "wc": "cathedral",        "key": "saint"},
]

var _tree: SceneTree
var _fail := 0
## quest records keyed by id, read straight from the data file (QuestManager keeps _by_id private).
var _quests: Dictionary = {}
## Reward-observation state for the layer currently under test — written by the npc_reward_granted
## handler (a lambda can't mutate captured locals, so these live on the harness).
var _rw_key := ""
var _rw_recipe := false
var _rw_placeable := ""
var _rw_log := ""

func _ready() -> void:
	_tree = get_tree()
	_load_quests()
	call_deferred("_bootstrap")

## Load quests.json once so the harness can read each step's (signal, target, next) without reaching
## into QuestManager's private _by_id.
func _load_quests() -> void:
	var f := FileAccess.open("res://data/quests.json", FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for q in (parsed as Dictionary).get("quests", []):
		if typeof(q) == TYPE_DICTIONARY:
			_quests[String((q as Dictionary).get("id", ""))] = q

func _bootstrap() -> void:
	get_parent().remove_child(self)
	_tree.root.add_child(self)
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in range(n):
		await _tree.process_frame

func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  — " + detail) if detail != "" else ""])
	if not cond:
		_fail += 1

func _scene_name() -> String:
	return _tree.current_scene.name if _tree.current_scene != null else "<null>"

func _run() -> void:
	print("=== v1.1.0 GP-4 NPC QUEST HARNESS ===")
	for layer in LAYERS:
		await _test_layer(layer)
	await _test_save_roundtrip()
	await _test_ngplus_reset()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	_tree.quit(_fail)


# ---- per-layer full chain via the REAL E path -----------------------------

func _test_layer(layer: Dictionary) -> void:
	var lid: String = layer["id"]
	var key: String = layer["key"]
	print("--- %s: NPC(%s) chain via real E path ---" % [lid, key])
	# Fresh run each layer so QuestManager pointers / inventory / modals don't bleed across scenes.
	SaveManager.new_game()
	WorldContext.current_scene = layer["wc"]
	_tree.change_scene_to_file(layer["path"])
	await _frames(16)
	if _scene_name() != layer["scene"]:
		_check("%s: scene booted" % lid, false, _scene_name())
		return

	var root := _tree.current_scene
	var interaction := root.get_node_or_null("Interaction") as InteractionController
	var player := root.get_node_or_null("YSortLayer/Player") as Player
	var ground := root.get_node_or_null("Ground") as TileMapLayer
	_check("%s: Interaction/Player/Ground present" % lid,
		interaction != null and player != null and ground != null)
	if interaction == null or player == null or ground == null:
		return

	# 1. The session spawned a QuestNPC for this layer's key (gatherable group, not a Cauldron).
	var npc := _find_npc(key)
	_check("%s: QuestNPC(%s) spawned into the gatherable group" % [lid, key], npc != null)
	if npc == null:
		return
	_check("%s: NPC object_id = npc_%s" % [lid, key], String(npc.object_id) == "npc_" + key,
		"object_id=%s" % String(npc.object_id))

	# 2. Park the player on a walkable cell adjacent to the NPC → it resolves as the E-target.
	var npc_cell := ground.local_to_map(ground.to_local(npc.target_point()))
	var adj := _adjacent_walkable_cell(npc_cell, ground, npc)
	_check("%s: found adjacent walkable cell to NPC" % lid, adj != Vector2i(-999, -999),
		"npc=%s" % str(npc_cell))
	if adj == Vector2i(-999, -999):
		return
	player.clear_path()
	player.velocity = Vector2.ZERO
	player.global_position = ground.to_global(ground.map_to_local(adj))
	await _frames(2)
	interaction._process(0.016)
	_check("%s: NPC IS the resolved E-target (adjacency)" % lid,
		interaction._target_object == npc, "target=%s" % str(interaction._target_object))

	# 3. E interact through the REAL resolver (NOT QuestManager.activate_npc_line) → sub-chain active.
	_check("%s: sub-chain dormant before E" % lid, QuestManager.npc_active_id(key) == "")
	interaction._do_interact()
	await _frames(2)
	var head := QuestManager.npc_active_id(key)
	_check("%s: E activates the sub-chain (real path)" % lid, head != "", "active=%s" % head)
	_check("%s: active head is this NPC's Q1" % lid, head == "N-%s-Q1" % key, head)
	# Close the dialog card the NPC opened so the modal lock doesn't wedge the next step.
	if npc.has_method("_close_card"):
		npc._close_card()
	await _frames(2)

	# 4. Complete all four quests by emitting the authentic gameplay signal each listens to.
	_rw_key = key
	_rw_recipe = false
	_rw_placeable = ""
	_rw_log = ""
	if not QuestManager.npc_reward_granted.is_connected(_on_reward):
		QuestManager.npc_reward_granted.connect(_on_reward)

	var chain := ["N-%s-Q1" % key, "N-%s-Q2" % key, "N-%s-Q3" % key, "N-%s-Q4" % key]
	for i in range(chain.size()):
		var qid: String = chain[i]
		_check("%s: %s is active before its step" % [lid, qid], QuestManager.npc_active_id(key) == qid,
			"active=%s" % QuestManager.npc_active_id(key))
		var q: Dictionary = _quest(qid)
		_emit_step_signal(q)
		await _frames(2)
		var nxt := String(q.get("next", ""))
		if nxt != "":
			_check("%s: %s → advanced to %s" % [lid, qid, nxt], QuestManager.npc_active_id(key) == nxt,
				"now=%s" % QuestManager.npc_active_id(key))
		else:
			_check("%s: %s → chain finished (no active id)" % [lid, qid],
				QuestManager.npc_active_id(key) == "", "now=%s" % QuestManager.npc_active_id(key))

	# 5. Reward assertions — recipe선공개 / 전용 배치물 해금 / 회고 로그 기록.
	_check("%s: Q1 reward — a recipe was discovered (선공개)" % lid, _rw_recipe)
	_check("%s: Q2 reward — a placeable was unlocked" % lid,
		_rw_placeable != "" and QuestManager.unlocked_placeables.has(_rw_placeable),
		"placeable=%s" % _rw_placeable)
	_check("%s: Q4 reward — 회고 로그 recorded in Codex (부록B 부가 보상)" % lid,
		_rw_log != "" and Codex.truth_log_count() > 0, "log=%s" % _rw_log)

	# 6. Chain finished + idempotent re-interaction (no re-activation).
	_check("%s: npc_line_finished true after full chain" % lid, QuestManager.npc_line_finished(key))
	interaction._do_interact()
	await _frames(2)
	_check("%s: re-E after finish stays dormant (idempotent)" % lid, QuestManager.npc_active_id(key) == "")
	if npc.has_method("_close_card"):
		npc._close_card()
	await _frames(2)


# ---- SAVE round-trip (echo chain, mid-progress) ---------------------------

func _test_save_roundtrip() -> void:
	print("--- SAVE: NPC sub-chain round-trips through to_dict/from_dict ---")
	SaveManager.new_game()
	await _frames(2)
	# Activate echo + complete Q1 (recipe) and Q2 (placeable unlock) so n_active AND an unlocked
	# placeable are both non-empty at save time; leave the pointer parked on Q3.
	QuestManager.activate_npc_line("echo")
	_emit_step_signal(_quest("N-echo-Q1"))   # → advances to Q2 (recipe granted)
	_emit_step_signal(_quest("N-echo-Q2"))   # → advances to Q3 (placeable unlocked)
	var active_before := QuestManager.npc_active_id("echo")
	var unlocked_before := QuestManager.unlocked_placeables.duplicate()
	_check("SAVE: echo active mid-chain before save", active_before == "N-echo-Q3", active_before)
	_check("SAVE: a placeable is unlocked before save", unlocked_before.size() > 0,
		"n=%d" % unlocked_before.size())

	var snap := QuestManager.to_dict()
	_check("SAVE: snapshot carries n_active", (snap.get("n_active", {}) as Dictionary).has("echo"))
	# Corrupt live state, then restore — proves from_dict actually rebuilds it (not a no-op pass-through).
	QuestManager.n_active.clear()
	QuestManager.n_progress.clear()
	QuestManager.unlocked_placeables.clear()
	QuestManager.from_dict(snap)
	await _frames(2)
	_check("SAVE: n_active restored", QuestManager.npc_active_id("echo") == active_before,
		"restored=%s" % QuestManager.npc_active_id("echo"))
	_check("SAVE: unlocked_placeables restored",
		QuestManager.unlocked_placeables.size() == unlocked_before.size() and unlocked_before.size() > 0,
		"n=%d" % QuestManager.unlocked_placeables.size())


# ---- NG+ reset (부록B: run 리셋, 도감 lifetime 보존) -------------------------

func _test_ngplus_reset() -> void:
	print("--- NG+: reset() drops sub-chains + placeables but keeps 도감 로그 ---")
	SaveManager.new_game()
	await _frames(2)
	# Run the echo chain to completion so a 회고 로그 is recorded + a placeable unlocked.
	QuestManager.activate_npc_line("echo")
	for qid in ["N-echo-Q1", "N-echo-Q2", "N-echo-Q3", "N-echo-Q4"]:
		_emit_step_signal(_quest(qid))
		await _frames(1)
	var log_recorded := Codex.truth_log_count() > 0
	var had_unlock := QuestManager.unlocked_placeables.size() > 0
	_check("NG+: pre-reset — echo finished", QuestManager.npc_line_finished("echo"))
	_check("NG+: pre-reset — a placeable was unlocked", had_unlock)
	_check("NG+: pre-reset — 회고 로그 recorded", log_recorded)

	var logs_before := Codex.truth_log_count()
	QuestManager.reset()
	await _frames(2)
	_check("NG+: reset drops echo sub-chain to dormant", QuestManager.npc_active_id("echo") == "")
	_check("NG+: reset clears unlocked_placeables", QuestManager.unlocked_placeables.is_empty())
	_check("NG+: reset re-seeds the L1 head (not an N- quest)",
		not QuestManager.active_id.begins_with("N-") and QuestManager.active_id != "",
		"head=%s" % QuestManager.active_id)
	_check("NG+: 도감 로그 survives reset (lifetime, 부록B)", Codex.truth_log_count() == logs_before)


# ---- helpers --------------------------------------------------------------

## npc_reward_granted observer for the layer under test (kind ∈ recipe/whisper/placeable/log).
func _on_reward(k: String, kind: String, detail: String) -> void:
	if k != _rw_key:
		return
	match kind:
		"recipe": _rw_recipe = true
		"placeable": _rw_placeable = detail
		"log": _rw_log = detail

## The QuestNPC the session spawned for `key` (gatherable group, has on_interact but can't gather,
## and is NOT a Cauldron). Matches by object_id so a scene with several NPCs stays unambiguous.
func _find_npc(key: String) -> Node:
	for n in _tree.get_nodes_in_group("gatherable"):
		if n is QuestNPC and str(n.get("object_id")) == "npc_" + key:
			return n
	return null

## A walkable cell in the NPC's 8-neighbourhood the player can stand on so the NPC (and only it)
## resolves as the E-target. Skips any neighbour occupied by ANOTHER gatherable — else the player
## would be parked on top of a resource node that wins the nearest-adjacent resolution (real bug this
## caught in L3, where a debris pickup sat one cell off the guard NPC). (-999,-999) if none qualifies.
func _adjacent_walkable_cell(anchor: Vector2i, ground: TileMapLayer, npc: Node) -> Vector2i:
	var loader := _tree.current_scene.get_node_or_null("Ground") as MapLoader
	var occupied := {}
	for n in _tree.get_nodes_in_group("gatherable"):
		if n == npc or not n.has_method("target_point"):
			continue
		occupied[ground.local_to_map(ground.to_local(n.target_point()))] = true
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	for d in dirs:
		var cell := anchor + d
		if occupied.has(cell):
			continue
		if loader != null and loader.has_method("is_cell_walkable"):
			if loader.is_cell_walkable(cell):
				return cell
		else:
			return cell
	return Vector2i(-999, -999)

## Quest record by id, from the data file loaded at boot.
func _quest(qid: String) -> Dictionary:
	return _quests.get(qid, {})

## Emit the SAME gameplay signal real play emits for this quest's step, so the completion travels the
## authentic QuestManager listener path (not a QuestManager API call).
##   item_crafted        ← Fusion emits on a successful fuse.
##   placed_object_placed ← InteractionController emits on a placement.
##   truth_shard_investigated ← TruthShard/WorldTree emit on 조사.
func _emit_step_signal(q: Dictionary) -> void:
	var sig := String(q.get("signal", ""))
	var target := String(q.get("target", "any"))
	match sig:
		"item_crafted":
			GameState.item_crafted.emit(target if target != "any" else "I3", "harness")
		"placed_object_placed":
			GameState.placed_object_placed.emit("I3", Vector2i.ZERO)
		"truth_shard_investigated":
			GameState.truth_shard_investigated.emit(target)
		_:
			pass
