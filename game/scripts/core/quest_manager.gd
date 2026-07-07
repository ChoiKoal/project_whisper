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

## (L3-5) The Layer-3 속삭임 line (L3-Q1…L3-Q7) is a THIRD independent chain coexisting with the
## L1 + L2 lines in the quest log. Dormant until first Layer-3 entry (clockwork_city calls
## activate_l3_line()). Mirrors the L2 line exactly with an "L3-" prefix.
var l3_active_id: String = ""
var l3_progress: int = 0
## id of the L3 chain head (first "L3-" quest), resolved at load.
var _l3_head_id: String = ""

## (L4-5) The Layer-4 속삭임 line (L4-Q1…L4-Q7) is a FOURTH independent chain coexisting with the
## L1 + L2 + L3 lines in the quest log. Dormant until first Layer-4 entry (mage_tower calls
## activate_l4_line()). Mirrors the L3 line exactly with an "L4-" prefix.
var l4_active_id: String = ""
var l4_progress: int = 0
## id of the L4 chain head (first "L4-" quest), resolved at load.
var _l4_head_id: String = ""

## (L5-5) The Layer-5 속삭임 line (L5-Q1…L5-Q7) is a FIFTH independent chain coexisting with the
## L1 + L2 + L3 + L4 lines in the quest log. Dormant until first Layer-5 entry (cathedral calls
## activate_l5_line()). Mirrors the L4 line exactly with an "L5-" prefix. 마지막 레이어.
var l5_active_id: String = ""
var l5_progress: int = 0
## id of the L5 chain head (first "L5-" quest), resolved at load.
var _l5_head_id: String = ""

## (v1.1.0 GP-4 §1) NPC 라인 (prefix "N-"). Unlike the five layer lines — one active pointer each —
## the NPC line is a BUNDLE of per-NPC sub-chains that can be active simultaneously (여러 잔재가 동시에
## 의뢰). Keyed by npckey (`N-{npckey}-Q{n}` → npckey). n_active[npckey] = active id, n_progress[npckey]
## = progress toward it. A sub-chain is activated on first QuestNPC interaction (activate_npc_line).
## Rewards (recipes/whisper/placeable/log) dispatch from _grant_reward on completion — see quests.json
## `reward`. 부록B: whisper 보조만 / 회고 의뢰는 진상 조각을 하드게이팅하지 않음(조사만으로 항상 회수).
var n_active: Dictionary = {}
var n_progress: Dictionary = {}
## npckey -> ordered list of that NPC's quest ids (chain), resolved at load.
var _n_chains: Dictionary = {}
## (v1.1.0 GP-4) Emitted when an NPC 퀘스트 완료로 보상이 지급될 때 — HUD/도감 연출 훅.
## kind ∈ {"recipe","whisper","placeable","log"}. detail = 지급 식별자 (recipe id / attr / placeable id / shard).
signal npc_reward_granted(npckey: String, kind: String, detail: String)
## (v1.1.0 GP-4) NPC별 전용 배치물 해금 집합 (placeable id -> true). 배치 시스템이 참조하는 lifetime 아님 —
## run 단위(reset에서 초기화). 도감/HUD가 "해금됨" 표기용.
var unlocked_placeables: Dictionary = {}


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
	# L1 head = first quest NOT prefixed L2-/L3-; L2 head = first "L2-"; L3 head = first "L3-"
	# (three coexisting lines).
	_n_chains.clear()
	for q in _order:
		var qid := String(q["id"])
		# (v1.1.0 GP-4) NPC 라인 quests (prefix "N-") belong to no layer line — group them by npckey.
		if qid.begins_with("N-"):
			var key := _npc_key(qid)
			if key != "":
				if not _n_chains.has(key):
					_n_chains[key] = []
				(_n_chains[key] as Array).append(qid)
			continue
		if _head_id == "" and not qid.begins_with("L2-") and not qid.begins_with("L3-") and not qid.begins_with("L4-") and not qid.begins_with("L5-"):
			_head_id = qid
		if _l2_head_id == "" and qid.begins_with("L2-"):
			_l2_head_id = qid
		if _l3_head_id == "" and qid.begins_with("L3-"):
			_l3_head_id = qid
		if _l4_head_id == "" and qid.begins_with("L4-"):
			_l4_head_id = qid
		if _l5_head_id == "" and qid.begins_with("L5-"):
			_l5_head_id = qid
	if _head_id == "" and not _order.is_empty():
		# Guard: never seed the L1 head with an "N-" quest even if it sorts first.
		for q2 in _order:
			var q2id := String(q2["id"])
			if not q2id.begins_with("N-"):
				_head_id = q2id
				break


