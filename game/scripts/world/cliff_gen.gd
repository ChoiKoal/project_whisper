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

# (L2-2) Metal-and-concrete cliff palette for the Layer-2 station (파손 금속 단면). Same geometry
# as the rock apron, recolored to the 남색 metal ramp + a concrete cap lip. Selected by the
# `metal` flag on make_apron (default false → the grove rock palette, unchanged).
const M_BASE := Color8(58, 68, 82)
const M_DARK := Color8(34, 42, 56)
const M_LIGHT := Color8(90, 100, 114)
const M_SHADOW := Color8(20, 26, 38)
const M_LIP := Color8(74, 78, 86)      # concrete cap
const M_LIP_DK := Color8(48, 52, 58)
const M_CYAN := Color8(74, 217, 200)   # conduit leak accent

# (L3-1) Copper/brass cliff palette for the Layer-3 machine city 「태엽이 멈춘 도시」 (구리/황동
# 단면). Same geometry as the metal apron, recolored warm (구리 base + 황동 램프 + a brass cap
# lip + a 주황 잔열 conduit weep instead of the L2 cyan). Selected by the `brass` flag.
const B_BASE := Color8(90, 74, 52)     # 구리/황동 base
const B_DARK := Color8(58, 44, 30)
const B_LIGHT := Color8(200, 162, 74)  # 밝은 황동 하이라이트
const B_SHADOW := Color8(36, 26, 16)
const B_LIP := Color8(138, 106, 52)    # brass cap
const B_LIP_DK := Color8(90, 68, 36)
const B_EMBER := Color8(232, 132, 44)  # 식어가는 잔열 (주황) conduit weep

# (L4-1) Amethyst/gold cliff palette for the Layer-4 magic tower 「봉인이 풀린 마탑」 (자수정 보라
# 단면). Same geometry as the metal/brass apron, recolored arcane (자수정 base + 보라 램프 + a
# violet cap lip + a 금색 룬 weep instead of the L3 주황). Selected by the `amethyst` flag.
const A_BASE := Color8(74, 54, 112)     # 자수정 보라 base
const A_DARK := Color8(48, 34, 78)
const A_LIGHT := Color8(122, 92, 174)   # 밝은 자수정 하이라이트
const A_SHADOW := Color8(34, 24, 56)
const A_LIP := Color8(100, 70, 150)     # amethyst cap
const A_LIP_DK := Color8(64, 44, 100)
const A_GOLD := Color8(242, 193, 78)    # 금색 룬 weep


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
static func make_apron(drop: int, expose_se: bool, expose_sw: bool, salt: int, metal: bool = false, brass: bool = false, amethyst: bool = false) -> Image:
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
			var shade := side_light * vshade + facet + crack + n
			var col: Color
			if amethyst:
				col = _amethyst_col(shade)
			elif brass:
				col = _brass_col(shade)
			elif metal:
				col = _metal_col(shade)
			else:
				col = _rock_col(shade)
			# (L2-2/L3-1) metal/brass cliff: a riveted strata line + an occasional conduit seam
			# (cyan leak for L2, 주황 잔열 weep for L3).
			if amethyst:
				if (y - wall_top) % 20 < 1:
					col = col.lerp(A_LIGHT, 0.4)                # amethyst rivet band
				elif not is_left and (_rock_noise(x / 9, 0, salt + 3) < 0.06):
					col = col.lerp(A_GOLD, 0.5)                 # 금색 룬 weep
			elif brass:
				if (y - wall_top) % 20 < 1:
					col = col.lerp(B_LIGHT, 0.4)                # brass rivet band
				elif not is_left and (_rock_noise(x / 9, 0, salt + 3) < 0.06):
					col = col.lerp(B_EMBER, 0.5)                # 식어가는 잔열 weep
			elif metal:
				if (y - wall_top) % 20 < 1:
					col = col.lerp(M_LIGHT, 0.4)                # rivet band
				elif not is_left and (_rock_noise(x / 9, 0, salt + 3) < 0.06):
					col = col.lerp(M_CYAN, 0.5)                 # leaking conduit
			img.set_pixel(x, y, col)
		# Cap lip: a 5px overhang so the raised rim doesn't read as a razor cut — grass for the
		# grove, concrete for the metal (L2) cliff.
		var lip_h := 5
		for y in range(wall_top, mini(wall_top + lip_h, img_h)):
			var g: Color
			if amethyst:
				g = A_LIP if ((x + y) % 3 != 0) else A_LIP_DK
			elif brass:
				g = B_LIP if ((x + y) % 3 != 0) else B_LIP_DK
			elif metal:
				g = M_LIP if ((x + y) % 3 != 0) else M_LIP_DK
			else:
				g = GRASS_LIP if ((x + y) % 3 != 0) else GRASS_LIP_DK
			# ragged bottom edge of the lip
			var jag := int(_rock_noise(x, 7, salt) * 3.0)
			if y < wall_top + lip_h - jag:
				img.set_pixel(x, y, g)
	return img


