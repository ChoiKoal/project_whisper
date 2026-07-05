extends Control
class_name TitleMenu
## Title screen for Project Whisper (v0.4.0-B 감성 rebuild).
##
## Flow / handlers are UNCHANGED (the m7 title-flow harness depends on them):
##   "새로 시작"        — always            → _on_new_game
##   "이어하기"         — SaveManager.has_save()          → _on_continue
##   "NG+ 시작"         — has_save() and save cleared     → _on_ng_plus
##   "종료"             — quit              → _on_quit
##
## v0.4.0-B — the owner asked for a more 감성적 start screen. Rebuilt to the pixel-title
## best-practice playbook (Hyper Light Drifter / Eastward): a flat deep navy-violet base
## with large gradient + vignette overlays, layered LOW-CONTRAST silhouette bands drifting
## at parallax depths, a soft-glow moon composited over sharp pixels, drifting fog streaks
## and fireflies, a restrained 2-hue palette (deep navy-violet + warm cream), a
## letter-spaced title that fades in, and a menu that slides up after a beat (0.8s).
##
## All composed from drawn primitives / gradients (no new external art, no shaders):
##   - flat navy base + vertical navy→violet gradient sky
##   - moon disc with a soft additive glow halo (upper-right)
##   - 3 parallax silhouette bands (distant forest line / mid trees / near world-tree
##     hill), each a low-contrast band drifting slowly at its own speed
##   - a low-alpha horizontal fog band drifting sideways + rising fireflies/violet motes
##   - a soft vertical vignette to focus the centre
##   - "Project Whisper" letter-spaced logotype (violet + additive glow), cream subtitle
##   - button column slides up + fades in after 0.8s; a key/click during the beat shows it
##     instantly (skippable intro-beat). All menu logic/버튼 UNCHANGED.
##
## Everything is code-built so there is no fragile hand-authored .tscn to drift.

const BG := Color("#2a2a33")
const CREAM := Color("#faf5e6")
const VIOLET := Color("#9e7ad9")
const VIOLET_SOFT := Color("#c8b0ec")
const MUTED := Color("#b8b4a8")
## Deep navy-violet base (restrained 2-hue palette per the pixel-title playbook).
const SKY_TOP := Color("#14131f")     # deep navy-violet zenith
const SKY_BOTTOM := Color("#241f38")  # warmer violet toward horizon
## Silhouette band tones — LOW CONTRAST (only a touch darker than the sky), so the bands
## read as depth layers rather than hard cutouts. Distant → near = progressively darker.
const BAND_FAR := Color("#1c1a2c")
const BAND_MID := Color("#171525")
const BAND_NEAR := Color("#100e1c")
const MOON := Color("#f2ead6")        # warm cream moon
const FIREFLY := Color("#ffe6a8")     # warm firefly glow

## Design canvas the parallax layout is authored against (project viewport).
const CANVAS := Vector2(1600, 900)

const HOME_SCENE := "res://scenes/world/home_island.tscn"
## 새로 시작 routes through the opening cutscene (CS-01), which fades into the home island;
## 이어하기 loads into whichever world the save was in; NG+ starts fresh in the home world.
const OPENING_SCENE := "res://scenes/ui/opening.tscn"

## Iso tile footprint (matches the in-game 128×64 diamonds): half-width, half-height.
const ISO := Vector2(64, 32)

var _buttons: VBoxContainer
var _glow_nodes: Array[CanvasItem] = []
var _glow_t: float = 0.0
var _fade_root: Control
## (B4) Parallax silhouette bands: {node, base_x, speed} drifting horizontally.
var _parallax: Array[Dictionary] = []
## (B4) The drifting fog band.
var _fog: CanvasItem
var _fog_t: float = 0.0
## (B4) Whether the menu has been revealed yet (guards the skippable intro-beat).
var _menu_revealed: bool = false


## (v0.5.1 BUG1) The window height (px) below which the layout starts compressing, and the
## floor height at which it is fully compressed. The owner's short window was ~526px.
const COMPRESS_FULL_H := 720.0   # at/above this the layout is at its full (design) size
const COMPRESS_MIN_H := 480.0    # at/below this the layout is fully compressed
## Fixed gap (px) kept between the last button and the bottom edge (compresses a little too).
const BUTTON_BOTTOM_GAP := 34.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	# (v0.5.1 BUG1) Rebuild the responsive layout when the window is resized so the menu
	# stays fully on-screen at any size the owner drags the (resizable) window to.
	get_viewport().size_changed.connect(_on_viewport_resized)


