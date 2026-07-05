extends SceneTree
## v0.5 ART FOUNDATION — tile slicer.
## Reads the CC0 rubberduck grassland source sheets from assets-src/grassland/ and
## produces the game's 128x64 iso-diamond tile PNGs into assets/tiles/.
##
## Source sheet layouts (verified by alpha-grid scan, see handoff-v050a.md):
##   grass_tiles.png / dirt_tiles.png : 8 col x 24 row of 128x64 diamonds.
##       4 colour BANDS of 6 rows each (band start rows 0,6,12,18). Within a band,
##       rows 0-1 are FULL solid diamonds; rows 2-5 are fringe/edge variants.
##   water_v01.png / water_v02.png : 6x6 of 128x64. This is a TILED water FIELD,
##       not per-cell diamonds — centre cells (rows 1-4, cols 1-4) are full-opacity
##       water texture. We take a full centre cell and apply our own diamond mask.
##
## Run: Godot --headless --path game --script res://tools_slice_tiles.gd
## Deterministic; safe to re-run. Writes only into assets/tiles/.

const SRC := "/workspace/group/project-whisper/assets-src/grassland/"
const OUT := "res://assets/tiles/"
const CW := 128
const CH := 64

var _cache := {}

func _load(name: String) -> Image:
	if _cache.has(name):
		return _cache[name]
	var img := Image.new()
	var err := img.load(SRC + name)
	if err != OK:
		push_error("slice: cannot load %s (%d)" % [name, err])
		return null
	img.convert(Image.FORMAT_RGBA8)
	_cache[name] = img
	return img

## Extract one 128x64 grid cell (col,row) from a sheet.
func _cell(sheet: String, col: int, row: int) -> Image:
	var img := _load(sheet)
	if img == null:
		return null
	return img.get_region(Rect2i(col * CW, row * CH, CW, CH))

## A crisp iso-diamond alpha mask: |x/64 - 1| + |y/32 - 1| <= 1 (with 1px AA).
func _diamond_alpha(x: int, y: int) -> float:
	var dx: float = abs(float(x) - 63.5) / 64.0
	var dy: float = abs(float(y) - 31.5) / 32.0
	var d := dx + dy
	if d <= 0.97:
		return 1.0
	elif d <= 1.03:
		return 1.0 - (d - 0.97) / 0.06
	return 0.0

## Apply a diamond mask to a full-rectangle texture cell → a clean iso diamond.
func _mask_diamond(src: Image) -> Image:
	var out := Image.create(CW, CH, false, Image.FORMAT_RGBA8)
	for y in range(CH):
		for x in range(CW):
			var a := _diamond_alpha(x, y)
			if a <= 0.0:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var c := src.get_pixel(x, y)
			c.a = a
			out.set_pixel(x, y, c)
	return out

## Colour transform helper: per-pixel callable(Color)->Color over opaque pixels.
func _transform(src: Image, fn: Callable) -> Image:
	var out := Image.create(CW, CH, false, Image.FORMAT_RGBA8)
	for y in range(CH):
		for x in range(CW):
			var c := src.get_pixel(x, y)
			if c.a > 0.01:
				out.set_pixel(x, y, fn.call(c, x, y))
			else:
				out.set_pixel(x, y, c)
	return out

## Horizontal 2-frame strip (256x64) from two 128x64 diamonds, for atlas animation.
func _strip2(a: Image, b: Image) -> Image:
	var out := Image.create(CW * 2, CH, false, Image.FORMAT_RGBA8)
	out.blend_rect(a, Rect2i(0, 0, CW, CH), Vector2i(0, 0))
	out.blend_rect(b, Rect2i(0, 0, CW, CH), Vector2i(CW, 0))
	return out


func _save(img: Image, name: String) -> void:
	var p := OUT + name
	var err := img.save_png(ProjectSettings.globalize_path(p))
	if err != OK:
		push_error("slice: save failed %s (%d)" % [name, err])
	else:
		print("  wrote ", name)

