extends Node
## Runtime adapter for Kana's immutable WH-HARVEST-001 pure module.
## Owns no input/time leases; interruptions never release another system's lock.
const STATE = preload("res://scripts/gameplay/harvest_action_state.gd")
const CONTACT_SECONDS := {"flora":0.09,"rock":0.14,"wood":0.16}
var state = STATE.new()
var target: Gatherable
var token := 0
var elapsed := 0.0
var kind := ""
var _owner: InteractionController
var _original_offset := Vector2.ZERO
var _actor_offset := Vector2.ZERO
var _actor: AnimatedSprite2D
var _direction := Vector2.ZERO
var _tap_reach := false

func _ready() -> void:
	_owner=get_parent() as InteractionController
	set_physics_process(false)
	GameState.ui_modal_changed.connect(_on_lock_edge)
	GameState.control_lock_changed.connect(_on_lock_edge)
	GameState.time_requested_changed.connect(_on_lock_edge)

func _on_lock_edge(_value: bool) -> void:
	cancel()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		cancel()
	for action in Player.MOVE_ACTIONS:
		if event.is_action_pressed(action): cancel()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		cancel()

func _available(node: Gatherable, tap_reach: bool) -> bool:
	if not is_instance_valid(_owner) or not is_instance_valid(_owner._player) or not is_instance_valid(_owner._tilemap): return false
	if GameState.ui_modal_open() or GameState.control_locked() or not GameState.time_running: return false
	if not _owner._tilemap.get_parent().is_ancestor_of(node): return false
	# Existing E uses cell adjacency; existing tap uses logical 150px reach.
	# Preserve both contracts rather than rejecting a tap already accepted by Touch.
	if tap_reach:
		if _owner._player.global_position.distance_to(node.target_point())>TouchController.ADJACENT_REACH:return false
	elif not _owner._cell_adjacent(_owner._object_cell(node),_owner._player_cell()): return false
	if _owner._player.is_pathing(): return false
	for action in Player.MOVE_ACTIONS:
		if Input.is_action_pressed(action): return false
	return true

static func material_for(item: String) -> String:
	match item:
		"I4": return "wood"
		"I6", "I8": return "rock"
		_: return "flora" # Gentle pickup fallback: soil/water/essence/other worlds.

func begin(node: Gatherable, tap_reach: bool = false) -> bool:
	if not is_instance_valid(node) or not node.can_gather(): return false
	if not _available(node,tap_reach): return false
	if node==target: return false
	cancel()
	kind=material_for(node.item_id)
	# Instance identity changes on each respawn. Include world + semantic position;
	# no stale action can bind to a replacement at the same saved cell.
	var key: String="%s:%s:%s:%d" % [node.get_parent().get_path(),node.item_id,node.target_point(),node.get_instance_id()]
	var result: Dictionary=state.begin(key,kind)
	if not result.ok: return false
	if not node.reserve_harvest(get_instance_id()):
		state.cancel(result.token)
		return false
	target=node; token=result.token; elapsed=0.0
	_tap_reach=tap_reach
	_original_offset=node.offset
	_direction=(_owner._player.global_position-node.target_point()).normalized()
	_actor=_owner._player._anim
	if is_instance_valid(_actor): _actor_offset=_actor.offset
	_owner._player._update_facing(-_direction*Vector2(1,2))
	set_physics_process(true)
	return true

func cancel() -> void:
	_restore_pose()
	if is_instance_valid(target): target.release_harvest(get_instance_id())
	state.reset("interrupted")
	target=null; token=0
	set_physics_process(false)

func _restore_pose() -> void:
	if is_instance_valid(target): target.offset=_original_offset
	if is_instance_valid(_actor): _actor.offset=_actor_offset
	_actor=null

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree() or not target.can_gather():
		cancel()
		return
	if not _available(target,_tap_reach):
		cancel()
		return
	elapsed+=delta
	var progress:=minf(elapsed/float(CONTACT_SECONDS[kind]),1.0)
	# Quantized ink-only anticipation; collision roots and save anchors never move.
	target.offset=_original_offset+(_direction*progress*(3.0 if kind=="flora" else -2.0)).round()
	if is_instance_valid(_actor): _actor.offset=_actor_offset+(-_direction*progress*3.0).round()
	if elapsed < float(CONTACT_SECONDS[kind]): return
	var node:=target
	var point:=_owner._object_visual_point(node)
	_restore_pose()
	if not state.reach_contact(token).ok: cancel(); return
	var committed: Dictionary=state.take_commit(token)
	if not committed.get("granted",false): cancel(); return
	# Module latch is already final. Gatherable sets its own spent guard before
	# Inventory.add; no animation callback ever owns a reward.
	var finished_token:=token
	var finished_kind:=kind
	node.release_harvest(get_instance_id())
	var item:=node.gather()
	# Synchronous inventory/quest listeners may already have begun another action.
	# Cleanup is conditional on ownership of the captured token.
	if token == finished_token:
		state.finish(finished_token)
		target=null; token=0
		set_physics_process(false)
	if item!="" and is_inside_tree() and is_instance_valid(node):
		_owner._spawn_feedback(point,item,node.last_granted_amount)
		if node.last_granted_amount>0 and node.is_inside_tree():
			var response:=preload("res://scripts/gameplay/harvest_response.gd").new()
			node.get_parent().add_child(response)
			var player_point:=_owner._player.global_position
			if _owner._tilemap is MapLoader:
				player_point.y+=_owner._tilemap.visual_height_offset(player_point)
			response.setup(node,finished_kind,player_point)

func _exit_tree() -> void:
	cancel()
