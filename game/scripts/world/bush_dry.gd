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
## A small mystic-glow texture reused as the "something here" shimmer cue.
const CUE_TEX := "res://assets/tiles/t5m_mystic_glow.png"
const QUEST_MARKER := "res://scripts/world/quest_marker.gd"
## Warm glow reused for the "holding water here" affordance.
const WARM_TEX := "res://assets/objects/light_pool_cyan.png"

var _bloomed: bool = false
var _body: StaticBody2D
## Faint periodic shimmer over the dry bush — a readability cue ("뭔가 있다") so the
## player notices the gate object in the corridor gap. Removed once bloomed.
var _cue: GlowSprite
## v0.5b: the Q4 water-drop QuestMarker (bobbing drop + pulse ring, visible during Q4).
var _marker: Node2D
## Warm glow shown when the player hovers with water (I7) held near the bush.
var _warm: Sprite2D


func _ready() -> void:
	super._ready()
	object_id = "bush_dry"  # ensure targetable even if not set in scene
	if texture == null:
		texture = load(DRY_TEX)
	offset = Vector2(0, -64)
	_add_block()
	_add_shimmer_cue()
	_add_quest_marker()
	_add_warm_glow()
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


## A small, faint shimmer positioned over the bush body (offset up to the tangle,
## not the tile floor). Uses the shared GlowSprite mechanism (additive, breathing
## pulse on the CanvasModulate-free glow layer) at a small scale + low alpha so it
## reads as a subtle "something here" sparkle, not a bright halo. Cleared on bloom.
func _add_shimmer_cue() -> void:
	_cue = GlowSprite.new()
	_cue.texture = load(CUE_TEX)
	# small + faint: hug the tangle, hint rather than shout.
	_cue.scale = Vector2(0.5, 0.5)
	_cue.modulate = Color(1.0, 1.0, 1.0, 0.6)  # scales the phase alpha down
	_cue.offset = Vector2(0, -84)  # sit over the bush body (bush offset is -80)
	add_child(_cue)


## v0.5b: the Q4 QuestMarker — a bobbing water-drop icon + a soft periodic pulse ring
## above the withered bush, visible ONLY while quest Q4 ("저 마른 것에게 물을") is the
## active whisper. Makes the "물을 줘야 한다" affordance explicit. Self-hides off-Q4 and
## self-frees once Q4 is complete (handled inside quest_marker.gd).
func _add_quest_marker() -> void:
	var scr := load(QUEST_MARKER)
	if scr == null:
		return
	_marker = Node2D.new()
	_marker.set_script(scr)
	_marker.set("quest_id", "Q4")
	_marker.set("variant", "drop")
	_marker.set("icon_offset", Vector2(0, -132))
	_marker.set("ring_offset", Vector2(0, -70))
	add_child(_marker)


## A warm cyan-violet glow under/around the bush, shown only while the player hovers
## with water (I7) held — reinforces "여기다 물을" the instant before they press E.
## Driven by the InteractionController via set_water_hover().
func _add_warm_glow() -> void:
	_warm = Sprite2D.new()
	_warm.texture = load(WARM_TEX)
	_warm.offset = Vector2(0, -70)
	_warm.z_index = 1
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_warm.material = mat
	_warm.modulate = Color(1.0, 0.92, 0.7, 0.0)  # warm, starts invisible
	add_child(_warm)


## Public (called by InteractionController): the player is hovering this bush with water
## held. Fades the warm glow in/out. No-op after bloom.
func set_water_hover(active: bool) -> void:
	if _bloomed or not is_instance_valid(_warm):
		return
	var target_a := 0.85 if active else 0.0
	var tw := _warm.create_tween()
	tw.tween_property(_warm, "modulate:a", target_a, 0.2)


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
	# the shimmer cue was a "gate here" hint; the bloom is self-evidently done.
	if is_instance_valid(_cue):
		_cue.queue_free()
		_cue = null
	# the water-drop affordance + warm glow have served their purpose.
	if is_instance_valid(_marker):
		_marker.queue_free()
		_marker = null
	if is_instance_valid(_warm):
		_warm.queue_free()
		_warm = null
	# celebratory little pulse
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.15)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2)
