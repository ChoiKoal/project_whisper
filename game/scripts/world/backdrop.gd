extends CanvasLayer
class_name Backdrop
## v0.3.0 A2 — atmospheric void-sky backdrop, drawn BEHIND everything.
##
## A screen-fixed CanvasLayer at layer -1 (below the root canvas, so the day/night
## CanvasModulate — which tints the root canvas — never touches it and the map's
## floating-island slab reads against a deep void sky like the reference dioramas).
##
## Content (all deterministic, cheap), painted by the BackdropCanvas child:
##   - a deep navy-violet vertical gradient (#12121c top → #1e1a2e bottom),
##   - sparse tiny stars / dust specks (fixed seed → same sky every run),
##   - a few very subtle drifting motes (slow horizontal drift, wrap-around).
##
## follow_viewport is DISABLED so the sky is fixed to the screen, not the world.

const CANVAS_SCRIPT := "res://scripts/world/backdrop_canvas.gd"

## (v0.5d) Home-island void mood: denser starfield + one large soft violet nebula glow patch
## behind the island. Off (grove) → the original sparse sky, unchanged.
@export var home_mood: bool = false
## (L2-2) Layer-2 「꺼진 관문 기지」 void mood: colder blue starfield + a cyan-tinted nebula, so
## the science station floats in a colder void than the violet home island. Mutually exclusive
## with home_mood (l2 wins if both set).
@export var l2_mood: bool = false

var _canvas: Control


func _ready() -> void:
	layer = -1
	follow_viewport_enabled = false
	_canvas = Control.new()
	_canvas.name = "BackdropCanvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scr := load(CANVAS_SCRIPT)
	if scr != null:
		_canvas.set_script(scr)
	add_child(_canvas)
	if l2_mood and _canvas.has_method("set_l2_mood"):
		_canvas.call("set_l2_mood", true)
	elif home_mood and _canvas.has_method("set_home_mood"):
		_canvas.call("set_home_mood", true)
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
