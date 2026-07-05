extends Node
## RecipeDB — global autoload recipe registry.
##
## Loads `res://data/recipes.json` at startup. Each recipe is a 2-ingredient
## fusion: `{"id", "inputs":[a,b], "output", "hint"}`. Matching is
## order-independent — inputs are canonicalized (ItemDB.resolve_id) and sorted so
## `[I5,I2]` and `[I2,I5]` both hit R04.
##
## Fully data-driven: adding recipes to recipes.json needs no code change. The
## output id may itself be an alias (e.g. R07 → I4, or a future D06) — callers
## fold it through Inventory which resolves aliases automatically.

const RECIPES_PATH := "res://data/recipes.json"

## recipe id -> raw record Dictionary.
var _recipes: Dictionary = {}
## sorted-canonical-key "a|b" -> recipe id, for O(1) order-independent lookup.
var _by_inputs: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	var f := FileAccess.open(RECIPES_PATH, FileAccess.READ)
	if f == null:
		push_error("RecipeDB: cannot open %s" % RECIPES_PATH)
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("recipes"):
		push_error("RecipeDB: malformed recipes.json")
		return
	for rec: Dictionary in parsed["recipes"]:
		var id: String = rec.get("id", "")
		var inputs: Array = rec.get("inputs", [])
		if id == "" or inputs.size() != 2:
			push_warning("RecipeDB: skipping malformed recipe '%s'" % id)
			continue
		_recipes[id] = rec
		_by_inputs[_input_key(inputs[0], inputs[1])] = id


## Build the order-independent lookup key from two ids (canonicalized + sorted).
func _input_key(a: String, b: String) -> String:
	var ca := ItemDB.resolve_id(a)
	var cb := ItemDB.resolve_id(b)
	var pair := [ca, cb]
	pair.sort()
	return "%s|%s" % [pair[0], pair[1]]


## Find the recipe matching an unordered pair of ingredient ids. Returns the raw
## recipe record Dictionary, or an empty Dictionary if none matches. Requires
## exactly 2 ids.
func find_recipe(ids: Array) -> Dictionary:
	if ids.size() != 2:
		return {}
	var key := _input_key(String(ids[0]), String(ids[1]))
	var rid: String = _by_inputs.get(key, "")
	if rid == "":
		return {}
	return _recipes[rid]


## Raw record for a recipe id (empty dict if unknown).
func get_recipe(recipe_id: String) -> Dictionary:
	return _recipes.get(recipe_id, {})


## (L2-3) Whisper 재화 cost of a recipe as {kind:amount} (e.g. {"energy":1}), or {} if the
## recipe carries no `whisper_cost` field. Fusion reads this to gate the fuse on WhisperCurrency
## (L2-R08 파워 코어 = 코어 조각 + 에너지). Data-driven: any recipe may declare a cost.
func whisper_cost(recipe: Dictionary) -> Dictionary:
	var c: Variant = recipe.get("whisper_cost", {})
	return c if typeof(c) == TYPE_DICTIONARY else {}


## All recipe records (order not guaranteed).
func all_recipes() -> Array:
	return _recipes.values()


## All recipe ids.
func all_ids() -> Array:
	return _recipes.keys()
