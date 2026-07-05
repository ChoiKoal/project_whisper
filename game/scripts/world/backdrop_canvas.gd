extends Control
class_name BackdropCanvas
## The painting surface for the void-sky Backdrop (v0.3.0 A2). Owns the deterministic
## star / dust / mote field and repaints each frame. Kept as its own script so the
## draw runs in a real, exported class (no runtime-compiled GDScript).

const TOP := Color("#12121c")
const BOTTOM := Color("#1e1a2e")
## (L2-2) colder-blue void gradient for the science station (남색 mood, no violet warmth).
const L2_TOP := Color("#0b1018")
const L2_BOTTOM := Color("#131c2c")

const STAR_COUNT := 90
const DUST_COUNT := 140
const MOTE_COUNT := 7
const STAR_SEED := 0x5151a7

## (v0.5d) Home-island void mood: a denser starfield + one large soft violet nebula patch.
var _home_mood: bool = false
## (L2-2) Layer-2 station mood: colder-blue gradient + cyan-tinted nebula.
var _l2_mood: bool = false
## Nebula centre (fraction of screen) + radii; painted as concentric soft violet rings.
const NEBULA_COL := Color(0.42, 0.28, 0.62, 1.0)
## (L2-2) cyan-teal nebula for the science void.
const NEBULA_COL_L2 := Color(0.20, 0.46, 0.52, 1.0)

func set_home_mood(on: bool) -> void:
	_home_mood = on
	_seed_field()
	queue_redraw()

func set_l2_mood(on: bool) -> void:
	_l2_mood = on
	_home_mood = on  # reuse the denser-field path
	_seed_field()
	queue_redraw()

func _star_count() -> int:
	return 180 if _home_mood else STAR_COUNT
func _dust_count() -> int:
	return 220 if _home_mood else DUST_COUNT

## Star tint ramp (neutral cream → faint violet), art-guide neutral/violet families.
const STAR_TINTS := [
	Color("#e8dfc8"), Color("#b8b4a8"), Color("#d9b8ff"), Color("#9e7ad9"),
]

var _stars: Array = []
var _dust: Array = []
var _motes: Array = []
var _t: float = 0.0
var _size: Vector2 = Vector2(1920, 1080)


func _ready() -> void:
	_refresh_size()
	_seed_field()
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_vp_resized):
		vp.size_changed.connect(_on_vp_resized)
	queue_redraw()


func _refresh_size() -> void:
	var vp := get_viewport()
	if vp != null:
		var s := vp.get_visible_rect().size
		if s.x >= 64 and s.y >= 64:
			_size = s


func _on_vp_resized() -> void:
	_refresh_size()
	_seed_field()
	queue_redraw()


func _seed_field() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	_stars.clear()
	for _i in range(_star_count()):
		_stars.append({
			"pos": Vector2(rng.randf() * _size.x, rng.randf() * _size.y),
			"size": 1.0 if rng.randf() < 0.72 else 2.0,
			"tint": STAR_TINTS[rng.randi() % STAR_TINTS.size()],
			"tw": rng.randf() * TAU,
		})
	_dust.clear()
	for _i in range(_dust_count()):
		_dust.append({
			"pos": Vector2(rng.randf() * _size.x, rng.randf() * _size.y),
			"tint": Color(0.55, 0.5, 0.62, 0.10 + rng.randf() * 0.10),
		})
	_motes.clear()
	for _i in range(MOTE_COUNT):
		_motes.append({
			"pos": Vector2(rng.randf() * _size.x, rng.randf() * _size.y),
			"vel": Vector2(4.0 + rng.randf() * 8.0, (rng.randf() - 0.5) * 2.0),
			"r": 3.0 + rng.randf() * 4.0,
			"a": 0.05 + rng.randf() * 0.06,
		})


func _process(delta: float) -> void:
	_t += delta
	for m in _motes:
		m["pos"] += m["vel"] * delta
		if m["pos"].x > _size.x + 12.0:
			m["pos"].x = -12.0
			m["pos"].y = fposmod(m["pos"].y + 37.0, _size.y)
	queue_redraw()


func _draw() -> void:
	var w := _size.x
	var h := _size.y
	# vertical gradient via a stack of horizontal bands (cheap, no shader).
	var bands := 48
	var top_col := L2_TOP if _l2_mood else TOP
	var bot_col := L2_BOTTOM if _l2_mood else BOTTOM
	for i in range(bands):
		var t := float(i) / float(bands - 1)
		var col := top_col.lerp(bot_col, t)
		var y := t * h
		draw_rect(Rect2(0, y, w, h / float(bands) + 1.0), col)
	# (v0.5d) one large soft violet nebula glow patch behind the island (home mood only),
	# painted as concentric feathered rings so it reads as a diffuse cloud, not a hard disc.
	if _home_mood:
		var nc := Vector2(w * 0.46, h * 0.5)
		var maxr := maxf(w, h) * 0.42
		var rings := 26
		for i in range(rings):
			var t := float(i) / float(rings - 1)     # 0 centre .. 1 edge
			var rr := maxr * t
			var a := (1.0 - t) * (1.0 - t) * 0.05     # very soft
			var col := NEBULA_COL_L2 if _l2_mood else NEBULA_COL
			col.a = a
			draw_circle(nc, maxf(1.0, maxr - rr), col)
	# static faint dust specks
	for d in _dust:
		draw_rect(Rect2(d["pos"], Vector2(1, 1)), d["tint"])
	# stars (slight alpha twinkle)
	for s in _stars:
		var tw: float = 0.65 + 0.35 * sin(_t * 1.3 + s["tw"])
		var col: Color = s["tint"]
		col.a = tw
		var sz: float = s["size"]
		draw_rect(Rect2(s["pos"], Vector2(sz, sz)), col)
	# drifting motes (soft violet, low-alpha discs; cyan under the L2 mood)
	for m in _motes:
		var mc := Color(0.36, 0.72, 0.78, m["a"]) if _l2_mood else Color(0.62, 0.48, 0.85, m["a"])
		draw_circle(m["pos"], m["r"], mc)
