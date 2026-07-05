extends CanvasLayer
class_name InventoryUI
## Inventory panel (grid) + held-item HUD (v0.2.0 art/UI redesign).
##
## Panel: a title-screen-style rounded dark panel (#2a2a33, 1px violet border) with
## a title bar "인벤토리  N종", a GRID of 56×56 slots (icon + count badge), and a
## detail pane showing the selected item's large icon, name, flavor text, and a
## 들기/내려놓기 button. Selected slot gets a violet border highlight.
##
## Held-item HUD (bottom-left): a 64×64 slot box in the same panel style showing the
## held icon + name; empty state = dashed border + "빈 손". A small hint line appears
## above the box when the held item can be placed/used on a nearby valid target.
##
## Input: I/Tab toggles; arrows navigate the grid; Enter = hold/drop the selected
## item; ESC/I close. Mouse: click select, double-click = hold. Rebuilds on
## Inventory.changed (signal-driven, no polling).

const BG := Color("#2a2a33")
const PANEL_INNER := Color("#33333d")
const SLOT_BG := Color("#22222a")
const TEXT := Color("#faf5e6")
const DIM := Color("#b8b4a8")
const VIOLET := Color("#9e7ad9")
const VIOLET_SOFT := Color("#c8b0ec")
const BADGE_BG := Color(0.10, 0.09, 0.13, 0.92)

const COLS := 6
const SLOT := 56
const DOUBLE_CLICK_SEC := 0.35

@export var interaction_path: NodePath

var _interaction: InteractionController
## Back-reference to the UI hub (set via set_hub) so opening/closing stays coordinated
## with the command bar and the one-window-at-a-time rule.
var _hub = null


## v0.3.0: the hub is the single window authority. It calls these; the hub also owns
## the I hotkey and ESC precedence, so this UI no longer handles those directly.
func set_hub(hub) -> void:
	_hub = hub

func open() -> void:
	_set_panel_visible(true)

func close() -> void:
	_set_panel_visible(false)

func is_open() -> bool:
	return _open

var _panel: PanelContainer
var _title: Label
var _grid: GridContainer
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_flavor: Label
var _hold_btn: Button

var _held_hud: Control
var _held_box: PanelContainer
var _held_icon: TextureRect
var _held_label: Label
var _held_empty_lbl: Label
var _held_hint: Label

var _open: bool = false
var _slots: Array[Control] = []
var _row_ids: Array[String] = []
var _selected_index: int = -1
var _held_item: String = ""
var _last_click_index: int = -1
var _last_click_t: float = -1.0


func _ready() -> void:
	_interaction = get_node_or_null(interaction_path) as InteractionController
	_build_ui()
	Inventory.changed.connect(_rebuild)
	_rebuild()
	_set_panel_visible(false)


func _process(_delta: float) -> void:
	_refresh_held_hint()


# ---- build ----------------------------------------------------------------

