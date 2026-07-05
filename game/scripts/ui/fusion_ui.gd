extends CanvasLayer
class_name FusionUI
## Fusion UI (조합) — opened by interacting with the Cauldron.
##
## Layout: an inventory strip (click an item to fill the next empty input slot),
## two input slots + a result slot, and a 조합 button. On fuse:
##   - match → Fusion consumes inputs, adds output, records Codex; the result slot
##     shows the output with its flavor text and does a small celebratory scale
##     pulse (Tween).
##   - no match → inputs stay, "…반응이 없다" shows, and the 5-dot hint gauge ticks.
##
## Colors: bg #2a2a33, text cream #faf5e6, accent #9e7ad9 (art guide §7).

const BG := Color("#2a2a33")
const PANEL := Color("#33333d")
const TEXT := Color("#faf5e6")
const ACCENT := Color("#9e7ad9")
const SLOT_EMPTY := Color("#1f1f26")
const DOT_ON := Color("#9e7ad9")
const DOT_OFF := Color("#44444f")

var _root: PanelContainer
var _strip: HFlowContainer
var _slot_icons: Array[TextureRect] = []
var _slot_labels: Array[Label] = []
var _result_icon: TextureRect
var _result_name: Label
var _result_flavor: Label
var _status: Label
var _dots: Array[ColorRect] = []
var _fuse_btn: Button

var _open: bool = false
## Two input slot ids ("" = empty).
var _inputs: Array[String] = ["", ""]

# ---- v0.2.1 fusion juice (조합 쾌감 §5) -----------------------------------
## Central cauldron graphic the input icons fly into on a valid fuse.
var _cauldron: TextureRect
var _cauldron_calm: Texture2D
var _cauldron_bubble: Texture2D
## Overlay layer (above the panel) hosting the flying icons, particles, flash,
## banner. Kept separate so it can be cleared each sequence without disturbing UI.
var _fx: Control
## Discovery banner ("✦ 새로운 발견! ✦") + codex counter, built lazily.
var _banner: Label
var _codex_counter: Label
## Guards against re-entrant fuse presses while a juice sequence is running.
var _animating: bool = false
## The currently running success sequence tween (so a click can skip it).
var _seq_tween: Tween
## Deferred result payload applied when the sequence completes or is skipped.
var _pending_result: Dictionary = {}
const SUCCESS_TOTAL := 1.2  ## seconds, full success sequence


func _ready() -> void:
	_build_ui()
	Inventory.changed.connect(func(): if _open: _rebuild_strip())
	Codex.hint_gauge_changed.connect(_on_gauge_changed)
	_set_visible(false)
	# Autowire: bind every Cauldron already in the scene (deferred so the whole
	# tree — including YSortLayer children — is present).
	call_deferred("_autobind_cauldrons")


## Bind every Cauldron in the `gatherable` group so interacting opens this UI. No
## scene node-path wiring needed; the cauldron lives under YSortLayer.
func _autobind_cauldrons() -> void:
	for node in get_tree().get_nodes_in_group(Gatherable.GROUP):
		if node is Cauldron:
			bind_cauldron(node)


## Wire a cauldron's `interacted` signal to open this UI.
func bind_cauldron(cauldron: Cauldron) -> void:
	if cauldron != null and not cauldron.interacted.is_connected(open):
		cauldron.interacted.connect(open)


# ---- build ---------------------------------------------------------------

