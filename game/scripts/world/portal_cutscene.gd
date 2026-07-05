extends CanvasLayer
class_name PortalCutscene
## Portal travel + CS-05 「귀환과 점화」 cutscene layer for the home island (v0.5.0 phase C).
##
## Two beats, both composed from the shared card+fade vocabulary (opening/clear style):
##   play_travel(then)          — CS-02 mini-transition: the screen swells with violet light
##                                (a full-screen violet ColorRect rising to opaque), a short
##                                text hold, then invokes `then` (the scene change). Used when
##                                the player enters a portal.
##   play_return_ignition()     — CS-05: on returning to the home island after a clear, the
##                                Layer-1 (nature) portal flickers → OPEN (bright), the next
##                                portal (science) begins flickering, text cards narrate it,
##                                and quest P2 opens. Awaitable.
##
## Layered above everything (layer 11). Pauses GameState time during the beats.

const VIOLET := Color("#9e7ad9")
const VIOLET_DEEP := Color(0.35, 0.22, 0.55, 1.0)
const CREAM := Color("#faf5e6")

var _swell: ColorRect
var _center: VBoxContainer
var _line: Label
var _active: bool = false


func _ready() -> void:
	layer = 11
	_build()


func _build() -> void:
	_swell = ColorRect.new()
	_swell.color = Color(VIOLET_DEEP.r, VIOLET_DEEP.g, VIOLET_DEEP.b, 0.0)
	_swell.set_anchors_preset(Control.PRESET_FULL_RECT)
	_swell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_swell)

	_center = VBoxContainer.new()
	_center.set_anchors_preset(Control.PRESET_CENTER)
	_center.alignment = BoxContainer.ALIGNMENT_CENTER
	_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_center.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_center)

	_line = Label.new()
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.add_theme_color_override("font_color", CREAM)
	_line.add_theme_font_size_override("font_size", 30)
	_line.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.09, 0.9))
	_line.add_theme_constant_override("outline_size", 5)
	_line.modulate.a = 0.0
	_center.add_child(_line)


# ---- CS-02 travel swell ---------------------------------------------------

## Play the violet-swell transition, then call `then` (scene change). The overlay stays
## opaque across the scene change so the destination fades in from violet.
func play_travel(then: Callable) -> void:
	if _active:
		then.call()
		return
	_active = true
	GameState.time_running = false
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("travel_whoosh")
	var tw := create_tween()
	tw.tween_property(_swell, "color:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.3)
	tw.tween_callback(func():
		GameState.time_running = true
		then.call())


# ---- CS-05 return & ignition ----------------------------------------------

const CS05_CARDS := [
	"하나의 세계가, 내 안에서 자리를 잡았다.",
	"…그리고 다음 문이, 나를 알아봤다.",
]

## CS-05: brighten the nature portal to OPEN, set science flickering, narrate with cards,
## and open quest P2. Awaitable (the caller awaits the whole beat before saving).
func play_return_ignition() -> void:
	_active = true
	GameState.time_running = false
	# Arrival lands from a violet swell; fade it down first.
	_swell.color = Color(VIOLET_DEEP.r, VIOLET_DEEP.g, VIOLET_DEEP.b, 1.0)
	var intro := create_tween()
	intro.tween_property(_swell, "color:a", 0.0, 1.0)
	await intro.finished

	# Card 1 — the nature portal fully opens.
	await _card(CS05_CARDS[0])
	GameState.set_portal_state("nature", GameState.PORTAL_OPEN)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("portal_ignite")
	await _hold(0.7)

	# Card 2 — the next portal (science) begins flickering (teaser).
	await _card(CS05_CARDS[1])
	GameState.set_portal_state("science", GameState.PORTAL_FLICKERING)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("portal_hum")
	await _hold(0.8)

	# Open quest P2 ("이 섬에… 네가 만든 것을 보여줘.").
	if QuestManager != null and QuestManager.has_method("advance_to"):
		QuestManager.advance_to("P2")
	_active = false
	GameState.time_running = true


func _card(text: String) -> void:
	_line.text = text
	var tw := create_tween()
	tw.tween_property(_line, "modulate:a", 1.0, 0.9)
	await tw.finished


func _hold(secs: float) -> void:
	var tw := create_tween()
	tw.tween_interval(secs)
	tw.tween_property(_line, "modulate:a", 0.0, 0.6)
	await tw.finished


func is_active() -> bool:
	return _active
