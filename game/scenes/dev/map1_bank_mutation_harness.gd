extends "res://scenes/dev/l1_gameplay_capture.gd"
## Synthetic endpoint; real public ground gather, disk save, reload and tile edit.
var failures:=0
var ground:MapLoader
const CELL=Vector2i(16,15)
func check(label:String,ok:bool)->void:
	print(("[PASS] " if ok else "[FAIL] ")+label)
	if not ok:failures+=1
func bank_matches_live()->bool:
	var source:=ground.get_cell_source_id(CELL)
	var found:=0
	for node in ground.find_children("*","Sprite2D",true,false):
		if node.get_meta("low_bank_surface_cell",Vector2i(-1,-1))!=CELL:continue
		found+=1
		if source<0:
			if node.visible:return false
			continue
		var atlas:=ground.tile_set.get_source(source) as TileSetAtlasSource
		var tex:=AtlasTexture.new();tex.atlas=atlas.texture;tex.region=atlas.get_tile_texture_region(Vector2i.ZERO)
		if not node.visible or node.texture.get_image().get_data()!=tex.get_image().get_data():return false
	return found==1
func _runtime_record(phase:String)->Dictionary:
	var r:=super._runtime_record(phase)
	r["capture_kind"]="diagnostic normal-root low-bank mutation"
	r["test_state_injection"]="new v2 direct scene and starting cell; public ground gather, isolated disk save/reload; separate explicit erase/restore fixture"
	return r
func _run()->void:
	SaveManager.new_game_for_layout("l1-v2")
	_tree.change_scene_to_file("res://scenes/world/starting_grove.tscn")
	if not await _wait_scene_seconds("StartingGrove",10):get_tree().quit(86);return
	await _tree.create_timer(4).timeout
	ground=_tree.current_scene.get_node("Ground")
	var player:Player=_tree.current_scene.get_node("YSortLayer/Player")
	player.global_position=ground.cell_center_world(CELL)
	player.get_node("Camera2D").reset_smoothing();await _frames(12)
	check("fresh bank matches live tile",bank_matches_live())
	var original:=ground.get_cell_source_id(CELL)
	var interaction:InteractionController=_tree.current_scene.get_node("Interaction")
	var data:=ground.get_cell_tile_data(CELL)
	var item:=str(data.get_custom_data("item_id"))
	var before:=Inventory.count(item)
	interaction.interact_with_cell(CELL);await _frames(6)
	check("actual low-bank gather changes source and rewards once",ground.get_cell_source_id(CELL)==11 and Inventory.count(item)==before+1)
	check("gathered low-bank presentation follows live hollow",bank_matches_live())
	await _capture("bank-gathered.png","diagnostic_public_gather")
	check("isolated mutation save",SaveManager.save_game())
	SaveManager.unregister_world();SaveManager.pending_load=true
	_tree.reload_current_scene();await _tree.create_timer(2).timeout
	ground=_tree.current_scene.get_node("Ground")
	check("reload restores gathered bank source",ground.get_cell_source_id(CELL)==11)
	check("loaded bank presentation follows save overlay",bank_matches_live())
	await _capture("bank-loaded.png","diagnostic_saved_hollow")
	ground.erase_cell(CELL);await _frames(6)
	check("explicit erase hides auxiliary low bank",bank_matches_live())
	ground.set_cell(CELL,original,Vector2i.ZERO);await _frames(6)
	check("explicit restore refreshes low bank",bank_matches_live())
	print("MAP1_BANK_MUTATION_DONE failures=",failures)
	_tree.quit(1 if failures or _failed else 0)
