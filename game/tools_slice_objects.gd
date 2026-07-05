extends SceneTree
## v0.5 ART FOUNDATION — object + cliff/rock slicer.
## Produces object PNGs (trees, bushes, flowers, rocks, dry bush, world tree) and
## terrain PNGs (cliff faces, continuous rock-wall ridge pieces) from the CC0
## rubberduck source sheets.
##
## Sources (see handoff-v050a.md for the full slicing map):
##   trees:        assets-src/trees/isometric_trees_01.png  (10 cols x ~28 rows, 384px cells;
##                 top ~14 rows GREEN trees, bottom ~14 rows BARE/DEAD trees)
##   cliffs/rocks: assets-src/grassland/grassland_1x1.png   (top y0..2048 = iso rock cliff
##                 pillars in 2-grid-row-tall pieces; y2176+ = small foliage bushes/tufts)
##   boulders:     assets-src/grassland/rock_cliffs.png
##
## Run: Godot --headless --path game --script res://tools_slice_objects.gd

const OUT := "res://assets/objects/"
const TOUT := "res://assets/tiles/"
const TREES := "/workspace/group/project-whisper/assets-src/trees/isometric_trees_01.png"
const S1 := "/workspace/group/project-whisper/assets-src/grassland/grassland_1x1.png"
const ROCKS := "/workspace/group/project-whisper/assets-src/grassland/rock_cliffs.png"

var _cache := {}

func _img(path: String) -> Image:
	if _cache.has(path):
		return _cache[path]
	var im := Image.new()
	if im.load(path) != OK:
		push_error("cannot load " + path)
		return null
	im.convert(Image.FORMAT_RGBA8)
	_cache[path] = im
	return im

## Tight alpha bbox of a region; returns cropped Image (trimmed to opaque content).
func _tight(src: Image, rx: int, ry: int, rw: int, rh: int, athresh: float = 0.35) -> Image:
	var minx := rw
	var miny := rh
	var maxx := 0
	var maxy := 0
	var any := false
	for y in range(rh):
		for x in range(rw):
			if src.get_pixel(rx + x, ry + y).a > athresh:
				any = true
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	if not any:
		return Image.create(2, 2, false, Image.FORMAT_RGBA8)
	var w := maxx - minx + 1
	var h := maxy - miny + 1
	return src.get_region(Rect2i(rx + minx, ry + miny, w, h))

func _save(img: Image, dir: String, name: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(dir + name))
	if err != OK:
		push_error("save fail " + name)
	else:
		print("  %s  %dx%d" % [name, img.get_width(), img.get_height()])

## Scale an image to a target HEIGHT preserving aspect (nearest for crispness).
func _scale_h(img: Image, target_h: int) -> Image:
	var h := img.get_height()
	if h == 0:
		return img
	var w := img.get_width()
	var nw := maxi(1, int(round(float(w) * target_h / h)))
	var out := img.duplicate()
	out.resize(nw, target_h, Image.INTERPOLATE_LANCZOS)
	return out

