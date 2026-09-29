extends Node
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var failures:=0
var armed:=false
var early:Dictionary={}
var early_saved:=true
func check(label:String,ok:bool)->void:
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
	if not ok:failures+=1
func _ready()->void:
	if not GUARD.require_isolated_user_data("harvest_save"):
		get_tree().quit(86);return
	call_deferred("run")
func on_added(_id:String,_amount:int)->void:
	armed=true
	early=SaveManager.build_save_dict()
	early_saved=SaveManager.save_game()
func run()->void:
	for tree in [false,true]:
		var node:Gatherable=WorldTree.new() if tree else Gatherable.new()
		if not tree:node.item_id="I5"
		add_child(node)
		armed=false
		Inventory.item_added.connect(on_added)
		node.gather()
		Inventory.item_added.disconnect(on_added)
		check("save listener armed tree=%s" % tree,armed)
		check("partial snapshot refused tree=%s" % tree,early.is_empty())
		check("midreward disk save postponed tree=%s" % tree,not early_saved)
		var saved:Variant=JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
		check("requested save flushed at completed reward tree=%s" % tree,saved is Dictionary)
		if saved is Dictionary:
			# Disk JSON numbers are floats; compare both sides through the same
			# serialization boundary, keeping every key/value (diagnostic receipt).
			check("saved codex complete tree=%s" % tree,saved.get("codex")==JSON.parse_string(JSON.stringify(Codex.to_dict())))
			check("saved quests complete tree=%s" % tree,saved.get("quests")==JSON.parse_string(JSON.stringify(QuestManager.to_dict())))
			check("saved truth complete tree=%s" % tree,saved.get("truth_shards")==GameState.truth_shards)
			check("saved actual reward tree=%s" % tree,int(saved.get("inventory",{}).get(node.item_id,0))==Inventory.count(node.item_id))
		if is_instance_valid(node) and not node.is_queued_for_deletion():node.queue_free()
		await get_tree().process_frame
	print("HARVEST_SAVE_DONE failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
