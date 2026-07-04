extends Control
class_name TitleMenu
## Minimal title screen for Project Whisper.
##   "새로 시작"        — always
##   "이어하기"         — only if SaveManager.has_save()
##   "NG+ 시작"         — only if the save is cleared (SaveManager.cleared)
##   "종료"             — quit
##
## Visual style (locked): bg #2a2a33, text #faf5e6, accent #9e7ad9. Shows the game
## name + subtitle. Placeholder pixel-ish styling (large fonts, letter spacing).

const BG := Color("#2a2a33")
const CREAM := Color("#faf5e6")
const VIOLET := Color("#9e7ad9")
const MUTED := Color("#b8b4a8")

const GROVE_SCENE := "res://scenes/world/starting_grove.tscn"

var _buttons: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.add_theme_constant_override("separation", 18)
	add_child(col)

	var title := _label("Project Whisper", 64, VIOLET)
	var sub := _label("속삭임이 세계를 만든다", 24, CREAM)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	col.add_child(title)
	col.add_child(sub)
	col.add_child(spacer)

	_buttons = VBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 12)
	col.add_child(_buttons)

	_add_button("새로 시작", _on_new_game)
	if SaveManager.has_save():
		_add_button("이어하기", _on_continue)
	if SaveManager.has_save() and _save_cleared():
		_add_button("NG+ 시작", _on_ng_plus)
	_add_button("종료", _on_quit)


func _save_cleared() -> bool:
	# Peek the save file's cleared flag without mutating live state.
	var data := SaveManager._read_save()
	var ng: Dictionary = data.get("ngplus", {})
	return bool(ng.get("cleared", false))


func _label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	return l


func _add_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 48)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", VIOLET)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(cb)
	_buttons.add_child(b)
	return b


# ---- actions -------------------------------------------------------------

func _on_new_game() -> void:
	SaveManager.new_game()
	SaveManager.delete_save()
	SaveManager.pending_load = false
	get_tree().change_scene_to_file(GROVE_SCENE)


func _on_continue() -> void:
	# Defer the load until the grove scene has built its map + player: the grove
	# session calls SaveManager.load_game() from its _ready when pending_load.
	SaveManager.pending_load = true
	get_tree().change_scene_to_file(GROVE_SCENE)


func _on_ng_plus() -> void:
	# Bring the finished run's discovery state into memory (core-only, no world),
	# then roll NG+ (resets + seeds 3 carried recipes). Fresh world, no pending load.
	var data := SaveManager._read_save()
	SaveManager._apply_core_state(data)
	SaveManager.start_ng_plus()
	SaveManager.pending_load = false
	get_tree().change_scene_to_file(GROVE_SCENE)


func _on_quit() -> void:
	get_tree().quit()
