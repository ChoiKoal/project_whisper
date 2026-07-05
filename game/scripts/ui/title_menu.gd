extends Control
class_name TitleMenu
## Title screen for Project Whisper (v0.1.2 visual rebuild).
##
## Flow / handlers are UNCHANGED (the m7 title-flow harness depends on them):
##   "새로 시작"        — always            → _on_new_game
##   "이어하기"         — SaveManager.has_save()          → _on_continue
##   "NG+ 시작"         — has_save() and save cleared     → _on_ng_plus
##   "종료"             — quit              → _on_quit
##
## Visuals are composed entirely from EXISTING game assets + drawn primitives
## (no new external art, no shaders):
##   - dark vertical gradient sky (#1a1a20 → #2a2a3c)
##   - a decorative isometric slice of the grove: grass diamonds, a small pond,
##     trees, the World Tree with its violet glow on the right, and the cat sitting
##     beside the cauldron — all Sprite2D on a scaled Node2D "diorama"
##   - a soft vertical vignette (GradientTexture) to focus the center
##   - "Project Whisper" logotype in violet with an additive glow duplicate,
##     subtitle in cream with an outline
##   - gentle motion: slow violet floating motes, a World-Tree glow pulse, and a
##     title fade-in on load
##   - styled button column (rounded #2a2a33 panels, violet border on hover/focus,
##     ≥48px tall) anchored in the lower third; tiny "v0.1.2" bottom-right.
##
## Everything is code-built so there is no fragile hand-authored .tscn to drift.

const BG := Color("#2a2a33")
const CREAM := Color("#faf5e6")
const VIOLET := Color("#9e7ad9")
const VIOLET_SOFT := Color("#c8b0ec")
const MUTED := Color("#b8b4a8")
const SKY_TOP := Color("#1a1a20")
const SKY_BOTTOM := Color("#2a2a3c")

const GROVE_SCENE := "res://scenes/world/starting_grove.tscn"
## 새로 시작 routes through the opening cutscene (v0.2.1); 이어하기/NG+ skip it.
const OPENING_SCENE := "res://scenes/ui/opening.tscn"

## Iso tile footprint (matches the in-game 128×64 diamonds): half-width, half-height.
const ISO := Vector2(64, 32)

var _buttons: VBoxContainer
var _glow_nodes: Array[CanvasItem] = []
var _glow_t: float = 0.0
var _fade_root: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _process(delta: float) -> void:
	# World-tree / title glow pulse (subtle breathing) — a plain sine so the title
	# needs no world nodes or GameState.
	_glow_t += delta * 1.4
	var pulse: float = 0.72 + 0.18 * sin(_glow_t)
	for g in _glow_nodes:
		if is_instance_valid(g):
			g.modulate.a = pulse


# ==== build ================================================================

func _build() -> void:
	_build_sky()
	_build_iso_backdrop()
	_build_vignette()
	_build_particles()

	# Everything above the backdrop fades in together on load.
	_fade_root = Control.new()
	_fade_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_root)

	_build_title()
	_build_buttons()
	_build_version()

	_fade_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_fade_root, "modulate:a", 1.0, 0.9).set_ease(Tween.EASE_OUT)


func _build_sky() -> void:
	# Vertical gradient via a GradientTexture2D on a full-rect TextureRect.
	var grad := Gradient.new()
	grad.set_color(0, SKY_TOP)
	grad.set_color(1, SKY_BOTTOM)
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_LINEAR
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 1.0)
	gtex.width = 64
	gtex.height = 64
	var sky := TextureRect.new()
	sky.texture = gtex
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)


