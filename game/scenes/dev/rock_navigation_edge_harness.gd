extends Node
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var failures:=0
func check(label: String,ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ")+label)
	if not ok: failures+=1
func _ready() -> void: call_deferred("run")
func run() -> void:
	if not GUARD.require_isolated_user_data("rock_navigation_edge"):
		get_tree().quit(86);return
	SaveManager.new_game()
	var scene: Node=load("res://scenes/world/starting_grove.tscn").instantiate();add_child(scene)
	for i in range(8): await get_tree().physics_frame
	var ground: MapLoader=scene.get_node("Ground")
	var player: Player=scene.get_node("YSortLayer/Player")
	var touch: TouchController=scene.get_node("TouchController")
	var respawn: ObjectRespawn=scene.get_node("ObjectRespawn")
	var cell:=Vector2i(22,37)
	var entry: Dictionary=respawn.entry_for_cell(cell)
	var rock: Gatherable=entry.node
	# Disclosed isolated setup, physically free side of the existing rock's cell.
	player.global_position=rock.target_point()+Vector2(48,0)
	await get_tree().physics_frame
	check("side of boulder is in omitted cell but outside physical foot",ground.world_to_cell(player.global_position)==cell and player.global_position.distance_to(rock.target_point())>44 and not player.test_move(player.global_transform,Vector2(2,0)))
	var dest:=Vector2i(22,36)
	var target:=ground.cell_center_world(dest)
	check("nearby object approach reachable from free edge of blocked cell",touch._nearest_walkable_adjacent(cell)!=Vector2i(-1,-1))
	var accepted:=touch.move_to(dest)
	check("tap can leave partially occupied cell without gathering",accepted)
	if accepted:
		for i in range(120):
			await get_tree().physics_frame
			if player.global_position.distance_to(target)<8: break
		check("edge escape physically arrives and preserves rock",player.global_position.distance_to(target)<8 and is_instance_valid(rock) and Inventory.count("I6")==0)
	player.release_move_and_path()
	SaveManager.unregister_world();scene.queue_free();await get_tree().process_frame
	print("ROCK_EDGE failures=",failures)
	get_tree().quit(1 if failures else 0)
