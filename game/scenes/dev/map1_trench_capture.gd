extends "res://scenes/dev/l1_gameplay_capture.gd"
## Diagnostic normal ROOT viewport, NOT a normal-input journey: explicit v2 fresh
## save, scene dispatch, player positioning, fixed day time. Production camera zoom.
var failures := 0
var samples: Array = []
func _runtime_record(phase: String) -> Dictionary:
	var data:=super._runtime_record(phase)
	data["capture_kind"]="diagnostic_normal_root_injected_scene_position_day"
	data["test_state_injection"]="fresh l1-v2, dispatch StartingGrove directly, player cell positioning and day=.30; no title/Home/input journey in this diagnostic"
	data["layout_revision"]="l1-v2"
	data["time"] = GameState.game_time
	return data
func check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ")+label)
	if not ok: failures+=1
func _run() -> void:
	SaveManager.new_game_for_layout("l1-v2")
	_tree.change_scene_to_file("res://scenes/world/starting_grove.tscn")
	if not await _wait_scene_seconds("StartingGrove",10):
		check("normal scene ready",false);finish_probe();return
	await _tree.create_timer(4.0).timeout
	var world := _tree.current_scene
	var map: MapLoader = world.get_node("Ground")
	var player: Player = world.get_node("YSortLayer/Player")
	var camera: Camera2D = player.get_node("Camera2D")
	check("v2 profile and real STACKED tiles",map.layout_revision=="l1-v2" and map.tile_set.tile_layout==TileSet.TILE_LAYOUT_STACKED)
	for setup in [["bands",Vector2i(22,12)],["left-mouth",Vector2i(16,12)],["right-mouth",Vector2i(32,12)]]:
		player.global_position=map.cell_center_world(setup[1])
		player.release_move_and_path()
		camera.reset_smoothing()
		await _frames(90)
		GameState.set_game_time(GameState.DAY_LENGTH*0.30)
		await _frames(2)
		await _capture(setup[0]+".png","DIAGNOSTIC_injected_position_time_"+setup[0])
		await RenderingServer.frame_post_draw
		var image := _tree.root.get_texture().get_image()
		var canvas := map.get_global_transform_with_canvas()
		var columns: Array = range(19,26) if setup[0]=="bands" else (range(13,19) if setup[0]=="left-mouth" else range(26,40))
		for row in [8,14]:
			for col: int in columns:
				var cell := Vector2i(col,row)
				if map._sym_at(cell)!="V":continue
				# Only cells actually sandwiched by a land bank at top and bottom;
				# exterior void is intentionally dark and is a negative control.
				var back_land := false;var front_land := false
				for side in [TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE]:
					back_land = back_land or map._is_island_cell(map.get_neighbor_cell(cell,side))
				for side in [TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE]:
					front_land = front_land or map._is_island_cell(map.get_neighbor_cell(cell,side))
				if not back_land or not front_land:continue
				var dark := 0;var tested := 0
				for dx in [-18,-6,6,18]:
					for dy in [-12,-4,4]:
						var screen := Vector2i(canvas*(map.map_to_local(cell)+Vector2(dx,dy)))
						if not Rect2i(Vector2i.ZERO,image.get_size()).has_point(screen):continue
						var color:=image.get_pixelv(screen)
						tested+=1
						if color.r8<30 and color.g8<30 and color.b8<38:dark+=1
				samples.append({"frame":setup[0],"cell":[col,row],"raw_void_pixels":dark,"tested":tested})
				check("no raw T0 core at %s %s"%[setup[0],cell],tested==12 and dark==0)
				check("V remains nonwalkable %s"%cell,not map.is_cell_walkable(cell))
				var seam_dark:=0;var seam_count:=0
				for x in range(-60,61,4):
					for y in range(-28,29,4):
						if absf(x)/64.0+absf(y)/32.0>0.94:continue
						var screen:=Vector2i(canvas*(map.map_to_local(cell)+Vector2(x,y)))
						if not Rect2i(Vector2i.ZERO,image.get_size()).has_point(screen):continue
						var color:=image.get_pixelv(screen)
						seam_count+=1
						if color.r8<30 and color.g8<30 and color.b8<38:seam_dark+=1
				samples.append({"frame":setup[0],"full_cut":[col,row],"raw_void_pixels":seam_dark,"tested":seam_count})
				check("full cut including mixed-height corner seams %s"%cell,seam_count>200 and seam_dark==0)
				# Broader raster oracle: the nonwalkable floor AND a low front
				# bank must not expose raw T0 rectangles outside the narrow core.
				var missing:=0;var count:=0
				for side in [TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE]:
					var nb:=map.get_neighbor_cell(cell,side)
					if not map._is_island_cell(nb) or map.height_at(nb)!=0:continue
					for x in range(-52,53,4):
						for y in range(-24,25,4):
							if absf(x)/64.0+absf(y)/32.0>0.82:continue
							var screen:=Vector2i(canvas*(map.map_to_local(nb)+Vector2(x,y)))
							if not Rect2i(Vector2i.ZERO,image.get_size()).has_point(screen):continue
							var color:=image.get_pixelv(screen)
							count+=1
							if color.r8<30 and color.g8<30 and color.b8<38:missing+=1
				if count>0:
					samples.append({"frame":setup[0],"low_bank_of":[col,row],"raw_void_pixels":missing,"tested":count})
					check("low bank is not cut away by T0 rectangle %s"%cell,missing==0)
	# Rebuild ownership: existing renderer may not yet supply the bank module.
	var trench := map.get_node_or_null("InternalTrenches")
	check("internal bank ownership exists",trench!=null)
	if trench!=null:
		var first := trench.get_child_count()
		map._build_elevation();await _frames(3)
		trench=map.get_node_or_null("InternalTrenches")
		check("elevation rebuild owns one bank set",trench!=null and trench.get_child_count()==first and world.find_children("InternalTrenches","",true,false).size()==1)
	check("nonempty pixel oracle",samples.size()>=20)
	var actual_cells:Dictionary={}
	for sample:Dictionary in samples:
		if sample.has("full_cut"):actual_cells[Vector2i(sample.full_cut[0],sample.full_cut[1])]=true
	var expected_cells:Dictionary={}
	for row in [8,14]:
		for col in range(map.width):
			var cell:=Vector2i(col,row)
			if map._sym_at(cell)!="V":continue
			var back:=false;var front:=false
			for side in [TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE]:back=back or map._is_island_cell(map.get_neighbor_cell(cell,side))
			for side in [TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE]:front=front or map._is_island_cell(map.get_neighbor_cell(cell,side))
			if back and front:expected_cells[cell]=true
	check("all authored internal cuts covered exactly",actual_cells==expected_cells)
	print("MAP1_PIXEL_CELLS expected=",expected_cells.size()," actual=",actual_cells.size()," expected_cells=",expected_cells.keys()," actual_cells=",actual_cells.keys())
	finish_probe()
func finish_probe() -> void:
	var data := {"kind":"diagnostic normal-root render, injected v2/scene/player/day; NOT normal-input evidence","records":_records,"samples":samples,"failures":failures}
	var file := FileAccess.open(_out_dir.path_join("trench-pixel-receipt.json"),FileAccess.WRITE)
	if file==null:failures+=1
	else:file.store_string(JSON.stringify(data,"\t"));file.close()
	print("MAP1_TRENCH_DONE failures=",failures)
	_tree.quit(1 if failures or _failed else 0)
