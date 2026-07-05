extends Gatherable
class_name BushDry
## G2 gate — the dry bush that blocks the single hill corridor (cell 18,16).
## It is a use-only Gatherable (object_id="bush_dry", no item_id) so the M2
## use-framework can target it. When I7 water is used on it
## (GameState.item_used_on_object), it blooms: swaps to the bloomed sprite,
## drops its collision, and the corridor opens.
##
## Collision: a StaticBody2D child physically blocks the corridor cell until
## bloom. bloomed() also toggles a logical flag the harness reads.

const DRY_TEX := "res://assets/objects/bush_dry.png"
const BLOOM_TEX := "res://assets/objects/bush_bloom.png"

var _bloomed: bool = false
var _body: StaticBody2D


func _ready() -> void:
	super._ready()
	object_id = "bush_dry"  # ensure targetable even if not set in scene
	if texture == null:
		texture = load(DRY_TEX)
	offset = Vector2(0, -80)
	_add_block()
	# Defensive autoload guard (ready-time; matches night_gate/glow_sprite). A
	# missing GameState would null-deref .item_used_on_object during the flush.
	if GameState == null:
		push_warning("BushDry: GameState singleton missing; bloom signal unwired")
		return
	GameState.item_used_on_object.connect(_on_used)


func _add_block() -> void:
	_body = StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	# iso-diamond footprint so the player can't slip past the corridor
	shape.points = PackedVector2Array([
		Vector2(0, -32), Vector2(64, 0), Vector2(0, 32), Vector2(-64, 0)
	])
	col.shape = shape
	_body.add_child(col)
	add_child(_body)


func is_bloomed() -> bool:
	return _bloomed


## A dry bush is not gatherable — it is use-only.
func can_gather() -> bool:
	return false


func _on_used(item_id: String, object: Node) -> void:
	if object != self:
		return
	if item_id != "I7":
		return
	bloom()


## Bloom: swap art, drop collision, open the corridor.
func bloom() -> void:
	if _bloomed:
		return
	_bloomed = true
	texture = load(BLOOM_TEX)
	if is_instance_valid(_body):
		_body.queue_free()
		_body = null
	# celebratory little pulse
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.15)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2)
