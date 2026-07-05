extends Node2D
class_name Portal
## 제0세계의 문 (v0.5.0 phase C, art rebuilt v0.5d) — a MONUMENTAL stone gate on the home
## island. Not a thin croquet-hoop arch: an imposing megalith gate ~2 tiles wide × ~3 tiles
## tall — two THICK weathered stone pillars standing on a raised 3-slab stone base + a heavy
## lintel spanning them + carved cracked runes running down each pillar (violet inlay) + a
## floating carved SIGIL stone above the lintel bearing the layer's motif glyph
## (1 leaf / 2 star / 3 gear / 4 rune / 5 halo). The pillars/lintel/base are composed from
## the REAL cliff_face rock texture (sampled + shaded per region), not flat fills.
##
## Five gates stand across the north half around the central dais, one per world "layer"
## (nature / science / machine / magic / divinity). Each has a 3-state machine driven by
## GameState.portal_states[layer]:
##   • dormant     — cold grey weathered stone, runes unlit, empty archway. No veil, no glow.
##                   Interacting shows a locked hint.
##   • flickering  — the carved runes pulse softly + a faint violet inner veil (semi-transparent
##                   swirl) + rising motes. Enterable (Layer-1 nature tease). Sigil lit.
##   • open        — a bright, stable violet swirl vortex fills the archway + a steady glow pool
##                   at the base + steady rune glow + a rising particle stream. Sigil lit.
##
## The gate composes programmatically off the cliff rock texture (deterministic), so there's no
## fragile hand-authored art. The node registers into the `gatherable` group so the existing
## InteractionController targets it and calls on_interact(); it is neither gatherable nor a
## use-target. Interaction routes through a signal so the world scene (home_island) owns
## travel / locked-hint policy.

const GROUP := "gatherable"

## Stable id for InteractionController targeting/debug.
@export var object_id: String = "portal"
## Which world layer this portal opens (nature/science/machine/magic/divinity).
@export var layer: String = "nature"
## (v0.6.0) Optional entry-prompt override. When non-empty, entry_prompt_text() returns this
## verbatim while the gate is enterable (used by the RETURN portal → "E 홈으로 돌아가기" instead
## of the generic "E 들어가기"). Dormant still shows the sleeping whisper.
@export var prompt_override: String = ""

## Emitted when the player interacts. The world scene decides: travel (flickering/open) or
## show the locked hint (dormant). Carries this portal so the scene can read its layer/state.
signal portal_interacted(portal: Portal)

# ---- gate geometry (px, local; anchor = base centre on the tile) -----------
## Monumental: ~2 tiles wide (128px tile → gate ~206px outer), ~3 tiles tall.
const GATE_W := 206         ## outer width of the whole gate (pillar to pillar)
const GATE_H := 316         ## total height from base bottom to the top of the sigil stone
const PILLAR_W := 50        ## thickness of each carved stone pillar
const OPENING_W := GATE_W - PILLAR_W * 2  ## inner opening width (~106)
const LINTEL_H := 52        ## height of the heavy lintel spanning the pillars
const LINTEL_OVERHANG := 14 ## how far the lintel juts past each pillar's outer face
const SIGIL_CY := 40        ## y of the floating sigil-stone centre (from top of image)
const SIGIL_R := 34         ## radius of the floating sigil stone
const LINTEL_TOP := 92      ## y (from top) where the lintel begins (below the sigil)
const PILLAR_TOP := LINTEL_TOP + LINTEL_H   ## y where the pillars begin (below the lintel)
const BASE_H := 40          ## total height of the stacked-slab stone base
const PILLAR_BOTTOM := GATE_H - BASE_H      ## y where the pillars meet the base
const VEIL_W := OPENING_W + 6   ## width of the inner veil filling the opening
const GLOW_R := 46.0        ## base glow-pool radius

# Rock palette (shared family with the cliffs) + violet accent.
const ROCK_BASE := Color8(120, 96, 78)
const ROCK_DARK := Color8(72, 56, 44)
const ROCK_LIGHT := Color8(150, 122, 102)
const ROCK_SHADOW := Color8(46, 36, 30)
const MOSS := Color8(78, 104, 58)
const VIOLET := Color("#9e7ad9")
const VIOLET_BRIGHT := Color("#c8a8f2")
const VIOLET_DEEP := Color("#5b3f86")
const RUNE_STONE := Color8(64, 50, 84)   ## the cold violet-grey sigil block

## Cached rock-texture sample (a clean patch of cliff_face_a, no baked foot). Sampled once.
static var _rock_tex: Image = null

