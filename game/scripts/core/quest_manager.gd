extends Node
## QuestManager — global autoload. Drives the v0.4.0-C "속삭임" quest line (Q1-Q9).
##
## Design:
##   - Loads data/quests.json into an ordered list + id->record map.
##   - Tracks ONE active quest at a time (`active_id`) plus `progress` toward its
##     `count`. The chain is linear: each quest's `next` names the quest that
##     becomes active on completion; "" means the line is finished.
##   - Listens to EXISTING gameplay signals (GameState.item_gathered / item_crafted /
##     stepping_stone_placed / item_used_on_object / day_phase_changed /
##     player_entered_area / world_tree_planted). A quest only counts a signal that
##     matches its `signal` name AND its `target` filter ("any"/"" = no filter).
##   - Emits its own signals for the HUD / quest log:
##       quest_started(id)            — a quest became active (also on load/reset)
##       quest_progress(id, cur, need)— progress ticked (cur/need countable display)
##       quest_completed(id)          — a quest hit its count; `next` is about to start
##       quest_advanced(old, new)     — active quest changed old->new
##       all_quests_completed()       — the final quest completed (Q9 → clear)
##   - Persists {active_id, progress, done:[ids]} in the save; NG+ / new_game reset
##     to a fresh Q1 line.
##
## Headless-safe: pure autoload, no scene dependency. The signal hooks fire whether or
## not a world scene exists, so the harness can drive Q1→Q9 programmatically.

signal quest_started(id: String)
signal quest_progress(id: String, cur: int, need: int)
signal quest_completed(id: String)
signal quest_advanced(old_id: String, new_id: String)
signal all_quests_completed()

const QUESTS_PATH := "res://data/quests.json"

## Ordered quest records as loaded.
var _order: Array = []
## id -> quest record Dictionary.
var _by_id: Dictionary = {}
## id of the first quest (chain head).
var _head_id: String = ""

## Currently active quest id ("" = none / line finished).
var active_id: String = ""
## Progress toward the active quest's count.
var progress: int = 0
## Set of completed quest ids (id -> true) for the quest log.
var _done: Dictionary = {}


func _ready() -> void:
	_load()
	_connect_signals()
	# Start the line if nothing has set state yet (a load will overwrite this).
	if active_id == "" and _done.is_empty():
		_start(_head_id)


func _load() -> void:
	var f := FileAccess.open(QUESTS_PATH, FileAccess.READ)
	if f == null:
		push_error("QuestManager: cannot open %s" % QUESTS_PATH)
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("quests"):
		push_error("QuestManager: malformed quests.json")
		return
	_order.clear()
	_by_id.clear()
	for q in parsed["quests"]:
		if typeof(q) != TYPE_DICTIONARY or not q.has("id"):
			continue
		_order.append(q)
		_by_id[String(q["id"])] = q
	if not _order.is_empty():
		_head_id = String(_order[0]["id"])


func _connect_signals() -> void:
	GameState.item_gathered.connect(func(id): _event("item_gathered", id))
	GameState.item_crafted.connect(func(out_id, _rid): _event("item_crafted", out_id))
	GameState.stepping_stone_placed.connect(func(_cell): _event("stepping_stone_placed", "any"))
	GameState.item_used_on_object.connect(func(_item, obj): _event("item_used_on_object", _object_id(obj)))
	GameState.day_phase_changed.connect(func(phase): _event("day_phase_changed", phase))
	GameState.player_entered_area.connect(func(area_id): _event("player_entered_area", area_id))
	GameState.world_tree_planted.connect(func(_cell): _event("world_tree_planted", "any"))


## Best-effort object id for a used-on target (bush_dry etc.).
func _object_id(obj: Node) -> String:
	if obj == null:
		return ""
	if obj.has_method("get") and obj.get("object_id") != null:
		var oid := String(obj.get("object_id"))
		if oid != "":
			return oid
	return ""


# ==== event routing ========================================================

## A gameplay signal fired. If it matches the active quest, tick progress.
func _event(sig: String, payload: String) -> void:
	if active_id == "":
		return
	var q: Dictionary = _by_id.get(active_id, {})
	if q.is_empty():
		return
	if String(q.get("signal", "")) != sig:
		return
	if not _target_matches(String(q.get("target", "any")), payload):
		return
	progress += 1
	var need := int(q.get("count", 1))
	quest_progress.emit(active_id, min(progress, need), need)
	if progress >= need:
		_complete(active_id)


## True if `payload` satisfies the quest's target filter. "any"/"" = anything.
func _target_matches(target: String, payload: String) -> bool:
	if target == "" or target == "any":
		return true
	# Item targets may be aliased (D06->I4); compare canonical forms when both look
	# like item ids (leading D/I/T). Non-item targets (phase names, object ids) match raw.
	if _looks_like_item(target) and _looks_like_item(payload):
		return ItemDB.resolve_id(payload) == ItemDB.resolve_id(target)
	return payload == target


func _looks_like_item(s: String) -> bool:
	return s.length() >= 2 and s[0] in ["D", "I", "T"] and s[1].is_valid_int()


# ==== progression ==========================================================

func _start(id: String) -> void:
	active_id = id
	progress = 0
	if id != "":
		quest_started.emit(id)
		var need := quest_count(id)
		quest_progress.emit(id, 0, need)


func _complete(id: String) -> void:
	_done[id] = true
	quest_completed.emit(id)
	var q: Dictionary = _by_id.get(id, {})
	var nxt := String(q.get("next", ""))
	var old := active_id
	if nxt == "":
		active_id = ""
		progress = 0
		quest_advanced.emit(old, "")
		all_quests_completed.emit()
	else:
		_start(nxt)
		quest_advanced.emit(old, nxt)


# ==== public queries (HUD / quest log) =====================================

## The active quest record ({} if none).
func active_quest() -> Dictionary:
	return _by_id.get(active_id, {})


## Whisper text of a quest id ("" if unknown).
func whisper(id: String) -> String:
	return String(_by_id.get(id, {}).get("whisper", ""))


## Required count for a quest id (1 default).
func quest_count(id: String) -> int:
	return int(_by_id.get(id, {}).get("count", 1))


## Sub-steps display list for a quest (Q8), or [] if none.
func sub_steps(id: String) -> Array:
	return _by_id.get(id, {}).get("sub_steps", [])


## Whether every quest in the line is done (line finished).
func all_completed() -> bool:
	return active_id == "" and not _done.is_empty()


## True if `id` has been completed.
func is_done(id: String) -> bool:
	return _done.has(id)


## Ordered quest ids (for the quest log).
func all_ids() -> Array:
	var out: Array = []
	for q in _order:
		out.append(String(q["id"]))
	return out


# ==== persistence ==========================================================

func to_dict() -> Dictionary:
	return {
		"active_id": active_id,
		"progress": progress,
		"done": _done.keys(),
	}


func from_dict(data: Dictionary) -> void:
	_done.clear()
	for id in data.get("done", []):
		_done[String(id)] = true
	progress = int(data.get("progress", 0))
	active_id = String(data.get("active_id", _head_id))
	# Re-announce so a freshly-built HUD reflects restored state.
	if active_id != "":
		quest_started.emit(active_id)
		quest_progress.emit(active_id, min(progress, quest_count(active_id)), quest_count(active_id))
	elif all_completed():
		all_quests_completed.emit()


## Reset to a fresh Q1 line (NG+ / new game).
func reset() -> void:
	_done.clear()
	progress = 0
	_start(_head_id)
