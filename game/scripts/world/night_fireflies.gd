extends Node2D
class_name NightFireflies
## v0.3.0 A4 — a handful of tiny firefly motes that drift around the world-tree zone
## at NIGHT ONLY. Additive violet glints on the glow CanvasLayer (unaffected by the
## day/night CanvasModulate), so they read as living light in the dark like the
## reference dioramas' glowing void-life.
##
## Cheap: 8 small radial-glow Sprite2Ds sharing the existing light-pool texture,
## each on a slow lissajous drift around the world-tree centroid. Alpha ramps to 0
## by day (fully hidden) and blooms at night. Fully deterministic drift (fixed seed).

const GLOW_LAYER_GROUP := "glow_layer"
const POOL_TEX := "res://assets/objects/light_pool_violet.png"

@export var map_loader_path: NodePath

const COUNT := 8
const DRIFT_RADIUS := 150.0
const SEED := 0x1CE_F1E5

var _flies: Array = []   # [{sprite, phase, sx, sy, rx, ry, speed}]
var _center: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _base_alpha: float = 0.0
var _layer: Node = null


func _ready() -> void:
	var loader := get_node_or_null(map_loader_path)
	if loader != null and loader.has_method("cell_center_world"):
		var cells: Array = loader.get("world_tree_cells")
		if cells != null and cells.size() > 0:
			# centroid of the world-tree cells, nudged like the tree's own placement.
			var sum := Vector2.ZERO
			for cell in cells:
				sum += loader.cell_center_world(cell)
			_center = sum / float(cells.size()) + Vector2(0, -40)
		else:
			_center = Vector2(0, 0)
	# Fireflies live on the glow layer so the CanvasModulate never dims them.
	if is_inside_tree():
		_layer = get_tree().get_first_node_in_group(GLOW_LAYER_GROUP)
	var tex := load(POOL_TEX) as Texture2D
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for _i in range(COUNT):
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(0.06, 0.06) * (0.7 + rng.randf() * 0.8)   # tiny glints
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = mat
		s.z_index = 6
		s.modulate = Color(0.85, 0.75, 1.0, 0.0)
		if _layer != null:
			_layer.add_child(s)
		else:
			add_child(s)
		_flies.append({
			"sprite": s,
			"phase": rng.randf() * TAU,
			"sx": 0.4 + rng.randf() * 0.7,
			"sy": 0.5 + rng.randf() * 0.8,
			"rx": DRIFT_RADIUS * (0.4 + rng.randf() * 0.6),
			"ry": DRIFT_RADIUS * (0.3 + rng.randf() * 0.5),
			"speed": 0.5 + rng.randf() * 0.7,
			"tw": rng.randf() * TAU,
		})
	if GameState != null:
		GameState.day_phase_changed.connect(_on_phase)
		_on_phase(GameState.phase())


func _on_phase(phase: String) -> void:
	# Night only: bloom at night, faint at dawn/evening edges, gone by day.
	match phase:
		"night": _base_alpha = 0.85
		"evening": _base_alpha = 0.15
		"dawn": _base_alpha = 0.2
		_: _base_alpha = 0.0


func _process(delta: float) -> void:
	_t += delta
	for f in _flies:
		var s: Sprite2D = f["sprite"]
		var ph: float = f["phase"] + _t * f["speed"]
		var off := Vector2(cos(ph * f["sx"]) * f["rx"], sin(ph * f["sy"]) * f["ry"])
		s.global_position = _center + off
		var tw: float = 0.55 + 0.45 * sin(_t * 2.3 + f["tw"])
		s.modulate.a = clampf(_base_alpha * tw, 0.0, 1.0)
