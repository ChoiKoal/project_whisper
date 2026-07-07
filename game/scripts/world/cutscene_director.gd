extends RefCounted
class_name CutsceneDirector
## (CQ-2) Shared cutscene "직조" 부품 — the common vocabulary every cutscene draws from so
## the direction (camera, ripples, letterbox, flash, typography) is authored ONCE and stays
## consistent across CS-01~06 and the L2~L5 purification set pieces.
##
## Design: pure builder helpers, no autoload, no scene. A cutscene owns a CanvasLayer (or a
## Node2D world layer) and asks the Director to build/animate pieces INTO it. Everything is
## null-guarded and headless-safe (tweens are created on a passed-in node that lives in the
## tree; missing optional nodes = graceful no-op — never assert()).
##
## Typography follows the v0.4.0b opening 규격 (cream #faf5e6, size ~30-34, line_spacing 10,
## dark outline) — see make_card_label() — and improves it with per-card tint crossfade helpers.
##
## Camera helpers drive a Camera2D (child of Player) with Tween sequences for pan / zoom /
## tilt / track. They restore smoothing + offset on completion so gameplay resumes cleanly.

const CREAM := Color("#faf5e6")
const VIOLET := Color("#9e7ad9")
const MUTED := Color("#b8b4a8")
const OUTLINE := Color(0.05, 0.04, 0.08, 0.9)

## v0.4.0b card timing (shared so opening / clear / ending / purify all breathe alike).
const CARD_FADE_IN := 1.0
const CARD_HOLD := 2.4
const CARD_FADE_OUT := 0.9


# ==== typography ===========================================================

## A centre-screen card Label authored to the v0.4.0b spec. Caller adds it to its own layer.
## `size` lets purification cards (30) and opening cards (34) share one builder.
static func make_card_label(size: int = 30) -> Label:
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", CREAM)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_constant_override("line_spacing", 10)
	lbl.add_theme_color_override("font_outline_color", OUTLINE)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.offset_left = 140
	lbl.offset_right = -140
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate.a = 0.0
	return lbl


## Fade a card label in → hold → out on the given host (a node in the tree). Awaitable.
## Overrides let a beat quicken/linger. `tint` recolours the font before fading (crossfade).
static func play_card(host: Node, label: Label, text: String, tint: Color = CREAM,
		fin: float = CARD_FADE_IN, hold: float = CARD_HOLD, fout: float = CARD_FADE_OUT) -> void:
	if host == null or label == null or not is_instance_valid(label):
		return
	label.add_theme_color_override("font_color", tint)
	label.text = text
	label.modulate.a = 0.0
	var tw := host.create_tween()
	tw.tween_property(label, "modulate:a", 1.0, fin)
	tw.tween_interval(hold)
	tw.tween_property(label, "modulate:a", 0.0, fout)
	await tw.finished


# ==== flash + letterbox ====================================================

## A full-screen flash ColorRect (default white). Caller adds it to its layer; returns it so
## the caller can flash() it. Starts transparent.
static func make_flash(color: Color = Color(1, 1, 1)) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(color.r, color.g, color.b, 0.0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## One-frame-ish bloom: rise fast to `peak`, ebb over `ebb`s. Awaitable.
static func flash(host: Node, rect: ColorRect, peak: float = 0.9, rise: float = 0.08, ebb: float = 0.8) -> void:
	if host == null or rect == null or not is_instance_valid(rect):
		return
	var tw := host.create_tween()
	tw.tween_property(rect, "color:a", peak, rise)
	tw.tween_property(rect, "color:a", 0.0, ebb)
	await tw.finished


## Two cinematic letterbox bars (top+bottom) as children of a CanvasLayer/Control host.
## Returns the two ColorRects [top, bottom] at zero height; call slide_letterbox to reveal.
static func make_letterbox(host: CanvasItem) -> Array:
	if host == null:
		return []
	var top := ColorRect.new()
	top.color = Color(0, 0, 0, 1)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, 0)
	top.size.y = 0
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bot := ColorRect.new()
	bot.color = Color(0, 0, 0, 1)
	bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bot.size.y = 0
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(top)
	host.add_child(bot)
	return [top, bot]


## Slide the letterbox bars to `h` px (0 to hide). Awaitable.
static func slide_letterbox(host: Node, bars: Array, h: float, secs: float = 0.6) -> void:
	if host == null or bars.size() < 2:
		return
	var tw := host.create_tween().set_parallel(true)
	for b in bars:
		if b is ColorRect and is_instance_valid(b):
			tw.tween_property(b, "size:y", h, secs).set_trans(Tween.TRANS_SINE)
	await tw.finished


# ==== expanding light ripple ring ==========================================

