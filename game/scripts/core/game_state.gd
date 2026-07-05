extends Node
## GameState — global autoload singleton.
## Holds game time (day/night cycle) and declares signals used across milestones.

signal game_time_changed(new_time: float)
## Fired when the time-of-day phase changes (M4 day/night cycle).
## phase ∈ {"day", "evening", "night", "dawn"}.
signal day_phase_changed(phase: String)
signal item_gathered(item_id: String)    ## M2 gathering: fired when an item is gathered
signal recipe_discovered(recipe_id: String)  ## M3 fusion

## M2 placement/use framework signals.
## Emitted when D22 (어린 세계수) is placed on a T0 VOID tile — the MVP clear
## condition. M4 hooks the clear cutscene here.
signal world_tree_planted(cell: Vector2i)
## Emitted when a `usable_on` item is used on a matching object (e.g. I7 water on
## a `bush_dry`).
signal item_used_on_object(item_id: String, object: Node)
## Emitted when D14 (디딤돌) makes a water tile walkable, for later SFX / audit.
signal stepping_stone_placed(cell: Vector2i)
## (v0.3.1 Fix 4) Emitted when gathering an interior tile turns it into a walkable
## HOLLOW (빈 자국). The pathfinding grid rebuilds its solids so tap-to-move crosses
## the emptied spot; before this the gathered cell was VOID (non-walkable to AStar)
## but had no physics wall — the "swiss-cheese" WASD/tap inconsistency the owner hit.
signal tile_walkable_changed(cell: Vector2i)

# ---- Day/night cycle (M4) -------------------------------------------------
## One full game day = 900s real (확정 스펙: 낮 540s / 저녁~새벽 360s).
## Phases as fractions of the day cycle:
##   day    0.00 .. 0.60  (540s)
##   evening0.60 .. 0.7333(120s ramp 갈→보라)
##   night  0.7333.. 0.9333(180s 어둠)
##   dawn   0.9333.. 1.00  (60s → day)
const DAY_LENGTH: float = 900.0
const DAY_END: float = 0.60      # 540s
const EVENING_END: float = 0.7333  # +120s = 660s
const NIGHT_END: float = 0.9333    # +180s = 840s
# dawn runs NIGHT_END..1.0 (60s), then wraps to day.

## In-game elapsed time in seconds (monotonic). Advanced by _process each frame.
var game_time: float = 0.0

## Whether time should advance (paused menus / cutscenes can toggle this).
var time_running: bool = true

var _phase: String = "day"


func _ready() -> void:
	_phase = _phase_for(game_time)


func _process(delta: float) -> void:
	if not time_running:
		return
	game_time += delta
	game_time_changed.emit(game_time)
	var p := _phase_for(game_time)
	if p != _phase:
		_phase = p
		day_phase_changed.emit(p)


# ---- time queries ---------------------------------------------------------

## Fraction 0.0..1.0 through the current day cycle.
func day_fraction() -> float:
	return fposmod(game_time, DAY_LENGTH) / DAY_LENGTH


## Integer day count (0-based) since start.
func day_index() -> int:
	return int(floor(game_time / DAY_LENGTH))


## Phase for a given absolute time.
func _phase_for(t: float) -> String:
	var f := fposmod(t, DAY_LENGTH) / DAY_LENGTH
	if f < DAY_END:
		return "day"
	elif f < EVENING_END:
		return "evening"
	elif f < NIGHT_END:
		return "night"
	return "dawn"


## Current phase string.
func phase() -> String:
	return _phase


## True during evening~dawn (the "밤" window when G3 night path is open and the
## world-tree area glows). Day is the only closed window.
func is_night_window() -> bool:
	return _phase != "day"


# ---- Rest Stump time skip -------------------------------------------------

## Jump game_time forward to the start of the NEXT evening (확정 스펙: Rest Stump
## skips to next evening, not next day). If we are already before this day's
## evening, jump to this day's evening; otherwise to the next day's evening.
func skip_to_next_evening() -> void:
	var day_start: float = floor(game_time / DAY_LENGTH) * DAY_LENGTH
	var evening_start: float = day_start + DAY_END * DAY_LENGTH
	if game_time < evening_start:
		game_time = evening_start
	else:
		game_time = evening_start + DAY_LENGTH
	var p := _phase_for(game_time)
	if p != _phase:
		_phase = p
		day_phase_changed.emit(p)
	game_time_changed.emit(game_time)


## Directly set game_time (harness / debug / M5 load) and re-emit phase.
func set_game_time(t: float) -> void:
	game_time = t
	var p := _phase_for(game_time)
	if p != _phase:
		_phase = p
		day_phase_changed.emit(p)
	game_time_changed.emit(game_time)
