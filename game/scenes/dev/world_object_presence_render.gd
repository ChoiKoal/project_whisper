extends Node
## Deterministic same-scene/same-camera visual evidence renderer.
## Instances the real home scene and real PlacedObject nodes; output is an engine viewport capture.

const HOME := "res://scenes/world/home_island.tscn"
const DEFAULT_OUT := "res://world-object-presence.png"
const PROBES := [
	{"id": "D29", "cell": Vector2i(7, 12)},
	{"id": "D24", "cell": Vector2i(10, 12)},
	{"id": "D32", "cell": Vector2i(13, 12)},
	{"id": "D41", "cell": Vector2i(8, 15)},
	{"id": "D44", "cell": Vector2i(11, 15)},
	{"id": "D45", "cell": Vector2i(14, 15)},
	{"id": "D48", "cell": Vector2i(10, 18)},
	{"id": "D96", "cell": Vector2i(13, 18)},
]


func _ready() -> void:
	call_deferred("_render")


func _render() -> void:
	Inventory.clear()
	GameState.set_game_time(0.0)
	SaveManager.pending_load = false
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1400, 900)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var world: Node = load(HOME).instantiate()
	viewport.add_child(world)
	for _frame in range(6):
		await get_tree().process_frame

	for layer_name in ["InventoryUI", "FusionUI", "CodexUI", "CharacterWindow", "TimeHUD",
			"QuestHUD", "QuestLog", "PortalCutscene", "FadeLayer", "PauseMenu", "UIHub"]:
		var layer := world.get_node_or_null(layer_name) as CanvasLayer
		if layer != null:
			layer.visible = false
	var player := world.get_node("YSortLayer/Player") as Node2D
	player.visible = false
	var player_camera := player.get_node("Camera2D") as Camera2D
	player_camera.enabled = false

	var loader := world.get_node("Ground") as MapLoader
	var ysort := world.get_node("YSortLayer") as Node2D
	var center := Vector2.ZERO
	for probe in PROBES:
		var object := PlacedObject.new()
		var cell: Vector2i = probe["cell"]
		object.setup(String(probe["id"]), cell)
		object.position = loader.cell_center_world(cell)
		ysort.add_child(object)
		center += object.position
	center /= float(PROBES.size())

	var camera := Camera2D.new()
	camera.position = center - Vector2(0, 36)
	camera.zoom = Vector2(1.05, 1.05)
	world.add_child(camera)
	camera.make_current()
	for _frame in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var output := OS.get_environment("WORLD_OBJECT_RENDER_OUT")
	if output == "":
		output = DEFAULT_OUT
	var image := viewport.get_texture().get_image()
	var error := ERR_CANT_CREATE if image == null else image.save_png(output)
	print("world object evidence saved: %s (err=%d size=%s probes=%d)" % [
		output, error, image.get_size() if image != null else Vector2i.ZERO, PROBES.size()])
	get_tree().quit(0 if error == OK else 1)