## Current viewport height in the title's design/canvas space. `canvas_items` stretch with
## `keep` aspect maps the real window onto the 1600×900 canvas, so the layout math is done in
## canvas space and the compression key is the canvas-space visible height. We read the real
## window height and the stretch to derive the effective canvas height available.
func _viewport_height() -> float:
	var vp := get_viewport()
	if vp == null:
		return CANVAS.y
	var wsize := vp.get_visible_rect().size
	if wsize.y <= 0.0:
		return CANVAS.y
	return wsize.y


## 1.0 = full (tall window) → 0.0 = fully compressed (short window). Drives every responsive
## size/offset via lerp so the whole column fits the viewport at ≥640×480.
func _compress() -> float:
	var h := _viewport_height()
	return clampf((h - COMPRESS_MIN_H) / (COMPRESS_FULL_H - COMPRESS_MIN_H), 0.0, 1.0)


## Title logotype font size — compresses on short windows.
func _title_font_size() -> int:
	return int(lerpf(56.0, 96.0, _compress()))


## Width reserved for the title stack (scales with the font so the letters aren't clipped).
func _title_stack_width() -> float:
	return lerpf(560.0, 820.0, _compress())


## Menu-button height — never below a comfortable ~40px tap target even fully compressed.
func _button_height() -> float:
	return lerpf(40.0, 52.0, _compress())


## Distance from the viewport bottom edge to the BOTTOM button. On a tall window this is a
## generous margin (the original ~90px feel); on a short window it shrinks to a small fixed
## gap so the column has room to fit above it. Always ≥ BUTTON_BOTTOM_GAP.
func _bottom_margin() -> float:
	return lerpf(BUTTON_BOTTOM_GAP, 90.0, _compress())


## Rebuild the whole title on a resize (cheap; it's a static screen). Guards against tearing
## down mid-transition by simply re-running _build after clearing children.
func _on_viewport_resized() -> void:
	for c in get_children():
		c.queue_free()
	_glow_nodes.clear()
	_parallax.clear()
	_fog = null
	_menu_revealed = false
	_build()


func _process(delta: float) -> void:
	# Moon / title glow pulse (subtle breathing) — a plain sine so the title needs no
	# world nodes or GameState.
	_glow_t += delta * 1.4
	var pulse: float = 0.72 + 0.18 * sin(_glow_t)
	for g in _glow_nodes:
		if is_instance_valid(g):
			g.modulate.a = pulse

	# (B4) parallax drift: each band eases sideways at its own slow speed and wraps.
	for layer in _parallax:
		var node: CanvasItem = layer["node"]
		if not is_instance_valid(node):
			continue
		var base_x: float = layer["base_x"]
		var speed: float = layer["speed"]
		var amp: float = layer["amp"]
		(node as Node2D).position.x = base_x + sin(_glow_t * speed) * amp

	# (B4) fog band slow horizontal streak drift.
	_fog_t += delta
	if is_instance_valid(_fog):
		(_fog as Node2D).position.x = -60.0 + fmod(_fog_t * 14.0, 120.0)


# ==== build ================================================================

func _build() -> void:
	_build_sky()
	_build_moon()
	_build_parallax_bands()
	_build_fog()
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

	# (B4) intro-beat: title fades in immediately; the menu slides up after 0.8s. A key
	# or click during the beat reveals the menu instantly (see _unhandled_input).
	_fade_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_fade_root, "modulate:a", 1.0, 0.9).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(0.8).timeout.connect(_reveal_menu)


## Skippable intro-beat: any key / mouse click before the timer fires reveals the menu.
func _unhandled_input(event: InputEvent) -> void:
	if _menu_revealed:
		return
	if (event is InputEventKey and event.pressed) \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		_reveal_menu()
		get_viewport().set_input_as_handled()


