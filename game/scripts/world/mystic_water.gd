extends Gatherable
class_name MysticWater
## Mystic water (m, behind the World Tree, rows 0~1). A gatherable that yields I7
## (물) — the 생명수 chain's water source at the world-tree map. Unlike the pond,
## these tiles glow violet (GlowSprite child). NOT unique — respawns like normal
## gatherables. The `m` tile beneath is non-walkable water; the player gathers
## from the adjacent grass (OBJECT_REACH), so no extra collision needed (the tile
## already carries a physics polygon).

const GLOW_TEX := "res://assets/tiles/t5m_mystic_glow.png"


func _ready() -> void:
	super._ready()
	item_id = "I7"
	object_id = "mystic_water"
	# The mystic tile art itself renders the water; this node draws no sprite of
	# its own (null texture), only the additive glow child.
	texture = null

	var glow := GlowSprite.new()
	glow.texture = load(GLOW_TEX)
	add_child(glow)


func target_point() -> Vector2:
	return global_position