## (v1.1.0 GP-4) Extract npckey from an "N-{npckey}-Q{n}" id ("" if malformed).
## e.g. "N-oak-Q1" -> "oak", "N-robot2-Q3" -> "robot2".
func _npc_key(qid: String) -> String:
	if not qid.begins_with("N-"):
		return ""
	var rest := qid.substr(2)   # drop "N-"
	var dash := rest.rfind("-")
	if dash <= 0:
		return ""
	return rest.substr(0, dash)


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
	# (v1.1.0 GP-4) NPC 회고 의뢰 completion listens to truth_shard_investigated (EVERY 조사, re-looks
	# included) NOT truth_shard_collected — so a player who collected the shard before taking the
	# quest can still finish it by looking again (부록B #2).
	if GameState.has_signal("truth_shard_investigated"):
		GameState.truth_shard_investigated.connect(func(sid): _event("truth_shard_investigated", sid))


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
	_event_line(sig, payload, 1)   # L1 line
	_event_line(sig, payload, 2)   # L2 line
	_event_line(sig, payload, 3)   # (L3-5) L3 line
	_event_line(sig, payload, 4)   # (L4-5) L4 line
	_event_line(sig, payload, 5)   # (L5-5) L5 line
	_event_npc(sig, payload)       # (v1.1.0 GP-4) NPC 라인 (all active sub-chains)


## (v1.1.0 GP-4) Tick every active NPC sub-chain that matches this signal+target. Iterates a copied
## key list because _complete() may mutate n_active (advance/finish) mid-loop.
func _event_npc(sig: String, payload: String) -> void:
	for key in n_active.keys().duplicate():
		var aid := String(n_active.get(key, ""))
		if aid == "":
			continue
		var q: Dictionary = _by_id.get(aid, {})
		if q.is_empty():
			continue
		if String(q.get("signal", "")) != sig:
			continue
		if not _target_matches(String(q.get("target", "any")), payload):
			continue
		var need := int(q.get("count", 1))
		var cur := int(n_progress.get(key, 0)) + 1
		n_progress[key] = cur
		quest_progress.emit(aid, min(cur, need), need)
		if cur >= need:
			_complete(aid)


func _event_line(sig: String, payload: String, line: int) -> void:
	var aid := active_id
	if line == 2:
		aid = l2_active_id
	elif line == 3:
		aid = l3_active_id
	elif line == 4:
		aid = l4_active_id
	elif line == 5:
		aid = l5_active_id
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
	if line == 2:
		l2_progress += 1
		quest_progress.emit(aid, min(l2_progress, need), need)
		if l2_progress >= need:
			_complete(aid)
	elif line == 3:
		l3_progress += 1
		quest_progress.emit(aid, min(l3_progress, need), need)
		if l3_progress >= need:
			_complete(aid)
	elif line == 4:
		l4_progress += 1
		quest_progress.emit(aid, min(l4_progress, need), need)
		if l4_progress >= need:
			_complete(aid)
	elif line == 5:
		l5_progress += 1
		quest_progress.emit(aid, min(l5_progress, need), need)
		if l5_progress >= need:
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
	if id.begins_with("N-"):
		var key := _npc_key(id)
		if key != "":
			n_active[key] = id
			n_progress[key] = 0
		if id != "":
			quest_started.emit(id)
			quest_progress.emit(id, 0, quest_count(id))
		return
	if id.begins_with("L2-"):
		l2_active_id = id
		l2_progress = 0
	elif id.begins_with("L3-"):
		l3_active_id = id
		l3_progress = 0
	elif id.begins_with("L4-"):
		l4_active_id = id
		l4_progress = 0
	elif id.begins_with("L5-"):
		l5_active_id = id
		l5_progress = 0
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


