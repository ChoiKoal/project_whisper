extends Node
## Presentation-only representative Home nature gate. No travel/input/save/physics changes.
## Inherited Portal remains the state/entry contract; only authored ink is replaced.
var portal: Portal
var _frames: Dictionary={}
var _last_state := ""
func _ready() -> void:
	portal=get_parent() as Portal
	if portal==null: return
	process_priority=100
	portal._gate.texture=load("res://assets/foundation/nature_gate.png")
	portal._gate.position=Vector2(-112,-288)
	portal._rune_glow.texture=load("res://assets/foundation/nature_inlay.png")
	portal._rune_glow.position=portal._gate.position
	portal._sigil.texture=load("res://assets/foundation/nature_crest.png")
	portal._sigil_glow.texture=load("res://assets/foundation/nature_crest_lit.png")
	portal._sigil_y0=-250.0
	portal._veil.position=Vector2(0,-142)
	for state in ["dormant","flicker","open"]:
		_frames[state]=load("res://assets/foundation/nature_veil_%s.png"%state)
	# These authored strokes are straight-alpha pixel ink, never additive soft blooms.
	portal._veil.material=null
	portal._sigil_glow.material=null
	portal._rune_glow.material=null
	_process(0.0)
func _process(_delta: float) -> void:
	if not is_instance_valid(portal): return
	var state:=portal.state()
	if state!=_last_state:
		_last_state=state
		portal._veil.texture=_frames["flicker" if state==GameState.PORTAL_FLICKERING else "open" if state==GameState.PORTAL_OPEN else "dormant"]
	# Keep the aperture inside its physical frame. Continuous rotation/scale would
	# destroy both its pixel lattice and the threshold relationship.
	portal._veil.rotation=0.0
	portal._veil.scale=Vector2.ONE
	portal._veil.self_modulate=Color.WHITE
	portal._veil.modulate=Color.WHITE
	portal._gate.self_modulate=Color.WHITE
	portal._sigil.self_modulate=Color.WHITE
	portal._sigil.position=Vector2(0,-250)
	portal._sigil_glow.position=portal._sigil.position
	# Existing state's lit/not-lit signals remain intact; the authored geometry
	# supplies the difference, rather than expanding a large glow over adjacent doors.
	portal._pool.visible=false
	portal._particles.emitting=false
	portal._swirl.emitting=false
	portal._spark.emitting=false
