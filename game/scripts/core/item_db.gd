extends Node
## ItemDB — global autoload item registry.
##
## Loads `res://data/items.json` at startup and exposes read-only lookups by item
## id. Fully data-driven: gathering / placement / use logic elsewhere reads the
## fields here (placeable_on, usable_on, unique, key_item) rather than hardcoding
## per-item behavior.
##
## `alias_of` collapses a derived id onto a canonical id (e.g. D06 "나무" →
## I4). `resolve_id()` returns the canonical id so aliased items stack into the
## same inventory entry.

const ITEMS_PATH := "res://data/items.json"
const ICON_DIR := "res://assets/icons/"
const ICON_SIZE := 48

## id -> Dictionary of the raw item record (canonical entries only).
var _items: Dictionary = {}
## alias id -> canonical id (e.g. "D06" -> "I4").
var _aliases: Dictionary = {}
## resolved id -> Texture2D (lazy). Real icon file, or a generated fallback square.
var _icon_cache: Dictionary = {}

## Fallback square colors when an icon file is missing (defensive).
const _CATEGORY_COLOR := {
	"gather": Color("#7ab567"),
	"craft": Color("#c89ae0"),
}


func _ready() -> void:
	_load()


func _load() -> void:
	var f := FileAccess.open(ITEMS_PATH, FileAccess.READ)
	if f == null:
		push_error("ItemDB: cannot open %s" % ITEMS_PATH)
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("items"):
		push_error("ItemDB: malformed items.json")
		return
	# First pass: register canonical (non-alias) entries.
	for rec: Dictionary in parsed["items"]:
		var id: String = rec.get("id", "")
		if id == "":
			continue
		if rec.has("alias_of"):
			_aliases[id] = String(rec["alias_of"])
		else:
			_items[id] = rec
	# alias_of records still carry their own flavor; keep the canonical record as
	# the source of truth for name/category/behavior. The alias is resolvable but
	# not a separate stackable entry.


## Resolve an id through alias_of to the canonical inventory id.
func resolve_id(id: String) -> String:
	return _aliases.get(id, id)


## True if the (resolved) id exists in the registry.
func has_item(id: String) -> bool:
	return _items.has(resolve_id(id))


## Raw record dictionary for an id (resolved). Empty dict if unknown.
func get_item(id: String) -> Dictionary:
	return _items.get(resolve_id(id), {})


func item_name(id: String) -> String:
	return get_item(id).get("name", id)


func item_category(id: String) -> String:
	return get_item(id).get("category", "")


func item_flavor(id: String) -> String:
	return get_item(id).get("flavor", "")


## Tile ids this item may be placed on (e.g. ["T5A","T5B"]). Empty if none.
func get_placeable_on(id: String) -> Array:
	return get_item(id).get("placeable_on", [])


## Object ids this item may be used on (e.g. ["bush_dry"]). Empty if none.
func get_usable_on(id: String) -> Array:
	return get_item(id).get("usable_on", [])


## Unique items cap at 1 in the inventory (I9 world-tree essence).
func is_unique(id: String) -> bool:
	return bool(get_item(id).get("unique", false))


func is_key_item(id: String) -> bool:
	return bool(get_item(id).get("key_item", false))


func can_place_on_tile(id: String, tile_id: String) -> bool:
	return tile_id in get_placeable_on(id)


func can_use_on_object(id: String, object_id: String) -> bool:
	return object_id in get_usable_on(id)


## All canonical item ids (order not guaranteed).
func all_ids() -> Array:
	return _items.keys()


## Icon texture for an item (resolved through alias, so D06 → I4's icon).
## Loads `res://assets/icons/<id>.png`; if that file is missing, returns a
## generated flat category-color square so the UI never shows a null/blank slot.
## Cached per resolved id.
func icon(id: String) -> Texture2D:
	var rid := resolve_id(id)
	if _icon_cache.has(rid):
		return _icon_cache[rid]
	var tex: Texture2D = null
	var p := ICON_DIR + rid + ".png"
	if ResourceLoader.exists(p):
		tex = load(p) as Texture2D
	if tex == null:
		tex = _fallback_square(rid)
	_icon_cache[rid] = tex
	return tex


## Defensive fallback: a flat ICON_SIZE square tinted by category. Used only when
## an icon PNG is absent (e.g. a future item added to items.json before art).
func _fallback_square(id: String) -> Texture2D:
	var col: Color = _CATEGORY_COLOR.get(item_category(id), Color("#888888"))
	var img := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(col)
	return ImageTexture.create_from_image(img)
