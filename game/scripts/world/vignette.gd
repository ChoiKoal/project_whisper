extends CanvasLayer
class_name Vignette
## v0.3.1 tone pass §5 — a subtle screen vignette: soft dark corners at ~15% peak
## strength that frame the diorama and pull the eye toward the center.
##
## Implemented as a full-rect ColorRect driven by a tiny fragment shader (radial
## falloff), on its own CanvasLayer above the world but below the UI windows so it
## never darkens panel text. Mouse-transparent; purely decorative. Follows the screen
## (anchored full-rect), independent of the world camera.

## Peak corner darkness (0..1). ~0.15 = a gentle frame, not a heavy tunnel.
const STRENGTH := 0.15
## Where the darkening starts (0 = center, 1 = corner). Higher = only the very corners.
const INNER := 0.55

var _rect: ColorRect


func _ready() -> void:
	layer = 1  # above the world/glow, below UI windows (layer 2) and pause (9)
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(0, 0, 0, 1)

	var shader := Shader.new()
	shader.code = _SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("strength", STRENGTH)
	mat.set_shader_parameter("inner", INNER)
	_rect.material = mat
	add_child(_rect)


## Radial vignette: alpha ramps from 0 at the center to `strength` at the corners,
## smoothstepped between `inner` and 1.0 of the normalized center distance.
const _SHADER := """
shader_type canvas_item;
uniform float strength = 0.15;
uniform float inner = 0.55;
void fragment() {
	vec2 d = UV - vec2(0.5);
	// Normalize so the corner (0.707 in UV) maps to ~1.0.
	float dist = length(d) / 0.7071;
	float a = smoothstep(inner, 1.0, dist) * strength;
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
"""
