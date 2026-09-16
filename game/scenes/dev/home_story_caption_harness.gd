extends Node
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var failures:=0
func check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ")+label)
	if not ok: failures+=1
func frames(n: int) -> void:
	for i in range(n): await get_tree().process_frame
func _ready() -> void: call_deferred("run")
func run() -> void:
	if not GUARD.require_isolated_user_data("home_story_caption"):
		get_tree().quit(86);return
	var win:=get_window()
	win.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	for size in [Vector2i(640,480),Vector2i(1600,900)]:
		win.content_scale_size=size;win.size=size
		await frames(2)
		SaveManager.new_game();SaveManager.mark_cleared()
		GameState.story_record_experiment("D10")
		WorldContext.arrival_mode="portal_arrival"
		var scene: Node=load("res://scenes/world/home_island.tscn").instantiate();add_child(scene)
		await frames(16)
		var panel:=scene.get_node_or_null("DialoguePanel") as DialoguePanel
		var label:=panel.body_label() if panel!=null else null
		check("persistent return dialogue exists %s" % size,panel!=null and panel.is_open() and label!=null)
		if label!=null:
			var rect:=label.get_global_rect()
			var viewport:=get_viewport().get_visible_rect()
			print("CAPTION_RECT size=",size," viewport=",viewport," label=",rect)
			check("caption fully inside viewport %s" % size,viewport.encloses(rect))
			check("dialogue centered above bottom HUD %s" % size,absf(panel.dialogue_rect().get_center().x-viewport.get_center().x)<1 and panel.dialogue_rect().end.y<=viewport.end.y-60 and label.is_visible_in_tree())
			check("caption renders whole line without clipping %s" % size,not label.clip_text and not label.text.is_empty() and rect.size.y>=label.get_minimum_size().y)
		SaveManager.unregister_world();scene.queue_free();await frames(3)
	print("HOME_STORY_CAPTION failures=",failures)
	get_tree().quit(1 if failures else 0)
