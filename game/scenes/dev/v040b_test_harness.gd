extends Node
## v0.4.0-B acceptance harness — visual/UI sprint (owner-feedback fixes B1–B4).
##
## Covers (validation §2), on the real starting_grove scene + generated assets:
##   B3.1 modal-block — opening a window (fusion) freezes the player: a queued click/tap
##                      path is dropped and velocity stays zero while the modal is up;
##                      world interaction is refused too. Movement resumes on close.
##   B3.2 close chrome — every window (fusion/inventory/codex/character/pause) exposes a
##                      "CloseButton" (✕) node AND an "EscHint" label.
##   B3.3 banner       — exactly ONE composed "DiscoveryBanner" node exists (no separate
##                      banner+counter pair that can overlap); its name label carries the
##                      composed "새로운 발견! — <item>" text and the count lives in the SAME
##                      banner, not a second floating label.
##   B3.4 codex hint   — the codex "HintChip" section lists every revealed hint; the inline
##                      fusion "힌트 보기" list mirrors them.
##   B1 character art  — character_sheet.png's dominant color is in the dark cloak family
##                      (black cloak per candA, NOT cream); portrait too.
##   B2 bush art       — bush_dry.png / bush_bloom.png exist with the rebuilt dimensions and
##                      the bush_dry.gd shimmer cue node is present.
##
## Instances the real grove like the other grove harnesses; reaches the window CanvasLayers
## as direct scene children.

const GROVE := "res://scenes/world/starting_grove.tscn"
const SHEET := "res://assets/character/character_sheet.png"
const PORTRAIT := "res://assets/character/character_portrait.png"
const BUSH_DRY := "res://assets/objects/bush_dry.png"
const BUSH_BLOOM := "res://assets/objects/bush_bloom.png"

var _fail := 0
var _grove_root: Node = null


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== v0.4.0-B TEST HARNESS ===")
	Inventory.clear()
	Codex.reset()
	GameState.set_game_time(0.0)
	SaveManager.pending_load = false

	# Asset checks don't need the scene.
	_test_character_art()
	_test_bush_art()

	var scene: PackedScene = load(GROVE)
	var map := scene.instantiate()
	_grove_root = map
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_test_bush_node(map)
	_test_close_chrome(map)
	await _test_modal_block(map)
	await _test_discovery_banner(map)
	await _test_codex_hint_section(map)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- B1: character sheet is the dark (black) cloak, not cream ---------------

func _test_character_art() -> void:
	var img := _load_image(SHEET)
	_check("character_sheet.png present", img != null)
	if img != null:
		_check("character_sheet is the production layout (288×384)",
			img.get_width() == 288 and img.get_height() == 384,
			"%dx%d" % [img.get_width(), img.get_height()])
		var dom := _dominant_color(img)
		_check("character sheet dominant color is DARK cloak family (not cream)",
			_is_dark(dom), "rgb=%d,%d,%d lum=%.0f" % [dom.r8, dom.g8, dom.b8, _lum(dom)])
	var pimg := _load_image(PORTRAIT)
	_check("character_portrait.png present", pimg != null)
	if pimg != null:
		var pdom := _dominant_color(pimg)
		_check("portrait dominant color is DARK cloak family (not cream)",
			_is_dark(pdom), "rgb=%d,%d,%d lum=%.0f" % [pdom.r8, pdom.g8, pdom.b8, _lum(pdom)])


# ---- B2: rebuilt bush textures exist w/ new dimensions ----------------------

