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
## (v0.4.0-B B3.4) Inline "힌트 보기" expander in the gauge area — a second surface
## (besides the 도감 "힌트" chip) where gauge-revealed hints are findable, right where
## they were earned. Toggle button + a collapsible VBox listing "? + [재료] = ?" rows.
var _hint_toggle: Button
var _hint_list: VBoxContainer
var _hints_expanded: bool = false

# ---- v1.1.0 GP-3 §4 조합 UI 리워크 ----------------------------------------
## (§4.3-B) Active ingredient-category filter for the strip ("" = 전체).
var _strip_filter: String = ""
## Category filter chip buttons (label -> Button), so the active one can be highlighted.
var _filter_chips: Dictionary = {}
## Row hosting the "최근 조합" one-tap re-craft buttons.
var _recent_row: HFlowContainer
## Recent SUCCESSFUL fusions as [a_id, b_id] pairs (most-recent first, capped).
var _recent: Array = []
const RECENT_MAX := 6
## (§4.3-D) 도감 연결 라벨 ("도감 N/M 발견").
var _codex_link_lbl: Label
## The (label -> [keywords]) category table shared with the codex classifier vibe. Chips use these.
const FILTER_CATEGORIES := [
	["전체", []],
	["물", ["물", "수", "이슬", "샘", "액", "냉각", "증류", "젖"]],
	["불", ["불", "화", "숯", "재", "잔불", "불씨", "열", "용암"]],
	["흙", ["흙", "토", "진흙", "모래", "점토", "땅"]],
	["광물", ["돌", "석", "철", "금속", "구리", "황동", "대리석", "결정", "광", "쇠", "고철", "바위"]],
	["식물", ["풀", "잎", "꽃", "씨", "나무", "이끼", "덩굴", "가지", "줄기", "뿌리"]],
	["기계", ["톱니", "태엽", "회로", "전선", "부품", "기어", "벨트", "나사", "전지", "배터리"]],
	["빛", ["빛", "등", "성물", "촛", "성수", "신성", "룬", "마력"]],
]

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
## (v0.4.0-B B3.3) SINGLE composed discovery banner (icon + "새로운 발견! — [name]" +
## small "도감 N/M") that slides in ABOVE the panel. Built lazily. Replaces the old
## two-node banner+counter that overlapped/garbled at the panel top.
var _banner: PanelContainer
var _banner_name_lbl: Label
var _banner_flavor_lbl: Label   # (v1.1.0 GP-5) 발견 카드 flavor line
var _banner_count_lbl: Label
var _banner_icon: TextureRect
## Discoveries that arrived while a banner was still animating; shown one at a time.
var _banner_queue: Array[String] = []
var _banner_busy: bool = false
## Guards against re-entrant fuse presses while a juice sequence is running.
var _animating: bool = false
## The currently running success sequence tween (so a click can skip it).
var _seq_tween: Tween
## Deferred result payload applied when the sequence completes or is skipped.
var _pending_result: Dictionary = {}
const SUCCESS_TOTAL := 1.2  ## seconds, full success sequence


func _ready() -> void:
	_build_ui()
	Inventory.changed.connect(func():
		if _open:
			_rebuild_strip()
			_rebuild_recent())   # refresh 최근 조합 in-stock/disabled states
	Codex.hint_gauge_changed.connect(_on_gauge_changed)
	# (v1.1.0 GP-3 §4.3-D) keep the 도감 연결 count live on new discoveries.
	Codex.recipe_discovered.connect(func(_id): if _open: _refresh_codex_link())
	# v0.3.1 R1: clamp the panel to the viewport on every resize so the ingredient
	# strip + 조합 button stay reachable at small window sizes (owner's top pain).
	get_viewport().size_changed.connect(_clamp_to_viewport)
	_clamp_to_viewport()
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

## v0.3.1 Fix 1: the panel is centered and CLAMPED to fit any viewport ≥ 1152×648.
## A full-rect anchor Control hosts a CenterContainer; the panel caps its height at
## ~85% of the viewport and its content lives in a ScrollContainer so the ingredient
## strip, 조합 button, gauge and result stay visible together at small window sizes.
var _fit: Control
var _scroll_body: ScrollContainer

