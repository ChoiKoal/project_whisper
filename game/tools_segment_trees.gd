extends SceneTree
## Auto-segment individual tree sprites out of isometric_trees_01.png by finding
## opaque column-runs separated by transparent gutters within each 384px band.
## Prints each found sprite's bbox so we can pick clean single trees for the object
## slicer. Also directly saves a chosen set.

const TREES := "/workspace/group/project-whisper/assets-src/trees/isometric_trees_01.png"

func _init() -> void:
	var im := Image.new()
	im.load(TREES)
	im.convert(Image.FORMAT_RGBA8)
	var W := im.get_width()
	var H := im.get_height()
	var band_h := 384
	var bands := H / band_h
	# For each band, build a per-column opaque flag, then find runs.
	for b in range(bands):
		var y0 := b * band_h
		var y1 := mini(y0 + band_h, H)
		var col_op := []
		col_op.resize(W)
		for x in range(W):
			var op := false
			for y in range(y0, y1, 4):
				if im.get_pixel(x, y).a > 0.4:
					op = true
					break
			col_op[x] = op
		# find runs with >= 40px width, gutters >= 16px
		var runs := []
		var x := 0
		while x < W:
			if not col_op[x]:
				x += 1
				continue
			var start := x
			var gap := 0
			while x < W and (col_op[x] or gap < 20):
				if col_op[x]:
					gap = 0
				else:
					gap += 1
				x += 1
			var endc := x - gap
			if endc - start >= 60:
				# tight vertical bbox for this run
				var miny := y1
				var maxy := y0
				for xx in range(start, endc):
					for yy in range(y0, y1):
						if im.get_pixel(xx, yy).a > 0.4:
							miny = mini(miny, yy)
							maxy = maxi(maxy, yy)
				runs.append([start, miny, endc - start, maxy - miny + 1])
		print("band %d (y%d): %d sprites: %s" % [b, y0, runs.size(), str(runs)])
	quit()
