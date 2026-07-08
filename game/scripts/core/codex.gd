extends Node
## Codex — global autoload, discovery tracker (도감 state).
##
## Tracks which items and recipes the player has discovered:
##   - an item is "discovered" once gathered or crafted at least once,
##   - a recipe is "discovered" once successfully fused.
## Also drives the hint gauge (recipes-v1.md §4): each failed fusion attempt
## increments a counter; at HINT_THRESHOLD (5) it auto-reveals ONE ingredient of
## one still-undiscovered recipe (a "silhouette" hint) and resets the gauge.
##
## All discovery state lives in plain Dictionaries/Arrays so M5 can serialize it
## via `to_dict()` / `from_dict()` without touching gameplay code.

signal item_discovered(id: String)
signal recipe_discovered(id: String)
## Emitted when the hint gauge changes (0..HINT_THRESHOLD) so UI can draw dots.
signal hint_gauge_changed(value: int)
## Emitted when a gauge reveal advances a recipe's hint stage.
## `recipe_id` = target recipe, `ingredient_id` = the revealed input id ("" until stage 3),
## `stage` = 1 (result silhouette + poetic name) / 2 (ingredient categories) / 3 (one ingredient).
signal hint_revealed(recipe_id: String, ingredient_id: String, stage: int)

## Failed fusions needed to advance ONE hint stage (v1.1.0 GP-2: was a single 5-fail reveal;
## now each threshold hit advances the *result-first* hint by one stage, 1→2→3).
const HINT_THRESHOLD := 3

## Highest hint stage (§2.2): 1 result-first, 2 ingredient categories, 3 one ingredient.
const HINT_STAGE_MAX := 3

## Canonical item ids discovered (as a set: id -> true).
var _items: Dictionary = {}
## Recipe ids discovered (id -> true).
var _recipes: Dictionary = {}
## Failed-fusion counter, 0..HINT_THRESHOLD.
var _hint_gauge: int = 0
## (v1.1.0 GP-2) recipe_id -> {stage:int, ingredient:String}. Result-first staged hints:
##   stage 1 = result silhouette + poetic name (§2.2), 2 = ingredient categories, 3 = one ingredient.
## `ingredient` is only filled at stage 3. Legacy saves (String value) migrate to {stage:3, ...}.
var _hints: Dictionary = {}
## Set of already-attempted failed pairs (order-independent key -> true). Used to
## suppress brute-force gauge farming: repeating an already-failed pair does NOT
## increment the gauge (economy-design §B-3 "중복 실패 미적립").
var _attempted_pairs: Dictionary = {}

## (EG-2) 도감 「기록(진상)」 탭 — collected truth-shard logs, keyed shard_id → full log text. Set
## when a shard is investigated (TruthShard.on_interact → record_truth_log). The GAMEPLAY gate
## (돌아선다) reads GameState.truth_shards; this holds the readable TEXT for re-viewing in the 도감.
## Lifetime honor: these persist even across NG+ (the shard FLAGS reset, but "이미 읽은 조각" text
## stays available — 설계 §5 추가2 "도감 기록 탭의 조각 열람 이력은 명예 보존").
var _truth_logs: Dictionary = {}
## (EG-2) True once the 5th shard's final 회수 카드 (§3.1) text should be shown — mirrors
## GameState.truth_final_seen but preserved lifetime here for the 기록 탭 재열람.
var _truth_final_seen: bool = false
## (EG-2) The final 회수 카드 text (§3.1) shown when all five shards are collected.
const TRUTH_FINAL_CARD := "선배들 역시 '다음 세계'라는 임무를 받았을 뿐. 악의는 없었다. 시스템이 그렇게 설계돼 있었다. 그리고 너에게도 같은 임무가 내려와 있다 — '제0세계를 완성하라'."

## (EG-2) Record a truth-shard log (idempotent-ish: overwrites with the same text). `title` is a
## short label for the 도감 row (e.g. "세계수의 잎"). Marks the final card seen when all five land.
signal truth_log_recorded(shard_id: String)
func record_truth_log(shard_id: String, title: String, text: String) -> void:
	if shard_id == "":
		return
	_truth_logs[shard_id] = {"title": title, "text": text}
	# (v1.1.0 GP-4) NPC 회고 logs (non-canonical ids like "npc_oak") also land here; only the
	# CANONICAL five may trip the final card, so NPC logs can never fake-complete the set.
	var canon := 0
	for sid in GameState.TRUTH_SHARD_IDS:
		if _truth_logs.has(sid):
			canon += 1
	if canon >= GameState.TRUTH_SHARD_IDS.size():
		_truth_final_seen = true
	truth_log_recorded.emit(shard_id)