func _build_ui() -> void:
	# Full-rect host + center container so the panel always sits centered and can be
	# height-clamped on resize.
	_fit = Control.new()
	_fit.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fit)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit.add_child(center)

	_root = PanelContainer.new()
	_root.custom_minimum_size = Vector2(480, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_content_margin_all(16)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = ACCENT
	_root.add_theme_stylebox_override("panel", sb)
	center.add_child(_root)

	# The panel's content scrolls vertically if it can't all fit (keeps every control
	# reachable at 1152×648); horizontal scroll disabled.
	_scroll_body = ScrollContainer.new()
	_scroll_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(_scroll_body)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_body.add_child(outer)

	# title row: title (left) + close (X) top-right (B3.2/B3.5).
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	outer.add_child(title_row)
	var title := Label.new()
	title.text = "솥단지 — 조합"
	title.add_theme_color_override("font_color", TEXT)
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title)
	title_row.add_child(WindowChrome.make_close_button(func(): _set_visible(false)))
	outer.add_child(_divider())

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
	outer.add_child(_divider())
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

	# (B3.4) "힌트 보기" toggle: expands an inline list of gauge-revealed hints right
	# in the gauge area, so revealed hints are findable where they were earned (the
	# owner's "도감 힌트도 안보인다" — surfaced here AND in the 도감 힌트 chip).
	_hint_toggle = Button.new()
	_hint_toggle.name = "HintToggle"
	_hint_toggle.focus_mode = Control.FOCUS_NONE
	_hint_toggle.flat = true
	_hint_toggle.add_theme_color_override("font_color", ACCENT)
	_hint_toggle.add_theme_color_override("font_hover_color", Color("#c8b0ec"))
	_hint_toggle.add_theme_font_size_override("font_size", 14)
	_hint_toggle.pressed.connect(_toggle_hints)
	gauge_row.add_child(_hint_toggle)

	# collapsible hint list (hidden until expanded / no hints)
	_hint_list = VBoxContainer.new()
	_hint_list.name = "FusionHintList"
	_hint_list.add_theme_constant_override("separation", 3)
	_hint_list.visible = false
	outer.add_child(_hint_list)

	# --- inventory strip ---
	outer.add_child(_divider())
	var strip_lbl := Label.new()
	strip_lbl.text = "재료 선택"
	strip_lbl.add_theme_color_override("font_color", TEXT)
	outer.add_child(strip_lbl)

	# (v1.1.0 GP-3 §4.3-B) category filter chips — tap to narrow the strip by ingredient family.
	var filter_row := HFlowContainer.new()
	filter_row.name = "FilterRow"
	filter_row.add_theme_constant_override("h_separation", 4)
	filter_row.add_theme_constant_override("v_separation", 4)
	outer.add_child(filter_row)
	_filter_chips.clear()
	for entry in FILTER_CATEGORIES:
		var label: String = entry[0]
		var chip := Button.new()
		chip.text = label
		chip.toggle_mode = true
		chip.focus_mode = Control.FOCUS_NONE
		chip.custom_minimum_size = Vector2(0, 44)   # ≥44px touch target (mobile)
		chip.add_theme_font_size_override("font_size", 14)
		chip.button_pressed = (label == "전체")
		chip.pressed.connect(_on_filter_chip.bind(label))
		filter_row.add_child(chip)
		_filter_chips[label] = chip

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(484, 120)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_strip = HFlowContainer.new()
	_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_strip)

	# (v1.1.0 GP-3 §4.3-C) 최근 조합 — one-tap re-craft buttons for the last few successful fusions.
	var recent_lbl := Label.new()
	recent_lbl.name = "RecentLabel"
	recent_lbl.text = "최근 조합"
	recent_lbl.add_theme_color_override("font_color", TEXT)
	outer.add_child(recent_lbl)
	_recent_row = HFlowContainer.new()
	_recent_row.name = "RecentRow"
	_recent_row.add_theme_constant_override("h_separation", 4)
	_recent_row.add_theme_constant_override("v_separation", 4)
	outer.add_child(_recent_row)

	# (v1.1.0 GP-3 §4.3-D) 도감 연결 — discovery count + [도감 열기 R] hint.
	_codex_link_lbl = Label.new()
	_codex_link_lbl.name = "CodexLink"
	_codex_link_lbl.add_theme_color_override("font_color", ACCENT)
	_codex_link_lbl.add_theme_font_size_override("font_size", 14)
	outer.add_child(_codex_link_lbl)

	# (B3.2) close affordance hint at the panel bottom — pairs with the ✕ button so it
	# reads as closeable ("닫을 수 있어 보이지도 않고").
	outer.add_child(_divider())
	outer.add_child(WindowChrome.make_esc_hint())

	# FX overlay: full-rect, above the panel, ignores mouse. Flying icons, particle
	# bursts, the success flash and the discovery banner all live here so they never
	# reflow the panel layout.
	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)

	# (B3.4) initialise the inline hint toggle caption ("▸ 힌트 보기 (0)" / disabled).
	_refresh_hint_toggle()


