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
## Pulsing water-drop affordance icon shown while quest Q4 (물 줘야 됨) is active —
## owner feedback: "물 줘야 된다는 느낌 전혀 안 듦".
const DROP_TEX := "res://assets/objects/water_drop_cue.png"

var _bloomed: bool = false
var _body: StaticBody2D
## Faint periodic shimmer over the dry bush — a readability cue ("뭔가 있다") so the
## player notices the gate object in the corridor gap. Removed once bloomed.
var _cue: GlowSprite
## The bobbing water-drop icon above the bush (visible only during Q4).
var _drop: Sprite2D


func _ready() -> void:
	super._ready()
	object_id = "bush_dry"  # ensure targetable even if not set in scene
	if texture == null:
		texture = load(DRY_TEX)
	offset = Vector2(0, -64)
	_add_block()
	_add_shimmer_cue()
	_add_water_drop_cue()
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


## A bobbing, pulsing water-drop icon floating above the withered bush. It is only
## visible while quest Q4 ("저 마른 것에게 물을") is the active whisper, making the
## "물을 줘야 한다" affordance explicit. Polled cheaply in _process (the quest state is
## a single autoload field). Freed on bloom.
func _add_water_drop_cue() -> void:
	_drop = Sprite2D.new()
	_drop.texture = load(DROP_TEX)
	_drop.offset = Vector2(0, -132)  # float above the bush silhouette
	_drop.z_index = 2
	_drop.visible = false
	add_child(_drop)
	# gentle looping bob + scale pulse
	var tw := _drop.create_tween().set_loops()
	tw.tween_property(_drop, "position:y", -6.0, 0.7).as_relative().set_trans(Tween.TRANS_SINE)
	tw.tween_property(_drop, "position:y", 6.0, 0.7).as_relative().set_trans(Tween.TRANS_SINE)


func _process(_dt: float) -> void:
	if _bloomed or _drop == null:
		return
	# Show the drop only during Q4 (its whisper target is this bush).
	var want := false
	if typeof(QuestManager) != TYPE_NIL and QuestManager != null:
		want = QuestManager.active_id == "Q4"
	if _drop.visible != want:
		_drop.visible = want


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
	# the water-drop affordance has served its purpose.
	if is_instance_valid(_drop):
		_drop.queue_free()
		_drop = null
	# celebratory little pulse
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.15)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2)
