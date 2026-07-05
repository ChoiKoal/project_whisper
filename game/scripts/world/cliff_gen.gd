extends RefCounted
class_name CliffGen
## Programmatic iso cliff-face / seating-shadow generator (v0.5 phase A2 fix).
##
## The inherited CC0 "cliff_face_*" art is a single ~171px-tall rock monolith with no
## grass cap and a baked diamond foot; region-clipping a 32px level out of it produced
## thin, gappy slivers that did not connect the plateau to the ground (owner reject:
## "높이가 전혀 안 이어져 보임"). Instead we DRAW the cliff faces parametrically so every
## exposed raised edge is skirted exactly from the raised diamond bottom edge down to the
## lower ground surface, with zero black gaps by construction, plus a grass lip and an AO
## seat. The rock palette is sampled to match the CC0 rock tone.
##
## All geometry is pure integer iso math (128×64 diamond, 32px/level) so the game
## (map_loader.gd) and the review overview (tools_overview_v050a.js, which mirrors this
## exact logic in JS) render identically.

const TW := 128
const TH := 64
const HW := 64   # half width
const HH := 32   # half height
const LIFT := 32 # px per elevation level

# Rock palette (sampled from cliff_face_a mid-tones). Warm brown granite.
const ROCK_BASE := Color8(120, 96, 78)
const ROCK_DARK := Color8(72, 56, 44)
const ROCK_LIGHT := Color8(150, 122, 102)
const ROCK_SHADOW := Color8(46, 36, 30)
# Grass lip (top overhang) — matches t2a grass mid.
const GRASS_LIP := Color8(86, 128, 60)
const GRASS_LIP_DK := Color8(58, 92, 42)


## Deterministic value hash (mirrors MapLoader._cell_hash / the JS cellHash).
static func hash2(c: int, r: int, salt: int = 0) -> int:
	var h := (c * 73856093) ^ (r * 19349663) ^ (salt * 83492791) ^ 0x9E3779B9
	h = h & 0xFFFFFFFF
	h = (h ^ (h >> 13)) * 1274126177
	h = h & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return h & 0x7FFFFFFF


## A per-cell noise in [0,1] used to break up flat rock shading.
static func _rock_noise(px: int, py: int, seed: int) -> float:
	var h := hash2(px, py, seed)
	return float(h & 0xFFFF) / 65535.0