## v0.3.1 R1: cap the panel height at min(700, viewport*0.85) so it never extends past
## the window bottom. The content lives in _scroll_body (vertical scroll), so when the
## natural content height exceeds the cap the strip stays reachable via scroll. Width is
## also capped at viewport*0.9 for very narrow windows. Called on _ready + every resize.
const MAX_PANEL_H := 700.0
## `override_size` lets the v031 harness drive an arbitrary viewport size headless (the
## dummy display can't actually resize the window); production passes Vector2.ZERO to read
## the live viewport.
func _clamp_to_viewport(override_size: Vector2 = Vector2.ZERO) -> void:
	if _root == null or _scroll_body == null:
		return
	var vp: Vector2 = override_size if override_size != Vector2.ZERO else get_viewport().get_visible_rect().size
	var cap_h: float = min(MAX_PANEL_H, vp.y * 0.85)
	# The PanelContainer adds 16px content margins top+bottom (=32) around the scroll body.
	var body_cap: float = max(120.0, cap_h - 32.0)
	_scroll_body.custom_minimum_size = Vector2(_scroll_body.custom_minimum_size.x, body_cap)
	_root.custom_minimum_size = Vector2(min(480.0, vp.x * 0.9), 0.0)
	# Hard-cap the panel so a tall content tree can't push it past the cap.
	_root.set("size", Vector2(_root.size.x, min(_root.size.y, cap_h)))


## (B3.5) A thin violet-tinted section divider for consistent panel rhythm.
func _divider() -> HSeparator:
	var sep := HSeparator.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.25)
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sb)
	return sep


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
	# (v1.1.0 GP-3) reflect 최근 조합 + 도감 연결 on open.
	_rebuild_recent()
	_refresh_codex_link()
	# (B3.4) reflect any hints revealed while the panel was closed; keep it collapsed
	# on open so the panel opens compact.
	_hints_expanded = false
	if _hint_list != null:
		_hint_list.visible = false
	_refresh_hint_toggle()
	_set_visible(true)
	_clamp_to_viewport()


## Close the fusion panel. Consistent with the other windows' close() API.
func close() -> void:
	_set_visible(false)


## (B3.4 harness) Programmatically expand the inline hint list; returns the number of
## hint rows now shown.
func expand_hints_for_test() -> int:
	if not _hints_expanded:
		_toggle_hints()
	return _hint_list.get_child_count() if _hint_list != null else 0


## (B3.4 harness) The child count of the inline fusion hint list.
func fusion_hint_row_count() -> int:
	return _hint_list.get_child_count() if _hint_list != null else 0


func _set_visible(v: bool) -> void:
	_open = v
	_root.visible = v
	# (v0.4.0-B B3.1) Freeze the world while the fusion panel is up.
	if GameState != null:
		if v:
			GameState.push_modal("fusion")
		else:
			GameState.pop_modal("fusion")


