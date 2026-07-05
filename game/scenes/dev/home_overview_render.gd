extends Node
## v0.5.0 phase C — home-island overview render. Boots the real home_island scene into a
## SubViewport, frames the whole island with an orthographic capture, forces the Layer-1
## (nature) portal flickering + the rest dormant, renders a few frames, and saves the
## viewport image to /workspace/group/preview-v050c-home.png. Run headless:
##   Godot --headless res://scenes/dev/home_overview_render.tscn

const OUT := "/workspace/group/preview-home.png"
const HOME := "res://scenes/world/home_island.tscn"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	# A SubViewport we can read back headlessly (main window has no framebuffer under --headless).
	var vp := SubViewport.new()
	vp.size = Vector2i(1400, 1000)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var scene: Node = load(HOME).instantiate()
	vp.add_child(scene)
	# Let the map build.
	for i in range(6):
		await get_tree().process_frame

	# Force the portal states for the shot: nature flickering, the rest dormant.
	GameState.set_portal_state("nature", GameState.PORTAL_FLICKERING)
	for lay in ["science", "machine", "magic", "divinity"]:
		GameState.set_portal_state(lay, GameState.PORTAL_DORMANT)

	# Reframe: drop the player's follow-camera and add a static camera centred on the island,
	# zoomed out to show the whole 22×22 slab + starfield.
	var loader := scene.get_node("Ground") as MapLoader
	var center := loader.cell_center_world(Vector2i(loader.width / 2, loader.height / 2))
	var pcam := scene.get_node_or_null("YSortLayer/Player/Camera2D") as Camera2D
	if pcam != null:
		pcam.enabled = false
	var cam := Camera2D.new()
	cam.position = center
	cam.zoom = Vector2(0.62, 0.62)
	scene.add_child(cam)
	cam.make_current()

	# Render a handful of frames so particles/glow settle, then read back.
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	if img == null:
		push_error("home_overview: null viewport image")
		get_tree().quit(1)
		return
	var err := img.save_png(OUT)
	print("home overview saved: %s (err=%d) size=%s" % [OUT, err, img.get_size()])
	get_tree().quit(0 if err == OK else 1)
