extends CanvasLayer
class_name UIHub
## v0.3.0 B1/B5 — bottom command bar + single-window coordinator.
##
## Renders the always-visible centered command bar (4 buttons with hotkey labels)
## and is the single authority for the "only one window open at a time" rule and the
## ESC precedence rule (ESC closes any open window BEFORE the pause menu opens).
##
## Buttons (owner wireframe): 캐릭터 (C) · 인벤토리 (I) · 도감 (R) · 메뉴 (ESC).
##   - 캐릭터 → character window (new, C).
##   - 인벤토리 → inventory window (I).
##   - 도감 → codex window (REMAP: was C, now R).
##   - 메뉴 → pause menu (ESC).
## A click does exactly what the hotkey does, routed through this hub.
##
## Windows register themselves in the "ui_window" group and implement:
##   open(), close(), is_open() -> bool
## The hub closes every other registered window before opening the requested one.

const BG := Color("#2a2a33")
const CREAM := Color("#faf5e6")
const VIOLET := Color("#9e7ad9")
const VIOLET_SOFT := Color("#c8b0ec")
const DIM := Color("#b8b4a8")

## Window kinds the hub coordinates.
enum Win { NONE, CHARACTER, INVENTORY, CODEX }

@export var pause_menu_path: NodePath

var _pause: PauseMenu
var _bar: Control
var _buttons: Dictionary = {}   # Win -> Button

## The window nodes, resolved lazily by group name/class.
var _character = null
var _inventory = null
var _codex = null


func _ready() -> void:
	layer = 3   # above world + inventory(1)/fusion(2)/codex(2), below fade(8)/pause(9)
	_pause = get_node_or_null(pause_menu_path) as PauseMenu
	_build_bar()
	# Resolve sibling windows after the scene is fully built.
	call_deferred("_resolve_windows")


func _resolve_windows() -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	_inventory = _find_by_class(root, "InventoryUI")
	_codex = _find_by_class(root, "CodexUI")
	_character = _find_by_class(root, "CharacterWindow")
	# Hand each window a back-reference so a window closing itself (its own ESC/I/R)
	# stays consistent with the hub. Windows call hub.notify_closed() on self-close.
	for w in [_inventory, _codex, _character]:
		if w != null and w.has_method("set_hub"):
			w.set_hub(self)


func _find_by_class(node: Node, cls: String):
	if node == null:
		return null
	if node.get_class() == cls or (node.get_script() != null and _script_is(node, cls)):
		return node
	for c in node.get_children():
		var r = _find_by_class(c, cls)
		if r != null:
			return r
	return null


func _script_is(node: Node, cls: String) -> bool:
	var s = node.get_script()
	return s != null and s.get_global_name() == cls


# ---- command bar ---------------------------------------------------------

func _build_bar() -> void:
	_bar = Control.new()
	_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_BEGIN
	frame.offset_bottom = -12
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BG.r, BG.g, BG.b, 0.92)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(8)
	sb.set_border_width_all(1)
	sb.border_color = VIOLET
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 6
	frame.add_theme_stylebox_override("panel", sb)
	_bar.add_child(frame)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	frame.add_child(row)

	_add_bar_button(row, Win.CHARACTER, "캐릭터", "C")
	_add_bar_button(row, Win.INVENTORY, "인벤토리", "I")
	_add_bar_button(row, Win.CODEX, "도감", "R")
	_add_bar_button(row, Win.NONE, "메뉴", "ESC")   # NONE = pause menu


func _add_bar_button(row: HBoxContainer, kind: int, label: String, hotkey: String) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(118, 44)
	b.text = "%s (%s)" % [label, hotkey]
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", VIOLET_SOFT)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", _bar_btn_style(false))
	b.add_theme_stylebox_override("hover", _bar_btn_style(true))
	b.add_theme_stylebox_override("pressed", _bar_btn_style(true))
	b.pressed.connect(_on_bar_pressed.bind(kind))
	row.add_child(b)
	_buttons[kind] = b


func _bar_btn_style(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#3a3a46") if active else Color("#2f2f39")
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	sb.set_border_width_all(1)
	sb.border_color = VIOLET if active else Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.3)
	return sb


func _on_bar_pressed(kind: int) -> void:
	match kind:
		Win.CHARACTER: toggle(Win.CHARACTER)
		Win.INVENTORY: toggle(Win.INVENTORY)
		Win.CODEX: toggle(Win.CODEX)
		_:
			# 메뉴 button = same as ESC: close any window first, else toggle pause.
			if _any_window_open():
				close_all()
			elif _pause != null:
				_pause.toggle()


# ---- window management ----------------------------------------------------

func _window_for(kind: int):
	match kind:
		Win.CHARACTER: return _character
		Win.INVENTORY: return _inventory
		Win.CODEX: return _codex
	return null


func _any_window_open() -> bool:
	for w in [_inventory, _codex, _character]:
		if w != null and w.has_method("is_open") and w.is_open():
			return true
	return false


## Public: is exactly one of the coordinated windows open?
func any_window_open() -> bool:
	return _any_window_open()


func close_all() -> void:
	for w in [_inventory, _codex, _character]:
		if w != null and w.has_method("is_open") and w.is_open():
			w.close()


## Toggle a window: if already open, close it; else close everything and open it.
func toggle(kind: int) -> void:
	var w = _window_for(kind)
	if w == null:
		return
	if w.has_method("is_open") and w.is_open():
		w.close()
		return
	close_all()
	if w.has_method("open"):
		w.open()


## Called by a window when it opens itself via its own hotkey, so the hub can close
## the others. `kind` is the window's own kind.
func request_focus(kind: int) -> void:
	for k in [Win.CHARACTER, Win.INVENTORY, Win.CODEX]:
		if k == kind:
			continue
		var w = _window_for(k)
		if w != null and w.has_method("is_open") and w.is_open():
			w.close()


# ---- input: ESC precedence + hotkeys -------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# ESC: if any window is open, close it and DO NOT let the pause menu open.
	if event.is_action_pressed("ui_cancel"):
		if _any_window_open():
			close_all()
			get_viewport().set_input_as_handled()
		return
	# Hotkeys route through the hub so the one-window rule always holds.
	if event.is_action_pressed("character"):
		toggle(Win.CHARACTER)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		toggle(Win.INVENTORY)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("codex"):
		toggle(Win.CODEX)
		get_viewport().set_input_as_handled()
