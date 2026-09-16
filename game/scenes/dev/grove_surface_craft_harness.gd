extends Node
## Grove-only outer geometry: continuity; raised-terrain behavior preserved.
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
var failures := 0
func check(label: String, ok: bool) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failures += 1
func _ready() -> void:
	if not GUARD.require_isolated_user_data("grove_surface_craft"):
		get_tree().quit(86)
		return
	SaveManager.new_game()
	var scene: Node = load("res://scenes/world/starting_grove.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	var loader: MapLoader = scene.get_node("Ground")
	check("grove material field source exists", ResourceLoader.exists("res://assets/tiles/grove_rock_field.png"))
	var seats := 0
	var bad_seats := 0
	var walls := 0
	var bad_walls := 0
	for node in loader.get_node("Elevation").get_children():
		if node is Sprite2D and node.z_index == loader.CLIFF_FACE_Z - 1:
			seats += 1
			var im: Image = node.texture.get_image()
			if not node.has_meta("contact_edge") or im.get_data() == CliffGen.make_ao_diamond(0.6).get_data():
				bad_seats += 1
	for node in loader.get_node("CliffSkirts").get_children():
		walls += 1
		if not node.has_meta("grove_material_origin"):
			bad_walls += 1
	check("raised-terrain contacts replace tile-centred AO after coupled physics tests", seats > 0 and bad_seats == 0)
	check("all grove outer skirts sample a continuous authored material field", walls > 0 and bad_walls == 0)
	var wrong_faces := 0
	var expected_faces := 0
	for cell in loader.get_used_cells():
		if not loader.call("_is_island_cell", cell): continue
		var se := loader.get_neighbor_cell(cell, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE)
		var sw := loader.get_neighbor_cell(cell, TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE)
		var right_open: bool = loader.call("_is_cliff_open", se)
		var left_open: bool = loader.call("_is_cliff_open", sw)
		if right_open or left_open: expected_faces += 1
	for node in loader.get_node("CliffSkirts").get_children():
		if not node.has_meta("grove_material_origin"): continue
		var origin: Vector2i = node.get_meta("grove_material_origin")
		var cell: Vector2i = loader.local_to_map(Vector2(origin + Vector2i(64,32)))
		var im: Image = node.texture.get_image()
		var se := loader.get_neighbor_cell(cell, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE)
		var sw := loader.get_neighbor_cell(cell, TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE)
		if (im.get_pixel(96,128).a > 0) != bool(loader.call("_is_cliff_open",se)): wrong_faces += 1
		if (im.get_pixel(32,128).a > 0) != bool(loader.call("_is_cliff_open",sw)): wrong_faces += 1
	check("actual staggered TileSet neighbours control both cliff faces", wrong_faces == 0 and walls == expected_faces)
	print("SURFACE_GEOMETRY wrong_faces=%d walls=%d expected=%d neighbour_delta=%s" % [wrong_faces,walls,expected_faces,loader.map_to_local(Vector2i(13,32))-loader.map_to_local(Vector2i(12,32))])
	# Equal world coordinates must be equal colors even when cell textures overlap.
	if walls > 0 and bad_walls == 0:
		var first: Sprite2D = loader.get_node("CliffSkirts").get_child(0)
		var art = load("res://scripts/world/grove_surface_art.gd")
		var origin: Vector2i = first.get_meta("grove_material_origin")
		# Explicit corner fixture: the first real border cell may expose ONLY its
		# left face, which has no overlap with a right-shifted fixture.
		var image: Image = art.wall(origin,176,true,true)
		var second: Image = art.wall(origin + Vector2i(64,32),176,true,true)
		var equal := true
		var compared := 0
		for y in range(32, image.get_height()):
			for x in range(64,128):
				var a := image.get_pixel(x,y)
				var b := second.get_pixel(x-64,y-32)
				if a.a > 0 and b.a > 0:
					compared += 1
					if a != b: equal = false
		check("overlapping skirt world pixels agree exactly", equal and compared > 100)
	check("base tile count stays 1600",loader.get_used_cells().size()==1600)
	var rimmed := 0
	for node in loader.get_node("CliffSkirts").get_children():
		if node.has_meta("grove_rim_profile"): rimmed += 1
	check("outer cliff has shared land-to-rock soil contact, not bare rock to grass",rimmed==walls and rimmed>0)
	var surface = load("res://scripts/world/grove_surface_art.gd")
	if surface.has_method("rim_profile"):
		var origins := [Vector2i(0,0),Vector2i(64,32)]
		var faces := [Vector2i.ONE,Vector2i.ONE]
		var profile: Dictionary = surface.rim_profile(origins,faces,176)
		var a: Image = surface.skirt_wall(origins[0],176,true,true,profile)
		var b: Image = surface.skirt_wall(origins[1],176,true,true,profile)
		var mismatch := 0
		var ink := 0
		for y in range(32,a.get_height()):
			for x in range(64,128):
				if a.get_pixel(x,y).a>0 and b.get_pixel(x-64,y-32).a>0:
					ink+=1
					if a.get_pixel(x,y)!=b.get_pixel(x-64,y-32): mismatch+=1
		check("shared outer-rim material never produces overlap stripes",ink>100 and mismatch==0)
		var original: Image = surface.wall(origins[0],176,true,true)
		var alpha_equal := true
		for y in range(a.get_height()):
			for x in range(a.get_width()):
				if a.get_pixel(x,y).a!=original.get_pixel(x,y).a: alpha_equal=false
		check("soil contact preserves the complete exterior alpha mask",alpha_equal)
	else:
		check("shared cliff rim raster API exists",false)
	var actual_edges: Dictionary = {}
	var actual_soil_banks: Dictionary = {}
	for sprite in loader.get_node("EdgeOverlay").get_children():
		var cell: Vector2i = loader.local_to_map(sprite.position)
		if sprite.has_meta("soil_water_bank"):
			actual_soil_banks[str(cell)+":"+String(sprite.get_meta("soil_water_bank"))]=true
		else:
			actual_edges[str(cell)+":"+sprite.texture.resource_path.get_file()] = true
	var expected_edges: Dictionary = {}
	var expected_soil_banks: Dictionary = {}
	var neighbours := {"br":TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,"bl":TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,"tl":TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,"tr":TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE}
	for cell in loader.get_used_cells():
		if not loader.call("_is_grass_cell",cell): continue
		for side in neighbours:
			var nb := loader.get_neighbor_cell(cell,neighbours[side])
			var mat: String = loader.call("_edge_material_at",nb)
			if not mat.is_empty(): expected_edges[str(cell)+":edge_%s_%s.png" % [mat,side]]=true
	check("grass banks meet actual staggered water/dirt neighbour sides",actual_edges==expected_edges)
	for cell in loader.get_used_cells():
		if loader.get_cell_source_id(cell)!=1: continue
		for side in neighbours:
			var nb := loader.get_neighbor_cell(cell,neighbours[side])
			if String(loader.call("_edge_material_at",nb))=="water":
				expected_soil_banks[str(cell)+":"+String(side)]=true
	check("soil-water junctions have complete physical-material bank coverage",expected_soil_banks.size()>0 and actual_soil_banks==expected_soil_banks)
	print("SOIL_BANK_GEOMETRY actual=%d expected=%d" % [actual_soil_banks.size(),expected_soil_banks.size()])
	print("BANK_GEOMETRY actual=%d expected=%d" % [actual_edges.size(),expected_edges.size()])
	check("spawn and stepping slots unchanged",loader.spawn_cell==Vector2i(12,32) and loader.stepping_slot_cells.size()==3)
	SaveManager.unregister_world()
	scene.queue_free()
	await get_tree().process_frame
	print("GROVE_SURFACE_RESULT failures=%d" % failures)
	get_tree().quit(failures)
