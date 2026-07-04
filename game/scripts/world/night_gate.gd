extends Node2D
class_name NightGate
## G3 gate — the night flower path entrance (cells 19,7 / 20,7). Passable only
## during the night window (evening~dawn). By day the flower bud is closed, an
## invisible wall blocks the cell, and touching it shows the flavor message
## "꽃봉오리가 닫혀 있다… 밤을 기다리는 걸까".
##
## One NightGate node is placed per N cell. It listens to
## GameState.day_phase_changed to open/close (no polling). Collision is a
## StaticBody2D toggled by phase.

const CLOSED_TEX := "res://assets/objects/night_bud_closed.png"
const OPEN_TEX := "res://assets/objects/night_bud_open.png"
const FLAVOR := "꽃봉오리가 닫혀 있다… 밤을 기다리는 걸까"

var _sprite: Sprite2D
var _body: StaticBody2D
var _glow: GlowSprite
var _open: bool = false
## Cooldown so the flavor message doesn't spam every frame of contact.
var _msg_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("night_gate")
	_sprite = Sprite2D.new()
	_sprite.texture = load(CLOSED_TEX)
	_sprite.offset = Vector2(0, -60)
	_sprite.y_sort_enabled = true
	add_child(_sprite)

	_body = StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([
		Vector2(0, -32), Vector2(64, 0), Vector2(0, 32), Vector2(-64, 0)
	])
	col.shape = shape
	_body.add_child(col)
	add_child(_body)

	# Glow overlay (only visible when open at night) — additive. Kept as a direct
	# reference because GlowSprite reparents itself onto the glow CanvasLayer, so a
	# by-name child lookup would no longer find it.
	_glow = GlowSprite.new()
	_glow.texture = load(OPEN_TEX)
	_glow.offset = Vector2(0, -60)
	_glow.visible = false
	_glow.name = "Glow"
	add_child(_glow)

	GameState.day_phase_changed.connect(_on_phase)
	_apply(GameState.is_night_window())


func _process(delta: float) -> void:
	if _msg_cooldown > 0.0:
		_msg_cooldown -= delta


func is_open() -> bool:
	return _open


func _on_phase(_phase: String) -> void:
	_apply(GameState.is_night_window())


func _apply(open: bool) -> void:
	_open = open
	if open:
		_sprite.texture = load(OPEN_TEX)
		if is_instance_valid(_body):
			_body.process_mode = Node.PROCESS_MODE_DISABLED
			_set_collision(false)
		if is_instance_valid(_glow): _glow.visible = true
	else:
		_sprite.texture = load(CLOSED_TEX)
		if is_instance_valid(_body):
			_body.process_mode = Node.PROCESS_MODE_INHERIT
			_set_collision(true)
		if is_instance_valid(_glow): _glow.visible = false


func _set_collision(on: bool) -> void:
	var col := _body.get_child(0) as CollisionShape2D
	if col:
		col.disabled = not on


## Called by the interaction/day-guard when the player bumps a closed gate.
func show_flavor(feedback_parent: Node) -> void:
	if _open or _msg_cooldown > 0.0:
		return
	_msg_cooldown = 2.5
	FloatingLabel.spawn(feedback_parent, global_position - Vector2(0, 80), FLAVOR)
