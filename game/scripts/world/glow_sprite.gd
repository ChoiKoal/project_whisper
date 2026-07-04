extends Sprite2D
class_name GlowSprite
## Additive violet glow overlay for the world tree / mystic water / night bloom.
## Kept in a separate CanvasLayer (or with additive material) so the day/night
## CanvasModulate does not dim it — at night the base darkens and the glow pops.
##
## Intensity ramps with the day/night phase: faint by day, strong at night.
## Driven by GameState.day_phase_changed (no per-frame polling).

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
	if GameState.day_phase_changed.connect(_on_phase) == OK:
		pass
	_apply_phase(GameState.phase())


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
