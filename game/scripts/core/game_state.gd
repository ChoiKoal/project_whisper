extends Node
## GameState — global autoload singleton.
## M0/M1 shell: holds game time and declares signals used by later milestones.

signal game_time_changed(new_time: float)
signal day_phase_changed(phase: String)  ## reserved for M4 day/night cycle
signal item_gathered(item_id: String)    ## M2 gathering: fired when an item is gathered
signal recipe_discovered(recipe_id: String)  ## reserved for M3 fusion

## M2 placement/use framework signals.
## Emitted when D22 (어린 세계수) is placed on a T0 VOID tile — the MVP clear
## condition. M4 hooks a cutscene here.
signal world_tree_planted(cell: Vector2i)
## Emitted when a `usable_on` item is used on a matching object (e.g. I7 water on
## a `bush_dry`). The bush object arrives in M4; the framework is live now.
signal item_used_on_object(item_id: String, object: Node)
## Emitted when D14 (디딤돌) makes a water tile walkable, for later SFX / audit.
signal stepping_stone_placed(cell: Vector2i)

## In-game elapsed time in seconds. Advanced by _process each frame.
var game_time: float = 0.0

## Whether time should advance (paused menus etc. can toggle this later).
var time_running: bool = true


func _process(delta: float) -> void:
	if not time_running:
		return
	game_time += delta
	game_time_changed.emit(game_time)