func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if not _open:
		return
	# A click / interact / left-mouse during a running success sequence SKIPS the
	# juice (jump to result) instead of closing the panel (juice §5).
	if _animating and (event.is_action_pressed("interact")
			or (event is InputEventMouseButton and event.pressed
				and event.button_index == MOUSE_BUTTON_LEFT)):
		_skip_sequence()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		_set_visible(false)
		var vp2 := get_viewport()
		if vp2:
			vp2.set_input_as_handled()


# ---- inventory strip -----------------------------------------------------

func _rebuild_strip() -> void:
	for c in _strip.get_children():
		c.queue_free()
	for id: String in Inventory.ids():
		if _matches_filter(id):
			_add_strip_item(id)


## (v1.1.0 GP-3 §4.3-B) True if `id`'s name matches the active category filter ("" / 전체 = all).
func _matches_filter(id: String) -> bool:
	if _strip_filter == "" or _strip_filter == "전체":
		return true
	var nm := ItemDB.item_name(id)
	for entry in FILTER_CATEGORIES:
		if String(entry[0]) == _strip_filter:
			for kw: String in entry[1]:
				if nm.contains(kw):
					return true
			return false
	return true


## Filter chip pressed: make it exclusive, set the active filter, rebuild the strip.
func _on_filter_chip(label: String) -> void:
	_strip_filter = label
	for l: String in _filter_chips.keys():
		(_filter_chips[l] as Button).button_pressed = (l == label)
	_rebuild_strip()


## (harness) Set the strip filter programmatically; returns the strip item count after filtering.
func set_strip_filter(label: String) -> int:
	_on_filter_chip(label)
	return _strip.get_child_count()


# ---- v1.1.0 GP-3 §4.3-C 최근 조합 + §4.3-D 도감 연결 -----------------------

## Push a successful pair onto the recent queue (dedup order-independent, most-recent first, capped).
func _record_recent(a_id: String, b_id: String) -> void:
	var ca := ItemDB.resolve_id(a_id)
	var cb := ItemDB.resolve_id(b_id)
	# Remove an existing same (unordered) pair so it re-surfaces at the front.
	for i in range(_recent.size() - 1, -1, -1):
		var p: Array = _recent[i]
		if (p[0] == ca and p[1] == cb) or (p[0] == cb and p[1] == ca):
			_recent.remove_at(i)
	_recent.push_front([ca, cb])
	while _recent.size() > RECENT_MAX:
		_recent.pop_back()
	_rebuild_recent()


## Rebuild the 최근 조합 row: one [재료A+재료B ⟳] button per remembered pair. Tapping auto-fills the
## two slots IF both are in stock (else the button is disabled — can't craft what you don't have).
func _rebuild_recent() -> void:
	if _recent_row == null:
		return
	for c in _recent_row.get_children():
		c.queue_free()
	if _recent.is_empty():
		var none := Label.new()
		none.text = "—"
		none.add_theme_color_override("font_color", DOT_OFF)
		_recent_row.add_child(none)
		return
	for pair: Array in _recent:
		var a: String = pair[0]
		var b: String = pair[1]
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 44)   # ≥44px touch target
		btn.add_theme_font_size_override("font_size", 13)
		btn.text = "%s + %s ⟳" % [ItemDB.item_name(a), ItemDB.item_name(b)]
		var in_stock := _pair_in_stock(a, b)
		btn.disabled = not in_stock
		btn.pressed.connect(_on_recent_pressed.bind(a, b))
		_recent_row.add_child(btn)


## True if the inventory can cover BOTH ingredients of a pair (2 of the same for a self-pair).
func _pair_in_stock(a: String, b: String) -> bool:
	if a == b:
		return Inventory.count(a) >= 2 or ItemDB.is_unique(a)
	return Inventory.count(a) >= 1 and Inventory.count(b) >= 1


## One-tap re-craft: fill both slots from a recent pair (in-stock guaranteed by the disabled state).
func _on_recent_pressed(a: String, b: String) -> void:
	if _animating:
		return
	_inputs = [a, b]
	_refresh_slots()


## (§4.3-D) Update the 도감 연결 line ("도감 N / M 발견   ·   [도감 열기 R]").
func _refresh_codex_link() -> void:
	if _codex_link_lbl == null:
		return
	_codex_link_lbl.text = "도감  %d / %d 레시피 발견   ·   [도감 열기 R]" % [
		Codex.discovered_recipe_count(), RecipeDB.all_ids().size()]


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
	_refresh_preview()


