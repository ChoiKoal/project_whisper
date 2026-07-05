extends Node2D
class_name QuestMarker
## v0.5b — QuestMarker: a subtle bobbing marker over the ACTIVE quest's target so the
## player knows where to go / what to act on (owner: "물을 줘야 된다는 느낌이 전혀 안 듦").
##
## Generic: an active quest's target object/area gets a small violet whisper-wisp that
## bobs gently + a soft periodic pulse ring. Q4 overrides the icon with a water-drop
## (물 줘야 함). The marker is visible ONLY while its `quest_id` is the active whisper,
## polled cheaply from the QuestManager autoload (a single field), and it self-frees
## once its quest has been completed so it never lingers.
##
## Add it as a child of the object it marks (Y-sorts with it) or free-standing at a
## world position for an AREA target (Q6 world-tree / night-path entrance).

## The wisp icon (small violet mystic glow) and the Q4 water-drop variant.
const WISP_TEX := "res://assets/tiles/t5m_mystic_glow.png"
const DROP_TEX := "res://assets/objects/water_drop_cue.png"

## Which quest activates this marker (e.g. "Q4", "Q6").
@export var quest_id: String = ""
## "wisp" (default violet whisper) or "drop" (Q4 water-drop variant).
@export var variant: String = "wisp"
## Pixel offset of the bobbing icon above the target anchor.
@export var icon_offset: Vector2 = Vector2(0, -132)
## Pixel offset of the pulse ring (sits lower, at the target's base).
@export var ring_offset: Vector2 = Vector2(0, -20)

var _icon: Sprite2D
var _ring: Sprite2D
var _t: float = 0.0
var _shown: bool = false
## Latches true once we've seen this quest active, so we can self-free after it passes.
var _seen_active: bool = false


func _ready() -> void:
	z_index = 6
	_icon = Sprite2D.new()
	_icon.texture = load(DROP_TEX if variant == "drop" else WISP_TEX)
	_icon.position = icon_offset
	_icon.z_index = 2
	if variant == "wisp":
		# tint the mystic glow toward a soft violet wisp + additive so it reads as light.
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_icon.material = mat
		_icon.modulate = Color(0.72, 0.55, 1.0, 0.9)
		_icon.scale = Vector2(0.7, 0.7)
	add_child(_icon)

	# soft pulse ring (reuse the mystic glow as a ring-ish soft disc that scales out).
	_ring = Sprite2D.new()
	_ring.texture = load(WISP_TEX)
	_ring.position = ring_offset
	var rmat := CanvasItemMaterial.new()
	rmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_ring.material = rmat
	_ring.modulate = Color(0.6, 0.45, 0.95, 0.0)
	add_child(_ring)

	_set_shown(false)


func _process(dt: float) -> void:
	var active := false
	if typeof(QuestManager) != TYPE_NIL and QuestManager != null:
		active = QuestManager.active_id == quest_id
	if active:
		_seen_active = true
	elif _seen_active:
		# our quest is done (advanced past) — remove the marker for good.
		queue_free()
		return

	if active != _shown:
		_set_shown(active)
	if not active:
		return

	_t += dt
	# gentle vertical bob of the icon.
	_icon.position = icon_offset + Vector2(0, sin(_t * 2.2) * 6.0)
	# periodic pulse ring: expand + fade on a ~1.6s cycle.
	var cyc := fmod(_t, 1.6) / 1.6
	_ring.scale = Vector2.ONE * (0.5 + cyc * 1.3)
	_ring.modulate.a = (1.0 - cyc) * 0.5


func _set_shown(v: bool) -> void:
	_shown = v
	visible = v
