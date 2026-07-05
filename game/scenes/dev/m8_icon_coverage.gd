extends Node
## Icon-coverage harness (v0.2.0 art/UI sprint).
##
## Asserts the item-icon guarantees from the sprint spec:
##   1. Every id in items.json (except the alias D06) has an icon PNG on disk that
##      resolves to a real Texture2D (not the defensive category-square fallback).
##   2. ItemDB.icon(id) is non-null for every id, and the alias D06 resolves to the
##      SAME texture as its canonical I4 (D06 → I4's icon).
##   3. No two icon FILES are byte-identical — i.e. 57 canonical icons are all
##      unique (the only allowed duplicate is D06.png == I4.png, the alias copy).
##
## Prints PASS/FAIL lines and quits with the failure count as the exit code.

const ICON_DIR := "res://assets/icons/"
const ITEMS_PATH := "res://data/items.json"

var _fail := 0


func _check(label: String, cond: bool) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== ICON COVERAGE HARNESS ===")

	var records := _load_records()
	_check("items.json loaded (>=58 records)", records.size() >= 58)

	# Split canonical vs alias.
	var canonical_ids: Array[String] = []
	var alias_ids: Array[String] = []
	for rec: Dictionary in records:
		var id := String(rec.get("id", ""))
		if id == "":
			continue
		if rec.has("alias_of"):
			alias_ids.append(id)
		else:
			canonical_ids.append(id)
	_check("30/58: 57 canonical + aliases split", canonical_ids.size() == 57 and alias_ids.size() == 1)

	# 1. every canonical id has a real icon FILE (present on disk).
	var missing: Array[String] = []
	for id in canonical_ids:
		if not ResourceLoader.exists(ICON_DIR + id + ".png"):
			missing.append(id)
	_check("every canonical id has an icon PNG (missing=%s)" % [missing], missing.is_empty())

	# 2. ItemDB.icon(id) non-null for every id (canonical + alias).
	var null_ids: Array[String] = []
	for id in canonical_ids + alias_ids:
		if ItemDB.icon(id) == null:
			null_ids.append(id)
	_check("ItemDB.icon() non-null for all ids (null=%s)" % [null_ids], null_ids.is_empty())

	# alias D06 resolves to I4's icon (same texture object / same file).
	var d06 := ItemDB.icon("D06")
	var i4 := ItemDB.icon("I4")
	_check("D06 icon resolves to I4's icon", d06 != null and d06 == i4)

	# 3. no two icon files byte-identical (57 canonical files all unique).
	var hashes := {}
	var dup_pairs: Array = []
	for id in canonical_ids:
		var bytes := _read_bytes(ICON_DIR + id + ".png")
		var h := bytes.get_string_from_ascii() if false else str(bytes.size()) + ":" + _digest(bytes)
		if hashes.has(h):
			dup_pairs.append([hashes[h], id])
		else:
			hashes[h] = id
	_check("all 57 canonical icon files are byte-unique (dupes=%s)" % [dup_pairs], dup_pairs.is_empty())
	_check("distinct icon hashes == 57", hashes.size() == 57)

	# Sanity: the alias file, if present, equals I4's file (spec: D06 shares I4 art).
	if ResourceLoader.exists(ICON_DIR + "D06.png"):
		var a := _read_bytes(ICON_DIR + "D06.png")
		var b := _read_bytes(ICON_DIR + "I4.png")
		_check("D06.png bytes == I4.png bytes (alias copy)", a == b)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


func _load_records() -> Array:
	var f := FileAccess.open(ITEMS_PATH, FileAccess.READ)
	if f == null:
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	return parsed.get("items", [])


func _read_bytes(path: String) -> PackedByteArray:
	# Read from the actual PNG (source), not the imported .ctex, so byte-identity
	# reflects the generated art.
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var b := f.get_buffer(f.get_length())
	f.close()
	return b


func _digest(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()