var _gate: Sprite2D            ## the pillars + lintel + stacked-slab base (rock body)
var _rune_glow: Sprite2D       ## additive violet glow over the carved pillar runes (state-lit)
var _sigil: Sprite2D           ## the floating carved sigil stone (bobs)
var _sigil_glow: Sprite2D      ## additive glow behind the sigil glyph (state-lit)
var _veil: Sprite2D            ## the inner swirl veil (alpha/scale animated by state)
var _pool: Sprite2D            ## the violet glow pool at the base (open only)
var _particles: CPUParticles2D
var _swirl: CPUParticles2D
var _spark: CPUParticles2D
var _state: String = "dormant"
var _pulse_t: float = 0.0
var _sigil_y0: float = 0.0

## (v0.5.1 BUG3) A generous entry apron Area2D in FRONT of the gate (a ~2×2-tile pad just
## screen-below the stepped base). The player stands here to enter — the monumental gate's own
## collision (its stone pillars) no longer breaks the adjacent-cell interact, because entry is
## driven by "is the player inside this apron?" rather than by an interactable anchor cell that
## fell inside/above the pillar footprint. HomeSession polls is_player_in_entry_zone() to show
## the prompt + route E; touch walks to entry_stand_point() then calls on_interact.
var _entry_zone: Area2D
var _player_in_zone: bool = false
## Apron footprint (px): ~2 tiles wide (iso) × ~2 tiles deep, seated in front of the base.
const ENTRY_W := 200.0
const ENTRY_H := 128.0
## How far (px) screen-DOWN from the gate base-centre the apron centre sits (in front of steps).
const ENTRY_FORWARD := 64.0

## Human-readable layer names (kept for debug / accessibility; the visible marker is the glyph).
const LAYER_NAMES := {
	"nature": "자연", "science": "과학", "machine": "기계",
	"magic": "마법", "divinity": "신성",
}
## Which motif glyph each layer's sigil stone carries.
const LAYER_GLYPH := {
	"nature": "leaf", "science": "star", "machine": "gear",
	"magic": "rune", "divinity": "halo",
}


func _ready() -> void:
	add_to_group(GROUP)
	_ensure_rock_tex()
	_build_gate()
	_build_rune_glow()
	_build_sigil()
	_build_veil()
	_build_pool()
	_build_particles()
	_build_entry_zone()
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
			_veil.visible = true
			_veil.self_modulate = Color(VIOLET_BRIGHT.r, VIOLET_BRIGHT.g, VIOLET_BRIGHT.b, 1.0)
			_veil.scale = Vector2(1.0, 1.0)
			_pool.visible = true
			_rune_glow.visible = true
			_rune_glow.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
			_sigil.self_modulate = Color(1.35, 1.2, 1.5)   # lit sigil stone
			_sigil_glow.visible = true
			_sigil_glow.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
			_particles.emitting = true
			_swirl.emitting = true
			_spark.emitting = false
			_gate.self_modulate = Color(1.08, 1.03, 1.12)   # warm-lit stone
		GameState.PORTAL_FLICKERING:
			_veil.visible = true
			_veil.self_modulate = Color(VIOLET.r, VIOLET.g, VIOLET.b, 1.0)
			_veil.scale = Vector2(0.94, 0.97)
			_pool.visible = false
			_rune_glow.visible = true
			_sigil.self_modulate = Color(1.12, 1.04, 1.22)
			_sigil_glow.visible = true
			_particles.emitting = false
			_swirl.emitting = false
			_spark.emitting = true
			_gate.self_modulate = Color(0.92, 0.90, 0.96)
		_:  # dormant
			_veil.visible = false
			_pool.visible = false
			_rune_glow.visible = false
			_sigil.self_modulate = Color(0.62, 0.58, 0.70)   # cold, unlit sigil stone
			_sigil_glow.visible = false
			_particles.emitting = false
			_swirl.emitting = false
			_spark.emitting = false
			_gate.self_modulate = Color(0.74, 0.72, 0.80)   # cold grey stone


func state() -> String:
	return _state


## Enterable = flickering (Layer 1 tease that actually travels) or open.
func is_enterable() -> bool:
	return _state == GameState.PORTAL_FLICKERING or _state == GameState.PORTAL_OPEN


## True when the floating sigil stone's glyph is LIT (non-dormant). The sigil stone itself is
## always present + bobbing; only its glyph glow ignites when the gate wakes. Used by the
## v050c harness to assert the state-driven sigil beat.
func is_sigil_lit() -> bool:
	return _sigil_glow != null and _sigil_glow.visible