## Slide the button column up into place + fade it in (idempotent).
func _reveal_menu() -> void:
	if _menu_revealed or _buttons == null:
		return
	_menu_revealed = true
	var target_y: float = _buttons.position.y
	_buttons.position.y = target_y + 42
	_buttons.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_buttons, "position:y", target_y, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_buttons, "modulate:a", 1.0, 0.45)


func _build_sky() -> void:
	# Flat navy base + vertical navy→violet gradient (large soft overlay).
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


## A warm cream moon disc upper-right with a soft additive glow halo composited over the
## sharp scene. The halo node pulses gently (added to _glow_nodes).
func _build_moon() -> void:
	var moon_pos := Vector2(CANVAS.x * 0.76, CANVAS.y * 0.24)
	# soft additive halo (a radial gradient disc, low alpha, large)
	var halo := _radial_sprite(Color(MOON.r, MOON.g, MOON.b, 0.5), 220.0)
	halo.position = moon_pos
	var hm := CanvasItemMaterial.new()
	hm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = hm
	halo.modulate.a = 0.8
	add_child(halo)
	_glow_nodes.append(halo)
	# crisp moon disc
	var disc := _disc_sprite(MOON, 46.0)
	disc.position = moon_pos
	add_child(disc)
	# a faint violet inner rim (2-hue palette accent)
	var rim := _disc_sprite(Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.18), 52.0)
	rim.position = moon_pos
	var rm := CanvasItemMaterial.new()
	rm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	rim.material = rm
	add_child(rim)


## 3 low-contrast silhouette bands at parallax depths. Each is a Node2D of drawn hill /
## tree-line polygons; the far band drifts least, the near band most (registered in
## _parallax and driven from _process).
func _build_parallax_bands() -> void:
	# distant forest line — a low, gently undulating ridge high up the frame.
	var far := _make_band(BAND_FAR, CANVAS.y * 0.60, 44.0, 7, 0.9)
	_register_band(far, 0.9, 0.10, 18.0)   # slow speed, small amplitude
	# mid tree line — taller jagged conifer silhouette, a bit lower.
	var mid := _make_tree_band(BAND_MID, CANVAS.y * 0.66, 120.0, 11)
	_register_band(mid, 0.66, 0.16, 30.0)
	# near world-tree hill — a big rounded hill on the right with a single tall tree.
	var near := _make_hill_band(BAND_NEAR, CANVAS.y * 0.74)
	_register_band(near, 0.74, 0.22, 42.0)


## Register a parallax band node for drift in _process.
func _register_band(node: Node2D, base_alpha: float, speed: float, amp: float) -> void:
	add_child(node)
	node.modulate.a = base_alpha
	_parallax.append({
		"node": node, "base_x": node.position.x, "speed": speed, "amp": amp,
		"span": CANVAS.x,
	})


## An undulating filled ridge polygon spanning the full width, `crest_y` at the sky, with
## `bumps` sine humps of `height`. Extended past both edges so parallax drift never reveals
## a gap.
func _make_band(col: Color, crest_y: float, height: float, bumps: int, _sharp: float) -> Node2D:
	var n := Node2D.new()
	var poly := Polygon2D.new()
	poly.color = col
	var pts: PackedVector2Array = []
	var x0 := -200.0
	var x1 := CANVAS.x + 200.0
	var steps := 48
	for i in range(steps + 1):
		var t := float(i) / steps
		var x: float = lerp(x0, x1, t)
		var y := crest_y - sin(t * PI * bumps) * height * 0.5 - height * 0.5
		pts.append(Vector2(x, y))
	pts.append(Vector2(x1, CANVAS.y + 40))
	pts.append(Vector2(x0, CANVAS.y + 40))
	poly.polygon = pts
	n.add_child(poly)
	return n


## A jagged conifer tree-line silhouette band (triangular peaks along a baseline).
func _make_tree_band(col: Color, base_y: float, peak_h: float, count: int) -> Node2D:
	var n := Node2D.new()
	var poly := Polygon2D.new()
	poly.color = col
	var pts: PackedVector2Array = []
	var x0 := -200.0
	var x1 := CANVAS.x + 200.0
	pts.append(Vector2(x0, base_y))
	var span := x1 - x0
	for i in range(count):
		var cx := x0 + span * (float(i) + 0.5) / count
		var w := span / count * 0.5
		var h: float = peak_h * (0.6 + 0.5 * absf(sin(i * 1.7)))
		pts.append(Vector2(cx - w, base_y))
		pts.append(Vector2(cx, base_y - h))
		pts.append(Vector2(cx + w, base_y))
	pts.append(Vector2(x1, base_y))
	pts.append(Vector2(x1, CANVAS.y + 40))
	pts.append(Vector2(x0, CANVAS.y + 40))
	poly.polygon = pts
	n.add_child(poly)
	return n


