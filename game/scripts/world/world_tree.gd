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