## (v1.1.0 GP-3 §4.3-A) 실시간 결과 미리보기 — the moment BOTH input slots are filled, peek (no
## consume) and paint the result slot: known recipe → 확정 output; unknown valid recipe → result
## silhouette (+ staged poetic hint); fail mapping → gray junk preview; else "?". LOGIC UNCHANGED:
## `Fusion.peek` never mutates; the real transaction is still the 조합 button.
func _refresh_preview() -> void:
	# Never fight the success/failure juice — the sequence owns the result slot then.
	if _animating or not _pending_result.is_empty():
		return
	if _result_icon == null:
		return
	if _inputs[0] == "" or _inputs[1] == "":
		_result_icon.texture = null
		_result_icon.modulate = Color.WHITE
		_result_name.text = "???"
		return
	var pk := Fusion.peek(_inputs[0], _inputs[1])
	var state := String(pk.get("state", "none"))
	match state:
		"known":
			_result_icon.texture = ItemDB.icon(String(pk["output"]))
			_result_icon.modulate = Color.WHITE
			_result_name.text = ItemDB.item_name(String(pk["output"]))
		"unknown":
			# Reveal the result as a silhouette; if a staged poetic hint exists, name it poetically.
			_result_icon.texture = ItemDB.icon(String(pk["output"]))
			_result_icon.modulate = Color(0.16, 0.15, 0.2, 1.0)
			var rid := String(pk.get("recipe_id", ""))
			if int(pk.get("hint_stage", 0)) >= 1 and rid != "":
				_result_name.text = Codex.hint_poetic_name(rid)
			else:
				_result_name.text = "? 무언가 만들어질 것 같다 ?"
		"fail":
			_result_icon.texture = ItemDB.icon(String(pk["output"]))
			_result_icon.modulate = Color(0.7, 0.7, 0.72)
			_result_name.text = "…?"
		_:
			_result_icon.texture = null
			_result_icon.modulate = Color.WHITE
			_result_name.text = "?"


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
	# (v1.1.0 GP-3 §4.3-C) capture the pair BEFORE fuse() clears the slots, to log 최근 조합 on success.
	var fused_pair := [_inputs[0], _inputs[1]]

	var res := Fusion.fuse(_inputs[0], _inputs[1])
	if res["matched"]:
		var first_discovery := Codex.discovered_recipe_count() > recipes_before
		_record_recent(fused_pair[0], fused_pair[1])
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
	elif String(res.get("fail_output", "")) != "":
		# (v1.1.0 GP-2 §2.3) 실패작: a plausible-wrong pair produced junk. Inputs WERE consumed, so
		# clear the slots + strip, then pop the 실패작 into the result slot with its swamp-tone quip.
		var fail_out := String(res["fail_output"])
		_inputs = ["", ""]
		_refresh_slots()
		_rebuild_strip()
		_result_icon.texture = ItemDB.icon(fail_out)
		_result_icon.modulate = Color(0.7, 0.7, 0.72)   # gray-tone: it's junk
		_result_name.text = ItemDB.item_name(fail_out)
		_result_flavor.text = String(res.get("fail_flavor", ""))
		_status.text = "…실패작이 나왔다  ·  도감에 기록되었다"
		_pop_result_slot()
		_burst_particles(_center_global(_cauldron), Color(0.72, 0.72, 0.76), 16)
	else:
		_status.text = "…반응이 없다"
		_result_flavor.text = ""
		# (L2-3) A MATCHED recipe that couldn't fuse for a Whisper-cost shortfall reports its
		# reason ("에너지가 부족하다") instead of the generic no-reaction line. Inputs untouched.
		var reason := String(res.get("failure_reason", ""))
		if reason != "":
			_status.text = "…%s" % reason
		elif res["hint_revealed"]:
			# (B3.4) point the player at where the hint went so it's findable.
			_status.text = "…반응이 없다  ·  도감(R)에 힌트가 기록되었다"
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
	_result_icon.modulate = Color.WHITE   # reset in case a prior 실패작 grayed it
	_result_name.text = ItemDB.item_name(out)
	_result_flavor.text = ItemDB.item_flavor(out)
	_status.text = "새로운 것을 만들었다!"
	_pop_result_slot()
	_burst_particles(_center_global(_result_icon), Color("#d9b8ff"), 20)
	if first:
		_queue_discovery_banner(out)


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