func _test_bush_art() -> void:
	var dry := _load_image(BUSH_DRY)
	var bloom := _load_image(BUSH_BLOOM)
	_check("bush_dry.png present", dry != null)
	_check("bush_bloom.png present", bloom != null)
	if dry != null:
		# v0.5: the dry bush is a real CC0 WITHERED/BARE tree (rubberduck dead-tree set),
		# tight-cropped (≈108×128). Assert it fits within a tile-ish canvas and reads as
		# dead wood — brown/desaturated, its dominant color must NOT be leafy green.
		_check("bush_dry.png is a reasonable withered-object canvas",
			dry.get_width() <= 160 and dry.get_height() <= 200 and dry.get_width() > 16,
			"%dx%d" % [dry.get_width(), dry.get_height()])
		var dom := _dominant_color(dry)
		# dead wood: green is NOT the strongly-dominant channel (not a green shrub).
		var not_green := not (dom.g8 > dom.r8 + 8 and dom.g8 > dom.b8 + 8)
		_check("bush_dry reads as dead/withered wood (not leafy green)",
			not_green, "rgb=%d,%d,%d" % [dom.r8, dom.g8, dom.b8])
	if bloom != null:
		# v0.5: the bloom is a lush green foliage clump (CC0 grassland plant). Assert a
		# sane small canvas and that green foliage dominates.
		_check("bush_bloom.png is a reasonable foliage canvas",
			bloom.get_width() <= 160 and bloom.get_height() <= 160 and bloom.get_width() > 16,
			"%dx%d" % [bloom.get_width(), bloom.get_height()])
		var bdom := _dominant_color(bloom)
		_check("bush_bloom is green foliage (bloomed/alive)",
			bdom.g8 >= bdom.r8 and bdom.g8 >= bdom.b8,
			"rgb=%d,%d,%d" % [bdom.r8, bdom.g8, bdom.b8])


## The gate bush node checks — run after the grove is instantiated.
func _test_bush_node(map: Node) -> void:
	var bush := _find_bush_dry_in(map)
	_check("gate bush (BushDry) is present in the grove", bush != null)
	if bush != null:
		# bush_dry.gd builds a GlowSprite shimmer cue (_cue). In the grove it reparents
		# itself onto the shared "glow_layer" CanvasLayer (so day/night doesn't dim it),
		# so assert on the bush's held reference rather than a direct child.
		var cue: Node = bush.get("_cue")
		_check("gate bush has a shimmer readability cue (GlowSprite)",
			cue != null and is_instance_valid(cue) and cue is GlowSprite)
		# v0.5b: the bush carries a Q4 QuestMarker (bobbing water-drop icon + pulse ring,
		# shown only while Q4 is the active whisper) and a warm hover-glow (shown when the
		# player holds water near it). Assert both affordance nodes exist.
		var marker: Node = bush.get("_marker")
		_check("gate bush has a Q4 water-drop QuestMarker",
			marker != null and is_instance_valid(marker) and marker.get("quest_id") == "Q4"
			and marker.get("variant") == "drop")
		var warm: Node = bush.get("_warm")
		_check("gate bush has a water-hover warm glow (has set_water_hover)",
			warm != null and is_instance_valid(warm) and bush.has_method("set_water_hover"))


# ---- B3.2: every window has a ✕ close button + an ESC hint ------------------

func _test_close_chrome(map: Node) -> void:
	for win_name in ["FusionUI", "InventoryUI", "CodexUI", "CharacterWindow", "PauseMenu"]:
		var win := map.get_node_or_null(win_name)
		_check("%s node present" % win_name, win != null)
		if win == null:
			continue
		var close_btn := win.find_child("CloseButton", true, false)
		_check("%s has a ✕ CloseButton" % win_name, close_btn != null and close_btn is Button)
		var esc := win.find_child("EscHint", true, false)
		_check("%s has an EscHint label" % win_name,
			esc != null and esc is Label and String((esc as Label).text).contains("ESC"))


# ---- B3.1: opening a window freezes the player + refuses interaction --------

