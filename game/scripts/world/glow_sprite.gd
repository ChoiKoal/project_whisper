extends Sprite2D
class_name GlowSprite
## Additive violet glow overlay for the world tree / mystic water / night bloom.
## Rendered on a SEPARATE CanvasLayer (the "glow_layer" group node, layer 1,
## follow_viewport_enabled) so the day/night CanvasModulate — which only tints its
## own canvas layer — does NOT dim it. At night the base darkens and the glow pops.
## If no glow layer exists (e.g. test_map), it stays under its spawner; the additive
## material still reads as light, just tint-affected (acceptable there).
##
## Intensity ramps with the day/night phase: faint by day, strong at night.
## Driven by GameState.day_phase_changed (no per-frame polling).

## Group name of the CanvasLayer that hosts glow sprites, unaffected by CanvasModulate.
const GLOW_LAYER_GROUP := "glow_layer"

## Alpha at each phase.
const DAY_ALPHA := 0.15
const EVENING_ALPHA := 0.45
const NIGHT_ALPHA := 1.0
const DAWN_ALPHA := 0.55

## Extra pulse so the glow breathes.
const PULSE_SPEED := 1.5
const PULSE_AMP := 0.12

var _base_alpha: float = DAY_ALPHA
var _t: float = 0.0


func _ready() -> void:
	# Additive blend so it reads as light, not paint.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_index = 5
	# GameState is an autoload singleton; guard anyway so a missing/renamed
	# singleton logs a warning instead of NULL-dereferencing during ready
	# propagation (release templates strip the null-check path → SIGSEGV).
	if GameState == null:
		push_warning("GlowSprite: GameState singleton missing; glow disabled")
		return
	GameState.day_phase_changed.connect(_on_phase)
	_apply_phase(GameState.phase())
	# Move onto the CanvasModulate-free glow layer once the spawner has finished
	# positioning us (offset/scale are set by the parent AFTER our _ready runs).
	call_deferred("_reparent_to_glow_layer")


## Reparent onto the dedicated glow CanvasLayer (unaffected by the day/night
## CanvasModulate), preserving world position. No-op if there is no glow layer.
func _reparent_to_glow_layer() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var layer := tree.get_first_node_in_group(GLOW_LAYER_GROUP)
	# get_first_node_in_group may legitimately return null (test_map has no glow
	# layer). Only reparent onto a real, still-valid, different parent node. The
	# is_instance_valid guard matters in RELEASE: this runs deferred, so between the
	# _ready that queued it and now the spawner (and its whole scene) may have been
	# freed by a portal scene-change — reparent onto a freed layer would SIGSEGV.
	if layer == null or not is_instance_valid(layer) or layer == get_parent():
		return
	reparent(layer, true)  # keep_global_transform → glow stays over its object


func _process(delta: float) -> void:
	_t += delta * PULSE_SPEED
	var pulse := 1.0 + sin(_t) * PULSE_AMP
	modulate.a = clampf(_base_alpha * pulse, 0.0, 1.0)


func _on_phase(phase: String) -> void:
	_apply_phase(phase)


func _apply_phase(phase: String) -> void:
	match phase:
		"day": _base_alpha = DAY_ALPHA
		"evening": _base_alpha = EVENING_ALPHA
		"night": _base_alpha = NIGHT_ALPHA
		"dawn": _base_alpha = DAWN_ALPHA
		_: _base_alpha = DAY_ALPHA
