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
## (B3.4) "힌트" filter chip + mode. When on, the grid area is replaced by a list of
## gauge-revealed hint rows ("? + [재료] = ?").
var _hint_chip: Button
var _hint_mode: bool = false
## (EG-2) "기록(진상)" 탭 — lists collected truth-shard logs. Mutually exclusive with hint mode.
var _truth_chip: Button
var _truth_mode: bool = false
## (CQ-5 G14) "재감상" 탭 — lists seen cutscenes with a play button. Mutually exclusive with the
## hint + truth modes. Playing one closes the codex and runs a side-effect-free CutsceneReplay.
var _replay_chip: Button
var _replay_mode: bool = false
var _replay_layer: CanvasLayer = null


func set_hub(hub) -> void:
	_hub = hub


func _ready() -> void:
	layer = 2
	_build_output_index()
	_build_catalog_order()
	_build_ui()
	Codex.item_discovered.connect(func(_id): if _open: _rebuild())
	Codex.recipe_discovered.connect(func(_id): if _open: _rebuild())
	Codex.hint_revealed.connect(func(_r, _i, _s): if _open: _rebuild())
	Codex.truth_log_recorded.connect(func(_s): if _open: _rebuild())
	_set_visible(false)


func _build_output_index() -> void:
	for rec: Dictionary in RecipeDB.all_recipes():
		var out := ItemDB.resolve_id(String(rec.get("output", "")))
		if not _output_to_recipes.has(out):
			_output_to_recipes[out] = []
		_output_to_recipes[out].append(rec)


func _build_catalog_order() -> void:
	# (v1.1.0 GP-2 §2.3) 실패작(category "fail") also belongs in the 도감 ("실패도 수집") — appended
	# after gather + craft so the catalog order stays stable for pre-fail items.
	_all_ids = _ids_for_category("gather") + _ids_for_category("craft") + _ids_for_category("fail")


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

	# (B3.4) "힌트" filter chip: toggles a view listing gauge-revealed hints as
	# "? + [재료] = ?" so the player can actually FIND them ("도감 힌트도 안보인다").
	_hint_chip = Button.new()
	_hint_chip.name = "HintChip"
	_hint_chip.toggle_mode = true
	_hint_chip.focus_mode = Control.FOCUS_NONE
	_hint_chip.text = "힌트"
	_hint_chip.add_theme_color_override("font_color", TEXT)
	_hint_chip.add_theme_color_override("font_hover_color", VIOLET_SOFT)
	_hint_chip.add_theme_stylebox_override("normal", _chip_style(false))
	_hint_chip.add_theme_stylebox_override("hover", _chip_style(true))
	_hint_chip.add_theme_stylebox_override("pressed", _chip_style(true))
	_hint_chip.toggled.connect(_on_hint_chip_toggled)
	topbar.add_child(_hint_chip)

	# (EG-2) "기록" chip: toggles the 진상 조각 log view (「기록(진상)」 탭).
	_truth_chip = Button.new()
	_truth_chip.name = "TruthChip"
	_truth_chip.toggle_mode = true
	_truth_chip.focus_mode = Control.FOCUS_NONE
	_truth_chip.text = "기록"
	_truth_chip.add_theme_color_override("font_color", TEXT)
	_truth_chip.add_theme_color_override("font_hover_color", VIOLET_SOFT)
	_truth_chip.add_theme_stylebox_override("normal", _chip_style(false))
	_truth_chip.add_theme_stylebox_override("hover", _chip_style(true))
	_truth_chip.add_theme_stylebox_override("pressed", _chip_style(true))
	_truth_chip.toggled.connect(_on_truth_chip_toggled)
	topbar.add_child(_truth_chip)

	# (CQ-5 G14) "재감상" chip: toggles the 컷신 재감상 menu (본 컷신 목록 → 재생).
	_replay_chip = Button.new()
	_replay_chip.name = "ReplayChip"
	_replay_chip.toggle_mode = true
	_replay_chip.focus_mode = Control.FOCUS_NONE
	_replay_chip.text = "재감상"
	_replay_chip.add_theme_color_override("font_color", TEXT)
	_replay_chip.add_theme_color_override("font_hover_color", VIOLET_SOFT)
	_replay_chip.add_theme_stylebox_override("normal", _chip_style(false))
	_replay_chip.add_theme_stylebox_override("hover", _chip_style(true))
	_replay_chip.add_theme_stylebox_override("pressed", _chip_style(true))
	_replay_chip.toggled.connect(_on_replay_chip_toggled)
	topbar.add_child(_replay_chip)

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

	# close (X) affordance, top-right (B3.2).
	topbar.add_child(WindowChrome.make_close_button(close))

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

	# (B3.2) close-affordance hint at the panel bottom.
	outer.add_child(WindowChrome.make_esc_hint())


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
	# (v0.4.0-B B3.1) freeze the world while the codex window is up.
	if GameState != null:
		if v:
			GameState.push_modal("codex")
		else:
			GameState.pop_modal("codex")
	if v:
		if _hub != null and _hub.has_method("request_focus"):
			_hub.request_focus(_hub.Win.CODEX)
		_rebuild()
		_search.grab_focus()


