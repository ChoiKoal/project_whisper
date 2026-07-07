extends CharacterBody2D
class_name Player
## 8-directional isometric player (AP-3; extended from the original 4-dir, backward
## compatible).
## Movement is mapped to iso screen axes: the input vector is transformed so that
## pressing "up" moves toward screen-up-along-the-iso-grid, giving the diagonal
## screen motion that matches a 2:1 diamond grid.
##
## Facing is one of eight compass headings. The four GRID-diagonal headings
## (SE/SW/NE/NW) are produced by single-axis input exactly as the legacy 4-dir code
## did, so the interaction system (facing_cell_step) is unchanged for them. The four
## SCREEN-cardinal headings (S/E/N/W) are the new diagonal-input poses.
##
## Tile-driven speed/collision: instead of hardcoding tile ids, we sample the
## TileMapLayer's custom data (`walkable`, `speed_mod`) under the target position.

@export var speed: float = 300.0
@export var tilemap_path: NodePath

var _tilemap: TileMapLayer
var _facing: String = "SE"  # one of: N NE E SE S SW W NW
var _anim: AnimatedSprite2D

## Screen-space heading (degrees, atan2(y,x) with +x=right, +y=down) at the CENTRE
## of each facing's 45°-wide sector. The four grid-diagonal facings land on the four
## screen cardinals (SE=right, SW=down, NW=left, NE=up) — identical to the legacy
## 4-dir mapping — and the four screen-cardinal facings fill the 45° diagonals
## between them. _update_facing snaps the input/travel vector to the nearest entry.
const FACING_ANGLES := {
	"SE": 0.0,     # screen →  (input +x)      [legacy]
	"S": 45.0,     # screen ↘  (input +x +y)
	"SW": 90.0,    # screen ↓  (input +y)      [legacy]
	"W": 135.0,    # screen ↙  (input -x +y)
	"NW": 180.0,   # screen ←  (input -x)      [legacy]
	"N": -135.0,   # screen ↖  (input -x -y)
	"NE": -90.0,   # screen ↑  (input -y)      [legacy]
	"E": -45.0,    # screen ↗  (input +x -y)
}

## (v0.4.0-C) Footstep SFX cadence. Accumulates while moving; every FOOTSTEP_INTERVAL of
## movement plays an alternating grass footstep through AudioManager.
const FOOTSTEP_INTERVAL := 0.34
var _footstep_t := 0.0
var _footstep_toggle := false

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

## (v0.5.1 BUG2) The four movement actions, released together on every control lock/unlock,
## on scene teardown, and on window-focus-loss so a swallowed key-RELEASE can never leave the
## player auto-walking (the owner's "계속 위로 가는 키가 눌려있음"). Physics reads actions fresh
## each frame (below) so a clean release stops motion immediately.
const MOVE_ACTIONS := ["move_up", "move_down", "move_left", "move_right"]


func _ready() -> void:
	# get_node_or_null (not $): every _anim use already null-guards, so a missing
	# sprite child degrades to "no animation" instead of a null-deref in release.
	_anim = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if tilemap_path != NodePath():
		_tilemap = get_node_or_null(tilemap_path) as TileMapLayer
	_update_animation(false)
	# (v0.5.1 BUG2c) React to the modal input-lock toggling: on BOTH lock and unlock, force-
	# release the move actions + clear any queued path so no held/queued input survives the
	# lock boundary. Guarded for headless safety.
	if GameState != null and GameState.has_signal("ui_modal_changed"):
		GameState.ui_modal_changed.connect(func(_open): release_move_and_path())
	# (v0.5.1 BUG2a) Cutscene control-lock toggling: release on BOTH lock and unlock edges.
	if GameState != null and GameState.has_signal("control_lock_changed"):
		GameState.control_lock_changed.connect(func(_locked): release_move_and_path())


## (v0.5.1 BUG2) Release all four move actions in the Input singleton. Call on every control
## lock AND unlock. `_physics_process` reads the actions fresh each frame, so this immediately
## stops keyboard-driven motion; a stuck (swallowed-release) key no longer reads as pressed.
func release_move_actions() -> void:
	for a in MOVE_ACTIONS:
		if InputMap.has_action(a):
			Input.action_release(a)


## Release move actions AND clear any queued tap/click path — the full "stop everything" used
## on lock/unlock, focus-loss, cutscene start, and scene teardown.
func release_move_and_path() -> void:
	release_move_actions()
	_path.clear()
	velocity = Vector2.ZERO


