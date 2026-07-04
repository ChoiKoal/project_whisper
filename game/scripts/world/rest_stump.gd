extends Sprite2D
class_name RestStump
## Rest Stump (U, cell 12,33) near spawn. Interact → fade out/in → time jumps to
## the start of the next evening (GameState.skip_to_next_evening()). Teaches the
## time-skip needed to open the G3 night gate.
##
## Joins the `gatherable` group and duck-types the InteractionController contract
## (target_point/can_gather/on_interact), exactly like Cauldron. can_gather()
## returns false so the controller routes to on_interact().

const GROUP := "gatherable"
const TEX := "res://assets/objects/rest_stump.png"
const FLAVOR := "잠깐 쉬어 갈까. …눈을 뜨면 저녁이겠지."

signal rested

## Optional fade layer (a full-screen ColorRect on a CanvasLayer). Set by the
## map loader; if null, the skip happens instantly (harness-friendly).
var fade_rect: ColorRect
var _busy: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	if texture == null:
		texture = load(TEX)
	offset = Vector2(0, -80)


func target_point() -> Vector2:
	return global_position


func can_gather() -> bool:
	return false


func on_interact() -> void:
	if _busy:
		return
	rest()


## Fade to black, skip to next evening, fade back in.
func rest() -> void:
	if _busy:
		return
	_busy = true
	if fade_rect == null:
		GameState.skip_to_next_evening()
		rested.emit()
		_busy = false
		return
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(fade_rect, "modulate:a", 1.0, 0.6)
	tw.tween_callback(func():
		GameState.skip_to_next_evening()
		rested.emit()
	)
	tw.tween_interval(0.3)
	tw.tween_property(fade_rect, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func():
		fade_rect.visible = false
		_busy = false
	)