func _process(delta: float) -> void:
	_pulse_t += delta
	# The sigil stone always hovers with a slow bob (even dormant — it's stone that never fell).
	if _sigil != null:
		_sigil.position.y = _sigil_y0 + sin(_pulse_t * 1.3) * 3.0
		if _sigil_glow != null:
			_sigil_glow.position.y = _sigil.position.y
	if _state == GameState.PORTAL_DORMANT:
		return
	# Pulse the carved pillar runes: slow breathe when flickering, steadier bright when open.
	if _rune_glow != null:
		if _state == GameState.PORTAL_FLICKERING:
			_rune_glow.modulate.a = 0.30 + 0.34 * (0.5 + 0.5 * sin(_pulse_t * 1.9))
		else:
			_rune_glow.modulate.a = 0.72 + 0.16 * sin(_pulse_t * 2.6)
	if _sigil_glow != null:
		_sigil_glow.modulate.a = (0.5 if _state == GameState.PORTAL_FLICKERING else 0.85) \
			* (0.7 + 0.3 * (0.5 + 0.5 * sin(_pulse_t * 2.1)))
	if _veil == null:
		return
	# flickering: slow violet breathing veil; open: steady bright churning vortex.
	if _state == GameState.PORTAL_FLICKERING:
		_veil.modulate.a = 0.24 + 0.26 * (0.5 + 0.5 * sin(_pulse_t * 1.8))
		_veil.rotation = sin(_pulse_t * 0.6) * 0.08
	else:  # open — rotating swirl vortex
		_veil.modulate.a = 0.80 + 0.10 * sin(_pulse_t * 2.4)
		_veil.rotation = _pulse_t * 0.4   # steady rotation → the swirl visibly spins


# ---- Gatherable-compatible interface (targeting) --------------------------

func can_gather() -> bool:
	return false

func gather() -> String:
	return ""

## Highlight anchor: the glowing centre of the gate opening (so the E-prompt sits in it).
func target_point() -> Vector2:
	return global_position + Vector2(0, -GATE_H * 0.5)

## Interaction: report to the world scene, which owns travel / locked-hint policy.
func on_interact() -> void:
	portal_interacted.emit(self)


# ---- entry apron (v0.5.1 BUG3) -------------------------------------------

## Build the generous front-apron Area2D the player stands in to enter. It sits just
## screen-DOWN of the gate base (in front of the steps), ~2×2 tiles, so the approach never
## overlaps the gate's own blocking collision. Monitors the "player" group for enter/exit.
func _build_entry_zone() -> void:
	_entry_zone = Area2D.new()
	_entry_zone.name = "EntryZone"
	_entry_zone.monitoring = true
	_entry_zone.monitorable = false
	# Only react to the player body (layer 2 is the player's; portals use collision layer 1 for
	# the blocking pillars). We mask broadly and filter by group in the callback for robustness.
	_entry_zone.collision_layer = 0
	_entry_zone.collision_mask = 0xFFFFFFFF
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(ENTRY_W, ENTRY_H)
	col.shape = shape
	# In front of (screen-below) the base centre. The gate anchor is at the base-bottom-centre
	# (this node's origin), so the apron sits just south of it.
	col.position = Vector2(0, ENTRY_FORWARD)
	_entry_zone.add_child(col)
	_entry_zone.body_entered.connect(_on_body_entered)
	_entry_zone.body_exited.connect(_on_body_exited)
	add_child(_entry_zone)


func _on_body_entered(body: Node) -> void:
	if body is Player or body.is_in_group("player"):
		_player_in_zone = true


func _on_body_exited(body: Node) -> void:
	if body is Player or body.is_in_group("player"):
		_player_in_zone = false


## True while the player is standing in this gate's entry apron. Authoritative: queries the
## Area2D's current overlaps each call (updated by the physics server every frame) rather than
## trusting only the cached enter/exit flag — so a TELEPORT into or out of the apron (scene load,
## cutscene reposition, arrival warp) reads correctly on the very next physics frame instead of
## waiting on a body_entered/exited signal that a same-frame teleport can skip.
func is_player_in_entry_zone() -> bool:
	if _entry_zone != null and _entry_zone.monitoring:
		for b in _entry_zone.get_overlapping_bodies():
			if b is Player or b.is_in_group("player"):
				return true
		return false
	return _player_in_zone


## World point at the apron centre — where touch walk-then-enter should path the player to.
func entry_stand_point() -> Vector2:
	return global_position + Vector2(0, ENTRY_FORWARD)


## State-driven prompt shown while the player is in the apron:
##   • enterable (flickering/open) → "E 들어가기"
##   • flickering (Layer-1 tease, first contact) → "E 다가가기"  (see note)
##   • dormant → the whisper "…아직 잠들어 있다"
## Per the brief: flickering shows the "다가가기" first-contact affordance; open shows "들어가기".
func entry_prompt_text() -> String:
	match _state:
		GameState.PORTAL_OPEN:
			return prompt_override if prompt_override != "" else "E 들어가기"
		GameState.PORTAL_FLICKERING:
			return prompt_override if prompt_override != "" else "E 다가가기"
		_:
			return "…아직 잠들어 있다"


