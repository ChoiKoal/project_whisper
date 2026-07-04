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
## Emitted when a gauge reveal exposes one ingredient of a recipe.
## `recipe_id` = target recipe, `ingredient_id` = the revealed input id.
signal hint_revealed(recipe_id: String, ingredient_id: String)

## Failed fusions needed to trigger a hint reveal.
const HINT_THRESHOLD := 5

## Canonical item ids discovered (as a set: id -> true).
var _items: Dictionary = {}
## Recipe ids discovered (id -> true).
var _recipes: Dictionary = {}
## Failed-fusion counter, 0..HINT_THRESHOLD.
var _hint_gauge: int = 0
## recipe_id -> revealed ingredient id (canonical), for hints surfaced in the 도감.
var _hints: Dictionary = {}
## Set of already-attempted failed pairs (order-independent key -> true). Used to
## suppress brute-force gauge farming: repeating an already-failed pair does NOT
## increment the gauge (economy-design §B-3 "중복 실패 미적립").
var _attempted_pairs: Dictionary = {}


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


## Revealed ingredient id for a recipe, or "" if that recipe has no active hint.
func hint_for_recipe(recipe_id: String) -> String:
	return _hints.get(recipe_id, "")


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
		var revealed := _reveal_one_hint()
		_hint_gauge = 0
		hint_gauge_changed.emit(_hint_gauge)
		return revealed
	return false


## Pick one still-undiscovered recipe that has no active hint yet, reveal one of
## its ingredients (prefer the ingredient the player has already discovered, so
## the hint reads as "known + ???"). Returns true if a hint was set.
func _reveal_one_hint() -> bool:
	for rec: Dictionary in RecipeDB.all_recipes():
		var rid: String = rec["id"]
		if _recipes.has(rid) or _hints.has(rid):
			continue
		var inputs: Array = rec["inputs"]
		var a := ItemDB.resolve_id(String(inputs[0]))
		var b := ItemDB.resolve_id(String(inputs[1]))
		# Prefer revealing an ingredient the player already knows.
		var pick := a
		if not is_item_discovered(a) and is_item_discovered(b):
			pick = b
		_hints[rid] = pick
		hint_revealed.emit(rid, pick)
		return true
	return false


# ---- persistence (M5) ----------------------------------------------------

## Serializable snapshot of all discovery state.
func to_dict() -> Dictionary:
	return {
		"items": _items.keys(),
		"recipes": _recipes.keys(),
		"hint_gauge": _hint_gauge,
		"hints": _hints.duplicate(),
		"attempted_pairs": _attempted_pairs.keys(),
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
	_hints = (data.get("hints", {}) as Dictionary).duplicate()
	_hint_gauge = int(data.get("hint_gauge", 0))
	hint_gauge_changed.emit(_hint_gauge)


## Reset all state (used by harnesses for a clean slate).
func reset() -> void:
	_items.clear()
	_recipes.clear()
	_hints.clear()
	_attempted_pairs.clear()
	_hint_gauge = 0
	hint_gauge_changed.emit(_hint_gauge)
