extends CanvasLayer
class_name ClearSequence
## G4 clear cutscene. Listens for GameState.world_tree_planted (emitted when D22
## 어린 세계수 is placed on a T0 VOID cell). Plays:
##   1. screen slow fade to dark
##   2. text "…들려? 방금, 세계가 대답했어."
##   3. "Project Whisper — 계속됩니다" + 발견률 stats (from Codex)
##   4. ESC / interact returns to game (free play; time resumes)
##
## Layered above everything (layer 10). Pauses GameState time during the fade so
## the world holds still for the beat.

const LINE1 := "…들려? 방금, 세계가 대답했어."
const TITLE := "Project Whisper — 계속됩니다"
const BG := Color("#1a1420")
const CREAM := Color("#faf5e6")
const VIOLET := Color("#9e7ad9")

var _dim: ColorRect
var _center: VBoxContainer
var _line1: Label
var _title: Label
var _stats: Label
var _hint: Label
var _active: bool = false
var _planted_cell: Vector2i = Vector2i(-999, -999)

signal cleared


func _ready() -> void:
	layer = 10
	_build()
	GameState.world_tree_planted.connect(_on_planted)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = BG
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.modulate.a = 0.0
	_dim.visible = false
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_center = VBoxContainer.new()
	_center.set_anchors_preset(Control.PRESET_CENTER)
	_center.alignment = BoxContainer.ALIGNMENT_CENTER
	_center.add_theme_constant_override("separation", 24)
	_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_center.grow_vertical = Control.GROW_DIRECTION_BOTH
	_dim.add_child(_center)

	_line1 = _mk_label(LINE1, 30, CREAM)
	_title = _mk_label(TITLE, 40, VIOLET)
	_stats = _mk_label("", 22, CREAM)
	_hint = _mk_label("[ESC / 상호작용] 돌아가기", 18, Color("#b8b4a8"))
	_line1.modulate.a = 0.0
	_title.modulate.a = 0.0
	_stats.modulate.a = 0.0
	_hint.modulate.a = 0.0
	_center.add_child(_line1)
	_center.add_child(_title)
	_center.add_child(_stats)
	_center.add_child(_hint)


func _mk_label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	return l


func is_active() -> bool:
	return _active


func _on_planted(cell: Vector2i) -> void:
	if _active:
		return
	_planted_cell = cell
	play()


func play() -> void:
	_active = true
	GameState.time_running = false
	_dim.visible = true
	_stats.text = _stats_text()
	var tw := create_tween()
	tw.tween_property(_dim, "modulate:a", 1.0, 2.0)   # slow fade
	tw.tween_property(_line1, "modulate:a", 1.0, 1.2)
	tw.tween_interval(0.8)
	tw.tween_property(_title, "modulate:a", 1.0, 1.0)
	tw.tween_property(_stats, "modulate:a", 1.0, 0.8)
	tw.tween_property(_hint, "modulate:a", 1.0, 0.6)
	tw.tween_callback(func(): cleared.emit())


func _stats_text() -> String:
	var di := Codex.discovered_item_count()
	var dr := Codex.discovered_recipe_count()
	var ti := ItemDB.all_ids().size()
	var tr := RecipeDB.all_ids().size()
	var total_disc := di + dr
	var total := ti + tr
	var pct := 0.0
	if total > 0:
		pct = 100.0 * float(total_disc) / float(total)
	return "발견률 %.0f%%   (아이템 %d/%d · 레시피 %d/%d)" % [pct, di, ti, dr, tr]


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		_dismiss()
		get_viewport().set_input_as_handled()


func _dismiss() -> void:
	if not _active:
		return
	var tw := create_tween()
	tw.tween_property(_dim, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func():
		_dim.visible = false
		_active = false
		GameState.time_running = true  # free play resumes
		# reset labels for potential replays
		for l in [_line1, _title, _stats, _hint]:
			l.modulate.a = 0.0
	)
