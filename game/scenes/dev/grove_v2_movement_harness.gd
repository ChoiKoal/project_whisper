extends "res://scenes/dev/grove_revision_harness.gd"
## Physics fixture: direct candidate boot; injected D14 only to open G1.
## Each lane uses real Player keyboard ascent and public tap descent; no teleport.
func run()->void:
	SaveManager.new_game_for_layout("l1-v2")
	var world:Node=load("res://scenes/world/starting_grove.tscn").instantiate()
	add_child(world);await frames(15)
	var ground:MapLoader=world.get_node("Ground")
	var player:Player=world.get_node("YSortLayer/Player")
	var touch:TouchController=world.get_node("TouchController")
	var interaction:InteractionController=world.get_node("Interaction")
	var directions:=[Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]
	for ramp:Vector2i in ground.ramp_cells:
		var legal:=0
		var climb:=ground._ramp_climb_dir(ramp)
		var sx:=1.0 if climb in ["ne","se"] else -1.0
		var sy:=1.0 if climb in ["se","sw"] else -1.0
		for direction:Vector2i in directions:
			var nb:=ground.terrain_neighbor(ramp,direction)
			var delta:=ground.map_to_local(nb)-ground.map_to_local(ramp)
			var midpoint:=delta*0.5
			var tangent:=Vector2(delta.x,-delta.y)*0.5
			var gap:=0.0
			for local:Vector2 in [midpoint-tangent,midpoint+tangent]:
				var slope:=clampf(0.5+0.5*(sx*local.x/64.0+sy*local.y/32.0),0,1)
				var neighbour_level:=float(ground.height_at(nb))
				if ground.is_ramp(nb):
					var q:=local-delta
					neighbour_level=clampf(0.5+0.5*(sx*q.x/64.0+sy*q.y/32.0),0,1)
				gap=maxf(gap,absf(slope-neighbour_level)*32)
			var traversable:=ground.can_traverse(ramp,nb)
			check("every allowed shared edge has coincident full endpoints %s -> %s gap=%s"%[ramp,nb,gap],not traversable or gap<0.01)
			if traversable:legal+=1
		check("broad slope remains laterally joined "+str(ramp),legal>=3)
	if failures>0:
		SaveManager.unregister_world();world.queue_free();await frames(3)
		print("GROVE_MOVEMENT_DONE failures=",failures);get_tree().quit(1);return
	Inventory.add("D14",3);interaction.set_held_item("D14")
	for cell in ground.stepping_slot_cells:interaction._try_place_on_tile(cell)
	interaction.set_held_item("");await frames(3)
	for row in range(16,23):
		var ramp:=Vector2i(11+row/2,row)
		var high:=ground.terrain_neighbor(ramp,Vector2i(0,-1))
		var low:=ground.terrain_neighbor(ramp,Vector2i(0,1))
		check("opposite lane endpoint levels "+str(ramp),ground.height_at(low)==0 and ground.height_at(high)==1)
		if not await walk(touch,player,ground,low):break
		var end:=ground.cell_center_world(high)
		var start:=player.global_position
		var horizontal:="move_right" if end.x>start.x else "move_left"
		Input.action_press(horizontal);Input.action_press("move_up")
		var deadline:=Time.get_ticks_msec()+2500
		while player.global_position.distance_to(end)>9 and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
		Input.action_release(horizontal);Input.action_release("move_up")
		await get_tree().physics_frame
		check("actual keyboard ascent lane "+str(ramp),player.global_position.distance_to(end)<12)
		if not await walk(touch,player,ground,low):break
		check("tap descent ends at low logical surface "+str(ramp),ground.height_at(ground.world_to_cell(player.global_position))==0)
		if failures>0:break
	SaveManager.unregister_world();world.queue_free();await frames(3)
	print("GROVE_MOVEMENT_DONE failures=",failures)
	get_tree().quit(1 if failures else 0)
func walk(touch:TouchController,player:Player,ground:MapLoader,cell:Vector2i)->bool:
	var accepted:=touch.move_to(cell)
	check("public tap route accepted "+str(cell),accepted)
	if not accepted:return false
	var target:=ground.cell_center_world(cell)
	var deadline:=Time.get_ticks_msec()+24000
	while player.is_pathing() and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
	var arrived:=player.global_position.distance_to(target)<9
	check("real physics arrives "+str(cell)+" actual="+str(player.global_position),arrived)
	return arrived