## (L2-2) Map a shade scalar to a metal-and-concrete colour (parallel to _rock_col).
static func _metal_col(s: float) -> Color:
	s = clampf(s, 0.0, 1.4)
	if s < 0.7:
		return M_SHADOW.lerp(M_DARK, clampf(s / 0.7, 0.0, 1.0))
	elif s < 1.0:
		return M_DARK.lerp(M_BASE, clampf((s - 0.7) / 0.3, 0.0, 1.0))
	else:
		return M_BASE.lerp(M_LIGHT, clampf((s - 1.0) / 0.4, 0.0, 1.0))


## (L3-1) Map a shade scalar to a copper/brass colour (parallel to _metal_col, warm palette).
static func _brass_col(s: float) -> Color:
	s = clampf(s, 0.0, 1.4)
	if s < 0.7:
		return B_SHADOW.lerp(B_DARK, clampf(s / 0.7, 0.0, 1.0))
	elif s < 1.0:
		return B_DARK.lerp(B_BASE, clampf((s - 0.7) / 0.3, 0.0, 1.0))
	else:
		return B_BASE.lerp(B_LIGHT, clampf((s - 1.0) / 0.4, 0.0, 1.0))


## (L4-1) Map a shade scalar to an amethyst/violet colour (parallel to _brass_col, arcane palette).
static func _amethyst_col(s: float) -> Color:
	s = clampf(s, 0.0, 1.4)
	if s < 0.7:
		return A_SHADOW.lerp(A_DARK, clampf(s / 0.7, 0.0, 1.0))
	elif s < 1.0:
		return A_DARK.lerp(A_BASE, clampf((s - 0.7) / 0.3, 0.0, 1.0))
	else:
		return A_BASE.lerp(A_LIGHT, clampf((s - 1.0) / 0.4, 0.0, 1.0))


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


## Violet whisper glow — the sealed theme colour, used faintly at the shard's deep tip.
const WHISPER_VIOLET := Color8(150, 118, 214)
## Deep bluish shadow rock cast the whole underside is cooled toward (the hidden root).
const UNDER_SHADOW := Color8(40, 38, 56)
const UNDER_SHADOW_DEEP := Color8(26, 22, 40)
## Mossy grass rim colours for the lip that hangs just under the island's jagged bottom.
const UNDER_MOSS := Color8(74, 110, 54)
const UNDER_MOSS_DK := Color8(48, 78, 40)

## (#257 v1.10.1) Build the rocky UNDERSIDE of the floating home-island shard as irregular
## BEDROCK — no longer a flat dirt wedge tapering straight to a point. The top edge hugs the
## island's actual jagged bottom outline (`top_profile`, so left/right gaps are closed), the
## silhouette descends in stepped/uneven layers with 2-3 strata bands (dark rock → darker
## deep rock), and a faint violet whisper-glow warms the deepest tip. Same warm-rock noise
## vocabulary as the cliff faces, now organised by banding instead of a smooth cone.
##
## Returns an image `span` wide × `depth` tall. Anchored so its top-centre sits a little above
## the island's bottom vertex: blit at (bottom_vertex.x - span/2, bottom_vertex.y - top_pad).
##   span         : full screen width of the island slab (px) — image width.
##   depth        : how far the mass hangs down (px).
##   top_profile  : per-column top y (px from image top) where the island's bottom rim sits
##                  above column x, or < 0 for columns with NO island above them (no rock is
##                  drawn there → the top edge follows the real 톱니 outline, no gap). May be
##                  empty → falls back to a flat top row (legacy behaviour) for callers that
##                  don't supply an outline.
## Smooth 1-D value noise in [0,1] (linear-interpolated between integer samples) — wobbles the
## silhouette CONTINUOUSLY down the body so the edge never jumps by whole steps row-to-row (that
## row jump was the left-side horizontal streak). Mirrors the JS snoise1.
static func _snoise1(t: float, salt: int) -> float:
	var i := int(floor(t))
	var f := t - float(i)
	var a := _rock_noise(i, salt, salt + 3)
	var b := _rock_noise(i + 1, salt, salt + 3)
	var u := f * f * (3.0 - 2.0 * f)
	return a + (b - a) * u


