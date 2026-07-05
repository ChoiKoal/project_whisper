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

## ---- Path following (M6a touch / click-to-move) --------------------------
## When a path is queued (by the touch controller), the player walks it unless
## keyboard input is given — keyboard always wins and cancels the path.
## The world-space waypoints still to reach (front = next).
var _path: Array[Vector2] = []
## How close (px) to a waypoint counts as "reached".
const WAYPOINT_EPS := 6.0
## Emitted when the player reaches the end of a queued path (touch auto-interact).
signal path_finished

# Screen-space basis vectors for the four iso movement directions.
# For a 2:1 diamond, moving one grid step "north-east" on screen is (+x, -y*0.5).
# We build a normalized diagonal for each cardinal input so movement reads as
# gliding along the diamond axes.
const ISO_UP := Vector2(0, -1)
const ISO_DOWN := Vector2(0, 1)
const ISO_LEFT := Vector2(-1, 0)
const ISO_RIGHT := Vector2(1, 0)


func _ready() -> void:
	# get_node_or_null (not $): every _anim use already null-guards, so a missing
	# sprite child degrades to "no animation" instead of a null-deref in release.
	_anim = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if tilemap_path != NodePath():
		_tilemap = get_node_or_null(tilemap_path) as TileMapLayer
	_update_animation(false)


func _physics_process(_delta: float) -> void:
	# (v0.4.0-B B3.1) While any window (fusion/inventory/codex/character/pause) is open,
	# the player is frozen — no keyboard walk, no queued click/tap path advance. This is
	# the "조합 떠있을때 움직이면 이상하잖아" lock. Guard the singleton for headless safety.
	if GameState != null and GameState.ui_modal_open():
		_path.clear()
		velocity = Vector2.ZERO
		_update_animation(false)
		move_and_slide()
		return

	var input_vec := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	# Keyboard always wins: any key input cancels a queued click/tap path.
	if input_vec != Vector2.ZERO:
		_path.clear()
		_move_screen(input_vec)
		return

	# No keyboard → follow a queued path if any (touch / click-to-move).
	if not _path.is_empty():
		_follow_path()
		return

	velocity = Vector2.ZERO
	_update_animation(false)
	move_and_slide()


## Drive velocity from a cardinal screen-input vector (keyboard).
func _move_screen(input_vec: Vector2) -> void:
	# Transform cardinal input into iso screen space: horizontal keeps full x,
	# vertical is squashed to 0.5 to follow the 2:1 diamond so diagonals feel right.
	var iso_dir := Vector2(input_vec.x, input_vec.y * 0.5).normalized()
	_update_facing(input_vec)
	var current_speed := speed * _speed_mod_at(global_position)
	velocity = iso_dir * current_speed
	move_and_slide()
	_update_animation(true)


## Follow the queued world-space path one waypoint at a time.
func _follow_path() -> void:
	var target: Vector2 = _path[0]
	var to_target := target - global_position
	if to_target.length() <= WAYPOINT_EPS:
		_path.remove_at(0)
		if _path.is_empty():
			velocity = Vector2.ZERO
			_update_animation(false)
			move_and_slide()
			path_finished.emit()
			return
		target = _path[0]
		to_target = target - global_position
	# Facing derives from the screen direction of travel (undo the iso squash).
	_update_facing(Vector2(to_target.x, to_target.y * 2.0))
	var dir := to_target.normalized()
	velocity = dir * speed * _speed_mod_at(global_position)
	move_and_slide()
	_update_animation(true)


## Queue a world-space path (list of waypoints) for the player to walk. Replaces
## any current path. Empty / null clears movement.
func set_path(points: Array[Vector2]) -> void:
	_path = points.duplicate()


## True while the player is walking a queued click/tap path.
func is_pathing() -> bool:
	return not _path.is_empty()


## (v0.3.1 Fix 3) True while the player is in motion — either driving velocity above a
## small epsilon (keyboard) or following a queued path (tap/click). The interaction
## controller hides the tile highlight + E-prompt while this is true so the cursor
## stops jumping around every frame during movement.
const MOVING_EPS := 8.0
func is_moving() -> bool:
	return velocity.length() > MOVING_EPS or not _path.is_empty()


func clear_path() -> void:
	_path.clear()


## Sample speed modifier from the tile under a world position. Non-walkable tiles
## are handled by StaticBody collision, so here we only scale speed (mud etc.).
func _speed_mod_at(world_pos: Vector2) -> float:
	if _tilemap == null:
		return 1.0
	var cell := _tilemap.local_to_map(_tilemap.to_local(world_pos))
	var data := _tilemap.get_cell_tile_data(cell)
	if data == null:
		return 1.0
	var raw: Variant = data.get_custom_data("speed_mod")
	# A tile without the speed_mod layer returns null; treat as full speed.
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return 1.0
	var m: float = float(raw)
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
