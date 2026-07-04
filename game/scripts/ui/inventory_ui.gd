extends CanvasLayer
class_name InventoryUI
## Inventory panel + held-item HUD.
##
## Toggle the grid panel with the `inventory` action (I/Tab). ESC or `inventory`
## closes it. Each row is a colored category-square icon + name + count. Clicking
## a row (or arrow-selecting + Enter) sets that item as the "held" item, shown in
## a corner HUD next to the player. Rebuilds on Inventory.changed (signal-driven).
##
## Colors: panel bg #2a2a33, text cream #faf5e6 (per spec).

const BG := Color("#2a2a33")
const TEXT := Color("#faf5e6")
const ROW_SELECTED := Color("#3d3d4a")
const HELD_BORDER := Color("#9e7ad9")

## Placeholder icon color per item category.
const CATEGORY_COLOR := {
	"gather": Color("#7ab567"),  # green
	"craft": Color("#c89ae0"),   # violet-ish
}

@export var interaction_path: NodePath

var _interaction: InteractionController
var _panel: PanelContainer
var _list: VBoxContainer
var _held_hud: HBoxContainer
var _held_icon: ColorRect
var _held_label: Label

var _open: bool = false
var _rows: Array[Control] = []
var _row_ids: Array[String] = []
var _selected_index: int = -1
var _held_item: String = ""


func _ready() -> void:
	_interaction = get_node_or_null(interaction_path) as InteractionController
	_build_ui()
	Inventory.changed.connect(_rebuild)
	_rebuild()
	_set_panel_visible(false)


func _build_ui() -> void:
	# --- grid panel (centered) ---
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(360, 420)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_content_margin_all(16)
	sb.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_panel.add_child(outer)

	var title := Label.new()
	title.text = "인벤토리"
	title.add_theme_color_override("font_color", TEXT)
	title.add_theme_font_size_override("font_size", 22)
	outer.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(328, 340)
	outer.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)

	# --- held-item HUD (bottom-left corner) ---
	_held_hud = HBoxContainer.new()
	_held_hud.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_held_hud.position = Vector2(24, -64)
	_held_hud.add_theme_constant_override("separation", 8)
	add_child(_held_hud)

	var held_bg := PanelContainer.new()
	var hb := StyleBoxFlat.new()
	hb.bg_color = BG
	hb.set_content_margin_all(6)
	hb.set_corner_radius_all(4)
	hb.set_border_width_all(2)
	hb.border_color = HELD_BORDER
	held_bg.add_theme_stylebox_override("panel", hb)
	_held_hud.add_child(held_bg)

	var held_row := HBoxContainer.new()
	held_row.add_theme_constant_override("separation", 6)
	held_bg.add_child(held_row)

	_held_icon = ColorRect.new()
	_held_icon.custom_minimum_size = Vector2(24, 24)
	held_row.add_child(_held_icon)

	_held_label = Label.new()
	_held_label.add_theme_color_override("font_color", TEXT)
	held_row.add_child(_held_label)

	_refresh_held_hud()


# ---- list build ----------------------------------------------------------

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_rows.clear()
	_row_ids.clear()

	var ids := Inventory.ids()
	for i in ids.size():
		var id: String = ids[i]
		_add_row(id, i)

	# Keep the selection valid and the held item consistent.
	if _held_item != "" and Inventory.count(_held_item) == 0:
		_set_held("")
	if _selected_index >= _row_ids.size():
		_selected_index = _row_ids.size() - 1
	_refresh_selection()


func _add_row(id: String, index: int) -> void:
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 40)
	btn.pressed.connect(_on_row_pressed.bind(index))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.color = CATEGORY_COLOR.get(ItemDB.item_category(id), Color("#888888"))
	row.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = ItemDB.item_name(id)
	name_lbl.add_theme_color_override("font_color", TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var count_lbl := Label.new()
	count_lbl.text = "x%d" % Inventory.count(id)
	count_lbl.add_theme_color_override("font_color", TEXT)
	row.add_child(count_lbl)

	_list.add_child(btn)
	_rows.append(btn)
	_row_ids.append(id)


# ---- input / selection ---------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		_set_panel_visible(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_select_current_as_held()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	_set_panel_visible(not _open)


func _set_panel_visible(v: bool) -> void:
	_open = v
	_panel.visible = v
	if v and _selected_index < 0 and _row_ids.size() > 0:
		_selected_index = 0
	_refresh_selection()


func _move_selection(delta: int) -> void:
	if _row_ids.is_empty():
		return
	if _selected_index < 0:
		_selected_index = 0
	else:
		_selected_index = clampi(_selected_index + delta, 0, _row_ids.size() - 1)
	_refresh_selection()


func _on_row_pressed(index: int) -> void:
	_selected_index = index
	_refresh_selection()
	_select_current_as_held()


func _select_current_as_held() -> void:
	if _selected_index < 0 or _selected_index >= _row_ids.size():
		return
	_set_held(_row_ids[_selected_index])


func _refresh_selection() -> void:
	for i in _rows.size():
		var sb := StyleBoxFlat.new()
		sb.bg_color = ROW_SELECTED if i == _selected_index else Color(0, 0, 0, 0)
		sb.set_corner_radius_all(4)
		_rows[i].add_theme_stylebox_override("normal", sb)
		_rows[i].add_theme_stylebox_override("hover", sb)
		_rows[i].add_theme_stylebox_override("pressed", sb)


# ---- held item -----------------------------------------------------------

func _set_held(id: String) -> void:
	_held_item = id
	if _interaction != null:
		_interaction.set_held_item(id)
	_refresh_held_hud()


func _refresh_held_hud() -> void:
	if _held_item == "":
		_held_icon.color = Color(0, 0, 0, 0)
		_held_label.text = "(들고 있는 것 없음)"
		return
	_held_icon.color = CATEGORY_COLOR.get(ItemDB.item_category(_held_item), Color("#888888"))
	_held_label.text = "%s  x%d" % [ItemDB.item_name(_held_item), Inventory.count(_held_item)]