## Build a cliff-face apron Image for one raised cell.
##   drop      : number of levels the exposed front drops (>=1). Wall height = drop*LIFT.
##   expose_se : the +col (screen down-RIGHT) front edge faces lower ground.
##   expose_sw : the +row (screen down-LEFT) front edge faces lower ground.
## The returned Image is 128 wide and (LIFT*drop + TH) tall. Its logical anchor is the
## RAISED cell's diamond centre: blit at (center.x - 64, center.y - 32).
## The top 64px row contains the two front diamond edges; the wall hangs below; the last
## `TH/2` rows fold back into the lower diamond foot so the base seats on the ground.
static func make_apron(drop: int, expose_se: bool, expose_sw: bool, salt: int) -> Image:
	var wall := LIFT * drop
	var img_h := wall + TH
	var img := Image.create(TW, img_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Diamond geometry (relative to top-left of the 128-wide box; centre at x=64, y=32).
	# Top vertex   (64, 0)   ; Right (128,32) ; Bottom (64,64) ; Left (0,32).
	# The two FRONT edges are: Right→Bottom (SE, +col) and Left→Bottom (SW, +row).
	# For each screen column x we compute, on the raised diamond, the y of its front rim
	# (the lower silhouette of the diamond) and extrude straight down by `wall`, then fold
	# the very bottom back up into the lower diamond so the foot reads as ground.
	for x in range(TW):
		# front rim y of the raised diamond at column x (lower half of the diamond).
		# left half (0..64): rim rises from (0,32) to (64,64) => y = 32 + x/2
		# right half (64..128): rim from (64,64) to (128,32) => y = 64 - (x-64)/2
		var rim: float
		var is_left: bool = x < HW
		if is_left:
			rim = float(HH) + float(x) * 0.5
		else:
			rim = float(TW - x) * 0.5 + float(HH)  # = 64 - (x-64)/2 ... simplify below
		# The face on this column only exists if the corresponding front edge is exposed.
		var edge_exposed := expose_sw if is_left else expose_se
		if not edge_exposed:
			continue
		var rim_y := int(round(rim))
		var wall_top := rim_y
		var wall_bottom := rim_y + wall
		# Shade: SW (left) face darker, SE (right) face lighter (light from upper-right).
		var side_light := 1.10 if not is_left else 0.74
		for y in range(wall_top, wall_bottom):
			var t := float(y - wall_top) / float(max(1, wall)) # 0 top .. 1 bottom
			# vertical gradient: darker toward the base (AO into ground)
			var vshade := 1.0 - 0.30 * t
			# blocky rock facets: quantise a 2-octave noise into horizontal strata + vertical
			# cracks so the face reads as fractured stone, not smooth dirt.
			var strata: float = floor(_rock_noise(x / 6, y / 5, salt) * 5.0) / 5.0  # 0..0.8 bands
			var facet: float = (strata - 0.4) * 0.5
			var crack: float = -0.34 if (_rock_noise(x / 3, y / 7, salt + 5) < 0.14) else 0.0
			var n: float = _rock_noise(x, y, salt) * 0.12 - 0.06
			var col: Color = _rock_col(side_light * vshade + facet + crack + n)
			img.set_pixel(x, y, col)
		# Grass lip: a 5px grass overhang hanging over the very top of the wall so the
		# raised rim doesn't read as a razor cut.
		var lip_h := 5
		for y in range(wall_top, mini(wall_top + lip_h, img_h)):
			var g := GRASS_LIP if ((x + y) % 3 != 0) else GRASS_LIP_DK
			# ragged bottom edge of the lip
			var jag := int(_rock_noise(x, 7, salt) * 3.0)
			if y < wall_top + lip_h - jag:
				img.set_pixel(x, y, g)
	return img


## Map a shade scalar (~[0.4..1.2]) to a rock colour by lerping the palette.
static func _rock_col(s: float) -> Color:
	s = clampf(s, 0.0, 1.4)
	if s < 0.7:
		return ROCK_SHADOW.lerp(ROCK_DARK, clampf(s / 0.7, 0.0, 1.0))
	elif s < 1.0:
		return ROCK_DARK.lerp(ROCK_BASE, clampf((s - 0.7) / 0.3, 0.0, 1.0))
	else:
		return ROCK_BASE.lerp(ROCK_LIGHT, clampf((s - 1.0) / 0.4, 0.0, 1.0))


## Build a soft AO seating-shadow diamond that sits on the LOWER ground at the base of a
## cliff, so the hill reads as resting ON the ground. Returns a 128×64 image with a dark
## diamond fading out toward its edges. `strength` in [0,1].
static func make_ao_diamond(strength: float) -> Image:
	var img := Image.create(TW, TH, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# For each pixel inside the diamond, alpha = strength * (1 - normalized iso distance),
	# with a soft falloff so it feathers into the ground (~14px).
	for y in range(TH):
		for x in range(TW):
			# iso distance from centre in diamond metric: |dx|/HW + |dy|/HH <= 1 inside.
			var dx := absf(float(x - HW)) / float(HW)
			var dy := absf(float(y - HH)) / float(HH)
			var d := dx + dy
			if d > 1.0:
				continue
			# feather: full near the centre-band, fade over the outer ~40%.
			var a := clampf((1.0 - d) / 0.62, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, a * a * strength))
	return img


## Build a ramp slope image: a worn-dirt strip that visibly CLIMBS from the low side to
## the high side, with short rock side-walls, so the crossing reads as a slope not a flat
## tile. `dir` is the climb screen-direction: "ne"/"nw"/"se"/"sw" (toward the HIGH side).
## Returns a 128 × (LIFT + TH) image anchored like the apron (blit at center-64, center-32
## of the ramp's MID position).
static func make_ramp(dir: String, salt: int) -> Image:
	var h := LIFT + TH
	var img := Image.create(TW, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Dirt palette.
	var dirt := Color8(150, 120, 84)
	var dirt_dk := Color8(110, 86, 58)
	var dirt_lt := Color8(178, 146, 104)
	# The ramp surface is a diamond sheared along the climb axis: we draw the top diamond
	# (the walkable slope) plus a short front wall so the ramp has thickness.
	for y in range(TH):
		for x in range(TW):
			var dx := absf(float(x - HW)) / float(HW)
			var dy := absf(float(y - HH)) / float(HH)
			if dx + dy > 1.0:
				continue
			# climb gradient along the requested direction (lighter uphill, banded steps)
			var g := _ramp_grad(x, y, dir)
			var band := (int(g * 6.0) % 2 == 0)
			var n := _rock_noise(x, y, salt) * 0.12 - 0.06
			var base := dirt.lerp(dirt_lt, g) if band else dirt.lerp(dirt_dk, 1.0 - g)
			base = base.lerp(Color(base.r + n, base.g + n, base.b + n, 1.0), 0.6)
			base.a = 1.0
			img.set_pixel(x, y, base)
	# Short front wall (thickness) under the front rim so it isn't a floating flat tile.
	for x in range(TW):
		var is_left := x < HW
		var rim := (float(HH) + float(x) * 0.5) if is_left else (float(TW - x) * 0.5 + float(HH))
		var rim_y := int(round(rim))
		for y in range(rim_y, mini(rim_y + LIFT, h)):
			var t := float(y - rim_y) / float(LIFT)
			var c := dirt_dk.lerp(Color8(74, 58, 40), t)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func _ramp_grad(x: int, y: int, dir: String) -> float:
	# normalized position 0..1 along the climb axis (1 = high end).
	match dir:
		"se": return clampf(float(x) / float(TW), 0.0, 1.0)
		"nw": return clampf(1.0 - float(x) / float(TW), 0.0, 1.0)
		"sw": return clampf(float(y) / float(TH), 0.0, 1.0)
		_:    return clampf(1.0 - float(y) / float(TH), 0.0, 1.0) # ne