## (EG-2) All recorded truth logs → [{id,title,text}]. Canonical shards first (narrative order),
## then any extra logs (v1.1.0 GP-4 NPC 회고 기록) in insertion order. For the 도감 탭.
func truth_logs_ordered() -> Array:
	var out: Array = []
	for sid in GameState.TRUTH_SHARD_IDS:
		if _truth_logs.has(sid):
			var e: Dictionary = _truth_logs[sid]
			out.append({"id": sid, "title": String(e.get("title", "")), "text": String(e.get("text", ""))})
	for sid in _truth_logs.keys():
		if String(sid) in GameState.TRUTH_SHARD_IDS:
			continue
		var e2: Dictionary = _truth_logs[sid]
		out.append({"id": String(sid), "title": String(e2.get("title", "")), "text": String(e2.get("text", ""))})
	return out

func truth_log_count() -> int:
	return _truth_logs.size()

func truth_final_seen() -> bool:
	return _truth_final_seen


# ---- (CQ-5 G14) cutscene 재감상 registry ----------------------------------
## 도감 「기록」 탭의 컷신 재감상 메뉴 — which cutscenes the player has SEEN (id -> true), so they
## can be replayed. Lifetime honor: preserved across NG+ (like truth logs). The canonical list +
## display titles live here; cutscene code calls mark_cutscene_seen(id) when a beat first plays.
const CUTSCENE_CATALOG := [
	{"id": "CS-01", "title": "각성 — 제0세계에서 눈뜨다"},
	{"id": "CS-02", "title": "첫 입장 — 시작의 숲 연못가"},
	{"id": "CS-03", "title": "세계수 앞에서"},
	{"id": "CS-04", "title": "정화 — 어린 세계수를 되심다"},
	{"id": "CS-05", "title": "귀환과 점화"},
	{"id": "E1", "title": "엔딩 「완성」"},
	{"id": "E2", "title": "엔딩 「속삭임」"},
]
var _cutscenes_seen: Dictionary = {}
signal cutscene_seen(cutscene_id: String)

## Record that a cutscene has played (idempotent). Emits cutscene_seen on the first time.
func mark_cutscene_seen(cutscene_id: String) -> void:
	if cutscene_id == "" or _cutscenes_seen.get(cutscene_id, false):
		return
	_cutscenes_seen[cutscene_id] = true
	cutscene_seen.emit(cutscene_id)

func is_cutscene_seen(cutscene_id: String) -> bool:
	return bool(_cutscenes_seen.get(cutscene_id, false))

func cutscene_seen_count() -> int:
	return _cutscenes_seen.size()

## The catalog with a `seen` flag on each, in canonical order — for the 재감상 menu.
func cutscenes_ordered() -> Array:
	var out: Array = []
	for e: Dictionary in CUTSCENE_CATALOG:
		var cid := String(e.get("id", ""))
		out.append({"id": cid, "title": String(e.get("title", "")), "seen": is_cutscene_seen(cid)})
	return out


func _ready() -> void:
	# Discovering an item happens on gather (M2 signal) and on craft (fusion UI).
	GameState.item_gathered.connect(_on_item_gathered)


func _on_item_gathered(item_id: String) -> void:
	discover_item(item_id)


# ---- discovery -----------------------------------------------------------

## Record an item as discovered (idempotent). Folds aliases to canonical.
func discover_item(item_id: String) -> void:
	var id := ItemDB.resolve_id(item_id)
	if not ItemDB.has_item(id):
		return
	if _items.has(id):
		return
	_items[id] = true
	item_discovered.emit(id)


## Record a recipe as discovered (idempotent). Also discovers its output item.
func discover_recipe(recipe_id: String) -> void:
	if recipe_id == "" or _recipes.has(recipe_id):
		return
	_recipes[recipe_id] = true
	# A discovered recipe no longer needs a hint.
	_hints.erase(recipe_id)
	recipe_discovered.emit(recipe_id)
	GameState.recipe_discovered.emit(recipe_id)


func is_item_discovered(item_id: String) -> bool:
	return _items.has(ItemDB.resolve_id(item_id))


func is_recipe_discovered(recipe_id: String) -> bool:
	return _recipes.has(recipe_id)


func discovered_item_count() -> int:
	return _items.size()


func discovered_recipe_count() -> int:
	return _recipes.size()


# ---- hint gauge ----------------------------------------------------------

func hint_gauge() -> int:
	return _hint_gauge


## (GP-2) Current hint STAGE for a recipe (0 = no active hint, 1..3 = revealed stage).
func hint_stage(recipe_id: String) -> int:
	var e: Variant = _hints.get(recipe_id, null)
	if e == null:
		return 0
	return int((e as Dictionary).get("stage", 0))