## (L3-5) Activate the Layer-3 속삭임 line on first L3 entry. Idempotent: no-op if the line is
## already active or already finished. The L1/L2 lines are untouched — the three coexist.
func activate_l3_line() -> void:
	if _l3_head_id == "":
		return
	if l3_active_id != "":
		return
	for qid in _by_id.keys():
		if String(qid).begins_with("L3-") and _done.has(qid):
			return
	_start(_l3_head_id)


## (L3-5) The active L3 quest record ({} if the L3 line is dormant/finished).
func l3_active_quest() -> Dictionary:
	return _by_id.get(l3_active_id, {})


## (L4-5) Activate the Layer-4 속삭임 line on first L4 entry. Idempotent: no-op if the line is
## already active or already finished. The L1/L2/L3 lines are untouched — the four coexist.
func activate_l4_line() -> void:
	if _l4_head_id == "":
		return
	if l4_active_id != "":
		return
	for qid in _by_id.keys():
		if String(qid).begins_with("L4-") and _done.has(qid):
			return
	_start(_l4_head_id)


## (L4-5) The active L4 quest record ({} if the L4 line is dormant/finished).
func l4_active_quest() -> Dictionary:
	return _by_id.get(l4_active_id, {})


## (L5-5) Activate the Layer-5 속삭임 line on first L5 entry. Idempotent: no-op if the line is
## already active or already finished. The L1/L2/L3/L4 lines are untouched — the five coexist.
func activate_l5_line() -> void:
	if _l5_head_id == "":
		return
	if l5_active_id != "":
		return
	for qid in _by_id.keys():
		if String(qid).begins_with("L5-") and _done.has(qid):
			return
	_start(_l5_head_id)


## (L5-5) The active L5 quest record ({} if the L5 line is dormant/finished).
func l5_active_quest() -> Dictionary:
	return _by_id.get(l5_active_id, {})


# ==== NPC line (v1.1.0 GP-4 §1) ============================================

## Activate an NPC's sub-chain on first interaction with its QuestNPC node. Idempotent: no-op if
## the sub-chain is already active OR already fully completed (any of its quests done). Mirrors
## activate_lN_line. Unknown npckey (no such chain in quests.json) → no-op.
func activate_npc_line(npckey: String) -> void:
	if npckey == "" or not _n_chains.has(npckey):
		return
	if n_active.has(npckey):
		return
	# Already finished this run? (any quest of the chain done ⇒ it was started before.)
	for qid in _n_chains[npckey]:
		if _done.has(qid):
			return
	var chain: Array = _n_chains[npckey]
	if chain.is_empty():
		return
	_start(String(chain[0]))


## The active quest record for an NPC ({} if that NPC's sub-chain is dormant/finished).
func npc_active_quest(npckey: String) -> Dictionary:
	return _by_id.get(String(n_active.get(npckey, "")), {})


## The active quest id for an NPC ("" if dormant/finished).
func npc_active_id(npckey: String) -> String:
	return String(n_active.get(npckey, ""))


## True if this NPC's whole sub-chain is finished (was active, now no active id, ≥1 done).
func npc_line_finished(npckey: String) -> bool:
	if n_active.has(npckey):
		return false
	if not _n_chains.has(npckey):
		return false
	for qid in _n_chains[npckey]:
		if _done.has(qid):
			return true
	return false


## Known NPC keys (from quests.json chains).
func npc_keys() -> Array:
	return _n_chains.keys()