## Public (harness): toggle the "힌트" filter chip and re-render. Returns the number of
## revealed-hint rows now shown (0 if none / not in hint mode).
func set_hint_filter(on: bool) -> int:
	if _hint_chip != null:
		_hint_chip.button_pressed = on   # fires _on_hint_chip_toggled → _rebuild
	else:
		_hint_mode = on
		if _open:
			_rebuild()
	return Codex.revealed_hint_count() if on else 0


## Public (harness): the child count of the hint-list grid while the chip is active.
func hint_row_count() -> int:
	if not _hint_mode:
		return 0
	# Count only PanelContainer rows (skip the "none" Label placeholder).
	var n := 0
	for c in _grid.get_children():
		if c is PanelContainer:
			n += 1
	return n


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
	if _truth_mode:
		_grid.columns = 1
		_fill_truth_grid()
		return
	if _hint_mode:
		_grid.columns = 1
		_fill_hint_grid()
		return
	if _replay_mode:
		_grid.columns = 1
		_fill_replay_grid()
		return
	_grid.columns = COLS
	_shown_ids = _filtered_ids()
	for id: String in _shown_ids:
		_grid.add_child(_make_cell(id))
	if _selected_id == "" and _shown_ids.size() > 0:
		_selected_id = _shown_ids[0]


## (B3.4) Hint view: one row per gauge-revealed hint, "? + [재료icon] = ?". The revealed
## ingredient is shown; the other input and the output stay hidden (that is the puzzle).
## The grid switches to a single column of rows here.
func _fill_hint_grid() -> void:
	var hints: Dictionary = Codex.revealed_hints()
	if hints.is_empty():
		var none := Label.new()
		none.text = "아직 드러난 힌트가 없다. 조합에 실패하며 힌트 게이지를 채워 보자."
		none.add_theme_color_override("font_color", DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(360, 0)
		_grid.add_child(none)
		return
	for rid: String in hints.keys():
		_grid.add_child(_hint_row(rid))


## (v1.1.0 GP-2/3) A single RESULT-FIRST staged hint row for a recipe:
##   stage 1 → result silhouette + poetic name ("무언가 빛나는 걸 만들 수 있다").
##   stage 2 → + 재료 카테고리 두 개 ("물 계열 + 광물 계열").
##   stage 3 → + 재료 한 개 실제 아이콘/이름 (마지막 안전망).
## The result icon is shown as a near-black SILHOUETTE until the recipe is discovered.
func _hint_row(recipe_id: String) -> Control:
	var stage := Codex.hint_stage(recipe_id)
	var out_id := Codex.hint_output_for_recipe(recipe_id)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _cell_style(false))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	box.add_child(col)

	# Row 1: result silhouette + poetic name (stage 1+).
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	var out_icon := _mini_icon(out_id)
	out_icon.modulate = SILHOUETTE_TINT   # result stays a silhouette until crafted
	top.add_child(out_icon)
	var name_lbl := Label.new()
	name_lbl.text = Codex.hint_poetic_name(recipe_id)
	name_lbl.add_theme_color_override("font_color", VIOLET_SOFT)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(name_lbl)
	col.add_child(top)

	# Row 2: ingredient categories (stage 2+).
	if stage >= 2:
		var cats: Array = Codex.hint_categories(recipe_id)
		if cats.size() == 2:
			var cat_lbl := Label.new()
			cat_lbl.text = "   %s  +  %s" % [String(cats[0]), String(cats[1])]
			cat_lbl.add_theme_color_override("font_color", DIM)
			col.add_child(cat_lbl)

	# Row 3: one revealed ingredient (stage 3).
	if stage >= 3:
		var ing := Codex.hint_for_recipe(recipe_id)
		if ing != "":
			var ing_row := HBoxContainer.new()
			ing_row.add_theme_constant_override("separation", 6)
			ing_row.add_child(_mini_icon(ing))
			var ing_lbl := Label.new()
			ing_lbl.text = "  %s + ?" % ItemDB.item_name(ing)
			ing_lbl.add_theme_color_override("font_color", DIM)
			ing_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ing_row.add_child(ing_lbl)
			col.add_child(ing_row)
	return box


