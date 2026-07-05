extends Sprite2D
class_name LightPool
## v0.3.0 — a soft additive radial light-pool decal laid under/around a light
## source (cauldron, world tree, mystic water, open night bud). Reads like the
## reference dioramas' local light: a low-alpha violet/cyan glow pooling on the
## ground beneath the object.
##
## Like GlowSprite, it renders on the dedicated "glow_layer" CanvasLayer (additive,
## follow_viewport), so the day/night CanvasModulate — which only tints its OWN
## canvas layer — does NOT dim it, and the pool blooms at night. Intensity ramps
## with the day/night phase (faint by day, strong at night), same as GlowSprite so
## the whole scene's local light reads consistently.
##
## The texture is one of the pre-generated radial-gradient PNGs
## (assets/objects/light_pool_*.png). Peak alpha is scaled per-phase; a very gentle
## breathe keeps it alive.

const GLOW_LAYER_GROUP := "glow_layer"

## Per-phase alpha ceilings (pools are meant to be subtle underlight, so a touch
## lower than GlowSprite's object-glow so they never wash out the object above).
const DAY_ALPHA := 0.10
const EVENING_ALPHA := 0.40
const NIGHT_ALPHA := 0.85
const DAWN_ALPHA := 0.48

const PULSE_SPEED := 1.1
const PULSE_AMP := 0.10

var _base_alpha: float = DAY_ALPHA
var _t: float = 0.0
## Multiplier applied on top of the phase alpha (lets callers dim/brighten a pool
## and lets an open-only pool be forced dark when its object is closed).
var strength: float = 1.0
## When true (night buds), the pool only lights during the night window.
var night_only: bool = false


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	# Below the object glow (GlowSprite z=5) so it reads as ground light, not a halo.
	z_index = 3
	if GameState == null:
		push_warning("LightPool: GameState singleton missing; pool disabled")
		return
	GameState.day_phase_changed.connect(_on_phase)
	_apply_phase(GameState.phase())
	call_deferred("_reparent_to_glow_layer")


func _reparent_to_glow_layer() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var layer := tree.get_first_node_in_group(GLOW_LAYER_GROUP)
	if layer == null or layer == get_parent():
		return
	reparent(layer, true)


func _process(delta: float) -> void:
	_t += delta * PULSE_SPEED
	var pulse := 1.0 + sin(_t) * PULSE_AMP
	modulate.a = clampf(_base_alpha * pulse * strength, 0.0, 1.0)


func _on_phase(phase: String) -> void:
	_apply_phase(phase)


func _apply_phase(phase: String) -> void:
	if night_only and phase == "day":
		_base_alpha = 0.0
		return
	match phase:
		"day": _base_alpha = DAY_ALPHA
		"evening": _base_alpha = EVENING_ALPHA
		"night": _base_alpha = NIGHT_ALPHA
		"dawn": _base_alpha = DAWN_ALPHA
		_: _base_alpha = DAY_ALPHA
