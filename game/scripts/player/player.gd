extends CharacterBody2D
class_name Player
## 4-directional isometric player.
## Movement is mapped to iso screen axes: the input vector is transformed so that
## pressing "up" moves toward screen-up-along-the-iso-grid, giving the diagonal
## screen motion that matches a 2:1 diamond grid.
##
## Tile-driven speed/collision: instead of hardcoding tile ids, we sample the
## TileMapLayer's custom data (`walkable`, `speed_mod`) under the target position.

@export var speed: float = 300.0
@export var tilemap_path: NodePath

var _tilemap: TileMapLayer
var _facing: String = "SE"  # SE, SW, NE, NW
var _anim: AnimatedSprite2D

# Screen-space basis vectors for the four iso movement directions.
# For a 2:1 diamond, moving one grid step "north-east" on screen is (+x, -y*0.5).
# We build a normalized diagonal for each cardinal input so movement reads as
# gliding along the diamond axes.
const ISO_UP := Vector2(0, -1)
const ISO_DOWN := Vector2(0, 1)
const ISO_LEFT := Vector2(-1, 0)
const ISO_RIGHT := Vector2(1, 0)


func _ready() -> void:
	_anim = $AnimatedSprite2D
	if tilemap_path != NodePath():
		_tilemap = get_node_or_null(tilemap_path) as TileMapLayer
	_update_animation(false)


func _physics_process(_delta: float) -> void:
	var input_vec := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	if input_vec == Vector2.ZERO:
		velocity = Vector2.ZERO
		_update_animation(false)
		move_and_slide()
		return

	# Transform cardinal input into iso screen space: horizontal keeps full x,
	# vertical is squashed to 0.5 to follow the 2:1 diamond so diagonals feel right.
	var iso_dir := Vector2(input_vec.x, input_vec.y * 0.5).normalized()

	_update_facing(input_vec)

	var current_speed := speed * _speed_mod_at(global_position)
	velocity = iso_dir * current_speed
	move_and_slide()
	_update_animation(true)


## Sample speed modifier from the tile under a world position. Non-walkable tiles
## are handled by StaticBody collision, so here we only scale speed (mud etc.).
func _speed_mod_at(world_pos: Vector2) -> float:
	if _tilemap == null:
		return 1.0
	var cell := _tilemap.local_to_map(_tilemap.to_local(world_pos))
	var data := _tilemap.get_cell_tile_data(cell)
	if data == null:
		return 1.0
	var m: float = data.get_custom_data("speed_mod")
	return m if m > 0.0 else 1.0


func _update_facing(input_vec: Vector2) -> void:
	# Choose iso facing from dominant screen axis.
	if abs(input_vec.x) >= abs(input_vec.y):
		_facing = "SE" if input_vec.x > 0 else "NW"
	else:
		_facing = "SW" if input_vec.y > 0 else "NE"


## Current cardinal facing string (SE/SW/NE/NW), read by the interaction system.
func get_facing() -> String:
	return _facing


## Grid-space step for the current facing, used to find the facing-adjacent cell.
## In this iso setup the four cardinal inputs map to the four diagonal-screen
## directions; the corresponding tile-grid neighbor is:
##   SE (input +x) -> +x,  NW (input -x) -> -x,
##   SW (input +y) -> +y,  NE (input -y) -> -y.
func facing_cell_step() -> Vector2i:
	match _facing:
		"SE": return Vector2i(1, 0)
		"NW": return Vector2i(-1, 0)
		"SW": return Vector2i(0, 1)
		"NE": return Vector2i(0, -1)
	return Vector2i(1, 0)


func _update_animation(moving: bool) -> void:
	if _anim == null:
		return
	var state := "walk" if moving else "idle"
	var anim_name := "%s_%s" % [state, _facing]
	if _anim.sprite_frames != null and _anim.sprite_frames.has_animation(anim_name):
		if _anim.animation != anim_name or not _anim.is_playing():
			_anim.play(anim_name)