# ---- rock material --------------------------------------------------------

## Sample a clean rock patch from the real cliff_face_a texture (the upper rock face, above
## the baked diamond foot) into a static Image we can read per-pixel to texture the gate.
## Falls back to a procedural rock field if the texture can't be loaded (headless safety).
static func _ensure_rock_tex() -> void:
	if _rock_tex != null:
		return
	var tex := load("res://assets/tiles/cliff_face_a.png") as Texture2D
	if tex != null:
		var img := tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			_rock_tex = img
			return
	# Fallback: a small procedural rock field (deterministic).
	var f := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	for y in range(96):
		for x in range(96):
			var strata: float = floor(CliffGen._rock_noise(x / 6, y / 5, 71) * 5.0) / 5.0
			var n: float = CliffGen._rock_noise(x, y, 71) * 0.14 - 0.07
			f.set_pixel(x, y, Portal._rock_col_s(0.9 + (strata - 0.4) * 0.5 + n))
	_rock_tex = f


## Read a rock-texture colour at (u,v) tiled into the texture's clean rock band, multiplied by
## a per-region light scalar so the same stone reads with faceted highlight/shadow.
static func _rock_sample(u: int, v: int, lit: float) -> Color:
	# Clean rock band of cliff_face_a: x∈[8,120], y∈[12,150] (rock face, no diamond foot).
	var bx := 8
	var by := 12
	var bw := 112
	var bh := 138
	var sx := bx + posmod(u, bw)
	var sy := by + posmod(v, bh)
	var c := _rock_tex.get_pixel(sx, sy)
	# multiply toward light; clamp so highlights don't blow out.
	lit = clampf(lit, 0.30, 1.55)
	return Color(
		clampf(c.r * lit, 0.0, 1.0),
		clampf(c.g * lit, 0.0, 1.0),
		clampf(c.b * lit, 0.0, 1.0), 1.0)


func _rock_col(s: float) -> Color:
	return Portal._rock_col_s(s)

static func _rock_col_s(s: float) -> Color:
	s = clampf(s, 0.0, 1.4)
	if s < 0.7:
		return ROCK_SHADOW.lerp(ROCK_DARK, clampf(s / 0.7, 0.0, 1.0))
	elif s < 1.0:
		return ROCK_DARK.lerp(ROCK_BASE, clampf((s - 0.7) / 0.3, 0.0, 1.0))
	return ROCK_BASE.lerp(ROCK_LIGHT, clampf((s - 1.0) / 0.4, 0.0, 1.0))


# ---- programmatic art -----------------------------------------------------