## A decorative isometric arrangement of grove tiles + objects, built in a Node2D
## "diorama" anchored toward the lower-right of the 1600×900 design canvas.
func _build_iso_backdrop() -> void:
	var world := Node2D.new()
	world.name = "Diorama"
	world.position = Vector2(1080, 300)
	world.scale = Vector2(1.15, 1.15)
	add_child(world)

	# --- ground: a small diamond field of grass tiles + a pond corner ---
	var grass := load("res://assets/tiles/t2a_grass.png") as Texture2D
	var grass_b := load("res://assets/tiles/t2b_grass_flowers.png") as Texture2D
	var grass_c := load("res://assets/tiles/t2c_grass_clover.png") as Texture2D
	var water := load("res://assets/tiles/t5a_water.png") as Texture2D
	var pond_cells := {Vector2i(1, 2): true, Vector2i(2, 2): true, Vector2i(2, 3): true}
	for r in range(6):
		for c in range(6):
			var cell := Vector2i(c, r)
			var tex := grass
			if pond_cells.has(cell):
				tex = water
			elif (c + r) % 5 == 0:
				tex = grass_b
			elif (c * 2 + r) % 7 == 0:
				tex = grass_c
			if tex == null:
				continue
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = true
			s.position = _iso(cell)
			world.add_child(s)

	# --- world tree with its violet glow, on the right edge ---
	var wt_pos := _iso(Vector2i(5, 0)) + Vector2(40, -160)
	_add_object(world, "res://assets/objects/world_tree.png", wt_pos, 0.62)
	var wt_glow := load("res://assets/objects/world_tree_glow.png") as Texture2D
	if wt_glow != null:
		var g := Sprite2D.new()
		g.texture = wt_glow
		g.centered = true
		g.scale = Vector2(0.62, 0.62)
		g.position = wt_pos
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		g.material = mat
		g.modulate.a = 0.8
		world.add_child(g)
		_glow_nodes.append(g)

	# --- a couple of ordinary trees for depth ---
	_add_object(world, "res://assets/objects/tree_a.png", _iso(Vector2i(0, 1)) + Vector2(-10, -84), 0.7)
	_add_object(world, "res://assets/objects/tree_b.png", _iso(Vector2i(0, 4)) + Vector2(-30, -84), 0.62)

	# --- cauldron + the cat sitting beside it, near the pond ---
	var caul_pos := _iso(Vector2i(3, 4)) + Vector2(0, -30)
	_add_object(world, "res://assets/objects/cauldron.png", caul_pos, 0.85)
	_add_cat(world, caul_pos + Vector2(-70, -6))

	# --- a scatter of violet flowers to catch the glow ---
	_add_object(world, "res://assets/objects/flower_violet.png", _iso(Vector2i(4, 3)) + Vector2(6, -14), 0.8)
	_add_object(world, "res://assets/objects/flower_violet.png", _iso(Vector2i(1, 4)) + Vector2(-8, -14), 0.7)


func _iso(cell: Vector2i) -> Vector2:
	return Vector2((cell.x - cell.y) * ISO.x, (cell.x + cell.y) * ISO.y)


func _add_object(parent: Node2D, path: String, pos: Vector2, sc: float) -> void:
	var tex := load(path) as Texture2D
	if tex == null:
		push_warning("TitleMenu: backdrop asset missing: %s" % path)
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = true
	s.scale = Vector2(sc, sc)
	s.position = pos
	parent.add_child(s)


## The cat = the player idle_SE frame from the character sheet (96×96 top-left).
func _add_cat(parent: Node2D, pos: Vector2) -> void:
	var sheet := load("res://assets/character/character_sheet.png") as Texture2D
	if sheet == null:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(0, 0, 96, 96)  # idle facing SE
	var s := Sprite2D.new()
	s.texture = atlas
	s.centered = true
	s.scale = Vector2(1.1, 1.1)
	s.position = pos
	parent.add_child(s)


## A soft vertical wash darkening the top and bottom edges to focus the eye toward
## the title/buttons. Drawn with a GradientTexture instead of a shader.
func _build_vignette() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([
		Color(0.06, 0.05, 0.09, 0.55),
		Color(0.06, 0.05, 0.09, 0.0),
		Color(0.04, 0.03, 0.07, 0.75),
	])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 1.0)
	gtex.width = 64
	gtex.height = 64
	var tr := TextureRect.new()
	tr.texture = gtex
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)


## Slow, sparse violet floating motes (CPUParticles2D). Kept light: few particles,
## gentle upward drift, additive so they read as ambient light.
func _build_particles() -> void:
	var p := CPUParticles2D.new()
	p.amount = 22
	p.lifetime = 9.0
	p.preprocess = 6.0
	p.position = Vector2(800, 900)   # emit from the bottom band
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(820, 40)
	p.direction = Vector2(0, -1)
	p.spread = 20.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 24.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 4.0
	p.color = Color(VIOLET_SOFT.r, VIOLET_SOFT.g, VIOLET_SOFT.b, 0.5)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	# Fade motes in/out over their life via an alpha ramp (CPUParticles2D takes a
	# Gradient directly for color_ramp — no texture wrapper).
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0),
	])
	p.color_ramp = ramp
	p.emitting = true
	add_child(p)


