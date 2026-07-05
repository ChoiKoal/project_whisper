extends Node2D
class_name Portal
## 제0세계의 문 (v0.5.0 phase C) — a stone arch portal on the home island.
##
## Five portals stand in a semicircle around the central dais, one per world "layer"
## (nature / science / machine / magic / divinity). Each has a 3-state machine driven by
## GameState.portal_states[layer]:
##   • dormant     — dark arch, no glow, no particles. Interacting shows a locked hint.
##   • flickering  — slow violet pulse + faint rising motes. Interacting TRAVELS (Layer 1
##                   nature portal in v0.5) — treated as enterable like open.
##   • open        — steady bright glow + a swirl of motes. Interacting travels.
##
## The arch sprite is composed programmatically (rock tones sampled from CliffGen + a
## violet inner glow disc), so there's no fragile hand-authored art. The node registers
## into the `gatherable` group so the existing InteractionController targets it and calls
## on_interact(); it is neither gatherable nor a use-target.
##
## Interaction routes through a signal so the world scene (home_island) owns the travel /
## locked-hint policy — the portal itself only reports "the player interacted with me".

const GROUP := "gatherable"

## Stable id for InteractionController targeting/debug.
@export var object_id: String = "portal"
## Which world layer this portal opens (nature/science/machine/magic/divinity).
@export var layer: String = "nature"

## Emitted when the player interacts. The world scene decides: travel (flickering/open) or
## show the locked hint (dormant). Carries this portal so the scene can read its layer/state.
signal portal_interacted(portal: Portal)

# ---- arch geometry (px, local; anchor = base centre on the tile) -----------
const ARCH_W := 96          ## outer width of the arch
const ARCH_H := 150         ## total height from base to top of the arch
const LEG_W := 20           ## thickness of each stone leg
const OPENING_W := ARCH_W - LEG_W * 2  ## inner opening width
const GLOW_R := 30.0        ## inner violet glow radius

# Rock palette (shared family with the cliffs) + violet accent.
const ROCK_BASE := Color8(120, 96, 78)
const ROCK_DARK := Color8(72, 56, 44)
const ROCK_LIGHT := Color8(150, 122, 102)
const VIOLET := Color("#9e7ad9")
const VIOLET_BRIGHT := Color("#c8a8f2")

var _arch: Sprite2D
var _glow: Sprite2D           ## the inner glow disc (alpha/scale animated by state)
var _particles: CPUParticles2D
var _swirl: CPUParticles2D
var _state: String = "dormant"
var _pulse_t: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_build_arch()
	_build_glow()
	_build_particles()
	# Adopt the current saved state and follow future changes.
	_apply_state(GameState.portal_state(layer))
	GameState.portal_state_changed.connect(_on_portal_changed)


func _on_portal_changed(changed_layer: String, state: String) -> void:
	if changed_layer == layer:
		_apply_state(state)


# ---- state machine --------------------------------------------------------

func _apply_state(state: String) -> void:
	_state = state
	match state:
		GameState.PORTAL_OPEN:
			_glow.visible = true
			_glow.self_modulate = Color(VIOLET_BRIGHT.r, VIOLET_BRIGHT.g, VIOLET_BRIGHT.b, 1.0)
			_glow.scale = Vector2(1.15, 1.15)
			_particles.emitting = true
			_swirl.emitting = true
			_arch.self_modulate = Color(1.06, 1.02, 1.10)   # lit stone
		GameState.PORTAL_FLICKERING:
			_glow.visible = true
			_glow.scale = Vector2(0.9, 0.9)
			_particles.emitting = true
			_swirl.emitting = false
			_arch.self_modulate = Color(0.86, 0.84, 0.9)
		_:  # dormant
			_glow.visible = false
			_particles.emitting = false
			_swirl.emitting = false
			_arch.self_modulate = Color(0.62, 0.60, 0.66)    # dark, cold stone


func state() -> String:
	return _state


## Enterable = flickering (Layer 1 tease that actually travels) or open.
func is_enterable() -> bool:
	return _state == GameState.PORTAL_FLICKERING or _state == GameState.PORTAL_OPEN


func _process(delta: float) -> void:
	if _state == GameState.PORTAL_DORMANT or _glow == null:
		return
	_pulse_t += delta
	# flickering: slow violet breathing; open: steady bright with a faint shimmer.
	if _state == GameState.PORTAL_FLICKERING:
		var a := 0.30 + 0.32 * (0.5 + 0.5 * sin(_pulse_t * 2.0))
		_glow.modulate.a = a
	else:  # open
		_glow.modulate.a = 0.78 + 0.08 * sin(_pulse_t * 3.0)


# ---- Gatherable-compatible interface (targeting) --------------------------

func can_gather() -> bool:
	return false

func gather() -> String:
	return ""

## Highlight anchor: the glowing centre of the arch (so the E-prompt sits in the opening).
func target_point() -> Vector2:
	return global_position + Vector2(0, -ARCH_H * 0.55)

## Interaction: report to the world scene, which owns travel / locked-hint policy.
func on_interact() -> void:
	portal_interacted.emit(self)