## Compose the monumental gate from real rock texture: a raised 3-slab stone BASE, two thick
## carved PILLARS standing on it (with a carved cracked-rune channel down each inner face), and
## a heavy LINTEL spanning them. Light from the upper-right; carved seams between blocks; moss
## low on the pillars. Anchored so the BASE bottom sits on the tile centre.
func _build_gate() -> void:
	var img := Image.create(GATE_W, GATE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := GATE_W / 2
	var inner_half := OPENING_W / 2
	var left_out := cx - inner_half - PILLAR_W    # outer x of left pillar
	var left_in := cx - inner_half                # inner x of left pillar
	var right_in := cx + inner_half               # inner x of right pillar
	var right_out := cx + inner_half + PILLAR_W   # outer x of right pillar
	var lintel_left := left_out - LINTEL_OVERHANG
	var lintel_right := right_out + LINTEL_OVERHANG

	# --- stacked-slab base: 3 weathered slabs, widest at the bottom, narrowing up ---
	# Each slab is a flat iso-ish band; the pillars stand centred on it.
	var slab_defs := [
		# [y_top, y_bot, x_left, x_right]
		[PILLAR_BOTTOM, PILLAR_BOTTOM + 14, lintel_left - 10, lintel_right + 10],
		[PILLAR_BOTTOM + 14, PILLAR_BOTTOM + 27, lintel_left - 2, lintel_right + 2],
		[PILLAR_BOTTOM + 27, GATE_H, left_out - 6, right_out + 6],
	]

	for y in range(GATE_H):
		for x in range(GATE_W):
			var in_stone := false
			var region := ""    # "lp"/"rp"/"li"/"base"
			# Pillars: two thick vertical columns between lintel and base.
			if y >= PILLAR_TOP and y < PILLAR_BOTTOM:
				if x >= left_out and x < left_in:
					in_stone = true; region = "lp"
				elif x >= right_in and x < right_out:
					in_stone = true; region = "rp"
			# Lintel: a heavy beam across the top, overhanging the pillars.
			if y >= LINTEL_TOP and y < PILLAR_TOP and x >= lintel_left and x < lintel_right:
				in_stone = true; region = "li"
			# Base slabs.
			var slab_i := -1
			for i in range(slab_defs.size()):
				var s = slab_defs[i]
				if y >= s[0] and y < s[1] and x >= s[2] and x < s[3]:
					in_stone = true; region = "base"; slab_i = i
					break
			if not in_stone:
				continue

			# Per-region light scalar (facet: light from upper-right).
			var lit := 1.0
			match region:
				"lp":
					var t := float(x - left_out) / float(PILLAR_W)
					lit = 0.70 + t * 0.46           # rounded: brighter toward centre-right
				"rp":
					var t2 := float(x - right_in) / float(PILLAR_W)
					lit = 0.80 + t2 * 0.44
				"li":
					var tv := float(y - LINTEL_TOP) / float(LINTEL_H)
					lit = 1.10 - tv * 0.40          # top-lit, dark underside
				"base":
					var tb := float(y - slab_defs[slab_i][0]) / 14.0
					lit = 0.92 - tb * 0.30          # each slab's top edge catches light
			# Texture the stone with the real rock sample (region-offset so blocks differ).
			var uoff := 0
			var voff := 0
			match region:
				"lp": uoff = 3; voff = 11
				"rp": uoff = 61; voff = 7
				"li": uoff = 20; voff = 90
				"base": uoff = 40 + slab_i * 17; voff = 150
			var col := Portal._rock_sample(x + uoff, y + voff, lit)
			# carved horizontal seams between stacked blocks on the pillars.
			if (region == "lp" or region == "rp") and (y % 40) < 2:
				col = col.darkened(0.42)
			# vertical centre joint on the lintel.
			if region == "li" and absi(x - cx) < 2:
				col = col.darkened(0.34)
			# seam between base slabs.
			if region == "base" and slab_i >= 0:
				if absi(y - int(slab_defs[slab_i][0])) < 2:
					col = col.lightened(0.18)
			# moss hints: low on the pillars, sparse, deterministic.
			if (region == "lp" or region == "rp") and y > PILLAR_BOTTOM - 70:
				var mv := CliffGen._rock_noise(x / 3, y / 3, 133)
				var low := float(y - (PILLAR_BOTTOM - 70)) / 70.0
				if mv < 0.16 * low:
					col = col.lerp(MOSS, 0.5)
			img.set_pixel(x, y, col)

	# --- carved cracked runes down the inner face of each pillar (violet inlay) ---
	# A vertical channel of glyph marks etched into the stone; unlit here (the additive
	# glow overlay lights them per state). Draw a DARK carved groove + a faint violet inlay.
	_carve_pillar_runes(img, left_in - 16, left_out + PILLAR_W)   # left pillar inner band
	_carve_pillar_runes(img, right_in + 2, right_out)             # right pillar inner band

	_gate = Sprite2D.new()
	_gate.texture = ImageTexture.create_from_image(img)
	_gate.centered = false
	_gate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Anchor: base-bottom-centre of the gate on the tile centre → top-left = (-W/2, -H).
	_gate.position = Vector2(-GATE_W / 2.0, -GATE_H)
	add_child(_gate)


## Etch a vertical column of carved rune marks into the stone image within [x0,x1). The marks
## are a dark carved groove with a thin violet-deep inlay (the "cracked runes"); the additive
## _rune_glow sprite lights the same region when the gate wakes.
func _carve_pillar_runes(img: Image, x0: int, x1: int) -> void:
	var cxr := (x0 + x1) / 2
	var gi := 0
	var y := PILLAR_TOP + 22
	while y < PILLAR_BOTTOM - 18:
		# an angular rune every ~46px: a vertical stave + two diagonal ticks (alternating side),
		# a hairline crack trailing off the foot — reads as a carved rune, not a medical cross.
		var flip := 1 if (gi % 2 == 0) else -1
		for dy in range(-13, 14):
			var yy := y + dy
			if yy < 0 or yy >= GATE_H:
				continue
			# central vertical stave (the rune's spine)
			for dx in range(-1, 2):
				var xx := cxr + dx
				if xx >= x0 and xx < x1:
					img.set_pixel(xx, yy, img.get_pixel(xx, yy).darkened(0.5).lerp(VIOLET_DEEP, 0.36))
		# upper diagonal tick (out from the spine)
		for t in range(0, 7):
			var xx2 := cxr + flip * t
			var yy2 := y - 8 + t
			if xx2 >= x0 and xx2 < x1 and yy2 >= 0 and yy2 < GATE_H:
				img.set_pixel(xx2, yy2, img.get_pixel(xx2, yy2).darkened(0.46).lerp(VIOLET_DEEP, 0.32))
		# lower diagonal tick (opposite side)
		for t2 in range(0, 6):
			var xx3 := cxr - flip * t2
			var yy3 := y + 3 + t2
			if xx3 >= x0 and xx3 < x1 and yy3 >= 0 and yy3 < GATE_H:
				img.set_pixel(xx3, yy3, img.get_pixel(xx3, yy3).darkened(0.44).lerp(VIOLET_DEEP, 0.3))
		# hairline crack off the foot (the "cracked" reading)
		for dd in range(1, 5):
			var xc := cxr + flip * dd
			var yc := y + 12 + dd
			if xc >= x0 and xc < x1 and yc < GATE_H:
				img.set_pixel(xc, yc, img.get_pixel(xc, yc).darkened(0.4))
		gi += 1
		y += 46


## Additive violet glow laid exactly over the carved pillar-rune channels, lit per state so the
## runes "pulse" awake. Two soft vertical bars (one per pillar inner face).
func _build_rune_glow() -> void:
	var img := Image.create(GATE_W, GATE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := GATE_W / 2
	var inner_half := OPENING_W / 2
	var bands := [
		[cx - inner_half - 16, cx - inner_half - 6],   # left pillar rune column x-centre band
		[cx + inner_half + 6, cx + inner_half + 16],
	]
	for band in bands:
		var bcx: int = int((int(band[0]) + int(band[1])) / 2)
		var gi := 0
		var yy := PILLAR_TOP + 22
		while yy < PILLAR_BOTTOM - 18:
			var flip := 1 if (gi % 2 == 0) else -1
			# soft glow along the stave + the two diagonal ticks (mirrors _carve_pillar_runes).
			for dy in range(-14, 15):
				var y: int = yy + dy
				if y < 0 or y >= GATE_H:
					continue
				for dx in range(-6, 7):
					var x: int = bcx + dx
					if x < 0 or x >= GATE_W:
						continue
					var vbar := (1.0 - clampf(absf(dx) / 6.0, 0.0, 1.0)) * (1.0 if absi(dx) < 2 else 0.30)
					# distance to the two diagonal ticks
					var tick := 0.0
					var uy := float(dy + 8)   # upper tick param
					if uy >= 0.0 and uy <= 6.0:
						tick = maxf(tick, 1.0 - clampf(absf(dx - flip * uy) / 3.0, 0.0, 1.0))
					var ly := float(dy - 3)   # lower tick param
					if ly >= 0.0 and ly <= 5.0:
						tick = maxf(tick, 1.0 - clampf(absf(dx + flip * ly) / 3.0, 0.0, 1.0))
					var a := maxf(vbar, tick * 0.85) * 0.9
					if a <= 0.02:
						continue
					var prev := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(VIOLET_BRIGHT.r, VIOLET_BRIGHT.g, VIOLET_BRIGHT.b, maxf(prev.a, a)))
			gi += 1
			yy += 46
	_rune_glow = Sprite2D.new()
	_rune_glow.texture = ImageTexture.create_from_image(img)
	_rune_glow.centered = false
	_rune_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rune_glow.position = Vector2(-GATE_W / 2.0, -GATE_H)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_rune_glow.material = mat
	_rune_glow.visible = false
	add_child(_rune_glow)


## The floating carved SIGIL stone above the lintel: a hex/diamond block of cold violet-grey
## stone carved with the LAYER's motif glyph (leaf/star/gear/rune/halo), hovering with a slow
## bob (set in _process). A separate additive glow sprite lights the glyph per state.
func _build_sigil() -> void:
	var s := SIGIL_R * 2 + 10
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(s / 2.0, s / 2.0)
	for y in range(s):
		for x in range(s):
			# hex-ish rounded stone tablet body (iso-lozenge with a flat-ish top/bottom).
			var dx := absf(x - c.x) / float(SIGIL_R)
			var dy := absf(y - c.y) / float(SIGIL_R * 0.9)
			var d := dx * 1.02 + dy
			if d > 1.0:
				continue
			# faceted stone: lit upper-right, dark lower-left.
			var lit := 0.66 + (1.0 - dx) * 0.32 + (1.0 - dy) * 0.30
			var col := RUNE_STONE.lerp(Color8(96, 84, 118), clampf(lit - 0.6, 0.0, 0.6))
			# a carved bevel rim
			if d > 0.82:
				col = col.darkened(0.34)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	# carve the layer glyph into the tablet face (bright violet inlay).
	_draw_glyph(img, c, String(LAYER_GLYPH.get(layer, "rune")))
	_sigil = Sprite2D.new()
	_sigil.texture = ImageTexture.create_from_image(img)
	_sigil.centered = true
	_sigil.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sigil_y0 = -GATE_H + SIGIL_CY
	_sigil.position = Vector2(0, _sigil_y0)
	_sigil.z_index = 2
	add_child(_sigil)

	# additive glow behind/over the glyph so it can be lit per state.
	var g := Image.create(s, s, false, Image.FORMAT_RGBA8)
	g.fill(Color(0, 0, 0, 0))
	_draw_glyph(g, c, String(LAYER_GLYPH.get(layer, "rune")), true)
	_sigil_glow = Sprite2D.new()
	_sigil_glow.texture = ImageTexture.create_from_image(g)
	_sigil_glow.centered = true
	_sigil_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sigil_glow.position = _sigil.position
	_sigil_glow.z_index = 2
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sigil_glow.material = mat
	_sigil_glow.visible = false
	add_child(_sigil_glow)


## Draw a simple motif glyph centred at `c` into image `img`. When `glow` is true, draws a
## soft additive violet field (for the glow sprite); otherwise a crisp bright violet inlay.
func _draw_glyph(img: Image, c: Vector2, kind: String, glow: bool = false) -> void:
	var col := VIOLET_BRIGHT if not glow else VIOLET
	var R := float(SIGIL_R) * 0.56
	# helper: stamp a soft dot
	var stamp := func(px: float, py: float, rad: float, aa: float) -> void:
		for yy in range(int(py - rad), int(py + rad + 1)):
			for xx in range(int(px - rad), int(px + rad + 1)):
				if xx < 0 or yy < 0 or xx >= img.get_width() or yy >= img.get_height():
					continue
				var dd := Vector2(xx - px, yy - py).length() / rad
				if dd > 1.0:
					continue
				var a := (1.0 - dd) * aa
				var prev := img.get_pixel(xx, yy)
				img.set_pixel(xx, yy, Color(col.r, col.g, col.b, maxf(prev.a, a)))
	var dot_r := 3.0 if not glow else 5.0
	var aa := 1.0 if not glow else 0.5
	match kind:
		"leaf":
			# a leaf: an almond outline + a central vein.
			for i in range(24):
				var t := float(i) / 23.0
				var ang := lerpf(-1.4, 1.4, t)
				var rr := R * (1.0 - absf(ang) / 1.6)
				stamp.call(c.x + sin(ang) * rr, c.y - cos(ang) * R * 0.4 - R * 0.1, dot_r, aa)
				stamp.call(c.x + sin(ang) * rr, c.y + cos(ang) * R * 0.4 - R * 0.1, dot_r, aa)
			for i in range(12):
				stamp.call(c.x, c.y - R * 0.5 + i / 11.0 * R, dot_r * 0.8, aa)
		"star":
			# 5-point star: spokes from centre.
			for k in range(5):
				var a0 := -PI / 2 + k * TAU / 5.0
				for i in range(12):
					var t2 := float(i) / 11.0
					stamp.call(c.x + cos(a0) * R * t2, c.y + sin(a0) * R * t2, dot_r * (1.1 - 0.4 * t2), aa)
		"gear":
			# gear: a ring + short teeth spokes + hub.
			for i in range(28):
				var a1 := float(i) / 28.0 * TAU
				stamp.call(c.x + cos(a1) * R * 0.7, c.y + sin(a1) * R * 0.7, dot_r, aa)
			for k in range(8):
				var a2 := k * TAU / 8.0
				stamp.call(c.x + cos(a2) * R, c.y + sin(a2) * R, dot_r * 1.1, aa)
			stamp.call(c.x, c.y, dot_r * 1.4, aa)
		"rune":
			# rune: an angular Y/branch mark.
			for i in range(12):
				var t3 := float(i) / 11.0
				stamp.call(c.x, c.y - R + t3 * R * 0.9, dot_r, aa)                      # stem
				stamp.call(c.x - t3 * R * 0.7, c.y - R * 0.1 + t3 * R * 0.7, dot_r, aa) # left branch
				stamp.call(c.x + t3 * R * 0.7, c.y - R * 0.1 + t3 * R * 0.7, dot_r, aa) # right branch
		_:  # halo
			# halo: a ring + a small inner ring (divinity).
			for i in range(30):
				var a3 := float(i) / 30.0 * TAU
				stamp.call(c.x + cos(a3) * R, c.y + sin(a3) * R, dot_r, aa)
				stamp.call(c.x + cos(a3) * R * 0.45, c.y + sin(a3) * R * 0.45, dot_r * 0.8, aa)


## Soft violet swirl veil filling the gate opening. Additive blend so it blooms over the
## dark stone; alpha/rotation animated per state in _process → a rotating vortex when open.
func _build_veil() -> void:
	var w := VEIL_W
	var h := int(PILLAR_BOTTOM - PILLAR_TOP)   # opening height (below the lintel, above base)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := w / 2.0
	var cy := h / 2.0
	for y in range(h):
		for x in range(w):
			var dx := (x - cx) / (w * 0.5)
			var dy := (y - cy) / (h * 0.5)
			var r := sqrt(dx * dx + dy * dy)
			if r > 1.0:
				continue
			# swirl: angle+radius modulated brightness → reads as a churning vortex, not a disc.
			var ang := atan2(dy, dx)
			var swirl := 0.5 + 0.5 * sin(ang * 3.0 + r * 7.0)
			var a := (1.0 - r) * (0.40 + 0.60 * swirl)
			img.set_pixel(x, y, Color(VIOLET_BRIGHT.r, VIOLET_BRIGHT.g, VIOLET_BRIGHT.b, a * 0.95))
	_veil = Sprite2D.new()
	_veil.texture = ImageTexture.create_from_image(img)
	_veil.centered = true
	_veil.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Centre the veil in the opening (between lintel bottom and base top).
	var opening_mid := -(GATE_H - PILLAR_TOP - (BASE_H)) * 0.5 - BASE_H
	_veil.position = Vector2(0, opening_mid)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_veil.material = mat
	_veil.visible = false
	add_child(_veil)


## Steady violet glow pool at the gate base (open state only): an iso-squashed additive disc.
func _build_pool() -> void:
	var w := int(GLOW_R * 2.6)
	var h := int(GLOW_R * 1.4)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(w / 2.0, h / 2.0)
	for y in range(h):
		for x in range(w):
			var dx := (x - c.x) / (w * 0.5)
			var dy := (y - c.y) / (h * 0.5)
			var d := sqrt(dx * dx + dy * dy)
			if d <= 1.0:
				var a := (1.0 - d) * (1.0 - d)
				img.set_pixel(x, y, Color(VIOLET.r, VIOLET.g, VIOLET.b, a * 0.8))
	_pool = Sprite2D.new()
	_pool.texture = ImageTexture.create_from_image(img)
	_pool.centered = true
	_pool.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pool.position = Vector2(0, -8)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_pool.material = mat
	_pool.visible = false
	add_child(_pool)


## Rising violet motes (open) + a tighter inner swirl (open) + occasional sparks (flickering).
func _build_particles() -> void:
	var open_center := Vector2(0, -float(PILLAR_BOTTOM - PILLAR_TOP) * 0.5 - BASE_H)

	_particles = CPUParticles2D.new()
	_particles.amount = 18
	_particles.lifetime = 2.6
	_particles.position = open_center
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = Vector2(OPENING_W * 0.42, (PILLAR_BOTTOM - PILLAR_TOP) * 0.4)
	_particles.direction = Vector2(0, -1)
	_particles.spread = 16.0
	_particles.gravity = Vector2(0, -14)
	_particles.initial_velocity_min = 6.0
	_particles.initial_velocity_max = 18.0
	_particles.scale_amount_min = 1.2
	_particles.scale_amount_max = 3.0
	_particles.color = Color(VIOLET_BRIGHT.r, VIOLET_BRIGHT.g, VIOLET_BRIGHT.b, 0.7)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_particles.material = mat
	_particles.emitting = false
	add_child(_particles)

	_swirl = CPUParticles2D.new()
	_swirl.amount = 24
	_swirl.lifetime = 2.0
	_swirl.position = open_center
	_swirl.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_swirl.emission_sphere_radius = OPENING_W * 0.32
	_swirl.direction = Vector2(1, 0)
	_swirl.spread = 180.0
	_swirl.tangential_accel_min = 24.0
	_swirl.tangential_accel_max = 52.0
	_swirl.initial_velocity_min = 4.0
	_swirl.initial_velocity_max = 10.0
	_swirl.scale_amount_min = 1.0
	_swirl.scale_amount_max = 2.2
	_swirl.color = Color(1.0, 1.0, 1.0, 0.55)
	var mat2 := CanvasItemMaterial.new()
	mat2.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_swirl.material = mat2
	_swirl.emitting = false
	add_child(_swirl)

	# Occasional spark (flickering): sparse, quick, upward flecks — "the veil is trying to catch".
	_spark = CPUParticles2D.new()
	_spark.amount = 7
	_spark.lifetime = 1.1
	_spark.position = open_center
	_spark.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_spark.emission_sphere_radius = OPENING_W * 0.28
	_spark.direction = Vector2(0, -1)
	_spark.spread = 40.0
	_spark.gravity = Vector2(0, -8)
	_spark.initial_velocity_min = 10.0
	_spark.initial_velocity_max = 26.0
	_spark.scale_amount_min = 1.0
	_spark.scale_amount_max = 1.8
	_spark.color = Color(VIOLET_BRIGHT.r, VIOLET_BRIGHT.g, VIOLET_BRIGHT.b, 0.85)
	var mat3 := CanvasItemMaterial.new()
	mat3.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_spark.material = mat3
	_spark.emitting = false
	add_child(_spark)