func _panel_style(border: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_content_margin_all(16)
	sb.set_corner_radius_all(10)
	if border:
		sb.set_border_width_all(1)
		sb.border_color = VIOLET
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


func _build_ui() -> void:
	# --- main panel (centered) ---
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	_panel.add_child(outer)

	# title bar
	_title = Label.new()
	_title.add_theme_color_override("font_color", TEXT)
	_title.add_theme_font_size_override("font_size", 24)
	outer.add_child(_title)

	var sep := HSeparator.new()
	outer.add_child(sep)

	# body: grid (left) + detail pane (right)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	outer.add_child(body)

	var grid_scroll := ScrollContainer.new()
	grid_scroll.custom_minimum_size = Vector2(COLS * (SLOT + 8) + 8, 5 * (SLOT + 8))
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
	detail.custom_minimum_size = Vector2(230, 0)
	body.add_child(detail)

	var dcol := VBoxContainer.new()
	dcol.add_theme_constant_override("separation", 10)
	detail.add_child(dcol)

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
	_detail_flavor.custom_minimum_size = Vector2(202, 96)
	_detail_flavor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dcol.add_child(_detail_flavor)

	_hold_btn = Button.new()
	_hold_btn.focus_mode = Control.FOCUS_NONE
	_hold_btn.custom_minimum_size = Vector2(0, 44)
	_hold_btn.add_theme_color_override("font_color", TEXT)
	_hold_btn.add_theme_color_override("font_hover_color", VIOLET_SOFT)
	_hold_btn.add_theme_stylebox_override("normal", _btn_style(false))
	_hold_btn.add_theme_stylebox_override("hover", _btn_style(true))
	_hold_btn.add_theme_stylebox_override("pressed", _btn_style(true))
	_hold_btn.pressed.connect(_on_hold_button)
	dcol.add_child(_hold_btn)

	_build_held_hud()


func _btn_style(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#3a3a46") if active else Color("#2f2f39")
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	sb.set_border_width_all(1)
	sb.border_color = VIOLET if active else Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.3)
	return sb


func _build_held_hud() -> void:
	_held_hud = Control.new()
	_held_hud.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_held_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_held_hud)

	# hint text above the box
	_held_hint = Label.new()
	_held_hint.position = Vector2(24, -104)
	_held_hint.add_theme_color_override("font_color", VIOLET_SOFT)
	_held_hint.add_theme_font_size_override("font_size", 15)
	_held_hint.add_theme_constant_override("outline_size", 4)
	_held_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08, 0.9))
	_held_hint.visible = false
	_held_hud.add_child(_held_hint)

	# the slot box (64×64) + name label to its right
	var row := HBoxContainer.new()
	row.position = Vector2(24, -88)
	row.add_theme_constant_override("separation", 10)
	_held_hud.add_child(row)

	_held_box = PanelContainer.new()
	_held_box.custom_minimum_size = Vector2(64, 64)
	_held_box.add_theme_stylebox_override("panel", _held_box_style(false))
	row.add_child(_held_box)

	_held_icon = TextureRect.new()
	_held_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_held_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_held_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_held_box.add_child(_held_icon)

	# "빈 손" shown inside the box when empty
	_held_empty_lbl = Label.new()
	_held_empty_lbl.text = "빈 손"
	_held_empty_lbl.add_theme_color_override("font_color", DIM)
	_held_empty_lbl.add_theme_font_size_override("font_size", 13)
	_held_empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_held_empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_held_box.add_child(_held_empty_lbl)

	_held_label = Label.new()
	_held_label.add_theme_color_override("font_color", TEXT)
	_held_label.add_theme_font_size_override("font_size", 17)
	_held_label.add_theme_constant_override("outline_size", 4)
	_held_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08, 0.9))
	_held_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_held_label)

	_refresh_held_hud()


## Held box border: solid violet when holding, dashed-look (dim, dotted via a thin
## border) when empty.
func _held_box_style(holding: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BG.r, BG.g, BG.b, 0.9)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(4)
	sb.set_border_width_all(2)
	# StyleBoxFlat has no dash; approximate "dashed/empty" with a soft dim border.
	sb.border_color = VIOLET if holding else Color(DIM.r, DIM.g, DIM.b, 0.5)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 4
	return sb


# ---- grid build -----------------------------------------------------------

func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_slots.clear()
	_row_ids.clear()

	var ids := Inventory.ids()
	for i in ids.size():
		_add_slot(ids[i], i)

	if _held_item != "" and Inventory.count(_held_item) == 0:
		_set_held("")
	if _selected_index >= _row_ids.size():
		_selected_index = _row_ids.size() - 1
	_title.text = "인벤토리   %d종" % _row_ids.size()
	_refresh_selection()
	_refresh_detail()
	_refresh_held_hud()


func _add_slot(id: String, index: int) -> void:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(SLOT, SLOT)
	box.add_theme_stylebox_override("panel", _slot_style(false))

	# icon
	var icon := TextureRect.new()
	icon.texture = ItemDB.icon(id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	# count badge (bottom-right pill)
	var badge := Label.new()
	badge.text = "%d" % Inventory.count(id)
	badge.add_theme_color_override("font_color", TEXT)
	badge.add_theme_font_size_override("font_size", 13)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = BADGE_BG
	bsb.set_corner_radius_all(6)
	bsb.content_margin_left = 5
	bsb.content_margin_right = 5
	bsb.content_margin_top = 1
	bsb.content_margin_bottom = 1
	badge.add_theme_stylebox_override("normal", bsb)
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(badge)

	# click target
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_slot_pressed.bind(index))
	var clear := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", clear)
	btn.add_theme_stylebox_override("hover", clear)
	btn.add_theme_stylebox_override("pressed", clear)
	btn.add_theme_stylebox_override("focus", clear)
	box.add_child(btn)

	_grid.add_child(box)
	_slots.append(box)
	_row_ids.append(id)