func _test_modal_block(map: Node) -> void:
	var player := map.get_node("YSortLayer/Player") as Player
	var fusion := map.get_node("FusionUI") as FusionUI
	var interaction := map.get_node("Interaction")

	# Park the player, queue a click/tap path (would move it if unlocked).
	player.clear_path()
	player.velocity = Vector2.ZERO
	var start := player.global_position
	player.set_path([start + Vector2(400, 0)])
	_check("no modal open before window", not GameState.ui_modal_open())

	# Open the fusion window → modal lock engages.
	fusion.open()
	await get_tree().process_frame
	_check("opening fusion pushes a UI modal", GameState.ui_modal_open())

	# Step physics: the guard must drop the queued path and hold velocity at zero.
	player._physics_process(0.016)
	await get_tree().physics_frame
	_check("queued move path is refused while a window is open", not player.is_moving())
	_check("player velocity stays zero while a window is open",
		player.velocity == Vector2.ZERO, "v=%s" % player.velocity)
	_check("player did not drift from its parked cell",
		player.global_position.distance_to(start) < 1.0,
		"d=%.2f" % player.global_position.distance_to(start))

	# World interaction is refused too (the E-interact process guard bails on modal).
	interaction._process(0.016)
	_check("interaction targeting is suppressed while a window is open",
		interaction._target_object == null)

	# Close → the lock releases and movement is possible again.
	fusion.close()
	await get_tree().process_frame
	_check("closing fusion pops the UI modal", not GameState.ui_modal_open())
	player.set_path([start + Vector2(400, 0)])
	player._physics_process(0.016)
	_check("player can move again once the window is closed", player.is_moving())
	player.clear_path()
	player.velocity = Vector2.ZERO


# ---- B3.3: ONE composed discovery banner (no overlapping counter pair) ------

func _test_discovery_banner(map: Node) -> void:
	var fusion := map.get_node("FusionUI") as FusionUI
	fusion.open()
	await get_tree().process_frame

	# Mark a recipe discovered, then trigger the SAME banner-construction path the fuse
	# uses on a first discovery. (We drive _queue_discovery_banner directly rather than the
	# full tween/particle juice, which is what actually builds the composed banner node.)
	Codex.reset()
	var rec: Dictionary = RecipeDB.all_recipes()[0]
	var out := ItemDB.resolve_id(String(rec["output"]))
	Codex.discover_recipe(String(rec["id"]))
	fusion._queue_discovery_banner(out)
	await get_tree().process_frame

	# There must be exactly ONE composed DiscoveryBanner node — the fix for the owner's
	# "'새로운 발견' 배너가 '도감 레시피 9종' 텍스트와 겹침" overlap (banner + separate counter).
	var banners := _find_all_named(fusion, "DiscoveryBanner")
	_check("exactly one composed DiscoveryBanner node (no overlapping pair)",
		banners.size() == 1, "n=%d" % banners.size())
	if banners.size() == 1:
		var banner: Node = banners[0]
		var name_lbl := _first_label_containing(banner, "새로운 발견")
		_check("banner carries the composed '✦ 새로운 발견! — <item>' text",
			name_lbl != null and String((name_lbl as Label).text).contains("—"))
		var count_lbl := _first_label_containing(banner, "도감")
		_check("the 도감 N/M counter lives INSIDE the same banner (not a 2nd floating label)",
			count_lbl != null)
		# The composed banner packs item name AND count in ONE panel — the two labels are
		# descendants of the SAME DiscoveryBanner (not free-floating siblings that overlap).
		_check("banner name + count share one banner panel",
			name_lbl != null and count_lbl != null
			and _is_descendant_of(name_lbl, banner) and _is_descendant_of(count_lbl, banner))
	# No legacy standalone codex-count node floating beside the banner.
	_check("no legacy second discovery-count node",
		_find_all_named(fusion, "DiscoveryCount").is_empty())
	fusion.close()
	await get_tree().process_frame


# ---- B3.4: codex hint section lists the revealed hints ----------------------

