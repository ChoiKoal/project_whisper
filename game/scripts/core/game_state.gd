extends Node
## GameState — global autoload singleton.
## M0/M1 shell: holds game time and declares signals used by later milestones.

signal game_time_changed(new_time: float)
signal day_phase_changed(phase: String)  ## reserved for M4 day/night cycle
signal item_gathered(item_id: String)    ## reserved for M2 gathering
signal recipe_discovered(recipe_id: String)  ## reserved for M3 fusion

## In-game elapsed time in seconds. Advanced by _process each frame.
var game_time: float = 0.0

## Whether time should advance (paused menus etc. can toggle this later).
var time_running: bool = true


func _process(delta: float) -> void:
	if not time_running:
		return
	game_time += delta
	game_time_changed.emit(game_time)