## The near hill: a large rounded hill filling the lower-right, with a single tall
## world-tree silhouette rising from its crest + a faint violet glow above the tree.
func _make_hill_band(col: Color, crest_y: float) -> Node2D:
	var n := Node2D.new()
	var poly := Polygon2D.new()
	poly.color = col
	var pts: PackedVector2Array = []
	var x0 := -200.0
	var x1 := CANVAS.x + 200.0
	var steps := 40
	var peak_x := CANVAS.x * 0.72
	for i in range(steps + 1):
		var t := float(i) / steps
		var x: float = lerp(x0, x1, t)
		# a broad rounded hump centred at peak_x
		var d := (x - peak_x) / (CANVAS.x * 0.55)
		var y := crest_y + 130.0 - exp(-d * d) * 150.0
		pts.append(Vector2(x, y))
	pts.append(Vector2(x1, CANVAS.y + 40))
	pts.append(Vector2(x0, CANVAS.y + 40))
	poly.polygon = pts
	n.add_child(poly)
	# a single tall tree silhouette on the crest
	var trunk := Polygon2D.new()
	trunk.color = col
	var tx := peak_x
	var ty := crest_y - 20.0
	trunk.polygon = PackedVector2Array([
		Vector2(tx - 10, ty), Vector2(tx - 4, ty - 150), Vector2(tx + 4, ty - 150), Vector2(tx + 10, ty),
	])
	n.add_child(trunk)
	var crown := _disc_sprite(col, 62.0)
	crown.position = Vector2(tx, ty - 168)
	n.add_child(crown)
	# faint violet glow above the world tree (2-hue accent), pulses with the moon.
	var glow := _radial_sprite(Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.35), 90.0)
	glow.position = Vector2(tx, ty - 180)
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	n.add_child(glow)
	_glow_nodes.append(glow)
	# (B4) the constructor: a tiny hooded figure on the hill crest, back to us, staff in
	# hand, gazing up at the world tree. A hair lighter than the hill so the silhouette
	# reads; the staff orb is a small violet glint (the same 2-hue accent as the tree glow).
	var fig_x := peak_x - 132.0
	var fig_y := crest_y + 6.0            # planted on the hill crest, just left of the tree
	_add_constructor_figure(n, fig_x, fig_y, col)
	return n


## A small back-view hooded constructor silhouette planted at (fx, fy): floor-length
## cloak (A-line), a rounded hood, and a staff on the right with a floating violet orb.
## Kept low-contrast (a touch above the hill tone) so it reads as part of the diorama.
func _add_constructor_figure(parent: Node2D, fx: float, fy: float, hill_col: Color) -> void:
	# figure tone: nudge the hill colour up toward the deep-violet cloak so it separates
	# from the hill without breaking the flat-silhouette look.
	var body_col := hill_col.lerp(Color("#241f38"), 0.75)
	var cloak := Polygon2D.new()
	cloak.color = body_col
	# A-line cloak: narrow shoulders → flared hem (≈22px tall, ≈16px hem).
	cloak.polygon = PackedVector2Array([
		Vector2(fx - 4, fy - 22), Vector2(fx + 4, fy - 22),
		Vector2(fx + 8, fy), Vector2(fx - 8, fy),
	])
	parent.add_child(cloak)
	# rounded hood (a small disc at the shoulders).
	var hood := _disc_sprite(body_col, 6.0)
	hood.position = Vector2(fx, fy - 24)
	parent.add_child(hood)
	# staff: a thin vertical bar on the figure's right side.
	var staff := Polygon2D.new()
	staff.color = body_col
	staff.polygon = PackedVector2Array([
		Vector2(fx + 9, fy - 26), Vector2(fx + 11, fy - 26),
		Vector2(fx + 11, fy + 2), Vector2(fx + 9, fy + 2),
	])
	parent.add_child(staff)
	# floating violet orb above the staff tip — a tiny additive glint (breathes w/ moon).
	var orb := _radial_sprite(Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.85), 9.0)
	orb.position = Vector2(fx + 10, fy - 32)
	var om := CanvasItemMaterial.new()
	om.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	orb.material = om
	parent.add_child(orb)
	_glow_nodes.append(orb)


