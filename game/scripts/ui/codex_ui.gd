extends CanvasLayer
class_name CodexUI
## 도감 (Codex) — fullscreen-ish encyclopedia, restyled per the owner wireframe.
## Opened via the command bar's 도감 button or the `codex` action (REMAP: R key —
## C is now the Character window). The UI hub owns the hotkey + one-window rule.
##
## Layout (wireframe):
##   - title "도감" (top-left) + 검색 LineEdit (top-right): filters the grid by name
##     substring (Korean ok).
##   - a discovery % header + gauge-hint line (kept from the previous codex).
##   - a GRID of ALL catalogued items: discovered = real icon + name; undiscovered =
##     darkened silhouette + "???".
##   - a detail pane (wireframe "#1"): big icon + name + flavor + a "조합법" section
##     listing DISCOVERED recipes that OUTPUT the selected item, each rendered as
##     [icon] + [icon] = [icon]. Undiscovered recipes are hidden; if none are known
##     it reads "아직 알아내지 못했다".
##
## Colors: bg #2a2a33, cream #faf5e6, violet #9e7ad9 (art guide §7).

const BG := Color("#2a2a33")
const PANEL_INNER := Color("#33333d")
const TEXT := Color("#faf5e6")
const ACCENT := Color("#9e7ad9")
const VIOLET_SOFT := Color("#c8b0ec")
const DIM := Color("#b8b4a8")
const SLOT_BG := Color("#22222a")
## Undiscovered entries: real icon darkened to a near-black silhouette.
const SILHOUETTE_TINT := Color(0.16, 0.15, 0.2, 1.0)

const COLS := 6
const SLOT := 60

var _root: PanelContainer
var _header: Label
var _search: LineEdit
var _grid: GridContainer
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_flavor: Label
var _recipe_box: VBoxContainer

var _open: bool = false
var _hub = null
## output-item id -> [recipe records], so a detail pane can list recipes making it.
var _output_to_recipes: Dictionary = {}
## All catalogued ids in a stable order (gather then craft, each id-sorted).
var _all_ids: Array = []
var _slots: Array = []          # parallel to the currently-shown (filtered) ids
var _shown_ids: Array = []
var _selected_id: String = ""
var _filter: String = ""


func set_hub(hub) -> void:
	_hub = hub


func _ready() -> void:
	layer = 2
	_build_output_index()
	_build_catalog_order()
	_build_ui()
	Codex.item_discovered.connect(func(_id): if _open: _rebuild())
	Codex.recipe_discovered.connect(func(_id): if _open: _rebuild())
	Codex.hint_revealed.connect(func(_r, _i): if _open: _rebuild())
	_set_visible(false)


func _build_output_index() -> void:
	for rec: Dictionary in RecipeDB.all_recipes():
		var out := ItemDB.resolve_id(String(rec.get("output", "")))
		if not _output_to_recipes.has(out):
			_output_to_recipes[out] = []
		_output_to_recipes[out].append(rec)


func _build_catalog_order() -> void:
	_all_ids = _ids_for_category("gather") + _ids_for_category("craft")


func _ids_for_category(cat: String) -> Array:
	var out: Array = []
	for id: String in ItemDB.all_ids():
		if ItemDB.item_category(id) == cat:
			out.append(id)
	out.sort()
	return out


# ---- build ---------------------------------------------------------------

