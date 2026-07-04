extends TileMapLayer
class_name MapBuilder
## Populates a 20x20 isometric test map in code so we avoid hand-authoring the
## packed tile_data binary. Source ids match tile ids:
##   0=T0 VOID, 1=T1 dirt, 2=T2A grass, 3=T2B, 4=T2C, 5=T2D, 7=T4 mud,
##   8=T5A water, 9=T5B water2.
## The atlas coord is always (0,0) since each source holds one tile.

const MAP_W := 20
const MAP_H := 20
const ATLAS := Vector2i(0, 0)

# source ids
const T0 := 0
const T1 := 1
const T2A := 2
const T2B := 3
const T2C := 4
const T2D := 5
const T4 := 7
const T5A := 8
const T5B := 9


func _ready() -> void:
	_build()


func _build() -> void:
	# Base: grass everywhere with some variation.
	for y in range(MAP_H):
		for x in range(MAP_W):
			var src := _base_grass(x, y)
			set_cell(Vector2i(x, y), src, ATLAS)

	# Pond: center-left, roughly x 3..7, y 7..12 as a rounded blob.
	var pond_cx := 5.0
	var pond_cy := 9.5
	for y in range(MAP_H):
		for x in range(MAP_W):
			var dx := (x - pond_cx) / 3.0
			var dy := (y - pond_cy) / 2.6
			var d := dx * dx + dy * dy
			if d <= 1.0:
				# inner deeper water, outer shallow
				var src := T5B if d <= 0.4 else T5A
				set_cell(Vector2i(x, y), src, ATLAS)

	# Dirt path: a horizontal-ish trail from the pond edge to the right side.
	for x in range(8, MAP_W):
		var py := 9 + int(round(sin(x * 0.5) * 1.0))
		set_cell(Vector2i(x, py), T1, ATLAS)
		set_cell(Vector2i(x, py + 1), T1, ATLAS)

	# Mud patch: a few tiles near the pond's south shore.
	for m in [Vector2i(6, 12), Vector2i(7, 12), Vector2i(6, 13), Vector2i(8, 12)]:
		set_cell(m, T4, ATLAS)


func _base_grass(x: int, y: int) -> int:
	# cheap deterministic scatter of grass variants
	var h := (x * 73856093) ^ (y * 19349663)
	h = (h >> 3) & 0xff
	if h < 30:
		return T2B
	elif h < 60:
		return T2C
	elif h < 80:
		return T2D
	return T2A