## Build the shared ripple-ring texture (a soft bright ring peaking near the rim). `tint`
## colours it. Cached per-tint would be nice but a 128² image is cheap for a one-shot beat.
static func make_ring_texture(tint: Color = Color(0.8, 1.0, 0.85), size: int = 128) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(size / 2.0, size / 2.0)
	for y in range(size):
		for x in range(size):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (size / 2.0)
			var ring := clampf(1.0 - absf(d - 0.85) / 0.15, 0.0, 1.0)
			if ring > 0.0:
				img.set_pixel(x, y, Color(tint.r, tint.g, tint.b, ring * 0.9))
	return ImageTexture.create_from_image(img)


## Spawn an additive ripple ring at `world_pos` on a Node2D parent and expand+fade it.
## `host` drives the tween (must be in tree). Returns the Sprite2D (freed on completion).
static func spawn_ripple_ring(host: Node, parent: Node2D, world_pos: Vector2,
		tint: Color = Color(0.8, 1.0, 0.85), grow: float = 16.0, secs: float = 1.6, z: int = 50) -> Sprite2D:
	if host == null or parent == null or not is_instance_valid(parent):
		return null
	var ring := Sprite2D.new()
	ring.texture = make_ring_texture(tint)
	ring.centered = true
	ring.position = world_pos
	ring.z_index = z
	ring.scale = Vector2(0.4, 0.4)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ring.material = mat
	parent.add_child(ring)
	var tw := host.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(grow, grow), secs).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ring, "modulate:a", 0.0, secs)
	tw.chain().tween_callback(func():
		if is_instance_valid(ring):
			ring.queue_free())
	return ring


# ==== purple-dot heartbeat (CS-01 회수) ====================================

## A small violet dot centre-screen that pulses `beats` times at a heartbeat rhythm. Shared by
## the opening (각성) and E2 (대답) so the rhythm is IDENTICAL. Awaitable; frees the dot after.
## Uses an unpausable tree timer so it plays even while GameState.time_running is false.
static func purple_dot_heartbeat(host: CanvasItem, tween_host: Node, beats: int = 2,
		up: float = 0.30, down: float = 0.42, gap: float = 0.34) -> void:
	if host == null or tween_host == null:
		return
	var dot := ColorRect.new()
	dot.color = Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.0)
	dot.custom_minimum_size = Vector2(18, 18)
	dot.size = Vector2(18, 18)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-9, -9)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(dot)
	for i in range(beats):
		var tw := tween_host.create_tween()
		tw.tween_property(dot, "color:a", 0.95, up)
		tw.tween_property(dot, "color:a", 0.0, down)
		await tw.finished
		if i < beats - 1:
			await _wait(tween_host, gap)
	if is_instance_valid(dot):
		dot.queue_free()


# ==== camera pan / zoom / tilt / track =====================================

## Ease a Camera2D from its current zoom to `to_zoom` over `secs` (>1 = zoom in). Awaitable.
## Suppresses position smoothing during the move if the camera exposes it, then restores it.
static func camera_zoom_to(host: Node, cam: Camera2D, to_zoom: float, secs: float = 2.0,
		ease_t: int = Tween.TRANS_CUBIC) -> void:
	if host == null or cam == null or not is_instance_valid(cam):
		return
	var tw := host.create_tween()
	tw.tween_property(cam, "zoom", Vector2(to_zoom, to_zoom), secs) \
		.set_trans(ease_t).set_ease(Tween.EASE_OUT)
	await tw.finished


## Pan the camera OFFSET to `to_offset` (screen-space nudge, safe with limits) over `secs`.
## A gentle way to draw the eye toward a portal / landmark without moving the follow target.
static func camera_pan_offset(host: Node, cam: Camera2D, to_offset: Vector2, secs: float = 1.4) -> void:
	if host == null or cam == null or not is_instance_valid(cam):
		return
	var tw := host.create_tween()
	tw.tween_property(cam, "offset", to_offset, secs) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## A vertical "tilt" reveal (CS-03 세계수): nudge the offset up→down (or the reverse) to sweep
## the camera across a tall subject, then settle back to zero. Awaitable.
static func camera_tilt_sweep(host: Node, cam: Camera2D, from_y: float, to_y: float,
		secs: float = 2.4, settle: float = 0.8) -> void:
	if host == null or cam == null or not is_instance_valid(cam):
		return
	cam.offset = Vector2(cam.offset.x, from_y)
	var tw := host.create_tween()
	tw.tween_property(cam, "offset:y", to_y, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "offset:y", 0.0, settle).set_trans(Tween.TRANS_SINE)
	await tw.finished


# ==== helpers ==============================================================

## Unpausable tree-timer wait (runs while time_running=false, since cutscenes own the pause).
static func _wait(host: Node, secs: float) -> void:
	if host == null or host.get_tree() == null:
		return
	await host.get_tree().create_timer(secs, true, false, true).timeout