func _init() -> void:
	print("== slicing objects ==")
	var trees := _img(TREES)
	var s1 := _img(S1)
	var rocks := _img(ROCKS)

	# ---- TREES (green) : exact per-sprite bboxes from tools_segment_trees scan ----
	# [x, y, w, h] tight bounding boxes of clean, isolated single trees.
	var t_a := trees.get_region(Rect2i(1193, 419, 267, 274))   # band1[3] round medium
	var t_b := trees.get_region(Rect2i(502, 1157, 248, 316))   # band3[1] tall
	var t_c := trees.get_region(Rect2i(3109, 407, 269, 279))   # band1[8] broad
	_save(_scale_h(t_a, 232), OUT, "tree_a.png")
	_save(_scale_h(t_b, 244), OUT, "tree_b.png")
	_save(_scale_h(t_c, 222), OUT, "tree_c.png")

	# world tree: the biggest lush green tree.
	var wt := trees.get_region(Rect2i(3085, 1152, 326, 313))   # band3[8]
	_save(_scale_h(wt, 470), OUT, "world_tree.png")
	# young_tree: a smaller green tree.
	var yt := trees.get_region(Rect2i(58, 415, 268, 319))      # band1[0]
	_save(_scale_h(yt, 150), OUT, "young_tree.png")

	# dry / withered bush: a small BARE tree from the dead-tree section (band17).
	var bare := trees.get_region(Rect2i(1227, 6603, 194, 229)) # band17[3] bare
	_save(_scale_h(bare, 128), OUT, "bush_dry.png")

	# ---- SMALL FOLIAGE (bushes / tufts / green bush) — exact bboxes ----
	# green decorative bush 'h': a leafy shrub clump (y2176 row).
	var bush := s1.get_region(Rect2i(647, 2247, 109, 45))     # bushes[7] full clump
	_save(_scale_h(bush, 54), OUT, "bush_green.png")
	var bush_bloom := s1.get_region(Rect2i(275, 2254, 77, 39)) # bushes[3]
	_save(_scale_h(bush_bloom, 52), OUT, "bush_bloom.png")
	# grass tuft: a small grass clump (y2432 row).
	var tuft := s1.get_region(Rect2i(280, 2502, 52, 39))      # tufts[3]
	_save(_scale_h(tuft, 34), OUT, "grass_tuft.png")

	# ---- ROCKS / STONES from rock_cliffs boulders (tight-cropped single pieces) ----
	# rock (boulder): use a compact boulder from the top-left, tight.
	var rock := _tight(rocks, 0, 0, 200, 160)
	_save(_scale_h(rock, 70), OUT, "rock.png")
	# stone (small pebble/low pile).
	var stone := _tight(rocks, 2 * 128, 3 * 128, 200, 140)
	_save(_scale_h(stone, 42), OUT, "stone.png")

	# ---- CLIFF FACES (terrain) : iso rock pillars from grassland_1x1 top ----
	# Each cliff piece is a 128-wide, ~208-tall iso rock wall (2 grid rows).
	# Grab 4 distinct pieces for variety along the island edge + ridge walls.
	# Content lives in cols 0..7 at y0..256 (top of the two-row piece + its dark side).
	var cliff0 := _tight(s1, 0 * 128, 0, 128, 256)
	var cliff1 := _tight(s1, 2 * 128, 0, 128, 256)
	var cliff2 := _tight(s1, 4 * 128, 0, 128, 256)
	var cliff3 := _tight(s1, 6 * 128, 0, 128, 256)
	# Save at native-ish size; the map loader scales/anchors them. Normalize width→128.
	for pair in [[cliff0, "cliff_face_a.png"], [cliff1, "cliff_face_b.png"], [cliff2, "cliff_face_c.png"], [cliff3, "cliff_face_d.png"]]:
		var im: Image = pair[0]
		# normalize to 128 wide preserving aspect
		var nh := int(round(128.0 * im.get_height() / im.get_width())) if im.get_width() > 0 else 128
		var scaled := im.duplicate()
		scaled.resize(128, nh, Image.INTERPOLATE_LANCZOS)
		_save(scaled, TOUT, pair[1])

	# ---- ROCK WALL ridge pieces : reuse cliff pillars but darker/rockier for interior ----
	# Interior ridge should read as a continuous rock WALL. Use the same iso rock
	# pillars (they tile side-by-side into a wall). Save 2 variants for break-up.
	var ridge0 := cliff1.duplicate()
	var ridge1 := cliff3.duplicate()
	for pair in [[ridge0, "ridge_rock.png"], [ridge1, "ridge_rock_b.png"]]:
		var im: Image = pair[0]
		var nh := int(round(128.0 * im.get_height() / im.get_width())) if im.get_width() > 0 else 160
		var scaled := im.duplicate()
		scaled.resize(128, nh, Image.INTERPOLATE_LANCZOS)
		_save(scaled, TOUT, pair[1])

	print("== done ==")
	quit()
