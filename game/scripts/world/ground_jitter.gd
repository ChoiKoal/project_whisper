extends Node2D
## Subtle per-cell grass brightness jitter (M6a §A-3). One custom-draw node paints
## a faint ±3% white/black diamond over each grass cell, deterministic per cell,
## to break up the flat colour fields — cheaper than (unsupported) per-cell
## TileMapLayer modulate and it never touches the base tiles.
##
## Drawn at z above the ground + edge overlays but still below the Y-sorted object
## layer (which is a sibling of the tilemap and rendered afterwards).

const TILE_HALF := Vector2(64, 32)  # half of a 128×64 iso tile

var _loader: MapLoader


func setup(loader: MapLoader) -> void:
	_loader = loader
	queue_redraw()


func _draw() -> void:
	if _loader == null:
		return
	for r in range(_loader.height):
		for c in range(_loader.width):
			var cell := Vector2i(c, r)
			var j := _loader.brightness_jitter(cell)
			if absf(j) < 0.004:
				continue
			# Positive jitter → faint cream lift; negative → faint shade.
			var col := Color(1, 1, 1, j) if j > 0.0 else Color(0, 0, 0, -j)
			var center: Vector2 = _loader.map_to_local(cell)
			var pts := PackedVector2Array([
				center + Vector2(0, -TILE_HALF.y),
				center + Vector2(TILE_HALF.x, 0),
				center + Vector2(0, TILE_HALF.y),
				center + Vector2(-TILE_HALF.x, 0),
			])
			draw_colored_polygon(pts, col)