func _chip_style(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#3a3a46") if active else Color("#2f2f39")
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.set_border_width_all(1)
	sb.border_color = ACCENT if active else Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.4)
	return sb


func _on_hint_chip_toggled(pressed: bool) -> void:
	_hint_mode = pressed
	if pressed and _truth_chip != null and _truth_chip.button_pressed:
		_truth_chip.button_pressed = false   # mutually exclusive (fires its toggle → _truth_mode off)
	# The detail pane + search are item-oriented; dim them out in hint mode.
	if _search != null:
		_search.editable = not pressed
	_rebuild()


func _on_truth_chip_toggled(pressed: bool) -> void:
	_truth_mode = pressed
	if pressed and _hint_chip != null and _hint_chip.button_pressed:
		_hint_chip.button_pressed = false    # mutually exclusive
	if _search != null:
		_search.editable = not pressed
	_rebuild()


## (EG-2) 「기록(진상)」 view: one row per collected truth-shard log, in canonical order, with the
## header + full text. When all five are collected, the 최종 회수 카드 (§3.1) is appended.
func _fill_truth_grid() -> void:
	var logs: Array = Codex.truth_logs_ordered()
	var total: int = GameState.TRUTH_SHARD_IDS.size()
	var head := Label.new()
	head.text = "진상 조각  %d / %d" % [logs.size(), total]
	head.add_theme_color_override("font_color", ACCENT)
	head.add_theme_font_size_override("font_size", 18)
	_grid.add_child(head)
	if logs.is_empty():
		var none := Label.new()
		none.text = "아직 회수한 조각이 없다. 다섯 세계에서 선배들의 흔적을 조사해 보자."
		none.add_theme_color_override("font_color", DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(560, 0)
		_grid.add_child(none)
		return
	for e: Dictionary in logs:
		_grid.add_child(_truth_row(String(e.get("title", "")), String(e.get("text", ""))))
	if Codex.truth_final_seen():
		var sep := HSeparator.new()
		_grid.add_child(sep)
		_grid.add_child(_truth_row("진실", Codex.TRUTH_FINAL_CARD))


func _truth_row(title: String, text: String) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _cell_style(false))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	box.add_child(col)
	var t := Label.new()
	t.text = "「%s」" % title
	t.add_theme_color_override("font_color", VIOLET_SOFT)
	t.add_theme_font_size_override("font_size", 16)
	col.add_child(t)
	var b := Label.new()
	b.text = text
	b.add_theme_color_override("font_color", TEXT)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(540, 0)
	col.add_child(b)
	return box


## Public (harness): toggle the 기록 탭 + return the number of shard rows shown.
func set_truth_filter(on: bool) -> int:
	if _truth_chip != null:
		_truth_chip.button_pressed = on
	else:
		_truth_mode = on
		if _open:
			_rebuild()
	return Codex.truth_log_count() if on else 0


## Public (harness): child rows in the 기록 grid (title/body panels) while active.
func truth_row_count() -> int:
	if not _truth_mode:
		return 0
	var n := 0
	for c in _grid.get_children():
		if c is PanelContainer:
			n += 1
	return n


func _on_replay_chip_toggled(pressed: bool) -> void:
	_replay_mode = pressed
	# 재감상 is mutually exclusive with the 힌트 + 기록 tabs.
	if pressed:
		if _hint_chip != null and _hint_chip.button_pressed:
			_hint_chip.button_pressed = false
		if _truth_chip != null and _truth_chip.button_pressed:
			_truth_chip.button_pressed = false
	# The detail pane + search are item-oriented; dim search out in replay mode.
	if _search != null:
		_search.editable = not pressed
	_rebuild()