func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = Vector2(520, 460)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_content_margin_all(18)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = ACCENT
	_root.add_theme_stylebox_override("panel", sb)
	add_child(_root)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	_root.add_child(outer)

	var title := Label.new()
	title.text = "솥단지 — 조합"
	title.add_theme_color_override("font_color", TEXT)
	title.add_theme_font_size_override("font_size", 24)
	outer.add_child(title)

	# --- slots row: [slot0] + [slot1] = [result] ---
	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 10)
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(slots_row)

	_slot_icons.clear()
	_slot_labels.clear()
	for i in 2:
		if i == 1:
			slots_row.add_child(_symbol("+"))
		slots_row.add_child(_make_slot(i))
	slots_row.add_child(_symbol("="))
	slots_row.add_child(_make_result_slot())

	# Central cauldron graphic (juice §5): input icons fly into this on a valid fuse.
	var caul_center := CenterContainer.new()
	outer.add_child(caul_center)
	_cauldron = TextureRect.new()
	_cauldron.custom_minimum_size = Vector2(96, 96)
	_cauldron.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cauldron.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cauldron.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cauldron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cauldron_calm = load("res://assets/objects/cauldron.png")
	_cauldron_bubble = load("res://assets/objects/cauldron_bubble.png")
	_cauldron.texture = _cauldron_calm
	caul_center.add_child(_cauldron)

	# --- clear + fuse buttons ---
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(btn_row)

	var clear_btn := Button.new()
	clear_btn.text = "비우기"
	clear_btn.focus_mode = Control.FOCUS_NONE
	clear_btn.pressed.connect(_clear_inputs)
	btn_row.add_child(clear_btn)

	_fuse_btn = Button.new()
	_fuse_btn.text = "조합"
	_fuse_btn.focus_mode = Control.FOCUS_NONE
	_fuse_btn.custom_minimum_size = Vector2(120, 40)
	_fuse_btn.pressed.connect(_on_fuse_pressed)
	btn_row.add_child(_fuse_btn)

	# --- status + flavor ---
	_status = Label.new()
	_status.add_theme_color_override("font_color", ACCENT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(_status)

	_result_flavor = Label.new()
	_result_flavor.add_theme_color_override("font_color", TEXT)
	_result_flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_flavor.custom_minimum_size = Vector2(480, 0)
	outer.add_child(_result_flavor)

	# --- hint gauge (5 dots) ---
	var gauge_row := HBoxContainer.new()
	gauge_row.add_theme_constant_override("separation", 6)
	gauge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(gauge_row)
	var gauge_lbl := Label.new()
	gauge_lbl.text = "힌트"
	gauge_lbl.add_theme_color_override("font_color", TEXT)
	gauge_row.add_child(gauge_lbl)
	_dots.clear()
	for i in Codex.HINT_THRESHOLD:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.color = DOT_OFF
		gauge_row.add_child(dot)
		_dots.append(dot)

	# --- inventory strip ---
	var strip_lbl := Label.new()
	strip_lbl.text = "재료 선택"
	strip_lbl.add_theme_color_override("font_color", TEXT)
	outer.add_child(strip_lbl)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(484, 120)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_strip = HFlowContainer.new()
	_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_strip)

	# FX overlay: full-rect, above the panel, ignores mouse. Flying icons, particle
	# bursts, the success flash and the discovery banner all live here so they never
	# reflow the panel layout.
	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)


func _symbol(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", TEXT)
	l.add_theme_font_size_override("font_size", 28)
	return l


func _make_slot(index: int) -> Control:
	var box := _slot_panel()
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(v)

	var icon := _icon_rect(56)
	v.add_child(icon)

	var lbl := Label.new()
	lbl.text = "비어 있음"
	lbl.add_theme_color_override("font_color", TEXT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl)

	# Click a filled slot to clear just that slot.
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_slot_pressed.bind(index))
	box.add_child(btn)

	_slot_icons.append(icon)
	_slot_labels.append(lbl)
	return box


func _make_result_slot() -> Control:
	var box := _slot_panel()
	box.name = "ResultSlot"
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(v)

	_result_icon = _icon_rect(56)
	v.add_child(_result_icon)

	_result_name = Label.new()
	_result_name.text = "???"
	_result_name.add_theme_color_override("font_color", TEXT)
	_result_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_result_name)
	return box


func _slot_panel() -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(96, 96)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_content_margin_all(6)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.4)
	box.add_theme_stylebox_override("panel", sb)
	return box


