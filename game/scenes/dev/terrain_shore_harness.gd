extends Node
## Surface geometry contracts, not aesthetic approval.
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
var failures := 0
func check(label: String, ok: bool, detail := "") -> void:
	print("[%s] %s %s" % ["PASS" if ok else "FAIL",label,detail])
	if not ok: failures += 1
func _ready() -> void:
	if not GUARD.require_isolated_user_data("terrain_shore"):
		get_tree().quit(86)
		return
	SaveManager.new_game()
	var scene: Node = load("res://scenes/world/starting_grove.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	var loader: MapLoader = scene.get_node("Ground")
	var walls := 0
	var contacts := 0
	var bad := 0
	var wall_cells: Dictionary = {}
	var covered: Dictionary = {}
	# Vertical ink now has contact roots in YSort; ground treatment stays in Elevation.
	for node in loader.get_node("Elevation").get_children()+scene.get_node("YSortLayer").get_children():
		if not node is Sprite2D: continue
		if node.z_index==loader.CLIFF_FACE_Z-1:
			contacts += 1
			if not node.has_meta("contact_edge"):
				bad += 1
				continue
			var im: Image = node.texture.get_image()
			var depths: Vector2i = node.get_meta("face_depths")
			for x in range(im.get_width()):
				var rim := 32 + (mini(x,127-x)/4)*2
				var depth := depths.y if x<64 else depths.x
				for y in range(im.get_height()):
					if im.get_pixel(x,y).a>0 and (depth==0 or y<rim+depth or y>=rim+depth+8): bad += 1
		elif node.has_meta("raised_cell"):
			walls += 1
			var cell: Vector2i = node.get_meta("raised_cell")
			wall_cells[cell]=true
			var im: Image = node.texture.get_image()
			var depths: Vector2i = node.get_meta("face_depths")
			var dirs := [Vector2i(1,0),Vector2i(0,1)]
			for index in range(2):
				var nb := loader.terrain_neighbor(cell,dirs[index])
				var expected := 0 if loader.is_ramp(nb) else maxi(0,loader.height_at(cell)-loader.height_at(nb))*32
				if depths[index]>0:
					if depths[index]!=expected: bad += 1
					var key := "%s:%d" % [cell,index]
					if covered.has(key): bad += 1
					covered[key]=true
			for x in range(128):
				var rim := 32+(mini(x,127-x)/4)*2
				var depth := depths.y if x<64 else depths.x
				for y in range(im.get_height()):
					var expected := depth>0 and y>=rim and y<rim+depth
					if (im.get_pixel(x,y).a>0)!=expected: bad += 1
	var expected_faces: Dictionary = {}
	for cell in loader.hill_cells:
		if loader.is_ramp(cell): continue
		for index in range(2):
			var nb := loader.terrain_neighbor(cell,Vector2i(1,0) if index==0 else Vector2i(0,1))
			if not loader.is_ramp(nb) and loader.height_at(nb)<loader.height_at(cell): expected_faces["%s:%d" % [cell,index]]=true
	check("all raised faces have independently correct side depths",wall_cells.size()==loader.cliff_face_count and walls>0 and covered==expected_faces,"wall_cells=%d faces=%d expected=%d" % [wall_cells.size(),walls,expected_faces.size()])
	check("shadows attach within 8px of actual wall feet, never tile centres",contacts>0 and bad==0,"contacts=%d bad=%d" % [contacts,bad])
	# Require a projected surface for every authored ramp, no solid dangling wedges.
	var ramps := 0
	for node in loader.get_node("Elevation").get_children():
		if node.has_meta("ramp_surface"): ramps += 1
	check("every ramp uses a height-projected earth surface",ramps==loader.ramp_cells.size() and ramps>0)
	SaveManager.unregister_world()
	scene.queue_free()
	await get_tree().process_frame
	print("SHORE_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