## (v0.5.1 BUG2c) macOS cmd-tab / any window focus loss drops key-up events, leaving move
## actions stuck "pressed" when focus returns → the player auto-walks. On focus-out release
## every move action + clear the path. On focus-IN release again (defensive: some platforms
## deliver a stale repeat on return).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_move_and_path()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		release_move_actions()
	elif what == NOTIFICATION_EXIT_TREE:
		# Scene change / teardown: never carry a queued path or a held key into the next scene.
		release_move_and_path()


## (v0.6.1) True while the world is frozen for the player: any modal window open, OR a cutscene
## running (time_running=false — clear/purification/travel swell), OR control locked (CS-05
## ignition). Mirrors TouchController._world_locked() so keyboard-walk and tap-path freeze on the
## exact same conditions. GameState-null-safe for headless.
func is_world_frozen() -> bool:
	return GameState != null and (GameState.ui_modal_open() \
			or not GameState.time_running or GameState.control_locked())


func _physics_process(_delta: float) -> void:
	# (v0.4.0-B B3.1) While any window (fusion/inventory/codex/character/pause) is open,
	# the player is frozen — no keyboard walk, no queued click/tap path advance. This is
	# the "조합 떠있을때 움직이면 이상하잖아" lock. Guard the singleton for headless safety.
	# (v0.6.1) ALSO freeze during cutscenes: L1 clear_sequence and L2 정화 컷신 pause via
	# time_running=false, and CS-04/05 use control_lock. TouchController already blocks queued
	# paths on both, but keyboard-walk read fresh each frame here did NOT — so holding a move
	# key during a cutscene let the player walk through it. Gate on the same conditions
	# TouchController._world_locked() uses so keyboard + touch freeze identically. Factored into
	# is_world_frozen() so the sweep harness can assert the exact predicate.
	if is_world_frozen():
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
	# Snap the screen-space input/travel vector to the nearest of the eight facings
	# by angle. A zero vector leaves the current facing unchanged (idle keeps its pose).
	if input_vec == Vector2.ZERO:
		return
	var ang := rad_to_deg(atan2(input_vec.y, input_vec.x))
	var best := _facing
	var best_diff := 999.0
	for name in FACING_ANGLES:
		var d: float = abs(wrapf(ang - FACING_ANGLES[name], -180.0, 180.0))
		if d < best_diff:
			best_diff = d
			best = name
	_facing = best


## Current cardinal facing string (SE/SW/NE/NW), read by the interaction system.
func get_facing() -> String:
	return _facing


## Grid-space step for the current facing, used to find the facing-adjacent cell.
## The four grid-diagonal facings map to single-axis grid neighbours exactly as the
## legacy 4-dir code did (SE=+x, NW=-x, SW=+y, NE=-y — screen right/left/down/up).
## The four screen-cardinal facings map to the grid diagonals between them, so an
## E-facing / interaction still resolves the cell the wanderer is looking at.
func facing_cell_step() -> Vector2i:
	match _facing:
		"SE": return Vector2i(1, 0)
		"NW": return Vector2i(-1, 0)
		"SW": return Vector2i(0, 1)
		"NE": return Vector2i(0, -1)
		"S": return Vector2i(1, 1)
		"W": return Vector2i(-1, 1)
		"N": return Vector2i(-1, -1)
		"E": return Vector2i(1, -1)
	return Vector2i(1, 0)


func _update_animation(moving: bool) -> void:
	_tick_footsteps(moving)
	if _anim == null:
		return
	var state := "walk" if moving else "idle"
	var anim_name := "%s_%s" % [state, _facing]
	if _anim.sprite_frames != null and _anim.sprite_frames.has_animation(anim_name):
		if _anim.animation != anim_name or not _anim.is_playing():
			_anim.play(anim_name)


## (v0.4.0-C) Play a footstep SFX at a walking cadence while moving. Resets when stopped so
## the first step after standing still lands promptly. Guards a missing AudioManager (headless).
func _tick_footsteps(moving: bool) -> void:
	if not moving:
		_footstep_t = FOOTSTEP_INTERVAL   # arm an immediate step on next move
		return
	_footstep_t += get_physics_process_delta_time()
	if _footstep_t >= FOOTSTEP_INTERVAL:
		_footstep_t = 0.0
		_footstep_toggle = not _footstep_toggle
		if AudioManager != null:
			AudioManager.play_sfx("footstep_grass2" if _footstep_toggle else "footstep_grass1")
