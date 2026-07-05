extends CanvasLayer
class_name TimeHUD
## Small time-of-day indicator (top-right): a sun/moon glyph + phase text that
## tracks GameState. Sun by day/dawn, moon by evening/night. Colors per art guide.

const CREAM := Color("#faf5e6")
const BG := Color("#2a2a33")

const PHASE_LABEL := {
	"day": "낮", "evening": "저녁", "night": "밤", "dawn": "새벽",
}
const PHASE_ICON := {
	"day": "☀", "evening": "☾", "night": "☾", "dawn": "☀",
}
const PHASE_COLOR := {
	"day": Color("#e8dfc8"),
	"evening": Color("#b59268"),
	"night": Color("#9e7ad9"),
	"dawn": Color("#d9b8ff"),
}

var _icon: Label
var _text: Label


func _ready() -> void:
	layer = 3
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-172, 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BG.r, BG.g, BG.b, 0.92)
	sb.set_content_margin_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color("#9e7ad9")
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	_icon = Label.new()
	_icon.add_theme_font_size_override("font_size", 24)
	row.add_child(_icon)

	_text = Label.new()
	_text.add_theme_color_override("font_color", CREAM)
	_text.add_theme_font_size_override("font_size", 18)
	row.add_child(_text)

	# Defensive autoload guard (ready-time). A missing GameState would null-deref
	# .day_phase_changed during the grove flush in a release template.
	if GameState == null:
		push_warning("TimeHUD: GameState singleton missing; HUD static")
		return
	GameState.day_phase_changed.connect(func(_p): _refresh())
	GameState.game_time_changed.connect(func(_t): _refresh())
	_refresh()


func _refresh() -> void:
	if GameState == null:
		return
	var p := GameState.phase()
	_icon.text = PHASE_ICON.get(p, "☀")
	_icon.add_theme_color_override("font_color", PHASE_COLOR.get(p, CREAM))
	var day := GameState.day_index() + 1
	_text.text = "%s · %d일차" % [PHASE_LABEL.get(p, p), day]
