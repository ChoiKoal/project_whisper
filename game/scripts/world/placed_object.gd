extends Sprite2D
class_name PlacedObject
## v0.4.0-C — a structure/decor object the player has PLACED into the world.
##
## Unlike the functional placeables (디딤돌 / 어린 세계수, which are consumed and change a
## TILE), a PlacedObject is a persistent node the player builds and can later RECALL
## (non-destructive: the item returns to the inventory). Structures with blocks=true get a
## StaticBody2D collider; glowing decor (등불꽃 D48 / 연꽃 D41) get a GlowSprite that ramps
## up at night. Placed objects:
##   - live in the YSortLayer so they sort with the player,
##   - self-register into the "placed_object" group so SaveManager can serialize them and
##     the respawn system can IGNORE them (they are never gathered/respawned),
##   - render using the item's existing icon texture (deterministic, already-imported art),
##     scaled up for world presence.
##
## Recall: the InteractionController duck-types this like a Gatherable target — it exposes
## target_point() and on_interact() (recall). It is NOT gatherable (no can_gather), so the
## E-prompt reads "회수" and gathering logic skips it.

const GROUP := "placed_object"
## World scale applied to the 48px icon so a placed object reads at tile scale.
const WORLD_SCALE := 1.7
## Trunk/base collision radius for blocking structures.
const BLOCK_RADIUS := 22.0

## The item id this object was placed from (returned on recall).
var item_id: String = ""
## Placement class ("structure" | "decor").
var pclass: String = ""
## Whether this object blocks movement (structures with blocks=true).
var blocks: bool = false
## Whether this object glows at night.
var glows: bool = false
## Cell it occupies (for save/recall bookkeeping).
var cell: Vector2i = Vector2i.ZERO

var _body: StaticBody2D = null
var _glow: Node2D = null


## Configure and build the object. Call right after instancing, before adding a collider is
## needed — but _ready() also (re)builds so it's safe either way.
func setup(p_item_id: String, p_cell: Vector2i) -> void:
	item_id = p_item_id
	cell = p_cell
	pclass = ItemDB.placement_class(item_id)
	blocks = ItemDB.placement_blocks(item_id)
	glows = ItemDB.placement_glows(item_id)


func _ready() -> void:
	add_to_group(GROUP)
	if item_id != "" and pclass == "":
		# setup() wasn't called (e.g. save-restore sets fields directly) — derive.
		pclass = ItemDB.placement_class(item_id)
		blocks = ItemDB.placement_blocks(item_id)
		glows = ItemDB.placement_glows(item_id)
	texture = ItemDB.icon(item_id)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2(WORLD_SCALE, WORLD_SCALE)
	# Lift the sprite so its base sits on the tile centre (icons are centred squares).
	offset = Vector2(0, -14)
	y_sort_enabled = true
	if blocks and _body == null:
		_add_block_collision()
	if glows and _glow == null:
		_add_glow()
	_play_spawn_pop()


## Squash-and-scale-in spawn (juice). Guarded so a headless restore doesn't error.
func _play_spawn_pop() -> void:
	var final_scale := Vector2(WORLD_SCALE, WORLD_SCALE)
	scale = Vector2(WORLD_SCALE * 1.25, WORLD_SCALE * 0.7)
	var tw := create_tween()
	tw.tween_property(self, "scale", final_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _add_block_collision() -> void:
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = BLOCK_RADIUS
	col.shape = shape
	_body.add_child(col)
	add_child(_body)


## A GlowSprite child (reused night-glow additive overlay) so 등불꽃/연꽃 light up at night.
func _add_glow() -> void:
	var GlowScript := load("res://scripts/world/glow_sprite.gd")
	if GlowScript == null:
		return
	_glow = Node2D.new()
	_glow.set_script(GlowScript)
	add_child(_glow)


## Interaction target point (base of the object).
func target_point() -> Vector2:
	return global_position


## Recall: return the item to the inventory and free this object. Non-destructive.
## Returns true if the item was returned.
func recall() -> bool:
	Inventory.add(item_id, 1)
	if GameState != null:
		GameState.placed_object_recalled.emit(item_id, cell)
	queue_free()
	return true


## InteractionController duck-typing: E on a placed object recalls it.
func on_interact() -> void:
	recall()


## Serialize for the save file.
func to_dict() -> Dictionary:
	return {"item_id": item_id, "cell": [cell.x, cell.y]}