## A low-alpha horizontal fog band (stacked soft streaks) that drifts sideways.
func _build_fog() -> void:
	var n := Node2D.new()
	n.name = "FogBand"
	n.position = Vector2(0, CANVAS.y * 0.62)
	for i in range(4):
		var streak := _radial_sprite(Color(VIOLET_SOFT.r, VIOLET_SOFT.g, VIOLET_SOFT.b, 0.06), 260.0)
		streak.position = Vector2(200 + i * 420, sin(i * 1.3) * 26.0)
		streak.scale = Vector2(2.4, 0.5)   # squashed → horizontal streak
		var sm := CanvasItemMaterial.new()
		sm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		streak.material = sm
		n.add_child(streak)
	add_child(n)
	_fog = n


## A soft vertical vignette darkening top + bottom edges to focus the centre.
func _build_vignette() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([
		Color(0.05, 0.04, 0.08, 0.55),
		Color(0.05, 0.04, 0.08, 0.0),
		Color(0.03, 0.02, 0.06, 0.80),
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


## Fireflies (warm) + a few violet motes, rising slowly, additive (soft glow over pixels).
func _build_particles() -> void:
	# warm fireflies drifting up from the tree-line band
	var f := CPUParticles2D.new()
	f.amount = 26
	f.lifetime = 11.0
	f.preprocess = 7.0
	f.position = Vector2(CANVAS.x * 0.5, CANVAS.y * 0.72)
	f.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	f.emission_rect_extents = Vector2(CANVAS.x * 0.5, 60)
	f.direction = Vector2(0, -1)
	f.spread = 24.0
	f.gravity = Vector2(6, -5)
	f.initial_velocity_min = 6.0
	f.initial_velocity_max = 18.0
	f.scale_amount_min = 1.5
	f.scale_amount_max = 3.5
	f.color = Color(FIREFLY.r, FIREFLY.g, FIREFLY.b, 0.85)
	var fmat := CanvasItemMaterial.new()
	fmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	f.material = fmat
	var framp := Gradient.new()
	framp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	framp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0),
	])
	f.color_ramp = framp
	f.emitting = true
	add_child(f)

	# sparse violet motes higher up (ambient depth)
	var p := CPUParticles2D.new()
	p.amount = 16
	p.lifetime = 12.0
	p.preprocess = 8.0
	p.position = Vector2(CANVAS.x * 0.5, CANVAS.y * 0.85)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(CANVAS.x * 0.55, 40)
	p.direction = Vector2(0, -1)
	p.spread = 18.0
	p.gravity = Vector2(0, -4)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = Color(VIOLET_SOFT.r, VIOLET_SOFT.g, VIOLET_SOFT.b, 0.45)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.65), Color(1, 1, 1, 0.0),
	])
	p.color_ramp = ramp
	p.emitting = true
	add_child(p)


# ---- drawn-primitive sprite helpers (no external art) ---------------------

## A crisp filled disc Sprite2D of `radius`, `col`, centred at its position.
func _disc_sprite(col: Color, radius: float) -> Sprite2D:
	var s := int(ceil(radius * 2.0))
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(radius, radius)
	for y in range(s):
		for x in range(s):
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= radius:
				img.set_pixel(x, y, col)
	var sp := Sprite2D.new()
	sp.texture = ImageTexture.create_from_image(img)
	sp.centered = true
	return sp


## A soft radial-gradient disc Sprite2D (alpha falls off to 0 at the edge) of `radius`.
func _radial_sprite(col: Color, radius: float) -> Sprite2D:
	var s := int(ceil(radius * 2.0))
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(radius, radius)
	for y in range(s):
		for x in range(s):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / radius
			if d <= 1.0:
				var a := col.a * (1.0 - d) * (1.0 - d)
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	var sp := Sprite2D.new()
	sp.texture = ImageTexture.create_from_image(img)
	sp.centered = true
	return sp


