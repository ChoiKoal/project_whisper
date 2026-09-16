extends Node
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var failures:=0
func check(label:String,ok:bool)->void:
	print(("[PASS] " if ok else "[FAIL] ")+label)
	if not ok:failures+=1
func _ready()->void:
	get_tree().create_timer(45,true,false,true).timeout.connect(func():get_tree().quit(89))
	call_deferred("run")
func run()->void:
	if not GUARD.require_isolated_user_data("flower_craft"):get_tree().quit(86);return
	for revision in ["l1-v2","l1-v1"]:
		SaveManager.new_game_for_layout(revision)
		var scene:Node=load("res://scenes/world/starting_grove.tscn").instantiate();add_child(scene)
		for i in range(12):await get_tree().process_frame
		var ground:MapLoader=scene.get_node("Ground")
		var respawn:ObjectRespawn=scene.get_node("ObjectRespawn")
		var found:=0
		for entry in respawn._tracked:
			if entry.symbol!="F":continue
			var node:Gatherable=entry.node
			var expected:=ground._object_texture("F",entry.cell)
			check(revision+" initial/respawn flower art agrees "+str(entry.cell),node.texture.resource_path==expected[0])
			check(revision+" art scope "+str(entry.cell),expected[0].contains("/foundation/flowers/")== (revision=="l1-v2"))
			check(revision+" flower contract "+str(entry.cell),node.item_id=="I5" and not node.blocks_movement and node.offset==Vector2(0,-24+ground.height_offset(entry.cell)))
			if found==0:
				var rebuilt:=ground.rebuild_gatherable("F",entry.cell)
				check(revision+" rebuilt identity/art preserved",rebuilt.item_id==node.item_id and rebuilt.texture.resource_path==node.texture.resource_path)
				rebuilt.free()
			found+=1
		check(revision+" live authored/scatter flower coverage",found>0)
		SaveManager.unregister_world();scene.queue_free();await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