## (B3.3) Queue a discovery. Multiple first-discoveries show ONE AT A TIME rather than
## stacking overlapping banners. `output_id` is the newly-crafted item.
func _queue_discovery_banner(output_id: String) -> void:
	_banner_queue.append(output_id)
	if not _banner_busy:
		_show_next_discovery_banner()


## The single composed discovery banner: [icon] "새로운 발견! — [item name]" + a small
## "도감 N/M" line, all in ONE panel that slides in from just ABOVE the fusion panel's
## top edge (never overlapping the "솥단지 — 조합" title). Auto-dismisses, then shows the
## next queued discovery.
func _show_next_discovery_banner() -> void:
	if _banner_queue.is_empty():
		_banner_busy = false
		return
	_banner_busy = true
	var output_id: String = _banner_queue.pop_front()

	if _banner == null:
		_banner = PanelContainer.new()
		_banner.name = "DiscoveryBanner"
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.12, 0.22, 0.95)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(10)
		sb.set_border_width_all(2)
		sb.border_color = Color("#9e7ad9")
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 6
		_banner.add_theme_stylebox_override("panel", sb)
		_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx.add_child(_banner)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		_banner.add_child(row)

		_banner_icon = TextureRect.new()
		_banner_icon.custom_minimum_size = Vector2(36, 36)
		_banner_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_banner_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_banner_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_banner_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_banner_icon)

		var textcol := VBoxContainer.new()
		textcol.add_theme_constant_override("separation", 1)
		row.add_child(textcol)

		_banner_name_lbl = Label.new()
		_banner_name_lbl.add_theme_color_override("font_color", Color("#d9b8ff"))
		_banner_name_lbl.add_theme_font_size_override("font_size", 20)
		textcol.add_child(_banner_name_lbl)

		# (v1.1.0 GP-5) 발견 카드 상향: a poetic flavor line under the name (아이콘+이름+flavor).
		_banner_flavor_lbl = Label.new()
		_banner_flavor_lbl.name = "DiscoveryFlavor"
		_banner_flavor_lbl.add_theme_color_override("font_color", Color("#c8b0ec"))
		_banner_flavor_lbl.add_theme_font_size_override("font_size", 13)
		_banner_flavor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_banner_flavor_lbl.custom_minimum_size = Vector2(260, 0)
		textcol.add_child(_banner_flavor_lbl)

		_banner_count_lbl = Label.new()
		_banner_count_lbl.add_theme_color_override("font_color", Color("#faf5e6"))
		_banner_count_lbl.add_theme_font_size_override("font_size", 14)
		textcol.add_child(_banner_count_lbl)

	# Fill content for THIS discovery.
	_banner_icon.texture = ItemDB.icon(output_id)
	_banner_name_lbl.text = "✦ 새로운 발견! — %s" % ItemDB.item_name(output_id)
	if _banner_flavor_lbl != null:
		_banner_flavor_lbl.text = ItemDB.item_flavor(output_id)
	_banner_count_lbl.text = "도감 %d / %d 종" % [
		Codex.discovered_recipe_count(), RecipeDB.all_ids().size()]
	_banner.visible = true

	# Position ABOVE the panel top, horizontally centered on the panel.
	_banner.reset_size()
	_banner.size = _banner.get_minimum_size()
	var cx := _root.global_position.x + _root.size.x * 0.5 - _banner.size.x * 0.5
	var top_y := _root.global_position.y - _banner.size.y - 8   # fully above the panel edge
	_banner.global_position = Vector2(cx, top_y - 28)
	_banner.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_banner, "global_position:y", top_y, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.28)
	# Hold, then fade out and advance the queue.
	tw.chain().tween_interval(1.1)
	tw.chain().tween_property(_banner, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func():
		if is_instance_valid(_banner):
			_banner.visible = false
		_show_next_discovery_banner())