## An icon TextureRect (nearest-filtered, aspect-fit), initially empty.
func _icon_rect(sz: int) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(sz, sz)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


# ---- open / close --------------------------------------------------------

func open() -> void:
	_clear_inputs()
	_status.text = ""
	_result_flavor.text = ""
	_rebuild_strip()
	_refresh_dots()
	_set_visible(true)


func _set_visible(v: bool) -> void:
	_open = v
	_root.visible = v


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	# A click / interact / left-mouse during a running success sequence SKIPS the
	# juice (jump to result) instead of closing the panel (juice §5).
	if _animating and (event.is_action_pressed("interact")
			or (event is InputEventMouseButton and event.pressed
				and event.button_index == MOUSE_BUTTON_LEFT)):
		_skip_sequence()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		_set_visible(false)
		get_viewport().set_input_as_handled()


# ---- inventory strip -----------------------------------------------------

func _rebuild_strip() -> void:
	for c in _strip.get_children():
		c.queue_free()
	for id: String in Inventory.ids():
		_add_strip_item(id)


func _add_strip_item(id: String) -> void:
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(150, 44)  # ≥44px touch target (M6a mobile)
	btn.pressed.connect(_on_strip_pressed.bind(id))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	var icon := _icon_rect(28)
	icon.texture = ItemDB.icon(id)
	row.add_child(icon)

	var lbl := Label.new()
	lbl.text = "%s x%d" % [ItemDB.item_name(id), Inventory.count(id)]
	lbl.add_theme_color_override("font_color", TEXT)
	row.add_child(lbl)

	_strip.add_child(btn)


func _on_strip_pressed(id: String) -> void:
	# Fill the first empty slot with this id.
	for i in _inputs.size():
		if _inputs[i] == "":
			_inputs[i] = id
			_refresh_slots()
			return


func _on_slot_pressed(index: int) -> void:
	if _inputs[index] != "":
		_inputs[index] = ""
		_refresh_slots()


func _clear_inputs() -> void:
	_inputs = ["", ""]
	_refresh_slots()
	_result_icon.texture = null
	_result_name.text = "???"


func _refresh_slots() -> void:
	for i in _inputs.size():
		var id := _inputs[i]
		if id == "":
			_slot_icons[i].texture = null
			_slot_labels[i].text = "비어 있음"
		else:
			_slot_icons[i].texture = ItemDB.icon(id)
			_slot_labels[i].text = ItemDB.item_name(id)


# ---- fuse ----------------------------------------------------------------

func _on_fuse_pressed() -> void:
	# A click during a running success sequence skips it to the result (juice §5).
	if _animating:
		_skip_sequence()
		return
	if _inputs[0] == "" or _inputs[1] == "":
		_status.text = "재료를 두 개 넣어라."
		return

	# --- LOGIC UNCHANGED: capture the input icons for the fly-in BEFORE fuse mutates
	# the slots, snapshot the codex recipe count for first-discovery detection, run
	# the real fuse, then drive the juice around the identical result payload. ---
	var in_icons: Array[Texture2D] = [ItemDB.icon(_inputs[0]), ItemDB.icon(_inputs[1])]
	var recipes_before := Codex.discovered_recipe_count()

	var res := Fusion.fuse(_inputs[0], _inputs[1])
	if res["matched"]:
		var first_discovery := Codex.discovered_recipe_count() > recipes_before
		# Inputs are consumed by fuse(); clear the slots + strip now (as before).
		_inputs = ["", ""]
		_refresh_slots()
		_rebuild_strip()
		# Defer the visible result until the sequence pops it (or a skip fast-forwards).
		_pending_result = {
			"output": res["output"],
			"first": first_discovery,
		}
		_status.text = ""
		_play_success_sequence(in_icons)
	else:
		_status.text = "…반응이 없다"
		_result_flavor.text = ""
		if res["hint_revealed"]:
			_status.text = "…반응이 없다  (힌트가 도감에 나타났다)"
		_play_failure_feedback()