func _slot_style(selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = SLOT_BG
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = VIOLET if selected else Color(0.3, 0.3, 0.36, 0.8)
	return sb


# ---- input / selection ----------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# The UI hub owns the I hotkey and ESC precedence (one-window rule). This panel
	# only handles in-panel navigation while it is open.
	if not _open:
		return
	if event.is_action_pressed("ui_right"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_selection(COLS)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_move_selection(-COLS)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_toggle_hold_current()
		get_viewport().set_input_as_handled()


func _set_panel_visible(v: bool) -> void:
	_open = v
	_panel.visible = v
	if v:
		# Ensure the one-window rule holds even if opened directly (defensive).
		if _hub != null and _hub.has_method("request_focus"):
			_hub.request_focus(_hub.Win.INVENTORY)
		if _selected_index < 0 and _row_ids.size() > 0:
			_selected_index = 0
	_refresh_selection()
	_refresh_detail()


func _move_selection(delta: int) -> void:
	if _row_ids.is_empty():
		return
	if _selected_index < 0:
		_selected_index = 0
	else:
		_selected_index = clampi(_selected_index + delta, 0, _row_ids.size() - 1)
	_refresh_selection()
	_refresh_detail()


func _on_slot_pressed(index: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var is_double := index == _last_click_index and (now - _last_click_t) <= DOUBLE_CLICK_SEC
	_last_click_index = index
	_last_click_t = now
	_selected_index = index
	_refresh_selection()
	_refresh_detail()
	if is_double:
		_toggle_hold_current()


func _refresh_selection() -> void:
	for i in _slots.size():
		_slots[i].add_theme_stylebox_override("panel", _slot_style(i == _selected_index))


# ---- detail pane ----------------------------------------------------------

func _current_id() -> String:
	if _selected_index < 0 or _selected_index >= _row_ids.size():
		return ""
	return _row_ids[_selected_index]


func _refresh_detail() -> void:
	var id := _current_id()
	if id == "":
		_detail_icon.texture = null
		_detail_name.text = "—"
		_detail_flavor.text = "가진 것이 없다."
		_hold_btn.text = ""
		_hold_btn.disabled = true
		return
	_hold_btn.disabled = false
	_detail_icon.texture = ItemDB.icon(id)
	_detail_name.text = "%s  x%d" % [ItemDB.item_name(id), Inventory.count(id)]
	_detail_flavor.text = ItemDB.item_flavor(id)
	_hold_btn.text = "내려놓기" if _held_item == id else "들기"


func _on_hold_button() -> void:
	_toggle_hold_current()


func _toggle_hold_current() -> void:
	var id := _current_id()
	if id == "":
		return
	if _held_item == id:
		_set_held("")
	else:
		_set_held(id)
	_refresh_detail()


# ---- held item ------------------------------------------------------------

func _set_held(id: String) -> void:
	_held_item = id
	if _interaction != null:
		_interaction.set_held_item(id)
	_refresh_held_hud()


func _refresh_held_hud() -> void:
	if _held_item == "":
		_held_icon.texture = null
		_held_icon.visible = false
		_held_empty_lbl.visible = true
		_held_label.text = ""
		_held_box.add_theme_stylebox_override("panel", _held_box_style(false))
		return
	_held_icon.texture = ItemDB.icon(_held_item)
	_held_icon.visible = true
	_held_empty_lbl.visible = false
	_held_label.text = "%s  x%d" % [ItemDB.item_name(_held_item), Inventory.count(_held_item)]
	_held_box.add_theme_stylebox_override("panel", _held_box_style(true))


## Show a context hint above the held box when the held item can act on a nearby
## valid target (placeable tile / usable object) the interaction controller sees.
func _refresh_held_hint() -> void:
	if _held_item == "" or _interaction == null:
		if _held_hint.visible:
			_held_hint.visible = false
		return
	var hint := _interaction.held_action_hint()
	if hint == "":
		if _held_hint.visible:
			_held_hint.visible = false
		return
	_held_hint.text = hint
	_held_hint.visible = true