## Per-column jagged offset (px) of a sediment-band boundary y, so the seam is an organic 지그재그
## 침식 노치 rather than a straight ruler line. Smooth in x, deterministic per band index.
static func _shelf_edge_offset(x: int, band_i: int, salt: int) -> float:
	return (_snoise1(float(x) / 26.0, salt + band_i * 131) - 0.5) * 22.0 \
		 + (_snoise1(float(x) / 7.0, salt + band_i * 57) - 0.5) * 7.0


## (#257 v1.10.3, 멤쵸 판정) 3개 로브 구조. 하나의 대칭 원뿔 대신 크기·깊이가 다른 2~3개의
## 겹치는 암반 로브(lobe)로 실루엣을 합성한다. 각 로브는 자체 중심·폭·깊이를 가지며, 로브
## 사이는 깊은 그림자 골(gully)로 갈라진다. 중앙 돌출(꼬리)은 넓고 짧게(로브 폭↑, hang↓).
## 지층 대비를 한 단계 강화하고 점묘 노이즈를 지층·로브 구조를 따라 클러스터링(균일 안개 제거).
## 반환값은 로브들의 하단 실루엣을 담는 (per-column) bottom profile 계산에 쓰인다.
##   반환: 각 로브 = {cx, half, top, bottom, salt}. make_underside 내부에서만 사용.
static func _underside_lobes(span: int, depth: int, rim_cx: float, rim_half: float, salt: int) -> Array:
	var lobes := []
	# 3개의 겹치는 암반 로브 — 크기·깊이·중심이 뚜렷이 다르다(비대칭). 좌·중(가장 깊고 넓음)·우.
	# 로브 사이 컬럼에서 실루엣이 위로 후퇴하며 깊은 그림자 골(gully)이 생기도록 배치 오프셋을 크게.
	# 로브별 정규화 중심 오프셋(×rim_half)과 상대 폭·깊이 계수. 메인(가운데)이 가장 크고 깊다.
	var specs := [
		Vector3(-0.66, 0.52, 0.60),   # 좌 로브: 얕고 좁음
		Vector3( 0.05, 0.86, 0.98),   # 중앙(메인): 넓고 가장 깊음 — 넓고 짧은 돌출
		Vector3( 0.62, 0.60, 0.72),   # 우 로브: 중간
	]
	for i in range(specs.size()):
		var sp: Vector3 = specs[i]
		var s := salt + 100 + i * 29
		# 결정적 지터로 대칭 깨기.
		var jx := (_rock_noise(s, 3, s + 2) - 0.5) * 0.22
		var jw := 0.85 + _rock_noise(s, 4, s + 3) * 0.30
		var jd := 0.85 + _rock_noise(s, 5, s + 4) * 0.28
		var lcx := rim_cx + (sp.x + jx) * rim_half
		var lhalf := rim_half * sp.y * jw
		var lbot := depth * sp.z * jd
		lobes.append({"cx": lcx, "half": lhalf, "bot": lbot, "salt": s, "main": i == 1})
	return lobes


