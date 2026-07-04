extends Node2D
class_name NightGateGuard
## Shows the G3 flavor message when the player approaches a CLOSED night gate by
## day. Polls player distance to nodes in the `night_gate` group (there are only
## two), throttled by each gate's own message cooldown. Keeps the message out of
## the collision/physics path so it works regardless of how the wall is felt.

const TRIGGER_DIST := 180.0

@export var player_path: NodePath
@export var feedback_layer_path: NodePath

var _player: Node2D
var _feedback: Node


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	_feedback = get_node_or_null(feedback_layer_path)
	if _feedback == null:
		_feedback = self


func _process(_delta: float) -> void:
	if _player == null:
		return
	for g in get_tree().get_nodes_in_group("night_gate"):
		var gate := g as NightGate
		if gate == null or gate.is_open():
			continue
		if gate.global_position.distance_to(_player.global_position) <= TRIGGER_DIST:
			gate.show_flavor(_feedback)
			return
