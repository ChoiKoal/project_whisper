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

	_panel = VBoxContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.add_theme_constant_override("separation", 14)
	_root.add_child(_panel)

	var head := _label("일시정지", 40, VIOLET)
	_panel.add_child(head)

	_add_button("계속", _on_resume)
	_add_button("저장", _on_save)
	_add_button("타이틀로", _on_title)

	_toast = _label("", 20, CREAM)
	_toast.modulate.a = 0.0
	_panel.add_child(_toast)


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
	b.custom_minimum_size = Vector2(240, 44)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", VIOLET)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	_panel.add_child(b)


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
	else:
		GameState.time_running = _time_was_running


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
