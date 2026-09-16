extends Node
## Synthetic future-version disk fixture. Never touches an unguarded user directory.
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var failures:=0
func check(label:String,ok:bool)->void:
	print(("[PASS] " if ok else "[FAIL] ")+label)
	if not ok:failures+=1
func _ready()->void:call_deferred("run")
func run()->void:
	if not GUARD.require_isolated_user_data("future_save_safety"):
		get_tree().quit(86);return
	SaveManager.new_game()
	var scene:Node=load("res://scenes/world/home_island.tscn").instantiate()
	add_child(scene)
	for i in range(6):await get_tree().process_frame
	Inventory.add("I2",7)
	SaveManager._worlds={"home":{"fixture":"current-cache"}}
	var baseline:=SaveManager.build_save_dict()
	var future:=baseline.duplicate(true)
	future.version=SaveManager.SAVE_VERSION+1
	future.inventory={"I2":999}
	future.worlds={"home":{"fixture":"future-cache"}}
	future["unknown_future_payload"]={"preserve":"exact whitespace and bytes"}
	var original:="  "+JSON.stringify(future,"\t")+"\n\n"
	var file:=FileAccess.open(SaveManager.SAVE_PATH,FileAccess.WRITE)
	file.store_string(original);file.close()
	check("future load is rejected",SaveManager.load_game().is_empty())
	check("rejected load preserves inventory",Inventory.count("I2")==7)
	check("rejected load preserves world cache",SaveManager._worlds==baseline.worlds)
	check("rejected load preserves original disk bytes",FileAccess.get_file_as_string(SaveManager.SAVE_PATH)==original)
	check("rejected future blocks explicit save",not SaveManager.save_game())
	check("blocked save preserves original disk bytes",FileAccess.get_file_as_string(SaveManager.SAVE_PATH)==original)
	# Exercise WM-close with the registered real Home world.
	SaveManager._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	check("WM close preserves future bytes",FileAccess.get_file_as_string(SaveManager.SAVE_PATH)==original)
	check("WM close preserves current world cache",SaveManager._worlds==baseline.worlds)
	SaveManager.unregister_world();scene.queue_free()
	# Explicit new-game is the existing deliberate reset boundary, not an implicit migration.
	SaveManager.new_game()
	check("explicit new game releases write guard",SaveManager.save_game())
	check("current version still round trips",not SaveManager.load_game().is_empty())
	print("FUTURE_SAVE_SAFETY_DONE failures=",failures)
	get_tree().quit(1 if failures else 0)
