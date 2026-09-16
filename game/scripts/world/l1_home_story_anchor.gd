extends Sprite2D
## Nonblocking environmental observation. No rewards, collisions or save-owned position.
signal inspected(anchor)
var kind := "perch"
var response: Sprite2D
var _idle := 0.0
var _base: Texture2D
var _alternate: Texture2D
var outcome := ""
var shadow: Sprite2D
var height_lift := 0.0
func _ready() -> void:
	add_to_group("gatherable")
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_base=load("res://assets/objects/l1_listening_perch.png" if kind=="perch" else "res://assets/objects/l1_story_cairn.png")
	texture=_base
	offset=Vector2(0,-80 if kind=="perch" else -56)
	if kind=="perch": _alternate=load("res://assets/objects/l1_listening_perch_idle.png")
	response=Sprite2D.new()
	response.name="Response"
	response.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	response.position=Vector2(-6,-101) if kind=="perch" else Vector2(6,-30)
	add_child(response)
	if kind=="perch":
		shadow=Sprite2D.new()
		shadow.name="RepeatingShadow"
		shadow.texture=load("res://assets/objects/l1_bird_shadow_strip.png")
		shadow.hframes=6
		shadow.position=Vector2(42,8)
		add_child(shadow)
func target_point() -> Vector2: return global_position
## Tap hit-test follows the visible raised prop, not its bare ground socket.
func visual_target_point() -> Vector2: return global_position+offset
func can_gather() -> bool: return false
func on_interact() -> void:
	if visible and not GameState.ui_modal_open() and not GameState.control_locked() and GameState.time_running:
		inspected.emit(self)
func set_outcome(value: String) -> void:
	outcome=value
	response.texture=load("res://assets/objects/l1_response_%s.png" % value) if value in GameState.STORY_OUTCOMES else null
	response.position=response_rest()

func response_rest() -> Vector2:
	if kind=="cairn": return Vector2(6,-30+height_lift)
	return (Vector2(-6,-101) if outcome=="nest" else Vector2(-14,-8))+Vector2(0,height_lift)

func set_height_lift(value: float) -> void:
	height_lift=value
	offset=Vector2(0,(-80 if kind=="perch" else -56)+value)
	response.position=response_rest()
func _process(delta: float) -> void:
	if kind!="perch" or not GameState.time_running: return
	_idle+=delta
	texture=_alternate if fmod(_idle,6.0)>5.5 else _base
	if shadow!=null:
		shadow.frame=3 if outcome=="nest" else int(_idle*5)%6
		shadow.flip_h=outcome=="nest"
		shadow.position=(Vector2(42,8) if outcome=="nest" else Vector2(42+int(_idle*10)%24*2,8))+Vector2(0,height_lift)
