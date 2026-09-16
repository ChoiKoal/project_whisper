extends Node
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
var failures := 0
func check(label: String, ok: bool, detail := "") -> void:
	print("[%s] %s %s" % ["PASS" if ok else "FAIL",label,detail])
	if not ok: failures += 1
func _ready() -> void:
	if not GUARD.require_isolated_user_data("foundation_cues"):
		get_tree().quit(86)
		return
	call_deferred("run")
func run() -> void:
	SaveManager.new_game()
	WorldContext.arrival_mode=""
	var scene: Node = load("res://scenes/foundation/representative_grove.tscn").instantiate()
	add_child(scene)
	for i in range(12): await get_tree().process_frame
	GameState.time_running=false
	var map: MapLoader=scene.get_node("Ground")
	var _traveler: Player=scene.get_node("YSortLayer/Player")
	var anim: AnimatedSprite2D=_traveler.get_node("AnimatedSprite2D")
	check("character uses native integer pixel scale",anim.scale==Vector2.ONE)
	check("dedicated surface shadow exists",_traveler.has_node("SurfaceShadow"))
	for animation in anim.sprite_frames.get_animation_names():
		for frame in range(anim.sprite_frames.get_frame_count(animation)):
			var image:=anim.sprite_frames.get_frame_texture(animation,frame).get_image()
			var bottom:=image.get_used_rect().end.y
			var foot:=_traveler._base_anim_position.y+(float(bottom)-image.get_height()*0.5)*anim.scale.y
			check("body-only planted foot anchored "+str(animation)+str(frame),absf(foot)<0.01,"gap=%.3f" % foot)
	var highlight: TileHighlight=scene.get_node("TileHighlight")
	var glow: TileGlow=scene.get_node("TileGlow")
	var ghost: PlacementGhost=scene.get_node("PlacementGhost")
	for cell in [Vector2i(12,32),Vector2i(18,17),Vector2i(18,22),Vector2i(19,20)]:
		var logical:=map.cell_center_world(cell)
		var expected:=logical+Vector2(0,map.visual_height_offset(logical))
		for repeat in range(3):
			highlight.show_cell(logical,true)
			glow.show_cell(logical)
			ghost.show_ghost("D08",logical,true)
			check("highlight projects once %s repeat%d" % [cell,repeat],highlight.global_position.is_equal_approx(expected))
			check("gather cue projects once %s repeat%d" % [cell,repeat],glow.global_position.is_equal_approx(expected))
			check("placement ghost projects once %s repeat%d" % [cell,repeat],ghost.global_position.is_equal_approx(expected))
		check("cue has terrain-projected polygon",highlight.has_method("surface_polygon"))
		if highlight.has_method("surface_polygon"):
			var polygon: PackedVector2Array=highlight.surface_polygon()
			check("cue outlines four corners with closure",polygon.size()==5 and polygon[0]==polygon[4])
			var corners: Array[Vector2]=[Vector2(0,-32),Vector2(64,0),Vector2(0,32),Vector2(-64,0)]
			var aligned:=true
			for index in range(4):
				var p:=logical+corners[index]*0.999
				var projected:=p+Vector2(0,map.visual_height_offset(p))
				aligned=aligned and highlight.to_global(polygon[index]).distance_to(projected)<0.1
			check("slope outline follows each corner height %s" % cell,aligned)
		check("logical query/cell remains unprojected %s" % cell,map.world_to_cell(logical)==cell)
	# Actual placement creation path; inventory/quest progression are not claimed here.
	var interaction: InteractionController = scene.get_node("Interaction")
	var high_cell := Vector2i(19,20)
	interaction._spawn_placed_object("D08",high_cell)
	await get_tree().create_timer(0.3).timeout
	var placed: PlacedObject
	for node in get_tree().get_nodes_in_group(PlacedObject.GROUP):
		if node is PlacedObject and node.cell==high_cell: placed=node
	check("raised placed object created through controller",placed!=null)
	if placed!=null:
		var logical:=map.cell_center_world(high_cell)
		ghost.show_ghost("D08",logical,true)
		check("placed object and preview share visible anchor",placed.to_global(placed.offset).distance_to(ghost._sprite.to_global(ghost._sprite.offset))<0.1,
			"placed=%s ghost=%s" % [placed.to_global(placed.offset),ghost._sprite.to_global(ghost._sprite.offset)])
		check("placed logical root and target not lifted",placed.global_position.is_equal_approx(logical) and placed.target_point().is_equal_approx(logical))
		check("placed save cell preserved",placed.to_dict().cell==[high_cell.x,high_cell.y])
		check("placed collider stays on logical root",placed._body==null or placed._body.global_position.is_equal_approx(logical))
	highlight.hide_highlight()
	glow.hide_glow()
	ghost.hide_ghost()
	check("all projected cues cancel",not highlight.visible and not glow.visible and not ghost.visible)
	SaveManager.unregister_world()
	scene.queue_free()
	await get_tree().process_frame
	print("FOUNDATION_CUES_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
