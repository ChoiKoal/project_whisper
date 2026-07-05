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

## (L2-5) The Layer-2 속삭임 line (L2-Q1…L2-Q7) runs as a SECOND, independent chain that
## COEXISTS with the L1 line in the quest log. It stays dormant until the player first enters
## Layer 2 (terminal_station calls activate_l2_line()), so the two lines never share one active
## pointer. Events tick whichever of the two active quests they match.
var l2_active_id: String = ""
var l2_progress: int = 0
## id of the L2 chain head (first "L2-" quest), resolved at load.
var _l2_head_id: String = ""


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
	# L1 head = first NON-L2 quest; L2 head = first "L2-" quest (the two coexisting lines).
	for q in _order:
		var qid := String(q["id"])
		if _head_id == "" and not qid.begins_with("L2-"):
			_head_id = qid
		if _l2_head_id == "" and qid.begins_with("L2-"):
			_l2_head_id = qid
	if _head_id == "" and not _order.is_empty():
		_head_id = String(_order[0]["id"])


func _connect_signals() -> void:
	GameState.item_gathered.connect(func(id): _event("item_gathered", id))
	GameState.item_crafted.connect(func(out_id, _rid): _event("item_crafted", out_id))
	GameState.stepping_stone_placed.connect(func(_cell): _event("stepping_stone_placed", "any"))
	GameState.item_used_on_object.connect(func(_item, obj): _event("item_used_on_object", _object_id(obj)))
	GameState.day_phase_changed.connect(func(phase): _event("day_phase_changed", phase))
	GameState.player_entered_area.connect(func(area_id): _event("player_entered_area", area_id))
	GameState.world_tree_planted.connect(func(_cell): _event("world_tree_planted", "any"))
	# (v0.5.0 phase C) home-island quests.
	GameState.portal_reached.connect(func(layer): _event("portal_reached", layer))
	GameState.placed_object_placed.connect(func(_id, _cell): _event("placed_object_placed", "any"))
	# (L2-3) Layer-2 전력 노드 급전 quests (L2-Q3 브리지 / L2-Q7 관제탑). node_id = target.
	if GameState.has_signal("power_node_energized"):
		GameState.power_node_energized.connect(func(node_id): _event("power_node_energized", node_id))


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

## A gameplay signal fired. Tick BOTH coexisting lines (L1 + L2) that match it — each has its
## own active pointer, so a shared signal (e.g. item_gathered) advances whichever line is live.
func _event(sig: String, payload: String) -> void:
	_event_line(sig, payload, false)   # L1 line
	_event_line(sig, payload, true)    # L2 line


func _event_line(sig: String, payload: String, l2: bool) -> void:
	var aid := l2_active_id if l2 else active_id
	if aid == "":
		return
	var q: Dictionary = _by_id.get(aid, {})
	if q.is_empty():
		return
	if String(q.get("signal", "")) != sig:
		return
	if not _target_matches(String(q.get("target", "any")), payload):
		return
	var need := int(q.get("count", 1))
	if l2:
		l2_progress += 1
		quest_progress.emit(aid, min(l2_progress, need), need)
		if l2_progress >= need:
			_complete(aid)
	else:
		progress += 1
		quest_progress.emit(aid, min(progress, need), need)
		if progress >= need:
			_complete(aid)


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
	if id.begins_with("L2-"):
		l2_active_id = id
		l2_progress = 0
	else:
		active_id = id
		progress = 0
	if id != "":
		quest_started.emit(id)
		var need := quest_count(id)
		quest_progress.emit(id, 0, need)


## (L2-5) Activate the Layer-2 속삭임 line on first L2 entry. Idempotent: no-op if the line is
## already active or already finished. The L1 line is untouched — the two coexist in the log.
func activate_l2_line() -> void:
	if _l2_head_id == "":
		return
	if l2_active_id != "":
		return
	# Already fully completed? (any L2 quest done means it was started before.)
	for qid in _by_id.keys():
		if String(qid).begins_with("L2-") and _done.has(qid):
			return
	_start(_l2_head_id)


## (L2-5) The active L2 quest record ({} if the L2 line is dormant/finished).
func l2_active_quest() -> Dictionary:
	return _by_id.get(l2_active_id, {})


func _complete(id: String) -> void:
	_done[id] = true
	quest_completed.emit(id)
	var q: Dictionary = _by_id.get(id, {})
	var nxt := String(q.get("next", ""))
	var l2 := id.begins_with("L2-")
	var old := l2_active_id if l2 else active_id
	if nxt == "":
		if l2:
			l2_active_id = ""
			l2_progress = 0
		else:
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
		# (L2-5) the coexisting Layer-2 line pointer.
		"l2_active_id": l2_active_id,
		"l2_progress": l2_progress,
	}


func from_dict(data: Dictionary) -> void:
	_done.clear()
	for id in data.get("done", []):
		_done[String(id)] = true
	progress = int(data.get("progress", 0))
	active_id = String(data.get("active_id", _head_id))
	# (L2-5) restore the L2 line (dormant "" if the save predates it).
	l2_active_id = String(data.get("l2_active_id", ""))
	l2_progress = int(data.get("l2_progress", 0))
	# Re-announce so a freshly-built HUD reflects restored state.
	if active_id != "":
		quest_started.emit(active_id)
		quest_progress.emit(active_id, min(progress, quest_count(active_id)), quest_count(active_id))
	elif all_completed():
		all_quests_completed.emit()
	if l2_active_id != "":
		quest_started.emit(l2_active_id)
		quest_progress.emit(l2_active_id, min(l2_progress, quest_count(l2_active_id)), quest_count(l2_active_id))


## Reset to a fresh line head (P0) (NG+ / new game). Both lines reset; L2 line goes dormant
## again (re-activated on the next first L2 entry).
func reset() -> void:
	_done.clear()
	progress = 0
	l2_active_id = ""
	l2_progress = 0
	_start(_head_id)


## (v0.5.0 phase C) Jump the active quest directly to `id`, marking the current active quest
## (and any skipped intermediates up to `id`) done. Used by CS-05 to open P2 after the clear
## chain (Q9 finishes with next="" → all_quests_completed; the cutscene then calls this to
## resume the line at P2). Idempotent if already on `id`.
func advance_to(id: String) -> void:
	if id == active_id:
		return
	if not _by_id.has(id):
		push_warning("QuestManager: advance_to unknown quest '%s'" % id)
		return
	# Mark everything before `id` in the authored order as done (so the log reads complete).
	var reached := false
	for q in _order:
		var qid := String(q["id"])
		if qid == id:
			reached = true
			break
		_done[qid] = true
	if active_id != "":
		_done[active_id] = true
	var old := active_id
	_start(id)
	quest_advanced.emit(old, id)