# ---- programmatic art -----------------------------------------------------

## Compose the stone-arch sprite: two legs + a rounded lintel spanning them, faceted rock
## shading (light from upper-right), anchored so its BASE sits on the tile centre.
func _build_arch() -> void:
	var img := Image.create(ARCH_W, ARCH_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := ARCH_W / 2
	var inner_half := OPENING_W / 2
	var arch_spring := int(ARCH_H * 0.42)   # y (from top) where the round arch springs
	for y in range(ARCH_H):
		for x in range(ARCH_W):
			var inside_stone := false
			# Legs: two vertical columns below the springline.
			if y >= arch_spring:
				var left_leg := x >= (cx - inner_half - LEG_W) and x < (cx - inner_half)
				var right_leg := x >= (cx + inner_half) and x < (cx + inner_half + LEG_W)
				if left_leg or right_leg:
					inside_stone = true
			# Rounded lintel: an annulus (outer arc minus inner arc) above the springline.
			var dx := float(x - cx)
			var dy := float(y - arch_spring)
			var outer_r := float(inner_half + LEG_W)
			var inner_r := float(inner_half)
			if dy <= 0.0:
				var d := sqrt(dx * dx + dy * dy)
				if d <= outer_r and d >= inner_r:
					inside_stone = true
			if not inside_stone:
				continue
			# Facet shading: light on the right face, dark on the left; block strata by hash.
			var lit := 1.0
			if x < cx:
				lit = 0.82
			else:
				lit = 1.06
			var strata: float = floor(CliffGen._rock_noise(x / 5, y / 6, 71) * 4.0) / 4.0
			var facet: float = (strata - 0.4) * 0.4
			var n: float = CliffGen._rock_noise(x, y, 71) * 0.10 - 0.05
			img.set_pixel(x, y, _rock_col(lit + facet + n))
	_arch = Sprite2D.new()
	_arch.texture = ImageTexture.create_from_image(img)
	_arch.centered = false
	_arch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Anchor: base-centre of the arch on the tile centre → top-left = (-W/2, -H).
	_arch.position = Vector2(-ARCH_W / 2.0, -ARCH_H)
	add_child(_arch)


func _rock_col(s: float) -> Color:
	s = clampf(s, 0.0, 1.4)
	if s < 1.0:
		return ROCK_DARK.lerp(ROCK_BASE, clampf(s, 0.0, 1.0))
	return ROCK_BASE.lerp(ROCK_LIGHT, clampf((s - 1.0) / 0.4, 0.0, 1.0))


## Soft violet glow disc filling the arch opening. On the glow CanvasLayer? No — kept a
## child so it Y-sorts with the arch; additive blend so it blooms over the dark stone.
func _build_glow() -> void:
	var s := int(GLOW_R * 2.0)
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(GLOW_R, GLOW_R)
	for y in range(s):
		for x in range(s):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / GLOW_R
			if d <= 1.0:
				var a := (1.0 - d) * (1.0 - d)
				img.set_pixel(x, y, Color(VIOLET.r, VIOLET.g, VIOLET.b, a))
	_glow = Sprite2D.new()
	_glow.texture = ImageTexture.create_from_image(img)
	_glow.centered = true
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Centre the glow in the arch opening (a bit above the base).
	_glow.position = Vector2(0, -ARCH_H * 0.52)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	add_child(_glow)


## Faint rising violet motes (flickering/open) + a tighter inner swirl (open only).
func _build_particles() -> void:
	_particles = CPUParticles2D.new()
	_particles.amount = 12
	_particles.lifetime = 2.4
	_particles.position = Vector2(0, -ARCH_H * 0.5)
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = Vector2(OPENING_W * 0.4, ARCH_H * 0.3)
	_particles.direction = Vector2(0, -1)
	_particles.spread = 18.0
	_particles.gravity = Vector2(0, -12)
	_particles.initial_velocity_min = 6.0
	_particles.initial_velocity_max = 16.0
	_particles.scale_amount_min = 1.0
	_particles.scale_amount_max = 2.6
	_particles.color = Color(VIOLET_BRIGHT.r, VIOLET_BRIGHT.g, VIOLET_BRIGHT.b, 0.7)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_particles.material = mat
	_particles.emitting = false
	add_child(_particles)

	_swirl = CPUParticles2D.new()
	_swirl.amount = 18
	_swirl.lifetime = 1.8
	_swirl.position = Vector2(0, -ARCH_H * 0.52)
	_swirl.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_swirl.emission_sphere_radius = GLOW_R * 0.8
	_swirl.direction = Vector2(1, 0)
	_swirl.spread = 180.0
	_swirl.tangential_accel_min = 20.0
	_swirl.tangential_accel_max = 44.0
	_swirl.initial_velocity_min = 4.0
	_swirl.initial_velocity_max = 10.0
	_swirl.scale_amount_min = 1.0
	_swirl.scale_amount_max = 2.0
	_swirl.color = Color(1.0, 1.0, 1.0, 0.6)
	var mat2 := CanvasItemMaterial.new()
	mat2.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_swirl.material = mat2
	_swirl.emitting = false
	add_child(_swirl)
