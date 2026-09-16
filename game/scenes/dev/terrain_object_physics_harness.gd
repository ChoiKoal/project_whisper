extends Node
## Raised blocking Gatherable must share the Player's logical collision coordinates.
## Synthetic fixture, actual Player and Gatherable scripts/physics, isolated HOME.
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
class Fixture extends MapLoader:
	func _ready() -> void: pass
class LegacyTarget extends Node2D:
	func target_point() -> Vector2: return global_position
var failures := 0
func check(label: String, ok: bool, detail := "") -> void:
	print("[%s] %s %s" % ["PASS" if ok else "FAIL",label,detail])
	if not ok: failures += 1
func _ready() -> void:
	if not GUARD.require_isolated_user_data("terrain_object_physics"):
		get_tree().quit(86)
		return
	call_deferred("run")
func frames(n: int) -> void:
	for i in range(n): await get_tree().physics_frame
func run() -> void:
	GameState.time_running = true
	var template: Node = load("res://scenes/world/starting_grove.tscn").instantiate()
	var tiles: TileSet = template.get_node("Ground").tile_set
	template.free()
	var legacy := LegacyTarget.new()
	legacy.position=Vector2(100,200)
	add_child(legacy)
	var fallback_controller := InteractionController.new()
	check("legacy target feedback fallback retains logical point",fallback_controller._object_visual_point(legacy)==legacy.global_position)
	fallback_controller.free()
	legacy.queue_free()
	for level in [0,1,2]:
		var loader := Fixture.new()
		loader.tile_set = tiles
		loader.width = 20
		loader.height = 20
		add_child(loader)
		for y in range(20):
			for x in range(20): loader.set_cell(Vector2i(x,y),2,Vector2i.ZERO)
		var cell := Vector2i(8,8+level)
		loader.elevation[cell] = level
		var origin := loader.cell_center_world(cell)
		var tree := Gatherable.new()
		tree.texture = load("res://assets/objects/tree_a.png")
		tree.blocks_movement = true
		tree.item_id = "I4"
		tree.offset = Vector2(0,-64)
		tree.position = origin
		add_child(tree)
		var decoration := Node2D.new()
		decoration.position = Vector2(4,-12)
		tree.add_child(decoration)
		var original_decoration := decoration.global_position
		var original_ink := tree.to_global(tree.offset)
		loader.apply_height_lift(tree)
		loader.apply_height_lift(tree)  # Initial pass + respawn reuse is idempotent.
		var visual := origin+Vector2(0,-32*level)
		check("projected interaction foot level%d" % level,tree.visual_target_point().is_equal_approx(visual))
		check("decoration lifted exactly once level%d" % level,decoration.global_position.is_equal_approx(original_decoration+Vector2(0,-32*level)))
		check("raised root stays at saved logical cell level%d" % level,tree.position.is_equal_approx(origin))
		check("raised target uses logical cell level%d" % level,tree.target_point().is_equal_approx(origin))
		check("raised sprite preserves exact projected artwork level%d" % level,tree.to_global(tree.offset).is_equal_approx(original_ink+Vector2(0,-32*level)))
		for child in tree.get_children():
			if child is StaticBody2D: check("trunk body stays at logical root level%d" % level,child.global_position.is_equal_approx(origin),"body=%s root=%s" % [child.global_position,origin])
		var player := Player.new()
		player.motion_mode=CharacterBody2D.MOTION_MODE_FLOATING
		player._tilemap=loader
		var collision := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius=20
		collision.shape=circle
		player.add_child(collision)
		add_child(player)
		var interaction := InteractionController.new()
		add_child(interaction)
		interaction._tilemap=loader
		interaction._player=player
		check("interaction resolves original raised object cell level%d" % level,interaction._object_cell(tree)==cell)
		for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			player.release_move_and_path()
			player.position=origin+direction*90
			await frames(3)
			player.set_path([origin])
			await frames(35)
			var distance := player.position.distance_to(origin)
			check("actual trunk collision aligned level%d direction%s" % [level,direction],distance>=39 and distance<=42,"distance=%s" % distance)
		player.release_move_and_path()
		interaction.set_process(false)
		var touch := TouchController.new()
		add_child(touch)
		touch._loader = loader
		touch._player = player
		touch._interaction = interaction
		check("tap picks projected foot level%d" % level,touch._object_near(visual)==tree)
		interaction._target_object = tree
		interaction._update_prompt()
		check("prompt uses projected foot level%d" % level,interaction._prompt != null and is_equal_approx(interaction._prompt.global_position.y,visual.y-64))
		# Exercise both controller paths against a real non-unique Gatherable. Capture
		# the real feedback label synchronously, before its tween starts to rise.
		for mode in ["direct", "tap"]:
			var flower := Gatherable.new()
			flower.item_id = "I5"
			flower.position = origin
			add_child(flower)
			loader.apply_height_lift(flower)
			var before := Inventory.count("I5")
			var feedback := Node2D.new()
			add_child(feedback)
			interaction._feedback_layer = feedback
			interaction._target_object = flower
			interaction._hover_object = null
			if mode == "direct": interaction._do_interact()
			else: touch._target_object(flower)
			check("real %s gather grants item level%d" % [mode,level],Inventory.count("I5")==before+1 and flower.is_queued_for_deletion())
			var label := feedback.get_child(0) as Label if feedback.get_child_count()>0 else null
			check("%s feedback uses projected foot level%d" % [mode,level],label!=null and label.global_position.is_equal_approx(visual-Vector2(0,40)),"actual=%s expected=%s" % [label.global_position if label else Vector2.ZERO,visual-Vector2(0,40)])
			feedback.queue_free()
		# Verify the blocking TREE itself, not only a nonblocking flower: the
		# real gather removes its trunk and the Player can enter the cleared foot.
		var wood_before := Inventory.count("I4")
		var tree_feedback := Node2D.new()
		add_child(tree_feedback)
		interaction._feedback_layer = tree_feedback
		interaction.interact_with_object(tree)
		check("raised blocking tree grants actual wood level%d" % level,Inventory.count("I4")==wood_before+1 and tree.is_queued_for_deletion())
		interaction._target_object = null
		await frames(2)
		player.position=origin+Vector2.RIGHT*90
		await frames(3)
		player.set_path([origin])
		await frames(35)
		check("gathered trunk releases real physics path level%d" % level,player.position.distance_to(origin)<8,"distance=%s" % player.position.distance_to(origin))
		player.release_move_and_path()
		tree_feedback.queue_free()
		touch.queue_free()
		interaction.queue_free()
		player.queue_free()
		loader.queue_free()
		await frames(2)
	print("OBJECT_PHYSICS_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