func _clear_fx() -> void:
	if _fx == null:
		return
	for c in _fx.get_children():
		c.queue_free()
	_banner = null
	_banner_name_lbl = null
	_banner_flavor_lbl = null
	_banner_count_lbl = null
	_banner_icon = null
	_banner_queue.clear()
	_banner_busy = false


## Global-space center of a Control.
func _center_global(c: Control) -> Vector2:
	return c.global_position + c.size * 0.5


# ---- hint gauge dots -----------------------------------------------------

func _on_gauge_changed(_value: int) -> void:
	if _open:
		_refresh_dots()
		# A hint may have just been revealed (gauge reset to 0 after a reveal); keep the
		# inline "힌트 보기" label count + expanded list current.
		_refresh_hint_toggle()
		if _hints_expanded:
			_rebuild_hint_list()


# ---- (B3.4) inline 힌트 보기 expander -------------------------------------

## Toggle the inline hint list open/closed.
func _toggle_hints() -> void:
	_hints_expanded = not _hints_expanded
	if _hints_expanded:
		_rebuild_hint_list()
	_hint_list.visible = _hints_expanded and _hint_list.get_child_count() > 0
	_refresh_hint_toggle()


## Update the toggle button caption with the current revealed-hint count + arrow.
func _refresh_hint_toggle() -> void:
	if _hint_toggle == null:
		return
	var n := Codex.revealed_hint_count()
	var arrow := "▾" if _hints_expanded else "▸"
	_hint_toggle.text = "%s 힌트 보기 (%d)" % [arrow, n]
	_hint_toggle.disabled = (n == 0)
	# collapse an emptied list so a stale open panel doesn't linger
	if n == 0 and _hint_list != null:
		_hint_list.visible = false


## (Re)build the inline hint rows: one "? + [재료] = ?" line per revealed hint.
func _rebuild_hint_list() -> void:
	if _hint_list == null:
		return
	for c in _hint_list.get_children():
		c.queue_free()
	# (v1.1.0 GP-2/3) Result-first staged hints: each row leads with the poetic RESULT fragment;
	# stage 2 adds ingredient categories; stage 3 adds the one revealed ingredient icon.
	var hints: Dictionary = Codex.revealed_hints()
	for rid: String in hints.keys():
		var stage := Codex.hint_stage(rid)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		# Result silhouette icon (stage 1+).
		var out_id := Codex.hint_output_for_recipe(rid)
		var out_icon := TextureRect.new()
		out_icon.custom_minimum_size = Vector2(22, 22)
		out_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		out_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		out_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		out_icon.texture = ItemDB.icon(out_id)
		out_icon.modulate = Color(0.16, 0.15, 0.2, 1.0)   # silhouette until crafted
		row.add_child(out_icon)
		var text := Codex.hint_poetic_name(rid)
		if stage >= 2:
			var cats: Array = Codex.hint_categories(rid)
			if cats.size() == 2:
				text += "  —  %s + %s" % [String(cats[0]), String(cats[1])]
		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_color_override("font_color", ACCENT)
		lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(lbl)
		if stage >= 3:
			var ing := Codex.hint_for_recipe(rid)
			if ing != "":
				var ing_icon := TextureRect.new()
				ing_icon.custom_minimum_size = Vector2(22, 22)
				ing_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ing_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ing_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				ing_icon.texture = ItemDB.icon(ing)
				row.add_child(ing_icon)
				var ing_lbl := Label.new()
				ing_lbl.text = "(%s)" % ItemDB.item_name(ing)
				ing_lbl.add_theme_color_override("font_color", TEXT)
				ing_lbl.add_theme_font_size_override("font_size", 14)
				row.add_child(ing_lbl)
		_hint_list.add_child(row)
	_hint_list.visible = _hints_expanded and _hint_list.get_child_count() > 0


func _refresh_dots() -> void:
	var g := Codex.hint_gauge()
	for i in _dots.size():
		_dots[i].color = DOT_ON if i < g else DOT_OFF
