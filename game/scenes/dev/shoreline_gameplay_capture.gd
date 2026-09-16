extends "res://scenes/dev/l1_gameplay_capture.gd"
## Extends the normal root route, walks every new bank cell through TouchController,
## then returns to the original route through AStar. No additional L1 teleport.
const BANK = [Vector2i(11,35),Vector2i(11,36),Vector2i(10,37),Vector2i(11,37),Vector2i(10,38),Vector2i(11,38)]
func _capture(filename: String, phase: String) -> void:
	await super._capture(filename,phase)
	if phase!="l1_after_real_movement": return
	var grove := _tree.current_scene
	var ground: MapLoader=grove.get_node("Ground")
	var player: Player=grove.get_node("YSortLayer/Player")
	var touch: TouchController=grove.get_node("TouchController")
	var start:=ground.world_to_cell(player.global_position)
	for cell in BANK:
		if not touch.move_to(cell):
			_fail("new bank real touch path rejected %s" % cell)
			return
		var target:=ground.to_global(ground.map_to_local(cell))
		var deadline:=Time.get_ticks_msec()+8000
		while player.global_position.distance_to(target)>7 and Time.get_ticks_msec()<deadline:
			await _physics_frames(1)
		player.release_move_and_path()
		if player.global_position.distance_to(target)>9:
			_fail("new bank real body could not reach %s actual=%s" % [cell,player.global_position])
			return
		print("[PASS] normal root actual bank walk ",cell)
	await _tree.create_timer(0.8,true,false,true).timeout
	await super._capture("normal-l1-new-bank.png","new_bank_after_actual_touch_walk_all_six")
	if not touch.move_to(start):
		_fail("new bank return route rejected")
		return
	var target:=ground.to_global(ground.map_to_local(start))
	var deadline:=Time.get_ticks_msec()+8000
	while player.global_position.distance_to(target)>7 and Time.get_ticks_msec()<deadline:
		await _physics_frames(1)
	player.release_move_and_path()
	if player.global_position.distance_to(target)>9: _fail("new bank cannot rejoin Home return route")
	else: print("[PASS] normal root bank walk rejoins return route without teleport")
