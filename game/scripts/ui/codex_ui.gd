extends CanvasLayer
class_name CodexUI
## 도감 (Codex/encyclopedia) UI — toggle with the `codex` action (C key).
##
## Two tabs:
##   채집  — the 9 gather items.
##   창조  — the canonical craft items (D06 folds into I4, so ItemDB reports 21
##           canonical craft-category items).
## Discovered entries show a category-colored square + name + flavor. Undiscovered
## entries show a dark silhouette + "???". The header shows the overall 발견률 %.
##
## Hint reveals from the fusion gauge (Codex._hints) surface here: on a craft
## item's row whose recipe was hinted-but-not-yet-crafted, it shows
## "힌트: <ingredient name> + ???".
##
## Colors: bg #2a2a33, text cream #faf5e6, accent #9e7ad9 (art guide §7).

const BG := Color("#2a2a33")
const TEXT := Color("#faf5e6")
const ACCENT := Color("#9e7ad9")
const SILHOUETTE := Color("#3a3a44")
const DIM := Color("#8a8590")
## Undiscovered entries show the real icon darkened to a near-black silhouette.
const SILHOUETTE_TINT := Color(0.16, 0.15, 0.2, 1.0)

var _root: PanelContainer
var _header: Label
var _tabs: TabContainer
var _gather_list: VBoxContainer
var _craft_list: VBoxContainer

var _open: bool = false
## output-item id -> recipe id, so a hinted recipe can annotate its output row.
var _output_to_recipe: Dictionary = {}


func _ready() -> void:
	_build_output_index()
	_build_ui()
	Codex.item_discovered.connect(func(_id): if _open: _rebuild())
	Codex.recipe_discovered.connect(func(_id): if _open: _rebuild())
	Codex.hint_revealed.connect(func(_r, _i): if _open: _rebuild())
	_set_visible(false)


func _build_output_index() -> void:
	for rec: Dictionary in RecipeDB.all_recipes():
		var out := ItemDB.resolve_id(String(rec["output"]))
		# First recipe that yields this output wins the annotation slot.
		if not _output_to_recipe.has(out):
			_output_to_recipe[out] = rec["id"]


# ---- build ---------------------------------------------------------------

func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = Vector2(480, 560)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_content_margin_all(16)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = ACCENT
	_root.add_theme_stylebox_override("panel", sb)
	add_child(_root)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_root.add_child(outer)

	var title := Label.new()
	title.text = "도감"
	title.add_theme_color_override("font_color", TEXT)
	title.add_theme_font_size_override("font_size", 24)
	outer.add_child(title)

	_header = Label.new()
	_header.add_theme_color_override("font_color", ACCENT)
	outer.add_child(_header)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.custom_minimum_size = Vector2(448, 460)
	outer.add_child(_tabs)

	_gather_list = _make_tab("채집")
	_craft_list = _make_tab("창조")


func _make_tab(tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	return list


# ---- data ----------------------------------------------------------------

## Canonical ids for a category, in a stable id-sorted order.
func _ids_for_category(cat: String) -> Array:
	var out: Array = []
	for id: String in ItemDB.all_ids():
		if ItemDB.item_category(id) == cat:
			out.append(id)
	out.sort()
	return out


# ---- toggle --------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("codex"):
		_set_visible(not _open)
		get_viewport().set_input_as_handled()
		return
	if _open and event.is_action_pressed("ui_cancel"):
		_set_visible(false)
		get_viewport().set_input_as_handled()


func _set_visible(v: bool) -> void:
	_open = v
	_root.visible = v
	if v:
		_rebuild()


# ---- render --------------------------------------------------------------

func _rebuild() -> void:
	var gather_ids := _ids_for_category("gather")
	var craft_ids := _ids_for_category("craft")

	_fill_list(_gather_list, gather_ids)
	_fill_list(_craft_list, craft_ids)

	# 발견률 combines item + recipe denominators (spec §5): all catalogued items
	# plus all recipes, over discovered items plus discovered recipes.
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
	_header.text = "발견률  %d / %d  (%.0f%%)   채집 %d/%d · 창조 %d/%d · 레시피 %d/%d" % [
		found, total, pct,
		_count_found(gather_ids), gather_ids.size(),
		_count_found(craft_ids), craft_ids.size(),
		recipe_found, recipe_total,
	]


func _count_found(ids: Array) -> int:
	var n := 0
	for id: String in ids:
		if Codex.is_item_discovered(id):
			n += 1
	return n


func _fill_list(list: VBoxContainer, ids: Array) -> void:
	for c in list.get_children():
		c.queue_free()
	for id: String in ids:
		list.add_child(_make_entry(id))


func _make_entry(id: String) -> Control:
	var discovered := Codex.is_item_discovered(id)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#30303a")
	sb.set_content_margin_all(8)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35 if discovered else 0.12)
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	# Real icon; undiscovered entries are darkened to a silhouette of the true art.
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = ItemDB.icon(id)
	if not discovered:
		icon.modulate = SILHOUETTE_TINT
	row.add_child(icon)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)

	var name_lbl := Label.new()
	name_lbl.add_theme_color_override("font_color", TEXT if discovered else DIM)
	name_lbl.text = ItemDB.item_name(id) if discovered else "???"
	text_col.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.custom_minimum_size = Vector2(360, 0)
	if discovered:
		sub_lbl.add_theme_color_override("font_color", DIM)
		sub_lbl.text = ItemDB.item_flavor(id)
	else:
		# Undiscovered: show a gauge-revealed hint if this item's recipe was hinted.
		var hint_text := _hint_text_for(id)
		if hint_text != "":
			sub_lbl.add_theme_color_override("font_color", ACCENT)
			sub_lbl.text = hint_text
		else:
			sub_lbl.add_theme_color_override("font_color", DIM)
			sub_lbl.text = "아직 발견하지 못했다."
	text_col.add_child(sub_lbl)

	return panel


## "힌트: <ingredient name> + ???" if this item's recipe has an active hint.
func _hint_text_for(item_id: String) -> String:
	var rid: String = _output_to_recipe.get(item_id, "")
	if rid == "":
		return ""
	var ing := Codex.hint_for_recipe(rid)
	if ing == "":
		return ""
	return "힌트: %s + ???" % ItemDB.item_name(ing)