## Revealed ingredient id for a recipe, or "" if not yet at stage 3 / no active hint.
func hint_for_recipe(recipe_id: String) -> String:
	var e: Variant = _hints.get(recipe_id, null)
	if e == null:
		return ""
	return String((e as Dictionary).get("ingredient", ""))


## (GP-2) The output item id whose silhouette+poetic name the stage-1 hint reveals for `recipe_id`.
## "" if the recipe is unknown to RecipeDB.
func hint_output_for_recipe(recipe_id: String) -> String:
	var rec: Dictionary = RecipeDB.get_recipe(recipe_id)
	if rec.is_empty():
		return ""
	return ItemDB.resolve_id(String(rec.get("output", "")))


## (GP-2) The poetic name fragment for a recipe's result (stage-1 hint text). Uses the recipe's
## own `hint` (already poetic) framed as a result whisper. Falls back to a generic fragment.
func hint_poetic_name(recipe_id: String) -> String:
	var rec: Dictionary = RecipeDB.get_recipe(recipe_id)
	if rec.is_empty():
		return "?무언가?"
	var h := String(rec.get("hint", "")).strip_edges()
	if h == "":
		return "?무언가 태어날 수 있다?"
	return "?%s…?" % h


## (GP-2) The two ingredient CATEGORY labels for a recipe (stage-2 hint), e.g. ["물 계열","광물 계열"].
func hint_categories(recipe_id: String) -> Array:
	var rec: Dictionary = RecipeDB.get_recipe(recipe_id)
	if rec.is_empty():
		return []
	var inputs: Array = rec.get("inputs", [])
	if inputs.size() != 2:
		return []
	return [_category_of(String(inputs[0])), _category_of(String(inputs[1]))]


## (GP-2) Keyword-based category classifier over an item's name/layer — data-light (no taxonomy
## field exists in items.json). Used only for the stage-2 "재료 카테고리" hint (fuzzy on purpose).
func _category_of(item_id: String) -> String:
	var id := ItemDB.resolve_id(item_id)
	var nm := ItemDB.item_name(id)
	var pairs := [
		["물 계열", ["물", "수", "이슬", "샘", "액", "젖", "냉각", "증류"]],
		["불 계열", ["불", "화", "숯", "재", "잔불", "불씨", "열"]],
		["흙 계열", ["흙", "토", "진흙", "모래", "점토", "땅"]],
		["광물 계열", ["돌", "석", "철", "금속", "구리", "황동", "대리석", "결정", "광", "쇠", "고철"]],
		["식물 계열", ["풀", "잎", "꽃", "씨", "나무", "이끼", "덩굴", "가지", "줄기", "뿌리"]],
		["기계 계열", ["톱니", "태엽", "회로", "전선", "부품", "기어", "벨트", "나사", "배터리", "전지"]],
		["빛 계열", ["빛", "등", "성물", "촛", "성수", "신성", "룬", "마력"]],
	]
	for p in pairs:
		for kw: String in p[1]:
			if nm.contains(kw):
				return String(p[0])
	# Fallback by layer flavor.
	return "미지의 계열"


## (v0.4.0-B B3.4) All ACTIVE staged hints: recipe_id -> {stage,ingredient}. Findable in the
## 도감 "힌트" filter + fusion inline list. Drops out once the recipe is discovered. Returns a copy.
func revealed_hints() -> Dictionary:
	return _hints.duplicate(true)


## Count of active revealed hints (for the chip badge).
func revealed_hint_count() -> int:
	return _hints.size()


## Order-independent key for an attempted pair (canonicalized + sorted), so
## "I5+I2" and "I2+I5" count as the same attempt.
func _pair_key(a_id: String, b_id: String) -> String:
	var pair := [ItemDB.resolve_id(a_id), ItemDB.resolve_id(b_id)]
	pair.sort()
	return "%s|%s" % [pair[0], pair[1]]


## Register a failed fusion attempt for the pair (a_id, b_id). The gauge only
## increments for a pair that has NOT been attempted before (중복 실패 미적립);
## repeating an already-failed pair is a no-op for the gauge. On reaching the
## threshold it reveals one undiscovered recipe's ingredient and resets. Returns
## true if a hint was revealed this call.
func register_failed_fusion(a_id: String = "", b_id: String = "") -> bool:
	if a_id != "" and b_id != "":
		var key := _pair_key(a_id, b_id)
		if _attempted_pairs.has(key):
			# Already-failed pair: no gauge credit.
			return false
		_attempted_pairs[key] = true
	_hint_gauge += 1
	hint_gauge_changed.emit(_hint_gauge)
	if _hint_gauge >= HINT_THRESHOLD:
		var revealed := _advance_hint_stage()
		_hint_gauge = 0
		hint_gauge_changed.emit(_hint_gauge)
		return revealed
	return false