func _test_codex_hint_section(map: Node) -> void:
	var codex := map.get_node("CodexUI") as CodexUI
	var fusion := map.get_node("FusionUI") as FusionUI

	# Reveal at least one hint: bump the gauge to threshold via distinct failed pairs.
	Codex.reset()
	var revealed := false
	for i in range(Codex.HINT_THRESHOLD):
		revealed = Codex.register_failed_fusion("HINT_A%d" % i, "HINT_B%d" % i) or revealed
	_check("a codex hint was revealed at the gauge threshold",
		Codex.revealed_hint_count() > 0, "n=%d" % Codex.revealed_hint_count())

	# The codex "힌트" chip/section exists and lists the revealed hint(s).
	codex.open()
	await get_tree().process_frame
	var chip := codex.find_child("HintChip", true, false)
	_check("codex has a '힌트' section chip pinned in the top bar", chip != null)
	if chip is Button:
		(chip as Button).button_pressed = true
		(chip as Button).toggled.emit(true)
		await get_tree().process_frame
	var listed := _count_labels_containing(codex, "?")
	_check("codex hint view lists the revealed hint rows",
		listed >= Codex.revealed_hint_count(), "rows≈%d hints=%d" % [listed, Codex.revealed_hint_count()])
	codex.close()
	await get_tree().process_frame

	# The inline fusion "힌트 보기" list mirrors the same revealed hints.
	fusion.open()
	await get_tree().process_frame
	var rows := fusion.expand_hints_for_test()
	_check("fusion inline 힌트 보기 lists the revealed hint(s)",
		rows >= Codex.revealed_hint_count(), "rows=%d hints=%d" % [rows, Codex.revealed_hint_count()])
	fusion.close()
	await get_tree().process_frame


# ---- helpers ---------------------------------------------------------------

func _load_image(path: String) -> Image:
	if not ResourceLoader.exists(path):
		# Fall back to a raw file load (import may lag in a fresh checkout).
		if FileAccess.file_exists(path):
			var i := Image.new()
			if i.load(path) == OK:
				return i
		return null
	var tex := load(path) as Texture2D
	return tex.get_image() if tex != null else null


## The most common fully-opaque color in an image (coarse 8-bit bucket).
func _dominant_color(img: Image) -> Color:
	if img.is_compressed():
		img.decompress()
	var counts := {}
	var best := Color.BLACK
	var best_n := -1
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var key := "%d,%d,%d" % [c.r8, c.g8, c.b8]
			var n: int = int(counts.get(key, 0)) + 1
			counts[key] = n
			if n > best_n:
				best_n = n
				best = c
	return best


func _lum(c: Color) -> float:
	return 0.299 * c.r8 + 0.587 * c.g8 + 0.114 * c.b8


## Dark cloak family: low luminance AND not a cream/warm-light tone.
func _is_dark(c: Color) -> bool:
	return _lum(c) < 90.0


func _has_violet(img: Image) -> bool:
	if img.is_compressed():
		img.decompress()
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			# violet/pink blossom: blue+red present, blue not dominated out, reasonably bright
			if c.b8 > 120 and c.r8 > 120 and c.g8 < c.r8 and c.g8 < c.b8:
				return true
	return false


func _find_bush_dry_in(root: Node) -> Node:
	if root is BushDry:
		return root
	for c in root.get_children():
		var r := _find_bush_dry_in(c)
		if r != null:
			return r
	return null


func _find_all_named(root: Node, target: String) -> Array:
	var out: Array = []
	if root.name == target:
		out.append(root)
	for c in root.get_children():
		out.append_array(_find_all_named(c, target))
	return out


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var n := node
	while n != null:
		if n == ancestor:
			return true
		n = n.get_parent()
	return false


func _first_label_containing(root: Node, needle: String) -> Label:
	if root is Label and String((root as Label).text).contains(needle):
		return root
	for c in root.get_children():
		var r := _first_label_containing(c, needle)
		if r != null:
			return r
	return null


func _count_labels_containing(root: Node, needle: String) -> int:
	var n := 0
	if root is Label and String((root as Label).text).contains(needle):
		n += 1
	for c in root.get_children():
		n += _count_labels_containing(c, needle)
	return n
