extends Sprite2D
class_name Cauldron
## 솥단지 — the fusion cauldron world object (M3).
##
## Placed on the map near the pond. It registers into the `gatherable` group so
## the existing InteractionController targets/highlights it, but it is neither
## gatherable nor use-target: instead, interacting with it emits `interacted`,
## which the Fusion UI listens to in order to open.
##
## Interaction hook: the controller, after finding no gather/use action, calls
## `on_interact()` on a targeted object if it has that method (duck-typed). This
## keeps M2's controller mostly untouched.

const GROUP := "gatherable"

## Stable id (parity with Gatherable.object_id for targeting/debug).
@export var object_id: String = "cauldron"

## Emitted when the player interacts with the cauldron.
signal interacted

## v0.2.1: subtle bubbling — alternate between two brew-surface frames on a slow
## timer + a faint scale pulse. Purely cosmetic (world-cauldron polish, 조합 쾌감 §5).
const TEX_CALM := "res://assets/objects/cauldron.png"
const TEX_BUBBLE := "res://assets/objects/cauldron_bubble.png"
const BUBBLE_PERIOD := 0.55  ## seconds per brew frame

var _tex_calm: Texture2D
var _tex_bubble: Texture2D
var _bubble_t: float = 0.0
var _bubble_on: bool = false
var _pulse_t: float = 0.0

## v1.0.4 P0 hotfix: L2-L5 crafting stations reuse the Cauldron class (so E → Fusion
## works in real play — see interaction_controller.gd on_interact hook) but keep their own
## workbench ART. When `configure()` supplies a static skin, the calm/bubble frame-swap and
## breathing pulse are DISABLED so the layer's workbench sprite stays put; only the interaction
## contract (group membership + `interacted`) matters here. Home/grove never call configure(),
## so their bubbling cauldron is untouched.
var _static_skin: bool = false


## (v1.0.4) Skin this cauldron with a layer-specific workbench texture/offset and turn OFF the
## brew animation. Call BEFORE adding to the tree (so _ready sees the assigned texture as calm).
func configure(skin_texture: Texture2D, skin_offset: Vector2, object_id_val: String = "workbench") -> void:
	if skin_texture != null:
		texture = skin_texture
	offset = skin_offset
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	object_id = object_id_val
	_static_skin = true


## (v1.1.0 GP-1) Configure this station as the SHARED 솥단지 — same cauldron art + live brew
## animation as home/L1, so the wanderer "summons their own pot" in every layer. Layer identity
## is expressed only by the flame (light pool) color, assigned by the session. Unlike configure()
## this KEEPS the bubbling/breathing animation on (no static skin). Call BEFORE adding to the tree.
func configure_shared(cauldron_offset: Vector2 = Vector2(0, -64), object_id_val: String = "cauldron") -> void:
	texture = load(TEX_CALM)
	offset = cauldron_offset
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	object_id = object_id_val
	_static_skin = false


func _ready() -> void:
	add_to_group(GROUP)
	# Skinned crafting stations (L2-L5) keep their static workbench art — no brew frames.
	if _static_skin:
		_tex_calm = texture
		_tex_bubble = null
		set_process(false)
		return
	_tex_calm = load(TEX_CALM)
	_tex_bubble = load(TEX_BUBBLE)
	# Cache the base texture actually assigned by the loader as the "calm" frame in
	# case art paths change; only animate if both frames resolved.
	if texture != null:
		_tex_calm = texture


func _process(delta: float) -> void:
	if _tex_bubble == null or _tex_calm == null:
		return
	_bubble_t += delta
	if _bubble_t >= BUBBLE_PERIOD:
		_bubble_t -= BUBBLE_PERIOD
		_bubble_on = not _bubble_on
		texture = _tex_bubble if _bubble_on else _tex_calm
	# Very subtle breathing pulse so the whole pot reads as alive (kept tiny so the
	# base footprint / Y-sort origin doesn't visibly shift).
	_pulse_t += delta * 2.2
	var s := 1.0 + sin(_pulse_t) * 0.02
	scale = Vector2(s, s)


# ---- Gatherable-compatible interface (so the controller can target it) ----

## Not gatherable — interacting opens fusion instead.
func can_gather() -> bool:
	return false


func gather() -> String:
	return ""


## World point for highlight / distance checks (base of the sprite).
func target_point() -> Vector2:
	return global_position


## Called by InteractionController when the player interacts with this object and
## no gather/use action applied. Opens the Fusion UI via the signal.
func on_interact() -> void:
	interacted.emit()