## 한 컬럼 x에서 로브들의 결합 하단 실루엣(bottom y)과 그 컬럼을 지배하는 로브의 국소 hx,
## 로브 간 골(gully) 깊이를 계산. 반환 [bottom_y, dominant_hx, gully].
static func _lobe_at(lobes: Array, x: float, salt: int) -> Array:
	var best_bot := -1.0
	var dom_hx := 1.0
	var second_bot := -1.0
	for lb in lobes:
		var lcx: float = lb["cx"]
		var lhalf: float = lb["half"]
		# 로브 실루엣: 반원형 돔의 하단 + 컬럼별 부드러운 침식 워블.
		var dx := (x - lcx) / maxf(1.0, lhalf)
		if absf(dx) >= 1.0:
			continue
		# 가파른 돔(pow 0.72)으로 로브 사이 컬럼은 위로 크게 후퇴 → 뚜렷한 골. 바닥 floor를 낮춤.
		var dome := pow(maxf(0.0, 1.0 - dx * dx), 0.72)     # 0 가장자리 .. 1 중앙
		# 저주파 워블(x/55)만 — 이전 x/22·0.16은 균일 톱니 커튼을 만들었다(멤쵸 "균일 스탈락타이트").
		# 로브 실루엣은 매끈한 둥근 바위로, 실루엣 변주는 로브 배치와 소수의 hanger가 담당.
		var wob := (_snoise1(x / 55.0, lb["salt"]) - 0.5) * 0.07
		var bot: float = lb["bot"] * (dome * (0.93 + wob) + 0.10)
		if bot > best_bot:
			second_bot = best_bot
			best_bot = bot
			dom_hx = absf(dx)
		elif bot > second_bot:
			second_bot = bot
	# 골: 두 로브가 겹치는 컬럼에서 실루엣이 두 번째 로브 근처까지 파고들면 그림자 골.
	var gully := 0.0
	if second_bot > 0.0 and best_bot > 0.0:
		gully = clampf(1.0 - absf(best_bot - second_bot) / (best_bot * 0.5 + 1.0), 0.0, 1.0)
	return [best_bot, dom_hx, gully]