## Dispatch an NPC quest reward. reward = {recipes:[...], whisper:{attr,amt}, placeable:id, log:{...}}.
## 부록B #1: whisper is 보조 only (small amounts) — never the sole supply. 부록B #2: `log` never gates
## the shard (the shard is collected by investigation regardless); it just records extra 도감 text.
## Every field is optional; a missing/empty reward is a no-op (backward-compatible with 5 layer lines).
func _grant_reward(npckey: String, reward: Variant) -> void:
	if typeof(reward) != TYPE_DICTIONARY:
		return
	var r: Dictionary = reward
	# Recipe unlocks — 힌트 게이지 우회 선공개.
	for rid in r.get("recipes", []):
		var rid_s := String(rid)
		if rid_s != "" and typeof(Codex) != TYPE_NIL and Codex.has_method("discover_recipe"):
			Codex.discover_recipe(rid_s)
			npc_reward_granted.emit(npckey, "recipe", rid_s)
	# Whisper 소량 (보조 공급).
	var w: Dictionary = r.get("whisper", {})
	if typeof(w) == TYPE_DICTIONARY and not w.is_empty():
		var attr := String(w.get("attr", ""))
		var amt := int(w.get("amt", 0))
		if amt > 0 and typeof(WhisperCurrency) != TYPE_NIL:
			match attr:
				"energy":
					if WhisperCurrency.has_method("add_energy"): WhisperCurrency.add_energy(amt)
				"mana":
					if WhisperCurrency.has_method("add_mana"): WhisperCurrency.add_mana(amt)
				"vita":
					if WhisperCurrency.has_method("add_vita"): WhisperCurrency.add_vita(amt)
			if attr != "":
				npc_reward_granted.emit(npckey, "whisper", attr)
	# 전용 배치물 해금 (run-단위; 도감/HUD 표기용).
	var pl := String(r.get("placeable", ""))
	if pl != "":
		unlocked_placeables[pl] = true
		npc_reward_granted.emit(npckey, "placeable", pl)
	# 도감 기록 (회고 로그) — 진상 조각과 별개의 부가 텍스트. shard_id는 canonical과 겹치지 않는 npc id로.
	var lg: Dictionary = r.get("log", {})
	if typeof(lg) == TYPE_DICTIONARY and not lg.is_empty():
		var lid := String(lg.get("id", ""))
		if lid != "" and typeof(Codex) != TYPE_NIL and Codex.has_method("record_truth_log"):
			Codex.record_truth_log(lid, String(lg.get("title", "")), String(lg.get("text", "")))
			npc_reward_granted.emit(npckey, "log", lid)


