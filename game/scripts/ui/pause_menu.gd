extends CanvasLayer
class_name PauseMenu
## In-game pause menu (ESC). Options: "계속" / "저장" / "타이틀로".
## Pauses GameState time while open (does not use the SceneTree pause so the
## menu itself stays responsive without process-mode juggling). Same visual style:
## bg #2a2a33, text #faf5e6, accent #9e7ad9.

const BG := Color("#2a2a33")
const CREAM := Color("#faf5e6")
const VIOLET := Color("#9e7ad9")
const TITLE_SCENE := "res://scenes/ui/title.tscn"

var _root: Control
var _panel: VBoxContainer
var _toast: Label
var _open: bool = false
var _time_was_running: bool = true


func _ready() -> void:
	layer = 9
	_build()
	_set_open(false)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(BG.r, BG.g, BG.b, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	# Framed panel (title-screen style) centered over the dim.
	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.11, 0.10, 0.14, 0.96)
	fsb.set_corner_radius_all(14)
	fsb.set_content_margin_all(28)
	fsb.set_border_width_all(1)
	fsb.border_color = VIOLET
	fsb.shadow_color = Color(0, 0, 0, 0.45)
	fsb.shadow_size = 10
	frame.add_theme_stylebox_override("panel", fsb)
	_root.add_child(frame)

	_panel = VBoxContainer.new()
	_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_theme_constant_override("separation", 14)
	frame.add_child(_panel)

	# header row: title + close (X) top-right (B3.2). "계속" already resumes, but the X
	# gives the same consistent close affordance every other window has.
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	_panel.add_child(head_row)
	var head := _label("일시정지", 40, VIOLET)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(head)
	head_row.add_child(WindowChrome.make_close_button(_on_resume))

	_add_button("계속", _on_resume)
	_add_button("저장", _on_save)
	_add_button("타이틀로", _on_title)

	_toast = _label("", 20, CREAM)
	_toast.modulate.a = 0.0
	_panel.add_child(_toast)

	# (B3.2) close-affordance hint at the panel bottom (ESC resumes).
	_panel.add_child(WindowChrome.make_esc_hint())


func _label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	return l


func _add_button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 48)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", VIOLET)
	b.add_theme_color_override("font_focus_color", VIOLET)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("normal", _pause_btn_style(false))
	b.add_theme_stylebox_override("hover", _pause_btn_style(true))
	b.add_theme_stylebox_override("focus", _pause_btn_style(true))
	b.add_theme_stylebox_override("pressed", _pause_btn_style(true))
	b.pressed.connect(cb)
	_panel.add_child(b)


func _pause_btn_style(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#33333f") if active else Color(BG.r, BG.g, BG.b, 0.85)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	sb.set_border_width_all(2)
	sb.border_color = VIOLET if active else Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.25)
	return sb


func is_open() -> bool:
	return _open


func toggle() -> void:
	_set_open(not _open)


func _set_open(v: bool) -> void:
	_open = v
	_root.visible = v
	if v:
		_time_was_running = GameState.time_running
		GameState.time_running = false
		GameState.push_modal("pause")   # (B3.1) also freeze the player while paused
	else:
		GameState.time_running = _time_was_running
		GameState.pop_modal("pause")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


# ---- actions -------------------------------------------------------------

func _on_resume() -> void:
	_set_open(false)


func _on_save() -> void:
	var ok := SaveManager.save_game()
	_flash("저장되었습니다" if ok else "저장 실패")


func _on_title() -> void:
	# Autosave before leaving so progress isn't lost, then unregister the world.
	SaveManager.save_game()
	GameState.time_running = true
	SaveManager.unregister_world()
	get_tree().change_scene_to_file(TITLE_SCENE)


func _flash(msg: String) -> void:
	_toast.text = msg
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)