# ==== title logotype =======================================================

func _build_title() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER_TOP)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.position = Vector2(0, 150)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_root.add_child(col)

	# Overlap a crisp title over an additive, scaled, low-alpha glow copy.
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(760, 120)
	stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var glow := _title_label("Project Whisper", 96, VIOLET)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.scale = Vector2(1.04, 1.06)
	glow.pivot_offset = Vector2(380, 60)
	glow.modulate = Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.45)
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = glow_mat

	var main := _title_label("Project Whisper", 96, VIOLET)
	main.set_anchors_preset(Control.PRESET_FULL_RECT)

	stack.add_child(glow)
	stack.add_child(main)
	col.add_child(stack)
	_glow_nodes.append(glow)

	var sub := _title_label("속삭임이 세계를 만든다", 26, CREAM)
	sub.add_theme_constant_override("outline_size", 6)
	sub.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.09, 0.9))
	col.add_child(sub)


func _title_label(txt: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", c)
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ==== buttons ==============================================================

func _build_buttons() -> void:
	_buttons = VBoxContainer.new()
	_buttons.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_buttons.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_buttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_buttons.position = Vector2(0, -90)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 14)
	_fade_root.add_child(_buttons)

	_add_button("새로 시작", _on_new_game)
	if SaveManager.has_save():
		_add_button("이어하기", _on_continue)
	if SaveManager.has_save() and _save_cleared():
		_add_button("NG+ 시작", _on_ng_plus)
	_add_button("종료", _on_quit)


func _add_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 52)  # ≥48px tall
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", VIOLET_SOFT)
	b.add_theme_color_override("font_focus_color", VIOLET_SOFT)
	b.add_theme_color_override("font_pressed_color", VIOLET)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_stylebox_override("normal", _btn_style(false))
	b.add_theme_stylebox_override("hover", _btn_style(true))
	b.add_theme_stylebox_override("focus", _btn_style(true))
	b.add_theme_stylebox_override("pressed", _btn_style(true))
	b.pressed.connect(cb)
	_buttons.add_child(b)
	return b


func _btn_style(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#33333f") if active else Color(BG.r, BG.g, BG.b, 0.86)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.set_border_width_all(2)
	sb.border_color = VIOLET if active else Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.25)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6 if active else 3
	sb.shadow_offset = Vector2(0, 3)
	return sb


## Version label, pulled from ProjectSettings config/version so it never drifts
## from project.godot. Falls back to a blank string if the setting is absent.
func _version_string() -> String:
	var raw: Variant = ProjectSettings.get_setting("application/config/version", "")
	var s := String(raw)
	if s == "":
		return ""
	return s if s.begins_with("v") else "v" + s


func _build_version() -> void:
	var v := Label.new()
	v.text = _version_string()
	v.add_theme_color_override("font_color", Color(MUTED.r, MUTED.g, MUTED.b, 0.7))
	v.add_theme_font_size_override("font_size", 15)
	v.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	v.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	v.position = Vector2(-72, -30)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_root.add_child(v)


# ==== state / actions (UNCHANGED behavior) =================================

func _save_cleared() -> bool:
	# Peek the save file's cleared flag without mutating live state.
	var data := SaveManager._read_save()
	var ng: Dictionary = data.get("ngplus", {})
	return bool(ng.get("cleared", false))


func _on_new_game() -> void:
	SaveManager.new_game()
	SaveManager.delete_save()
	SaveManager.pending_load = false
	# v0.2.1: 새로 시작 plays the opening cutscene first, which then loads the grove.
	get_tree().change_scene_to_file(OPENING_SCENE)


func _on_continue() -> void:
	# Defer the load until the grove scene has built its map + player: the grove
	# session calls SaveManager.load_game() from its _ready when pending_load.
	SaveManager.pending_load = true
	get_tree().change_scene_to_file(GROVE_SCENE)


func _on_ng_plus() -> void:
	# Bring the finished run's discovery state into memory (core-only, no world),
	# then roll NG+ (resets + seeds 3 carried recipes). Fresh world, no pending load.
	var data := SaveManager._read_save()
	SaveManager._apply_core_state(data)
	SaveManager.start_ng_plus()
	SaveManager.pending_load = false
	get_tree().change_scene_to_file(GROVE_SCENE)


func _on_quit() -> void:
	get_tree().quit()