func _complete(id: String) -> void:
	_done[id] = true
	quest_completed.emit(id)
	var q: Dictionary = _by_id.get(id, {})
	var nxt := String(q.get("next", ""))
	# (v1.1.0 GP-4) NPC 라인: grant the reward, then advance the per-NPC sub-chain pointer.
	if id.begins_with("N-"):
		var key := _npc_key(id)
		_grant_reward(key, q.get("reward", {}))
		var old_n := String(n_active.get(key, ""))
		if nxt == "":
			n_active.erase(key)
			n_progress.erase(key)
			quest_advanced.emit(old_n, "")
		else:
			_start(nxt)
			quest_advanced.emit(old_n, nxt)
		return
	var l2 := id.begins_with("L2-")
	var l3 := id.begins_with("L3-")
	var l4 := id.begins_with("L4-")
	var l5 := id.begins_with("L5-")
	var old := active_id
	if l2:
		old = l2_active_id
	elif l3:
		old = l3_active_id
	elif l4:
		old = l4_active_id
	elif l5:
		old = l5_active_id
	if nxt == "":
		if l2:
			l2_active_id = ""
			l2_progress = 0
		elif l3:
			l3_active_id = ""
			l3_progress = 0
		elif l4:
			l4_active_id = ""
			l4_progress = 0
		elif l5:
			l5_active_id = ""
			l5_progress = 0
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
		# (L3-5) the coexisting Layer-3 line pointer.
		"l3_active_id": l3_active_id,
		"l3_progress": l3_progress,
		# (L4-5) the coexisting Layer-4 line pointer.
		"l4_active_id": l4_active_id,
		"l4_progress": l4_progress,
		# (L5-5) the coexisting Layer-5 line pointer.
		"l5_active_id": l5_active_id,
		"l5_progress": l5_progress,
		# (v1.1.0 GP-4) NPC 라인 다중 서브체인 포인터 + 해금 배치물 (predates → 빈 Dict).
		"n_active": n_active.duplicate(),
		"n_progress": n_progress.duplicate(),
		"unlocked_placeables": unlocked_placeables.duplicate(),
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
	# (L3-5) restore the L3 line (dormant "" if the save predates it).
	l3_active_id = String(data.get("l3_active_id", ""))
	l3_progress = int(data.get("l3_progress", 0))
	# (L4-5) restore the L4 line (dormant "" if the save predates it).
	l4_active_id = String(data.get("l4_active_id", ""))
	l4_progress = int(data.get("l4_progress", 0))
	# (L5-5) restore the L5 line (dormant "" if the save predates it).
	l5_active_id = String(data.get("l5_active_id", ""))
	l5_progress = int(data.get("l5_progress", 0))
	# (v1.1.0 GP-4) restore NPC sub-chains (predates → empty Dict; keys coerced to String).
	n_active.clear()
	for k in (data.get("n_active", {}) as Dictionary):
		n_active[String(k)] = String((data["n_active"] as Dictionary)[k])
	n_progress.clear()
	for k2 in (data.get("n_progress", {}) as Dictionary):
		n_progress[String(k2)] = int((data["n_progress"] as Dictionary)[k2])
	unlocked_placeables.clear()
	for k3 in (data.get("unlocked_placeables", {}) as Dictionary):
		unlocked_placeables[String(k3)] = true
	# Re-announce so a freshly-built HUD reflects restored state.
	if active_id != "":
		quest_started.emit(active_id)
		quest_progress.emit(active_id, min(progress, quest_count(active_id)), quest_count(active_id))
	elif all_completed():
		all_quests_completed.emit()
	if l2_active_id != "":
		quest_started.emit(l2_active_id)
		quest_progress.emit(l2_active_id, min(l2_progress, quest_count(l2_active_id)), quest_count(l2_active_id))
	if l3_active_id != "":
		quest_started.emit(l3_active_id)
		quest_progress.emit(l3_active_id, min(l3_progress, quest_count(l3_active_id)), quest_count(l3_active_id))
	if l4_active_id != "":
		quest_started.emit(l4_active_id)
		quest_progress.emit(l4_active_id, min(l4_progress, quest_count(l4_active_id)), quest_count(l4_active_id))
	if l5_active_id != "":
		quest_started.emit(l5_active_id)
		quest_progress.emit(l5_active_id, min(l5_progress, quest_count(l5_active_id)), quest_count(l5_active_id))
	# (v1.1.0 GP-4) re-announce every active NPC sub-quest.
	for key in n_active.keys():
		var nid := String(n_active[key])
		if nid != "":
			quest_started.emit(nid)
			quest_progress.emit(nid, min(int(n_progress.get(key, 0)), quest_count(nid)), quest_count(nid))


## Reset to a fresh line head (P0) (NG+ / new game). Both lines reset; L2 line goes dormant
## again (re-activated on the next first L2 entry).
func reset() -> void:
	_done.clear()
	progress = 0
	l2_active_id = ""
	l2_progress = 0
	l3_active_id = ""
	l3_progress = 0
	l4_active_id = ""
	l4_progress = 0
	l5_active_id = ""
	l5_progress = 0
	# (v1.1.0 GP-4) NPC 서브체인 전부 dormant + 해금 배치물 초기화 (NG+/새 게임 — 도감 lifetime은 Codex가 별도 보존).
	n_active.clear()
	n_progress.clear()
	unlocked_placeables.clear()
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
