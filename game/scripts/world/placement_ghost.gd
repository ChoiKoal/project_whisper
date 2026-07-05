extends Node2D
class_name PlacementGhost
## v0.4.0-C — ghost preview for placement mode. While the player holds a placeable
## structure/decor item, a translucent icon of it follows the grid-snapped facing/cursor
## cell, tinted GREEN when the cell is a valid drop and RED when not. Confirm (E / click)
## then drops the real PlacedObject; this node is purely visual.
##
## Driven by the InteractionController: show_ghost(item_id, world_center, valid) each frame
## while a placeable is held and a candidate cell exists; hide_ghost() otherwise.

const VALID_TINT := Color(0.5, 1.0, 0.55, 0.55)
const INVALID_TINT := Color(1.0, 0.42, 0.42, 0.5)
const GHOST_SCALE := 1.7

var _sprite: Sprite2D
var _cur_item: String = ""
var _active: bool = false
var _pulse: float = 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(GHOST_SCALE, GHOST_SCALE)
	_sprite.offset = Vector2(0, -14)
	add_child(_sprite)
	visible = false
	z_index = 6   # above ground/objects so the preview reads clearly


func _process(delta: float) -> void:
	if not _active:
		return
	_pulse += delta * 4.0
	# subtle breathing alpha so the ghost reads as a preview, not a placed object
	var a: float = 0.75 + 0.25 * sin(_pulse)
	_sprite.self_modulate.a = a


## Show the ghost of `item_id` at `world_center`, tinted by validity.
func show_ghost(item_id: String, world_center: Vector2, valid: bool) -> void:
	if item_id != _cur_item:
		_cur_item = item_id
		_sprite.texture = ItemDB.icon(item_id)
	global_position = world_center
	var tint := VALID_TINT if valid else INVALID_TINT
	_sprite.modulate = Color(tint.r, tint.g, tint.b, 1.0)
	_sprite.self_modulate = Color(1, 1, 1, tint.a)
	_active = true
	visible = true


func hide_ghost() -> void:
	if not _active:
		return
	_active = false
	visible = false


func is_active() -> bool:
	return _active