func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.offset_left = 60
	_root.offset_top = 40
	_root.offset_right = -60
	_root.offset_bottom = -80   # leave room for the command bar
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_content_margin_all(18)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = ACCENT
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 8
	_root.add_theme_stylebox_override("panel", sb)
	add_child(_root)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_root.add_child(outer)

	# --- top bar: title (left) + search (right) ---
	var topbar := HBoxContainer.new()
	topbar.add_theme_constant_override("separation", 12)
	outer.add_child(topbar)

	var title := Label.new()
	title.text = "도감"
	title.add_theme_color_override("font_color", TEXT)
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topbar.add_child(title)

	var search_lbl := Label.new()
	search_lbl.text = "검색"
	search_lbl.add_theme_color_override("font_color", DIM)
	search_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	topbar.add_child(search_lbl)

	_search = LineEdit.new()
	_search.custom_minimum_size = Vector2(220, 0)
	_search.placeholder_text = "이름으로 찾기…"
	_search.add_theme_color_override("font_color", TEXT)
	_search.text_changed.connect(_on_search_changed)
	topbar.add_child(_search)

	# --- discovery % header ---
	_header = Label.new()
	_header.add_theme_color_override("font_color", ACCENT)
	outer.add_child(_header)

	# --- body: grid (left) + detail pane (right) ---
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)

	var grid_scroll := ScrollContainer.new()
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(grid_scroll)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	grid_scroll.add_child(_grid)

	# detail pane
	var detail := PanelContainer.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = PANEL_INNER
	dsb.set_content_margin_all(14)
	dsb.set_corner_radius_all(8)
	detail.add_theme_stylebox_override("panel", dsb)
	detail.custom_minimum_size = Vector2(300, 0)
	body.add_child(detail)

	var dscroll := ScrollContainer.new()
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail.add_child(dscroll)
	var dcol := VBoxContainer.new()
	dcol.add_theme_constant_override("separation", 10)
	dcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.add_child(dcol)

	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(96, 96)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dcol.add_child(_detail_icon)

	_detail_name = Label.new()
	_detail_name.add_theme_color_override("font_color", TEXT)
	_detail_name.add_theme_font_size_override("font_size", 20)
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dcol.add_child(_detail_name)

	_detail_flavor = Label.new()
	_detail_flavor.add_theme_color_override("font_color", DIM)
	_detail_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_flavor.custom_minimum_size = Vector2(268, 0)
	dcol.add_child(_detail_flavor)

	var rsep := HSeparator.new()
	dcol.add_child(rsep)

	var rtitle := Label.new()
	rtitle.text = "조합법"
	rtitle.add_theme_color_override("font_color", ACCENT)
	rtitle.add_theme_font_size_override("font_size", 18)
	dcol.add_child(rtitle)

	_recipe_box = VBoxContainer.new()
	_recipe_box.add_theme_constant_override("separation", 6)
	dcol.add_child(_recipe_box)


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
			_hub.request_focus(_hub.Win.CODEX)
		_rebuild()
		_search.grab_focus()


## Public (harness): set the search filter programmatically and re-filter the grid.
func set_search(text: String) -> void:
	_filter = text.strip_edges().to_lower()
	if _search != null:
		_search.text = text
	if _open:
		_rebuild()


func _on_search_changed(text: String) -> void:
	_filter = text.strip_edges().to_lower()
	_rebuild()


# ---- render --------------------------------------------------------------

func _rebuild() -> void:
	_fill_header()
	_fill_grid()
	_fill_detail()


func _fill_header() -> void:
	var gather_ids := _ids_for_category("gather")
	var craft_ids := _ids_for_category("craft")
	var item_total := gather_ids.size() + craft_ids.size()
	var item_found := 0
	for id: String in gather_ids + craft_ids:
		if Codex.is_item_discovered(id):
			item_found += 1
	var recipe_total: int = RecipeDB.all_ids().size()
	var recipe_found: int = Codex.discovered_recipe_count()
	var total := item_total + recipe_total
	var found := item_found + recipe_found
	var pct := 0.0 if total == 0 else (float(found) / float(total)) * 100.0
	var gauge := Codex.hint_gauge()
	_header.text = "발견률  %d / %d  (%.0f%%)   ·   아이템 %d/%d · 레시피 %d/%d   ·   힌트 게이지 %d/%d" % [
		found, total, pct, item_found, item_total, recipe_found, recipe_total,
		gauge, Codex.HINT_THRESHOLD,
	]


## The (name-substring-filtered) subset of the full catalog, in catalog order.
func _filtered_ids() -> Array:
	if _filter == "":
		return _all_ids.duplicate()
	var out: Array = []
	for id: String in _all_ids:
		# Only discovered items expose their real name to the filter; undiscovered
		# entries match nothing (their name is hidden as "???").
		if not Codex.is_item_discovered(id):
			continue
		if ItemDB.item_name(id).to_lower().contains(_filter):
			out.append(id)
	return out


