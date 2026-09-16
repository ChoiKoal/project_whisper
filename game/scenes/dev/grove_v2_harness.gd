extends Node
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var failures:=0
func check(label:String,ok:bool)->void:
	print("[%s] %s"%["PASS" if ok else "FAIL",label]);if not ok:failures+=1
func _ready()->void:
	if not GUARD.require_isolated_user_data("grove_v2"):get_tree().quit(86);return
	call_deferred("run")
func frames(n:int)->void:
	for i in range(n):await get_tree().process_frame
func run()->void:
	SaveManager.new_game_for_layout("l1-v2")
	var scene:Node=load("res://scenes/world/starting_grove.tscn").instantiate()
	add_child(scene);await frames(15)
	var ground:MapLoader=scene.get_node("Ground")
	var interaction:InteractionController=scene.get_node("Interaction")
	var touch:TouchController=scene.get_node("TouchController")
	var story:Node=scene.get_node("GroveSession/L1HomeStory")
	check("v2 void is not silently reinterpreted as tall ridge walls",ground.ridge_cells.is_empty())
	var dirt_top:Sprite2D=ground.get_node_or_null("Elevation/Surfaces/Top_24_17")
	var dirt_texture:Texture2D=(ground.tile_set.get_source(1) as TileSetAtlasSource).texture
	check("raised D route keeps actual dirt material",dirt_top!=null and dirt_top.texture is AtlasTexture and dirt_top.texture.atlas==dirt_texture)
	check("v2 actual cairn uses revision anchor",ground.world_to_cell(story.cairn.global_position)==Vector2i(29,17))
	var protected:=[Vector2i(21,30),Vector2i(22,30)]
	for cell in protected:
		var before:=Inventory.count("I7")
		interaction.interact_with_cell(cell)
		check("v2 X/K gather does not grant water "+str(cell),Inventory.count("I7")==before)
		check("v2 X/K remains solid stream "+str(cell),ground.get_cell_source_id(cell)==8)
		ground.set_cell(cell,8,Vector2i.ZERO) # isolate subsequent assertions after expected RED
		interaction._target_object=null;interaction._has_tile_target=true;interaction._target_cell=cell
		check("protected water has honest no-gather cue "+str(cell),interaction._prompt_text().contains("물살"))
	Inventory.add("D14",4);interaction.set_held_item("D14")
	check("X stream is not a D14 placement preview",not touch._cell_is_actionable(Vector2i(21,30)))
	check("X cannot consume D14 or bridge around G1",not interaction._try_place_on_tile(Vector2i(21,30)) and Inventory.count("D14")==4)
	for cell in ground.stepping_slot_cells:
		check("K still accepts D14 "+str(cell),interaction._try_place_on_tile(cell))
	interaction.set_held_item("")
	var pond:=Vector2i(-1,-1)
	for y in range(ground.height):
		for x in range(ground.width):
			if ground._layout[y][x]=="W":pond=Vector2i(x,y)
	var water_before:=Inventory.count("I7")
	interaction.interact_with_cell(pond)
	check("pond still yields I7 and walkable hollow",Inventory.count("I7")==water_before+1 and ground.get_cell_source_id(pond)==11)
	check("new revision saves",SaveManager.save_game())
	var encoded:=FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	SaveManager._worlds.grove.void_cells.append([21,30])
	check("invalid protected-water snapshot rejected before mutation",not SaveManager.restore_registered_world())
	check("rejected snapshot never overwrites original disk",not SaveManager.save_game() and FileAccess.get_file_as_string(SaveManager.SAVE_PATH)==encoded)
	SaveManager.unregister_world();scene.queue_free();await frames(3)
	print("GROVE_V2_DONE failures=",failures)
	get_tree().quit(1 if failures else 0)
