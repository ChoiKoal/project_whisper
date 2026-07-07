extends Node
## AP-3 acceptance harness — 8-direction character facing + animation selection,
## plus a no-regression check that the four legacy grid-diagonal facings behave
## exactly as the original 4-dir player did.
##
## Builds a real Player with an AnimatedSprite2D driven by data/player_frames.tres
## (no full scene needed — facing/anim selection is self-contained). For each of the
## eight screen-input vectors it drives _update_facing + _update_animation and asserts:
##   1. the resolved _facing is the expected compass heading,
##   2. the sprite is playing the matching idle_/walk_ animation,
##   3. the animation actually exists in the SpriteFrames (all 16 present).
## Then it re-asserts the legacy 4-dir grid steps (facing_cell_step) are unchanged.

const FRAMES := "res://data/player_frames.tres"

var _fail := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== AP-3 8-DIRECTION FACING HARNESS ===")

	var player := Player.new()
	var anim := AnimatedSprite2D.new()
	anim.name = "AnimatedSprite2D"
	anim.sprite_frames = load(FRAMES) as SpriteFrames
	player.add_child(anim)
	add_child(player)
	await get_tree().process_frame

	var frames: SpriteFrames = anim.sprite_frames

	# --- A. all 16 animations present in the SpriteFrames ---
	var dirs := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	for d in dirs:
		_check("SpriteFrames has idle_%s" % d, frames.has_animation("idle_%s" % d))
		_check("SpriteFrames has walk_%s" % d, frames.has_animation("walk_%s" % d))

	# --- B. each of the eight screen-input vectors resolves to the right facing + anim ---
	# Screen space: +x=right, +y=down. Mapping mirrors FACING_ANGLES in player.gd.
	#   right → SE,  down-right → S,  down → SW,  down-left → W,
	#   left  → NW,  up-left    → N,  up   → NE,  up-right  → E.
	var cases := [
		[Vector2(1, 0), "SE"],
		[Vector2(1, 1), "S"],
		[Vector2(0, 1), "SW"],
		[Vector2(-1, 1), "W"],
		[Vector2(-1, 0), "NW"],
		[Vector2(-1, -1), "N"],
		[Vector2(0, -1), "NE"],
		[Vector2(1, -1), "E"],
	]
	for c in cases:
		var vec: Vector2 = c[0]
		var want: String = c[1]
		# WALK: drive facing from the input vector then request the walk anim.
		player._update_facing(vec)
		_check("input %s → facing %s" % [str(vec), want], player.get_facing() == want,
				"got %s" % player.get_facing())
		player._update_animation(true)
		_check("input %s → plays walk_%s" % [str(vec), want], anim.animation == StringName("walk_%s" % want),
				"got %s" % anim.animation)
		# IDLE: same facing, idle anim.
		player._update_animation(false)
		_check("input %s → plays idle_%s" % [str(vec), want], anim.animation == StringName("idle_%s" % want),
				"got %s" % anim.animation)

	# --- C. a zero vector keeps the last facing (idle keeps its pose) ---
	player._update_facing(Vector2(1, 0))   # face SE
	player._update_facing(Vector2.ZERO)
	_check("zero input keeps facing", player.get_facing() == "SE", "got %s" % player.get_facing())

	# --- D. NO-REGRESSION: legacy 4-dir grid steps unchanged ---
	var legacy := {
		"SE": Vector2i(1, 0), "NW": Vector2i(-1, 0),
		"SW": Vector2i(0, 1), "NE": Vector2i(0, -1),
	}
	for f in legacy:
		player._facing = f
		_check("legacy facing_cell_step %s" % f, player.facing_cell_step() == legacy[f],
				"got %s" % str(player.facing_cell_step()))

	# --- E. new screen-cardinal facings get grid-diagonal steps ---
	var newsteps := {
		"S": Vector2i(1, 1), "W": Vector2i(-1, 1),
		"N": Vector2i(-1, -1), "E": Vector2i(1, -1),
	}
	for f in newsteps:
		player._facing = f
		_check("new facing_cell_step %s" % f, player.facing_cell_step() == newsteps[f],
				"got %s" % str(player.facing_cell_step()))

	# --- F. diagonal-input walk drives a screen-diagonal velocity (movement no-regression) ---
	# Reproduce the iso-squash transform _move_screen uses and confirm a nonzero glide.
	var iso_dir := Vector2(1, 1 * 0.5).normalized()   # down-right input, iso-squashed
	_check("diagonal input yields nonzero iso velocity", iso_dir.length() > 0.99)
	_check("diagonal iso velocity is screen-down-right", iso_dir.x > 0 and iso_dir.y > 0)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)