## (v1.1.0 GP-2) Advance ONE recipe's result-first hint by a single stage on each threshold hit.
## Policy (§2.2 "한 레시피를 순차 공개"): a focus recipe climbs 1→2→3 before another opens.
##   1. If an undiscovered recipe already has an active hint below HINT_STAGE_MAX → advance it.
##   2. Otherwise open the first undiscovered recipe with no hint yet at stage 1 (result reveal).
## Returns true if a stage was advanced/opened.
func _advance_hint_stage() -> bool:
	# 1. Advance an in-progress hint (deterministic: first undiscovered recipe with a sub-max hint).
	for rec: Dictionary in RecipeDB.all_recipes():
		var rid: String = rec["id"]
		if _recipes.has(rid) or not _hints.has(rid):
			continue
		var entry: Dictionary = _hints[rid]
		var stage := int(entry.get("stage", 0))
		if stage < HINT_STAGE_MAX:
			_set_hint_stage(rid, stage + 1)
			return true
	# 2. Open a fresh recipe at stage 1 (result silhouette + poetic name).
	for rec: Dictionary in RecipeDB.all_recipes():
		var rid: String = rec["id"]
		if _recipes.has(rid) or _hints.has(rid):
			continue
		_set_hint_stage(rid, 1)
		return true
	return false


## Set a recipe's hint to a specific stage, filling the ingredient id at stage 3, and emit.
func _set_hint_stage(rid: String, stage: int) -> void:
	var ingredient := ""
	if stage >= HINT_STAGE_MAX:
		var rec: Dictionary = RecipeDB.get_recipe(rid)
		var inputs: Array = rec.get("inputs", [])
		if inputs.size() == 2:
			var a := ItemDB.resolve_id(String(inputs[0]))
			var b := ItemDB.resolve_id(String(inputs[1]))
			# Prefer revealing an ingredient the player already knows.
			ingredient = a
			if not is_item_discovered(a) and is_item_discovered(b):
				ingredient = b
	_hints[rid] = {"stage": stage, "ingredient": ingredient}
	hint_revealed.emit(rid, ingredient, stage)


# ---- persistence (M5) ----------------------------------------------------

## Serializable snapshot of all discovery state.
func to_dict() -> Dictionary:
	return {
		"items": _items.keys(),
		"recipes": _recipes.keys(),
		"hint_gauge": _hint_gauge,
		"hints": _hints.duplicate(true),
		"attempted_pairs": _attempted_pairs.keys(),
		"truth_logs": _truth_logs.duplicate(true),
		"truth_final_seen": _truth_final_seen,
		"cutscenes_seen": _cutscenes_seen.keys(),
	}


## Restore from a snapshot produced by `to_dict()`.
func from_dict(data: Dictionary) -> void:
	_items.clear()
	_recipes.clear()
	_hints.clear()
	_attempted_pairs.clear()
	for id: String in data.get("items", []):
		_items[id] = true
	for id: String in data.get("recipes", []):
		_recipes[id] = true
	for key: String in data.get("attempted_pairs", []):
		_attempted_pairs[key] = true
	# (GP-2) hints are now {stage,ingredient}. Migrate legacy saves where a hint was a bare
	# ingredient String → treat as fully-revealed stage 3 (predates-safe, no data loss).
	_hints.clear()
	for rid: String in (data.get("hints", {}) as Dictionary).keys():
		var v: Variant = data["hints"][rid]
		if typeof(v) == TYPE_DICTIONARY:
			_hints[rid] = {"stage": int(v.get("stage", HINT_STAGE_MAX)), "ingredient": String(v.get("ingredient", ""))}
		else:
			_hints[rid] = {"stage": HINT_STAGE_MAX, "ingredient": ItemDB.resolve_id(String(v))}
	_hint_gauge = int(data.get("hint_gauge", 0))
	# (EG-2) truth logs (기록 탭). Null-guarded — v0.9.0 saves lack the key.
	_truth_logs = (data.get("truth_logs", {}) as Dictionary).duplicate(true)
	_truth_final_seen = bool(data.get("truth_final_seen", false))
	# (CQ-5 G14) cutscenes seen (재감상). Null-guarded — pre-v1.3.0 saves lack the key.
	_cutscenes_seen.clear()
	for cid: String in data.get("cutscenes_seen", []):
		_cutscenes_seen[cid] = true
	hint_gauge_changed.emit(_hint_gauge)


## Reset all state (used by harnesses for a clean slate).
func reset() -> void:
	_items.clear()
	_recipes.clear()
	_hints.clear()
	_attempted_pairs.clear()
	_truth_logs.clear()
	_truth_final_seen = false
	_cutscenes_seen.clear()
	_hint_gauge = 0
	hint_gauge_changed.emit(_hint_gauge)
