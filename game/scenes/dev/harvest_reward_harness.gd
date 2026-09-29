extends Node
## Synthetic real-node reward tests. Never touches real saves.
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
var failures := 0
var calls := 0
var nested := "not-called"
var subject: Gatherable
var snapshot: Array = []
func check(label: String, ok: bool) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
	if not ok: failures += 1
func _ready() -> void:
	if not GUARD.require_isolated_user_data("harvest_reward"):
		get_tree().quit(86)
		return
	call_deferred("run")
func make_object(is_unique: bool) -> Gatherable:
	var node := Gatherable.new()
	node.item_id = "I5"
	node.unique = is_unique
	node.amount = 3
	add_child(node)
	return node
func on_added(id: String, _amount: int) -> void:
	if id != "I5": return
	calls += 1
	if calls == 1:
		nested = subject.gather()
		snapshot = SaveManager._object_states()
func run() -> void:
	var node := make_object(false)
	var before := Inventory.count("I5")
	check("A1 first nonunique gather grants",node.gather()=="I5")
	check("A1 same-frame second direct call rejected",node.gather()=="")
	check("A1 exactly configured quantity",Inventory.count("I5")==before+3)
	check("A1 consumed nonunique cannot gather",not node.can_gather())
	await get_tree().process_frame
	for is_unique in [false,true]:
		subject=make_object(is_unique)
		var respawn := ObjectRespawn.new()
		respawn._tracked = [{"cell":Vector2i(2,3),"symbol":"F","node":subject,"respawn_at":-1.0}]
		SaveManager._respawn=respawn
		before=Inventory.count("I5")
		calls=0
		nested="not-called"
		Inventory.item_added.connect(on_added)
		subject.gather()
		Inventory.item_added.disconnect(on_added)
		check("A5 item_added reentry armed unique=%s" % is_unique,calls>=1 and nested!="not-called")
		check("A5 finalized BEFORE item_added unique=%s" % is_unique,nested=="" and calls==1)
		check("A5 one reward unique=%s" % is_unique,Inventory.count("I5")==before+3)
		if not is_unique:
			check("snapshot during item_added records removed object",snapshot.size()==1 and not snapshot[0].present)
			check("snapshot during item_added records respawn deadline",snapshot.size()==1 and is_equal_approx(snapshot[0].respawn_at,GameState.game_time+GameState.DAY_LENGTH))
		SaveManager._respawn=null
		respawn.free()
		if is_unique:
			check("A3 unique sequential repeat guarded",subject.gather()=="" and not subject.is_queued_for_deletion())
			subject.queue_free()
		await get_tree().process_frame
	print("HARVEST_REWARD_DONE failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