# ==== title logotype =======================================================

func _build_title() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER_TOP)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# (v0.5.1 BUG1) Top offset compresses with the viewport height so the title never pushes
	# the menu column off the bottom edge on a short window.
	col.position = Vector2(0, lerpf(64.0, 150.0, _compress()))
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", int(lerpf(4.0, 10.0, _compress())))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_root.add_child(col)

	# (B4) letter-spaced logotype (tracked out with thin spaces for a calmer, more
	# 감성적 title). Overlap a crisp title over an additive, low-alpha glow copy.
	# (v0.5.1 BUG1) The glow copy is now aligned EXACTLY over the main label — same anchors,
	# NO scale (a scaled copy pivoted off-centre drifted sideways and read as "PProject
	# WWhisper"). It is a pure additive-alpha bloom, offset a single pixel DOWN (never
	# sideways), so it sits directly under the crisp letters.
	var title_size := _title_font_size()
	var spaced := _letter_space("Project Whisper")
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(_title_stack_width(), title_size * 1.25)
	stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var glow := _title_label(spaced, title_size, VIOLET)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.position = Vector2(0, 1)   # additive bloom, 1px down, same x — never sideways
	glow.modulate = Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.45)
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = glow_mat

	var main := _title_label(spaced, title_size, VIOLET)
	main.set_anchors_preset(Control.PRESET_FULL_RECT)

	stack.add_child(glow)
	stack.add_child(main)
	col.add_child(stack)
	_glow_nodes.append(glow)

	var sub := _title_label("속삭임이 세계를 만든다", int(lerpf(18.0, 26.0, _compress())), CREAM)
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


## Track a string out with a thin space (U+2009) between characters for the logotype.
func _letter_space(s: String) -> String:
	var out := ""
	for i in s.length():
		if i > 0:
			out += " "
		out += s[i]
	return out


# ==== buttons ==============================================================

func _build_buttons() -> void:
	_buttons = VBoxContainer.new()
	# (v0.5.1 BUG1) Anchor the column to the viewport BOTTOM and grow UPWARD from a fixed
	# bottom margin, so the last button always sits a fixed gap above the bottom edge no
	# matter the window height. Separation + button height compress on short windows so the
	# whole 3-4-button column stays inside the viewport (verified 640×480 … 1920×1080).
	_buttons.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_buttons.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_buttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_buttons.position = Vector2(0, -_bottom_margin())
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", int(lerpf(8.0, 14.0, _compress())))
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
	# (v0.5.1 BUG1) Height + font compress on a short window so the full column fits; never
	# below a comfortable tap target (~40px) even at 480px tall.
	b.custom_minimum_size = Vector2(lerpf(240.0, 320.0, _compress()), _button_height())
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", VIOLET_SOFT)
	b.add_theme_color_override("font_focus_color", VIOLET_SOFT)
	b.add_theme_color_override("font_pressed_color", VIOLET)
	b.add_theme_font_size_override("font_size", int(lerpf(20.0, 26.0, _compress())))
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
	# Defer the load until the destination world scene has built its map + player: that
	# scene's session calls SaveManager.load_game() from its _ready when pending_load. The
	# save records which world the player was in (home/grove) via WorldContext; peek it to
	# route to the correct scene. A rejected 구버전 save falls back to a fresh home start.
	var data := SaveManager._read_save()
	if data.is_empty():
		_on_new_game()
		return
	SaveManager.pending_load = true
	var dest := String(data.get("world_context", {}).get("current_scene", WorldContext.SCENE_HOME))
	get_tree().change_scene_to_file(WorldContext.scene_path(dest))


func _on_ng_plus() -> void:
	# Bring the finished run's discovery state into memory (core-only, no world),
	# then roll NG+ (resets + seeds 3 carried recipes). Fresh world, no pending load.
	var data := SaveManager._read_save()
	SaveManager._apply_core_state(data)
	SaveManager.start_ng_plus()
	SaveManager.pending_load = false
	get_tree().change_scene_to_file(HOME_SCENE)


func _on_quit() -> void:
	get_tree().quit()
