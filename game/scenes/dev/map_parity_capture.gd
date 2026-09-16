extends Node
## Test-only launcher for a genuine title -> new game -> opening -> home capture.
## The watcher is reparented to SceneTree.root so it survives real scene changes.

func _ready() -> void:
	var watcher_script := load("res://scenes/dev/map_parity_capture_watcher.gd") as GDScript
	if watcher_script == null or not watcher_script.can_instantiate():
		push_error("MAP_PARITY_CAPTURE: watcher script failed to load")
		get_tree().quit(88)
		return
	var watcher: Node = watcher_script.new()
	if watcher == null:
		push_error("MAP_PARITY_CAPTURE: watcher failed to instantiate")
		get_tree().quit(88)
		return
	watcher.name = "MapParityCaptureWatcher"
	get_tree().root.add_child.call_deferred(watcher)
