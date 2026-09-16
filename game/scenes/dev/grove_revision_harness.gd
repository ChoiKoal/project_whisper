extends Node
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var failures:=0
func check(label:String,ok:bool)->void:
	print("[%s] %s"%["PASS" if ok else "FAIL",label]);if not ok:failures+=1
func _ready()->void:
	if not GUARD.require_isolated_user_data("grove_revision"):get_tree().quit(86);return
	get_tree().current_scene=null # persistent test owner across actual Title scene changes
	call_deferred("run")
func run()->void:
	check("run layout resolver exists before scene instantiation",SaveManager.has_method("inspect_grove_layout"))
	if not SaveManager.has_method("inspect_grove_layout"):get_tree().quit(1);return
	var legacy:Dictionary=SaveManager.call("inspect_grove_layout",{"worlds":{"home":{}}})
	check("old never-visited Grove resolves legacy",legacy.ok and legacy.revision=="l1-v1")
	for token in ["l1-v1","l1-v2"]:
		var data:Dictionary={"world_layouts":{"grove":token},"worlds":{"grove":{"layout_revision":token,"placed_objects":[{"item_id":"D10","cell":[23,35]}]}}}
		var before:=JSON.stringify(data)
		var result:Dictionary=SaveManager.call("inspect_grove_layout",data)
		check("exact revision accepted "+token,result.ok and result.revision==token)
		check("inspection never remaps source "+token,JSON.stringify(data)==before)
	for token in ["l1-v3","L1-v2","l1-v2 ",2,null]:
		var result:Dictionary=SaveManager.call("inspect_grove_layout",{"world_layouts":{"grove":token}})
		check("unknown literal rejected "+str(token),not result.ok)
	var mismatch:Dictionary=SaveManager.call("inspect_grove_layout",{"world_layouts":{"grove":"l1-v2"},"worlds":{"grove":{"placed_objects":[]}}})
	check("missing snapshot revision cannot be transplanted onto v2",not mismatch.ok)
	await runtime_contract()
	print("GROVE_REVISION_DONE failures=",failures)
	get_tree().quit(1 if failures else 0)
func runtime_contract()->void:
	check("explicit candidate run API exists",SaveManager.has_method("new_game_for_layout"))
	if not SaveManager.has_method("new_game_for_layout"):return
	check("candidate choice accepted",SaveManager.call("new_game_for_layout","l1-v2"))
	check("candidate choice precedes Grove visit",SaveManager.build_save_dict().get("world_layouts",{}).get("grove")=="l1-v2")
	check("new run candidate persists to isolated disk",SaveManager.save_game())
	var preserved:=FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	SaveManager.new_game()
	SaveManager.pending_load=true
	check("pending load chooses disk revision before map ready",SaveManager.call("grove_revision_for_build")=="l1-v2")
	SaveManager.pending_load=false
	var bad:Dictionary=JSON.parse_string(preserved)
	bad.world_layouts.grove="l1-v999"
	var bad_text:=JSON.stringify(bad)
	var out:=FileAccess.open(SaveManager.SAVE_PATH,FileAccess.WRITE);out.store_string(bad_text);out.close()
	check("unsupported disk layout rejected",SaveManager._read_save().is_empty())
	check("rejected layout blocks autosave",not SaveManager.save_game())
	var title:=TitleMenu.new();add_child(title)
	title._on_continue()
	check("Continue refuses unknown layout without deleting save",FileAccess.get_file_as_string(SaveManager.SAVE_PATH)==bad_text)
	title.queue_free()
	if failures>0:get_tree().quit(1);return
	SaveManager.new_game()
	await scene_contract()
func frames(count:int)->void:
	for i in range(count):await get_tree().process_frame
func scene_contract()->void:
	SaveManager.call("new_game_for_layout","l1-v2")
	var scene:Node=load("res://scenes/world/starting_grove.tscn").instantiate()
	add_child(scene);await frames(15)
	var ground:MapLoader=scene.get_node("Ground")
	check("candidate selected before map construction",ground.spawn_cell==Vector2i(14,35))
	check("candidate uses seven authored ramp lanes",ground.ramp_cells.size()==7)
	check("candidate scatter disabled",not ground.enable_scatter)
	check("new path still uses STACKED adjacency",ground.uses_grove_topology() and ground.terrain_neighbor(Vector2i(20,19),Vector2i(1,0))==ground.get_neighbor_cell(Vector2i(20,19),TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE))
	var save:=SaveManager.build_save_dict()
	check("snapshot revision matches run revision",save.worlds.grove.get("layout_revision")=="l1-v2")
	var source:=ground.get_cell_source_id(Vector2i(1,1))
	SaveManager._worlds.grove={"layout_revision":"l1-v1","void_cells":[[1,1]],"objects":[]}
	check("mismatch restore is refused",not SaveManager.restore_registered_world())
	check("mismatch refuses before touching cells",ground.get_cell_source_id(Vector2i(1,1))==source)
	SaveManager.unregister_world();scene.queue_free();await frames(3)
	SaveManager.new_game()
