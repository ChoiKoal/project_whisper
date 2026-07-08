extends CanvasLayer
class_name CutsceneReplay
## (CQ-5 G14) 컷신 재감상 플레이어 — a side-effect-free playback overlay for the 도감 「기록」 탭's
## replay menu. Replays a cutscene's TEXT CARDS + its signature visual beat (heartbeat / flash /
## birdsong / purple dot) using the shared CutsceneDirector, WITHOUT any gameplay side effects
## (no scene changes, no portal-state writes, no quest advances, no cleared/ending records).
##
## Layered above everything (layer 14). Pauses GameState (time+control) for the beat and restores
## on every exit path (finish or ESC). Headless-safe: play()/skip()/is_done() drive it for tests.

const CREAM := Color("#faf5e6")

## Per-cutscene replay scripts: an ordered list of beats. Each beat is a card string, plus an
## optional signature visual (played once, keyed by cutscene id).
const SCRIPTS := {
	"CS-01": [
		"어둠 속에서, 누군가 나를 불렀다.",
		"…아니. 부른 게 아니라, 속삭였다.",
		"여기가 나의 세계라고 했다. …아무것도 없는데.",
		"문 하나가, 숨을 쉬고 있었다.",
	],
	"CS-02": [
		"아름다웠다. 그리고… 어딘가 잘못돼 있었다.",
		"같은 새가, 같은 노래를, 같은 자리에서.",
	],
	"CS-03": [
		"이 세계에서 유일하게, 따뜻한 것.",
		"…방금, 나를 본 건가?",
	],
	"CS-04": [
		"세계가, 숨을 뱉었다.",
		"…들려? 방금, 세계가 대답했어.",
		"돌아갈 시간이야. 나의 세계로.",
	],
	"CS-05": [
		"하나의 세계가, 내 안에서 자리를 잡았다.",
		"…그리고 다음 문이, 나를 알아봤다.",
	],
	"E1": [
		"자연 — 어린 세계수를 되심는 순간.",
		"과학 — 관제탑에 불이 들어오는 순간.",
		"기계 — 대시계가 다시 도는 순간.",
		"마법 — 최심부 봉인이 다시 짜이는 순간.",
		"신성 — 대제단이 처음 '대답'을 받는 순간.",
	],
	"E2": [
		"완성하지 않을 거야. 계속 말을 걸 거야.",
	],
}

var _id: String = ""
var _bg: ColorRect
var _flash: ColorRect
var _label: Label
var _skip_hint: Label
var _done: bool = false


func _ready() -> void:
	layer = 14
	_build()


func _build() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.02, 0.03, 1.0)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_label = CutsceneDirector.make_card_label(30)
	add_child(_label)

	_flash = CutsceneDirector.make_flash(Color(1, 1, 1))
	add_child(_flash)

	_skip_hint = Label.new()
	_skip_hint.text = "건너뛰기 (ESC)"
	_skip_hint.add_theme_color_override("font_color", Color(0.72, 0.70, 0.66, 0.7))
	_skip_hint.add_theme_font_size_override("font_size", 16)
	_skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip_hint.position = Vector2(-190, -46)
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skip_hint)


## Public entry (also harness). Replays cutscene `cutscene_id`; frees itself when done.
func play(cutscene_id: String) -> void:
	_id = cutscene_id
	if GameState != null:
		GameState.time_running = false
		GameState.set_control_lock(true)
	_run()


func is_done() -> bool:
	return _done


func _run() -> void:
	# Signature opening beat per cutscene (side-effect-free).
	match _id:
		"CS-01":
			await CutsceneDirector.purple_dot_heartbeat(self, self, 2)
		"CS-04":
			await CutsceneDirector.flash(self, _flash, 0.9, 0.08, 0.8)
		"E1":
			await CutsceneDirector.flash(self, _flash, 0.9, 0.12, 0.7)
	if _done:
		return
	var cards: Array = SCRIPTS.get(_id, [])
	for card in cards:
		if _done:
			return
		await CutsceneDirector.play_card(self, _label, String(card), CREAM)
	# Signature closing beat.
	if not _done:
		match _id:
			"CS-02", "CS-04", "E1":
				if AudioManager != null and AudioManager.has_method("play_sfx"):
					AudioManager.play_sfx("bird")
				await CutsceneDirector._wait(self, 0.9)
			"E2":
				await CutsceneDirector.purple_dot_heartbeat(self, self, 2)
	_finish()


func _finish() -> void:
	if _done:
		# Still ensure state restore even on a double-finish.
		pass
	_done = true
	if GameState != null:
		GameState.time_running = true
		GameState.set_control_lock(false)
	if is_instance_valid(self):
		queue_free()


## Public (harness / ESC): stop the replay immediately and restore state. Idempotent.
func skip() -> void:
	if _done:
		return
	_finish()


func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree() or _done:
		return
	if event.is_action_pressed("ui_cancel") \
			or event.is_action_pressed("interact") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
		skip()