func _fill_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_slots.clear()
	_shown_ids = _filtered_ids()
	for id: String in _shown_ids:
		_grid.add_child(_make_cell(id))
	if _selected_id == "" and _shown_ids.size() > 0:
		_selected_id = _shown_ids[0]


func _make_cell(id: String) -> Control:
	var discovered := Codex.is_item_discovered(id)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(SLOT, SLOT)
	box.add_theme_stylebox_override("panel", _cell_style(id == _selected_id))

	var icon := TextureRect.new()
	icon.texture = ItemDB.icon(id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not discovered:
		icon.modulate = SILHOUETTE_TINT
	box.add_child(icon)

	if not discovered:
		var q := Label.new()
		q.text = "???"
		q.add_theme_color_override("font_color", DIM)
		q.add_theme_font_size_override("font_size", 12)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		q.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.add_child(q)

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	var clear := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", clear)
	btn.add_theme_stylebox_override("hover", clear)
	btn.add_theme_stylebox_override("pressed", clear)
	btn.pressed.connect(_on_cell_pressed.bind(id))
	box.add_child(btn)
	_slots.append(box)
	return box


func _cell_style(selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = SLOT_BG
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = ACCENT if selected else Color(0.3, 0.3, 0.36, 0.8)
	return sb


func _on_cell_pressed(id: String) -> void:
	_selected_id = id
	# refresh selection borders
	for i in _slots.size():
		if i < _shown_ids.size():
			_slots[i].add_theme_stylebox_override("panel", _cell_style(_shown_ids[i] == _selected_id))
	_fill_detail()


func _fill_detail() -> void:
	var id := _selected_id
	if id == "" or not ItemDB.has_item(id):
		_detail_icon.texture = null
		_detail_name.text = "—"
		_detail_flavor.text = ""
		_clear_recipes()
		return
	var discovered := Codex.is_item_discovered(id)
	_detail_icon.texture = ItemDB.icon(id)
	_detail_icon.modulate = Color.WHITE if discovered else SILHOUETTE_TINT
	_detail_name.text = ItemDB.item_name(id) if discovered else "???"
	_detail_flavor.text = ItemDB.item_flavor(id) if discovered else "아직 발견하지 못했다."
	_fill_recipes(id)


func _clear_recipes() -> void:
	for c in _recipe_box.get_children():
		c.queue_free()


## List DISCOVERED recipes that output this item, each as [icon] + [icon] = [icon].
## Undiscovered recipes are hidden; if none are known, show "아직 알아내지 못했다".
func _fill_recipes(item_id: String) -> void:
	_clear_recipes()
	var recs: Array = _output_to_recipes.get(item_id, [])
	var shown := 0
	for rec: Dictionary in recs:
		if not Codex.is_recipe_discovered(String(rec.get("id", ""))):
			continue
		_recipe_box.add_child(_recipe_row(rec))
		shown += 1
	if shown == 0:
		var none := Label.new()
		none.text = "아직 알아내지 못했다"
		none.add_theme_color_override("font_color", DIM)
		_recipe_box.add_child(none)


func _recipe_row(rec: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var inputs: Array = rec.get("inputs", [])
	var out_id := ItemDB.resolve_id(String(rec.get("output", "")))
	if inputs.size() == 2:
		row.add_child(_mini_icon(String(inputs[0])))
		row.add_child(_op_label("+"))
		row.add_child(_mini_icon(String(inputs[1])))
	row.add_child(_op_label("="))
	row.add_child(_mini_icon(out_id))
	return row


func _mini_icon(id: String) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(32, 32)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.texture = ItemDB.icon(id)
	return t


func _op_label(op: String) -> Label:
	var l := Label.new()
	l.text = op
	l.add_theme_color_override("font_color", VIOLET_SOFT)
	l.add_theme_font_size_override("font_size", 18)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