static func make_underside(span: int, depth: int, salt: int, top_profile: PackedFloat32Array = PackedFloat32Array()) -> Image:
	var img := Image.create(span, depth, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var have_profile := top_profile.size() == span
	# Horizontal extent of the island footprint at the top (leftmost / rightmost column that
	# actually has island above it).
	var rim_l := 0.0
	var rim_r := float(span)
	if have_profile:
		rim_l = float(span)
		rim_r = 0.0
		for x in range(span):
			if top_profile[x] >= 0.0:
				rim_l = minf(rim_l, float(x))
				rim_r = maxf(rim_r, float(x) + 1.0)
		if rim_r <= rim_l:
			rim_l = 0.0
			rim_r = float(span)
	var rim_cx := (rim_l + rim_r) * 0.5
	var rim_half := maxf(2.0, (rim_r - rim_l) * 0.5)
	var nb := 5   # sediment bands
	# 로브 실루엣을 미리 계산 (per-column bottom / hx / gully).
	var lobes := _underside_lobes(span, depth, rim_cx, rim_half, salt)
	var col_bot := PackedFloat32Array(); col_bot.resize(span)
	var col_hx := PackedFloat32Array(); col_hx.resize(span)
	var col_gully := PackedFloat32Array(); col_gully.resize(span)
	for x in range(span):
		var la := _lobe_at(lobes, float(x), salt)
		col_bot[x] = la[0]
		col_hx[x] = la[1]
		col_gully[x] = la[2]
	for y in range(depth):
		var ty := float(y) / float(depth)              # 0 top .. 1 bottom
		for x in range(span):
			# Respect the island's real bottom outline near the top: skip columns with no
			# island above them, and don't draw ABOVE where the rim actually is.
			var top_y := 0.0
			if have_profile:
				top_y = top_profile[x]
				if top_y < 0.0:
					continue
				if float(y) < top_y:
					continue
			var bot := col_bot[x]
			if bot <= 0.0 or float(y) > bot:
				continue
			var hx: float = col_hx[x]
			var gully: float = col_gully[x]
			# local vertical position within THIS column's rock mass (0 top .. 1 lobe bottom).
			var ly := clampf((float(y) - top_y) / maxf(1.0, bot - top_y), 0.0, 1.0)
			# STRATA BANDS — one step stronger contrast than before (멤쵸 #3). Jagged per-column seam.
			var band_f := ty * nb
			var nearest_seam := int(round(band_f))
			var seam_y := float(nearest_seam) / float(nb) * float(depth) + _shelf_edge_offset(x, nearest_seam, salt)
			var dist_to_seam := float(y) - seam_y
			var band_i := clampi(int(band_f), 0, nb - 1)
			var band := 0.98 - 0.090 * band_i                    # 강화된 밴드 간 대비 (was 0.055)
			band += (0.055 if (band_i % 2 == 0) else -0.045)     # 밴드 명암 강화 (was ±0.028/0.02)
			# CLUSTERED faceted strata — 노이즈를 지층(수평 스트라이프) + 로브 구조를 따라 뭉친다.
			# 균일 분포 대신 큰 블록(x/9,y/4) 클러스터를 만들어 안개가 아닌 바위 질감으로 읽히게.
			var cluster: float = floor(_rock_noise(x / 9, y / 4, salt) * 4.0) / 4.0     # 0..0.75 큰 얼룩
			var strata: float = floor(_rock_noise(x / 6, y / 5, salt + 2) * 5.0) / 5.0  # 지층 세부
			var facet: float = (cluster - 0.375) * 0.42 + (strata - 0.4) * 0.30         # 강화된 대비
			var crack: float = -0.34 if (_rock_noise(x / 3, y / 6, salt + 5) < 0.15) else 0.0
			# seam notch (jagged, dithered).
			var seam := 0.0
			if absf(dist_to_seam) < 2.6:
				var dith := ((x * 7 + y * 3 + int(_rock_noise(x, y, salt + 9) * 4.0)) & 3) != 0
				if dith:
					seam = -0.30 * (1.0 - absf(dist_to_seam) / 2.6)
			var edge := -0.40 * hx * hx                          # rounded rock sides
			# GULLY: deep shadow gorge between overlapping lobes.
			var gsh := -0.55 * gully
			var n: float = _rock_noise(x, y, salt) * 0.12 - 0.06
			var col := _rock_col(band + facet + crack + seam + edge + gsh + n)
			# cool toward a bluish shadow — LESS than before so the underside isn't washed/foggy
			# and stays close to surface brightness (멤쵸: 흐리지 않게 전체 명도/샤프니스 점검).
			col = col.lerp(UNDER_SHADOW, 0.08 + 0.14 * ty)
			col = col.lerp(UNDER_SHADOW_DEEP, clampf((ly - 0.60) / 0.40, 0.0, 1.0) * 0.34)
			# violet whisper rim-glow — weighted to the rounded SIDES / gully so it rims the rock.
			if ty > 0.42:
				var glow := clampf((ty - 0.42) / 0.58, 0.0, 1.0) * (0.10 + 0.42 * hx * hx) * 0.50
				col = col.lerp(WHISPER_VIOLET, glow)
			# moss/grass lip on the very first exposed rows under the island rim.
			if have_profile and float(y) - top_y < 4.0 and hx < 0.92:
				col = UNDER_MOSS if ((x + y) % 3 != 0) else UNDER_MOSS_DK
			# HARD-ish eroded edge (no foggy alpha feather that read as haze — 멤쵸 "안개 덩어리").
			# Only a 1px dithered rim; interior stays fully opaque, crisp rock.
			var a := 1.0
			if hx > 0.90:
				a = 1.0 if ((x + y) & 1) == 0 else 0.35          # 1px 지그재그 침식 rim (not a soft gradient)
			if float(y) > bot - 2.0:
				a = 1.0 if ((x + y) & 1) == 0 else 0.35
			col.a = a
			img.set_pixel(x, y, col)
	# ---- hanging rock chunks + stalactites (asymmetric, 2-4) --------------------------------
	_underside_hangers(img, span, depth, rim_cx, rim_half, salt)
	return img


## Paint a few asymmetric hanging rock chunks and stalactite spikes onto the underside, so the
## silhouette reads as broken bedrock rather than a clean wedge. Deterministic per salt.
static func _underside_hangers(img: Image, span: int, depth: int, rim_cx: float, rim_half: float, salt: int) -> void:
	# Fewer, CHUNKIER hangers (멤쵸: 균일한 스탈락타이트 커튼 제거) — mostly blocky rock nubs, only
	# an occasional thin spike, biased off-centre for asymmetry.
	var count := 2 + int(_rock_noise(salt, 3, salt + 21) * 2.0)   # 2..3
	for i in range(count):
		var s := salt + 40 + i * 17
		# anchor somewhere across the width, biased off-centre (asymmetry).
		var ax := rim_cx + (_rock_noise(s, 1, s + 2) - 0.5) * 2.0 * rim_half * 0.85
		var ay := depth * (0.34 + _rock_noise(s, 2, s + 3) * 0.42)  # hang from mid-body
		var is_spike := _rock_noise(s, 4, s + 5) > 0.70            # spikes are the exception now
		var chunk_h := depth * (0.10 + _rock_noise(s, 6, s + 7) * 0.16)
		var chunk_w := (span * 0.05) + _rock_noise(s, 8, s + 9) * span * 0.055   # chunkier
		if is_spike:
			chunk_w *= 0.55   # stalactites are thin
			chunk_h *= 1.4
		for dy in range(int(chunk_h)):
			var t := float(dy) / maxf(1.0, chunk_h)
			# spikes taper hard to a point; chunks taper gently (blocky nub).
			var w := chunk_w * (pow(1.0 - t, 2.2) if is_spike else (1.0 - t * 0.55))
			var yy := int(ay + dy)
			if yy < 0 or yy >= depth:
				continue
			for dx in range(int(-w), int(w) + 1):
				var xx := int(ax) + dx
				if xx < 0 or xx >= span:
					continue
				var sdx := float(dx) / maxf(1.0, w)      # -1 left .. +1 right within the nub
				var hx := absf(sdx)
				# Recessed rounded RELIEF, cooled into the body — a gentle lit-left/shadow-right
				# volume that stays DARKER than the surrounding rock (never a bright tan cup/spike).
				var spine := (1.0 - hx) * 0.16
				var shade := 0.60 - 0.26 * t - 0.16 * sdx + spine
				var col := _rock_col(shade + _rock_noise(xx, yy, s) * 0.09 - 0.045)
				col = col.lerp(UNDER_SHADOW, 0.34 + 0.22 * t)
				col = col.lerp(UNDER_SHADOW_DEEP, clampf((t - 0.3) / 0.7, 0.0, 1.0) * 0.35)
				if t > 0.45:
					col = col.lerp(WHISPER_VIOLET, (t - 0.45) / 0.55 * (0.46 if is_spike else 0.34))
				col.a = 1.0 if t < 0.85 else clampf((1.0 - t) / 0.15, 0.0, 1.0)
				var existing := img.get_pixel(xx, yy)
				# chunks are relief carved INTO the body (only where rock exists); a spike may
				# protrude a short way past the body's lower edge as a short hanging tip.
				if existing.a > 0.0 or (is_spike and t > 0.6):
					img.set_pixel(xx, yy, col)


## (v0.5d) Build a small floating debris islet: a tiny rock chunk (top diamond nub + a short
## tapering underside) that drifts near the main island. Returns a compact image; anchored by
## its top-centre. `w` ~ 40-90 px. Deterministic per salt.
static func make_debris(w: int, salt: int) -> Image:
	var top_h := int(w * 0.42)
	var under_h := int(w * 0.7)
	var h := top_h + under_h
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := w * 0.5
	# top: a small grass-capped rock diamond nub.
	for y in range(top_h):
		var ty := float(y) / float(top_h)
		var half := (w * 0.5) * (0.55 + 0.45 * ty)   # widen toward its base
		for x in range(int(cx - half), int(cx + half)):
			if x < 0 or x >= w:
				continue
			var strata: float = floor(_rock_noise(x / 4, y / 4, salt) * 4.0) / 4.0
			var facet: float = (strata - 0.4) * 0.4
			var n: float = _rock_noise(x, y, salt) * 0.10 - 0.05
			var col := _rock_col(0.9 + facet + n)
			# grass lip on the very top rows
			if y < 4:
				col = GRASS_LIP if ((x + y) % 3 != 0) else GRASS_LIP_DK
			col.a = 1.0
			img.set_pixel(x, y, col)
	# underside: short taper to a point.
	for y in range(under_h):
		var ty2 := float(y) / float(under_h)
		var half := (w * 0.5) * pow(1.0 - ty2, 1.3)
		for x in range(int(cx - half), int(cx + half)):
			if x < 0 or x >= w:
				continue
			var vshade := 0.6 - 0.4 * ty2
			var n: float = _rock_noise(x, top_h + y, salt) * 0.10 - 0.05
			var col := _rock_col(vshade + n).lerp(Color8(40, 38, 56), 0.35)
			col.a = 1.0 if ty2 < 0.85 else clampf((1.0 - ty2) / 0.15, 0.0, 1.0)
			img.set_pixel(x, top_h + y, col)
	return img