func _init() -> void:
	print("== slicing tiles ==")

	# ---- GRASS variants (full solid diamonds) ----
	# T2A base: band 2 plain (calm mid green), row 12 col 2.
	_save(_cell("grass_tiles.png", 2, 12), "t2a_grass.png")
	# T2B flowered: band 0 speckled, row 0 col 0.
	_save(_cell("grass_tiles.png", 0, 0), "t2b_grass_flowers.png")
	# T2C clover: band 0 variant, row 1 col 3.
	_save(_cell("grass_tiles.png", 3, 1), "t2c_grass_clover.png")
	# T2D bright flower-grass: band 3 brighter, row 18 col 0.
	_save(_cell("grass_tiles.png", 0, 18), "t2d_flower_grass.png")

	# ---- DIRT ----
	# T1: dirt band 0 clean tan, row 0 col 0.
	_save(_cell("dirt_tiles.png", 0, 0), "t1_dirt.png")

	# ---- MUD (T4): darker dirt band 1, wet/desaturated ----
	var mud_src := _cell("dirt_tiles.png", 1, 6)
	var mud := _transform(mud_src, func(c, x, y):
		# darken to ~0.6, pull toward a cool wet brown, slight desaturation.
		var r: float = c.r * 0.62
		var g: float = c.g * 0.60
		var b: float = c.b * 0.66  # keep a touch more blue → wet look
		return Color(r, g, b, c.a))
	_save(mud, "t4_mud.png")

	# ---- WATER (T5A / T5B animated frames) ----
	# Take a full-opacity centre cell from each water field and diamond-mask it.
	var w1 := _cell("water_v01.png", 2, 2)   # frac 1.0 centre
	var w2 := _cell("water_v02.png", 2, 3)   # frac 1.0 centre (darker frame)
	# A third, slightly-shifted ripple frame from a neighbouring centre cell so the
	# animation reads as moving water rather than a 2-frame flicker.
	var w1b := _cell("water_v01.png", 3, 2)
	var w2b := _cell("water_v02.png", 3, 3)
	var d1 := _mask_diamond(w1)
	var d1b := _mask_diamond(w1b)
	var d2 := _mask_diamond(w2)
	var d2b := _mask_diamond(w2b)
	_save(d1, "t5a_water.png")
	_save(d2, "t5b_water2.png")
	# Horizontal 2-frame animation strips (256x64) for TileSet atlas animation.
	# T5A shimmer: light(v01) -> light-shifted; T5B: dark(v02) -> dark-shifted.
	_save(_strip2(d1, d1b), "t5a_water_anim.png")
	_save(_strip2(d2, d2b), "t5b_water2_anim.png")

	# ---- MYSTIC (T5M): water v01 tinted violet ----
	var mystic := _transform(w1, func(c, x, y):
		# push hue toward violet: boost blue+red, drop green; lift luminance a touch.
		var r: float = clampf(c.r * 1.15 + 0.22, 0.0, 1.0)
		var g: float = clampf(c.g * 0.70, 0.0, 1.0)
		var b: float = clampf(c.b * 1.10 + 0.30, 0.0, 1.0)
		return Color(r, g, b, c.a))
	_save(_mask_diamond(mystic), "t5m_mystic.png")
	# t5m_mystic_glow variant (brighter core for the glow overlay), kept for compat.
	var mystic_glow := _transform(w1, func(c, x, y):
		var r: float = clampf(c.r * 1.2 + 0.35, 0.0, 1.0)
		var g: float = clampf(c.g * 0.75 + 0.10, 0.0, 1.0)
		var b: float = clampf(c.b * 1.15 + 0.45, 0.0, 1.0)
		return Color(r, g, b, c.a))
	_save(_mask_diamond(mystic_glow), "t5m_mystic_glow.png")

	# ---- HOLLOW (T0): dirt darkened heavily + violet rim ----
	# Base from dirt band 1, darkened to a deep inset; add a violet rim near the
	# diamond edge so a gathered/void hollow reads as a walkable dark inset.
	var hol_src := _cell("dirt_tiles.png", 3, 7)
	var hollow := Image.create(CW, CH, false, Image.FORMAT_RGBA8)
	for y in range(CH):
		for x in range(CW):
			var a := _diamond_alpha(x, y)
			if a <= 0.0:
				hollow.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var c := hol_src.get_pixel(x, y)
			# rim factor: near the diamond edge (d close to 1) → violet glow.
			var dx: float = abs(float(x) - 63.5) / 64.0
			var dy: float = abs(float(y) - 31.5) / 32.0
			var d := dx + dy
			var rim: float = clampf((d - 0.62) / 0.38, 0.0, 1.0)
			# deep-dark inset base
			var base := Color(c.r * 0.22, c.g * 0.20, c.b * 0.26, a)
			# violet rim mix
			var violet := Color(0.42, 0.20, 0.55, a)
			var mixv: float = rim * 0.55
			hollow.set_pixel(x, y, base.lerp(violet, mixv))
	_save(hollow, "t0_hollow.png")

	# ---- VOID (T0 outer): pure dark diamond (island edge / off-map) ----
	# Keep the existing t0_void look: very dark, faint cool tint, full diamond.
	var void_img := Image.create(CW, CH, false, Image.FORMAT_RGBA8)
	for y in range(CH):
		for x in range(CW):
			var a := _diamond_alpha(x, y)
			if a <= 0.0:
				void_img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				void_img.set_pixel(x, y, Color(0.06, 0.06, 0.09, a))
	_save(void_img, "t0_void.png")

	print("== done ==")
	quit()
