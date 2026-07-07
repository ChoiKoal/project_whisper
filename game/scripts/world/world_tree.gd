extends Gatherable
class_name WorldTree
## G4 — the World Tree (O0). A UNIQUE gatherable: gathering it once grants I9
## (세계수 정수) and the tree stays in the world (Gatherable's unique/_spent
## exception). A separate additive GlowSprite child makes it blaze at night.
##
## Placed once, centered over the O cluster (cols 19~20, rows 2~3). A StaticBody2D
## blocks the trunk so the player gathers from adjacent (OBJECT_REACH).

const TEX := "res://assets/objects/world_tree.png"
const GLOW_TEX := "res://assets/objects/world_tree_glow.png"

## (EG-2) L1 진상 조각 — 세계수의 잎. Investigating the tree (or gathering its 정수) records the
## shard. New text per 설계 §3 (L1/L2 needed new 조각 대사). TruthShard-style card via a lazy modal.
const SHARD_ID := "world_tree"
const SHARD_TITLE := "세계수의 잎"
const SHARD_LOG := "…잎 뒤에 새겨진 글: 나를 심은 이도 '완성하라'는 말을 들었다 한다. 완성하고 떠난 자리에서, 나는 홀로 시들었다. 그러니 너는 — 자꾸 말을 걸어 다오."

var _shard_card: CanvasLayer = null


func _ready() -> void:
	super._ready()
	item_id = "I9"
	unique = true
	object_id = "world_tree"
	if texture == null:
		texture = load(TEX)
	# 512×512 sprite, ground origin at bottom-center: offset up by half height.
	offset = Vector2(0, -240)
	scale = Vector2(0.5, 0.5)  # fit the canopy over the O cluster footprint

	# Glow overlay (additive, night-reactive).
	var glow := GlowSprite.new()
	glow.texture = load(GLOW_TEX)
	glow.offset = offset
	glow.scale = scale
	add_child(glow)

	# Trunk collision.
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([
		Vector2(0, -32), Vector2(64, 0), Vector2(0, 32), Vector2(-64, 0)
	])
	col.shape = shape
	body.add_child(col)
	add_child(body)


func target_point() -> Vector2:
	return global_position


## (EG-2) Gathering the 세계수 정수 ALSO collects the L1 진상 조각 + records its log (the leaf's
## inscription). The player who takes the essence has read the leaf.
func gather() -> String:
	var granted := super.gather()
	if granted != "":
		_collect_shard()
	return granted


## (EG-2) After the tree is 정수-spent, E on it 조사s the leaf: collect the shard + show the card.
## (Before it's spent, E gathers — and gather() collects too — so the shard is reachable either way.)
func on_interact() -> void:
	_collect_shard()
	_show_shard_card()


func _collect_shard() -> void:
	if GameState != null:
		GameState.collect_truth_shard(SHARD_ID)
		# (v1.1.0 GP-4) every investigation announces itself for NPC 회고 quests (부록B #2).
		GameState.truth_shard_investigated.emit(SHARD_ID)
	if Codex != null:
		Codex.record_truth_log(SHARD_ID, SHARD_TITLE, SHARD_LOG)


func _show_shard_card() -> void:
	if _shard_card != null and is_instance_valid(_shard_card):
		return
	var append_final := GameState != null and GameState.truth_final_seen
	_shard_card = TruthShard.build_card(self, SHARD_TITLE, SHARD_LOG, append_final, _close_shard_card)


func _close_shard_card() -> void:
	if _shard_card != null and is_instance_valid(_shard_card):
		_shard_card.queue_free()
	_shard_card = null
	if GameState != null:
		GameState.pop_modal("truth_card")
		GameState.set_control_lock(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if _shard_card == null or not is_instance_valid(_shard_card):
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
		_close_shard_card()
