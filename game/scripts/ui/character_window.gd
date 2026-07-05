extends CanvasLayer
class_name CharacterWindow
## 캐릭터 창 (v0.3.0 B3) — opened via the command bar's 캐릭터 button or the `character`
## action (C key; REMAP moved 도감 off C to R). The UI hub owns the hotkey + the
## one-window rule.
##
## Layout (owner wireframe):
##   - left: the cloaked-constructor portrait (assets/character/character_portrait.png).
##   - right: 6 equipment slot squares in the wireframe H/A/M/T/G/B arrangement, shown
##     as LOCKED/dimmed placeholders ("?" + tooltip "아직 잠겨 있다"). No equipment
##     system yet — the layout is reserved.
##   - below: stats — 발견률 %, 진행 일차, 회차(NG+ run), 심은 세계수 여부.
##
## Colors: bg #2a2a33, cream #faf5e6, violet #9e7ad9.

const BG := Color("#2a2a33")
const PANEL_INNER := Color("#33333d")
const TEXT := Color("#faf5e6")
const ACCENT := Color("#9e7ad9")
const DIM := Color("#b8b4a8")
const SLOT_BG := Color("#26262e")
const PORTRAIT := "res://assets/character/character_portrait.png"

## Equipment slots per wireframe: 머리(H)/방어구(A)/장신구(M)/도구(T)/장갑(G)/신발(B).
const SLOTS := [
	["H", "머리"], ["A", "방어구"], ["M", "장신구"],
	["T", "도구"], ["G", "장갑"], ["B", "신발"],
]

var _root: PanelContainer
var _stats: VBoxContainer
var _open: bool = false
var _hub = null
## The equipment slot squares, for the harness ("6 locked slots").
var slot_boxes: Array = []


func set_hub(hub) -> void:
	_hub = hub


func _ready() -> void:
	layer = 2
	_build_ui()
	# v0.3.1 R1: keep the panel inside the viewport on resize (620×460 already fits the
	# 1280×720 floor, but clamp defensively for smaller retina point sizes).
	get_viewport().size_changed.connect(_clamp_to_viewport)
	_clamp_to_viewport()
	_set_visible(false)


## v0.3.1 R1: cap panel height at min(700, viewport*0.85) and re-center. The content is
## short (≈460px) so it fits the 1280×720 floor without scrolling; the cap only engages
## on unusually short windows.
const MAX_PANEL_H := 700.0
## `override_size` lets the v031 harness drive an arbitrary viewport size headless; live
## code passes Vector2.ZERO to read the real viewport. Height caps against `override_size`
## (or the live viewport); re-centering always uses the real viewport so the panel stays
## on-screen in production.
func _clamp_to_viewport(override_size: Vector2 = Vector2.ZERO) -> void:
	if _root == null:
		return
	var real_vp := get_viewport().get_visible_rect().size
	var vp: Vector2 = override_size if override_size != Vector2.ZERO else real_vp
	var cap_h: float = min(MAX_PANEL_H, vp.y * 0.85)
	_root.set("size", Vector2(_root.size.x, min(_root.size.y, cap_h)))
	_root.position = (real_vp - _root.size) * 0.5


func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = Vector2(620, 460)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_content_margin_all(20)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = ACCENT
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 8
	_root.add_theme_stylebox_override("panel", sb)
	add_child(_root)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	_root.add_child(outer)

	var title := Label.new()
	title.text = "캐릭터"
	title.add_theme_color_override("font_color", TEXT)
	title.add_theme_font_size_override("font_size", 28)
	outer.add_child(title)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	outer.add_child(body)

	# --- left: portrait ---
	var pframe := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = PANEL_INNER
	psb.set_content_margin_all(8)
	psb.set_corner_radius_all(8)
	psb.set_border_width_all(1)
	psb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.4)
	pframe.add_theme_stylebox_override("panel", psb)
	body.add_child(pframe)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(192, 192)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(PORTRAIT):
		portrait.texture = load(PORTRAIT)
	pframe.add_child(portrait)

	# --- right: equipment slot grid (H/A/M / T/G/B) ---
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)

	var eq_lbl := Label.new()
	eq_lbl.text = "장비"
	eq_lbl.add_theme_color_override("font_color", ACCENT)
	eq_lbl.add_theme_font_size_override("font_size", 18)
	right.add_child(eq_lbl)

	var eq_grid := GridContainer.new()
	eq_grid.columns = 3
	eq_grid.add_theme_constant_override("h_separation", 10)
	eq_grid.add_theme_constant_override("v_separation", 10)
	right.add_child(eq_grid)
	for pair in SLOTS:
		eq_grid.add_child(_locked_slot(pair[0], pair[1]))

	# --- stats (below) ---
	var ssep := HSeparator.new()
	outer.add_child(ssep)

	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", 4)
	outer.add_child(_stats)


## A dimmed, locked equipment placeholder: a "?" glyph + tooltip "아직 잠겨 있다".
func _locked_slot(code: String, label: String) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(84, 84)
	var sb := StyleBoxFlat.new()
	sb.bg_color = SLOT_BG
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(DIM.r, DIM.g, DIM.b, 0.28)
	box.add_theme_stylebox_override("panel", sb)
	box.tooltip_text = "아직 잠겨 있다"
	box.modulate = Color(1, 1, 1, 0.55)   # dimmed = locked

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(col)

	var q := Label.new()
	q.text = "?"
	q.add_theme_color_override("font_color", DIM)
	q.add_theme_font_size_override("font_size", 30)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(q)

	var lbl := Label.new()
	lbl.text = "%s (%s)" % [label, code]
	lbl.add_theme_color_override("font_color", DIM)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lbl)

	slot_boxes.append(box)
	return box


# ---- stats ---------------------------------------------------------------

func _refresh_stats() -> void:
	for c in _stats.get_children():
		c.queue_free()
	_stats.add_child(_stat_row("발견률", "%.0f%%" % _discovery_pct()))
	_stats.add_child(_stat_row("진행 일차", "%d일차" % (GameState.day_index() + 1)))
	_stats.add_child(_stat_row("회차", "%d회차" % _run_number()))
	_stats.add_child(_stat_row("심은 세계수", "심음" if _world_tree_planted() else "아직"))


func _stat_row(key: String, val: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = key
	k.add_theme_color_override("font_color", DIM)
	k.custom_minimum_size = Vector2(120, 0)
	row.add_child(k)
	var v := Label.new()
	v.text = val
	v.add_theme_color_override("font_color", TEXT)
	row.add_child(v)
	return row


func _discovery_pct() -> float:
	var item_total: int = ItemDB.all_ids().size()
	var item_found: int = Codex.discovered_item_count()
	var recipe_total: int = RecipeDB.all_ids().size()
	var recipe_found: int = Codex.discovered_recipe_count()
	var total := item_total + recipe_total
	var found := item_found + recipe_found
	return 0.0 if total == 0 else (float(found) / float(total)) * 100.0


func _run_number() -> int:
	if SaveManager != null and "run_number" in SaveManager:
		return int(SaveManager.run_number)
	return 1


func _world_tree_planted() -> bool:
	if SaveManager != null and "cleared" in SaveManager:
		return bool(SaveManager.cleared)
	return false


# ---- toggle (hub-driven) -------------------------------------------------

func open() -> void:
	_set_visible(true)

func close() -> void:
	_set_visible(false)

func is_open() -> bool:
	return _open


func _set_visible(v: bool) -> void:
	_open = v
	_root.visible = v
	if v:
		if _hub != null and _hub.has_method("request_focus"):
			_hub.request_focus(_hub.Win.CHARACTER)
		_refresh_stats()