## (CQ-5 G14) 재감상 view: one row per catalogued cutscene. SEEN → a 「재생」 button that closes the
## codex and plays a side-effect-free CutsceneReplay. UNSEEN → a dim 🔒 잠김 row (no button).
func _fill_replay_grid() -> void:
	var entries: Array = Codex.cutscenes_ordered()
	var seen: int = Codex.cutscene_seen_count()
	var head := Label.new()
	head.text = "컷신 재감상  %d / %d" % [seen, entries.size()]
	head.add_theme_color_override("font_color", ACCENT)
	head.add_theme_font_size_override("font_size", 18)
	_grid.add_child(head)
	for e: Dictionary in entries:
		_grid.add_child(_replay_row(String(e.get("id", "")), String(e.get("title", "")), bool(e.get("seen", false))))


func _replay_row(cutscene_id: String, title: String, seen: bool) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _cell_style(false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	var id_lbl := Label.new()
	id_lbl.text = cutscene_id
	id_lbl.add_theme_color_override("font_color", VIOLET_SOFT if seen else DIM)
	id_lbl.custom_minimum_size = Vector2(56, 0)
	id_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(id_lbl)

	var name_lbl := Label.new()
	name_lbl.text = title if seen else "??? — 아직 보지 못한 컷신"
	name_lbl.add_theme_color_override("font_color", TEXT if seen else DIM)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	if seen:
		var play := Button.new()
		play.text = "재생"
		play.focus_mode = Control.FOCUS_NONE
		play.add_theme_color_override("font_color", TEXT)
		play.pressed.connect(_on_replay_pressed.bind(cutscene_id))
		row.add_child(play)
	else:
		var lock := Label.new()
		lock.text = "🔒 잠김"
		lock.add_theme_color_override("font_color", DIM)
		lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lock)
	return box


## Close the codex and play the selected cutscene's replay (side-effect-free). The replay overlay
## is parented at the tree root so it outlives this window; on finish it frees itself and — through
## GameState time/lock pairing — restores play. Idempotent if a replay is already up.
func _on_replay_pressed(cutscene_id: String) -> void:
	if not Codex.is_cutscene_seen(cutscene_id):
		return
	if _replay_layer != null and is_instance_valid(_replay_layer):
		return
	close()
	var rep := CutsceneReplay.new()
	_replay_layer = rep
	var tree := get_tree()
	if tree != null and tree.root != null:
		tree.root.add_child(rep)
	else:
		add_child(rep)
	rep.tree_exited.connect(func(): _replay_layer = null)
	rep.play(cutscene_id)


## Public (harness): toggle the 재감상 탭 + return the number of SEEN cutscenes.
func set_replay_filter(on: bool) -> int:
	if _replay_chip != null:
		_replay_chip.button_pressed = on
	else:
		_replay_mode = on
		if _open:
			_rebuild()
	return Codex.cutscene_seen_count() if on else 0


## Public (harness): row panels in the 재감상 grid while the tab is active.
func replay_row_count() -> int:
	if not _replay_mode:
		return 0
	var n := 0
	for c in _grid.get_children():
		if c is PanelContainer:
			n += 1
	return n


## Public (harness): start a replay for `cutscene_id` (as the 재생 button would) and return the
## live CutsceneReplay overlay (or null if locked/unseen). Lets the harness drive play/skip.
func start_replay(cutscene_id: String) -> Node:
	_on_replay_pressed(cutscene_id)
	return _replay_layer


## (v1.1.0 GP-3) If `output_id` is produced by a recipe with an active (stage 1+) result-first
## hint, return its poetic name fragment; else "". Used to light up undiscovered 도감 slots.
func _active_poetic_for_output(output_id: String) -> String:
	var recs: Array = _output_to_recipes.get(ItemDB.resolve_id(output_id), [])
	for rec: Dictionary in recs:
		var rid := String(rec.get("id", ""))
		if Codex.hint_stage(rid) >= 1:
			return Codex.hint_poetic_name(rid)
	return ""


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
		# (v1.1.0 GP-3) Result-first hint: if this item is the OUTPUT of a recipe whose hint has
		# reached stage 1+, show its poetic name fragment instead of a blank "???" — the 도감 slot
		# becomes a wishlist ("저 빛나는 걸 만들고 싶다") rather than an opaque unknown.
		var poetic := _active_poetic_for_output(id)
		var q := Label.new()
		q.text = poetic if poetic != "" else "???"
		q.add_theme_color_override("font_color", VIOLET_SOFT if poetic != "" else DIM)
		q.add_theme_font_size_override("font_size", 10 if poetic != "" else 12)
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