# ==== success juice sequence (~1.2s, click-skippable) ======================

func _play_success_sequence(in_icons: Array[Texture2D]) -> void:
	_animating = true
	_clear_fx()
	# Clear the result slot while brewing (it pops in at the end).
	_result_icon.texture = null
	_result_name.text = "???"
	_result_flavor.text = ""

	var caul_pos := _center_global(_cauldron)

	# 1. Input icons fly from the two input slots into the cauldron (arc + shrink).
	for i in in_icons.size():
		if in_icons[i] == null:
			continue
		var fly := TextureRect.new()
		fly.texture = in_icons[i]
		fly.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fly.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fly.size = Vector2(56, 56)
		fly.pivot_offset = Vector2(28, 28)
		var start := _center_global(_slot_icons[i]) - Vector2(28, 28)
		fly.global_position = start
		_fx.add_child(fly)
		var arc := create_tween()
		arc.set_parallel(true)
		# arc via an intermediate raised midpoint
		var mid := start.lerp(caul_pos - Vector2(28, 28), 0.5) - Vector2(0, 60)
		arc.tween_property(fly, "global_position", mid, 0.18).set_ease(Tween.EASE_OUT)
		arc.chain().tween_property(fly, "global_position", caul_pos - Vector2(28, 28), 0.18).set_ease(Tween.EASE_IN)
		arc.parallel().tween_property(fly, "scale", Vector2(0.3, 0.3), 0.36)
		arc.parallel().tween_property(fly, "modulate:a", 0.4, 0.36)
		arc.chain().tween_callback(fly.queue_free)

	# 2. Cauldron anticipation: bubble frame + scale pulse + violet particle burst.
	_seq_tween = create_tween()
	_seq_tween.tween_interval(0.36)  # wait for the fly-in
	_seq_tween.tween_callback(func():
		if _cauldron_bubble != null:
			_cauldron.texture = _cauldron_bubble
		_burst_particles(caul_pos, Color("#9e7ad9"), 26))
	_cauldron.pivot_offset = _cauldron.size * 0.5
	_seq_tween.tween_property(_cauldron, "scale", Vector2(1.22, 1.22), 0.2).set_trans(Tween.TRANS_SINE)
	_seq_tween.tween_property(_cauldron, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE)
	# 3. Flash.
	_seq_tween.tween_callback(_flash)
	# 4. Result POPS + sparkles.
	_seq_tween.tween_callback(_reveal_result)
	_seq_tween.tween_callback(func(): _animating = false)


## Apply the pending result to the result slot and pop it (overshoot). Idempotent.
func _reveal_result() -> void:
	if _pending_result.is_empty():
		return
	var out: String = _pending_result.get("output", "")
	var first: bool = _pending_result.get("first", false)
	_pending_result = {}
	if _cauldron != null:
		_cauldron.texture = _cauldron_calm
	_result_icon.texture = ItemDB.icon(out)
	_result_name.text = ItemDB.item_name(out)
	_result_flavor.text = ItemDB.item_flavor(out)
	_status.text = "새로운 것을 만들었다!"
	_pop_result_slot()
	_burst_particles(_center_global(_result_icon), Color("#d9b8ff"), 20)
	if first:
		_show_discovery_banner()


func _pop_result_slot() -> void:
	var slot := _root.find_child("ResultSlot", true, false) as Control
	if slot == null:
		return
	slot.pivot_offset = slot.size * 0.5
	slot.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_property(slot, "scale", Vector2(1.35, 1.35), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(slot, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE)


## Click-skip: jump straight to the popped result.
func _skip_sequence() -> void:
	if _seq_tween != null and _seq_tween.is_valid():
		_seq_tween.kill()
	_clear_fx()
	if _cauldron != null:
		_cauldron.scale = Vector2.ONE
	_reveal_result()
	_animating = false


# ==== failure feedback (gray smoke + panel shake) ==========================

func _play_failure_feedback() -> void:
	# Gray smoke puff at the cauldron.
	_burst_particles(_center_global(_cauldron), Color(0.72, 0.72, 0.76), 16)
	# Panel shake (position tween).
	var base := _root.position
	var tw := create_tween()
	for i in 4:
		var dx := 10.0 if i % 2 == 0 else -10.0
		tw.tween_property(_root, "position", base + Vector2(dx, 0), 0.05).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_root, "position", base, 0.05)


