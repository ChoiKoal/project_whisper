extends Node
## M7 title-flow acceptance harness (permanent regression for the v0.1.2 macOS
## release-crash fix). Drives the REAL title → grove scene-change path the crash
## report implicates, exercising _propagate_ready of the whole starting_grove tree
## twice (new game + 이어하기), plus a save round-trip in between:
##
##   1. boot title.tscn
##   2. 새로 시작  → grove, survive 90 frames (the crash window)
##   3. ESC pause → 저장 (save round-trip while the live world is registered)
##   4. 타이틀로   → back to title
##   5. 이어하기   → grove again (loads the save into the freshly-built scene)
##   6. survive 60 more frames
##
## Everything is driven by calling the real button handlers on the real nodes
## (headless has no rendered input), so the actual change_scene_to_file + ready
## propagation runs exactly as in-game. Prints PASS/FAIL and quits with the
## failure count as the exit code (0 = green), matching the other m* harnesses.
##
## A separate FlowWatcher node is spawned on the tree root with PROCESS_MODE_ALWAYS
## so it keeps ticking across scene changes (current_scene is swapped underneath it).

func _ready() -> void:
	var script: GDScript = load("res://scenes/dev/m7_title_flow_watcher.gd")
	var watcher: Node = script.new()
	watcher.name = "FlowWatcher"
	get_tree().root.add_child.call_deferred(watcher)
