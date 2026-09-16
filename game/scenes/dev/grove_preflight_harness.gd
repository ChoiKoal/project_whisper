extends "res://scenes/dev/grove_revision_harness.gd"
func store(data:Dictionary)->String:
	var text:=JSON.stringify(data);var f:=FileAccess.open(SaveManager.SAVE_PATH,FileAccess.WRITE);f.store_string(text);f.close();return text
func run()->void:
	SaveManager.new_game_for_layout("l1-v2")
	var world:Node=load("res://scenes/world/starting_grove.tscn").instantiate();add_child(world);await frames(15)
	var ground:MapLoader=world.get_node("Ground")
	var ic:InteractionController=world.get_node("Interaction")
	ic.set_held_item("D14");ic._has_tile_target=true;ic._target_object=null;ic._target_cell=Vector2i(21,30)
	check("held HUD refuses X placement affordance",ic.held_action_hint()!="E: 배치")
	ic._target_cell=Vector2i(22,30);check("held HUD retains K placement affordance",ic.held_action_hint()=="E: 배치")
	ic.set_held_item("")
	SaveManager.save_game();var good:=SaveManager.build_save_dict();var original:=store(good)
	var worlds_before:=JSON.stringify(SaveManager._worlds)
	SaveManager.grove_layout_revision="l1-v1"
	check("run/loader mismatch refuses save",not SaveManager.save_game())
	check("rejected save preserves disk bytes",FileAccess.get_file_as_string(SaveManager.SAVE_PATH)==original)
	check("rejected save preserves cached worlds",JSON.stringify(SaveManager._worlds)==worlds_before)
	SaveManager._apply_core_state(good)
	var loaded:=[0];SaveManager.game_loaded.connect(func():loaded[0]+=1)
	var bad:=good.duplicate(true);bad.inventory={"I1":777};bad.worlds.grove.void_cells.append([21,30])
	var bad_bytes:=store(bad);var inventory_before:=Inventory.count("I1")
	check("disk protected-stream rejection reports failure",SaveManager.load_game().is_empty())
	check("disk rejection leaves inventory untouched",Inventory.count("I1")==inventory_before)
	check("disk rejection never emits loaded",loaded[0]==0)
	check("disk rejection keeps source water and original bytes",ground.get_cell_source_id(Vector2i(21,30))==8 and FileAccess.get_file_as_string(SaveManager.SAVE_PATH)==bad_bytes)
	SaveManager.unregister_world();world.queue_free();await frames(3)
	SaveManager.new_game();store(SaveManager.build_save_dict());SaveManager.pending_load=true
	world=load("res://scenes/foundation/grove_v2_candidate.tscn").instantiate();add_child(world);await frames(15)
	check("profile rejection cannot register an unbuilt map",SaveManager._loader==null)
	check("profile rejection remains blocked after session setup",not SaveManager.layout_load_error.is_empty() and not SaveManager.save_game())
	SaveManager.unregister_world();world.queue_free();await frames(3)
	print("GROVE_PREFLIGHT_DONE failures=",failures);get_tree().quit(1 if failures else 0)