# ==== fx primitives ========================================================

## A short-lived violet flash over the whole panel.
func _flash() -> void:
	var f := ColorRect.new()
	f.color = Color(0.85, 0.72, 1.0, 0.0)
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "color:a", 0.5, 0.06)
	tw.tween_property(f, "color:a", 0.0, 0.22)
	tw.tween_callback(f.queue_free)


## A one-shot CPUParticles2D burst at a global position.
func _burst_particles(global_pos: Vector2, col: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = global_pos
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 0.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 6.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 120)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = col
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	_fx.add_child(p)
	p.emitting = true
	# Auto-free after the burst finishes.
	var t := get_tree().create_timer(1.0)
	t.timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())


## Slide-in "✦ 새로운 발견! ✦" banner + a visible codex recipe counter tick.
func _show_discovery_banner() -> void:
	if _banner == null:
		_banner = Label.new()
		_banner.add_theme_color_override("font_color", Color("#d9b8ff"))
		_banner.add_theme_font_size_override("font_size", 22)
		_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.12, 0.22, 0.92)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(8)
		sb.set_border_width_all(2)
		sb.border_color = Color("#9e7ad9")
		_banner.add_theme_stylebox_override("normal", sb)
		_fx.add_child(_banner)

		_codex_counter = Label.new()
		_codex_counter.add_theme_color_override("font_color", Color("#faf5e6"))
		_codex_counter.add_theme_font_size_override("font_size", 16)
		_codex_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fx.add_child(_codex_counter)

	_banner.text = "✦ 새로운 발견! ✦"
	_banner.visible = true
	_banner.size = _banner.get_minimum_size()
	var cx := _root.global_position.x + _root.size.x * 0.5 - _banner.size.x * 0.5
	var top_y := _root.global_position.y - 6
	_banner.global_position = Vector2(cx, top_y - 40)
	_banner.modulate.a = 0.0

	_codex_counter.text = "도감 레시피 %d종" % Codex.discovered_recipe_count()
	_codex_counter.visible = true
	_codex_counter.size = _codex_counter.get_minimum_size()
	_codex_counter.global_position = Vector2(
		_root.global_position.x + _root.size.x * 0.5 - _codex_counter.size.x * 0.5,
		top_y - 8)
	_codex_counter.modulate = Color(1, 1, 1, 0)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_banner, "global_position:y", top_y - 8, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(_codex_counter, "modulate:a", 1.0, 0.4).set_delay(0.2)
	# Tick pulse on the counter.
	tw.chain().tween_callback(func():
		if not is_instance_valid(_codex_counter):
			return
		_codex_counter.pivot_offset = _codex_counter.size * 0.5
		var pt := create_tween()
		pt.tween_property(_codex_counter, "scale", Vector2(1.3, 1.3), 0.12)
		pt.tween_property(_codex_counter, "scale", Vector2.ONE, 0.15))


func _clear_fx() -> void:
	if _fx == null:
		return
	for c in _fx.get_children():
		c.queue_free()
	_banner = null
	_codex_counter = null


## Global-space center of a Control.
func _center_global(c: Control) -> Vector2:
	return c.global_position + c.size * 0.5


# ---- hint gauge dots -----------------------------------------------------

func _on_gauge_changed(_value: int) -> void:
	if _open:
		_refresh_dots()


func _refresh_dots() -> void:
	var g := Codex.hint_gauge()
	for i in _dots.size():
		_dots[i].color = DOT_ON if i < g else DOT_OFF
