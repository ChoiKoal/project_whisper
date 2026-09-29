extends Node
## Synthetic map with real InteractionController/Player/Gatherable and inventory.
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
class Fixture extends MapLoader:
	func _ready() -> void: pass
class BlockedTouch extends TouchController:
	func _nearest_walkable_adjacent(_cell:Vector2i)->Vector2i:return Vector2i(-1,-1)
var failures := 0
var loader: MapLoader
var player: Player
var interaction: InteractionController
var next_target: Gatherable
var reentered := false
func reenter_added(id: String, _amount: int) -> void:
	reenter_gathered(id)
func reenter_gathered(id: String) -> void:
	if id=="I5" and not reentered:
		reentered=true
		interaction.interact_with_object(next_target)
func reentry_cases() -> void:
	for signal_name in ["item_added","item_gathered"]:
		var a:=resource("I5")
		next_target=resource("I4")
		var flowers:=Inventory.count("I5")
		var wood:=Inventory.count("I4")
		reentered=false
		if signal_name=="item_added": Inventory.item_added.connect(reenter_added)
		else: GameState.item_gathered.connect(reenter_gathered)
		interaction.interact_with_object(a)
		await frames(45)
		if signal_name=="item_added": Inventory.item_added.disconnect(reenter_added)
		else: GameState.item_gathered.disconnect(reenter_gathered)
		check("cross-target reentry armed %s" % signal_name,reentered)
		check("cross-target reentry both exactly once %s" % signal_name,Inventory.count("I5")==flowers+1 and Inventory.count("I4")==wood+1)
		check("cross-target no stranded reservation %s" % signal_name,not is_instance_valid(next_target))
		if is_instance_valid(next_target): next_target.queue_free()
		await frames(2)

func check(label: String, ok: bool) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
	if not ok: failures+=1
func frames(n: int) -> void:
	for i in range(n): await get_tree().physics_frame
func _ready() -> void:
	if not GUARD.require_isolated_user_data("harvest_integration"):
		get_tree().quit(86)
		return
	call_deferred("run")
func resource(id: String) -> Gatherable:
	var g := Gatherable.new()
	g.item_id=id
	g.position=loader.cell_center_world(Vector2i(5,5))
	g.texture=load("res://assets/objects/flower.png") if ResourceLoader.exists("res://assets/objects/flower.png") else load("res://assets/objects/rock.png")
	add_child(g)
	return g
func run() -> void:
	var template: Node=load("res://scenes/world/starting_grove.tscn").instantiate()
	loader=Fixture.new()
	loader.tile_set=template.get_node("Ground").tile_set
	template.free()
	loader.width=12; loader.height=12
	add_child(loader)
	for y in range(12):
		for x in range(12): loader.set_cell(Vector2i(x,y),2,Vector2i.ZERO)
	player=Player.new()
	add_child(player)
	player._tilemap=loader
	player.position=loader.cell_center_world(Vector2i(4,5))
	interaction=InteractionController.new()
	add_child(interaction)
	interaction._tilemap=loader; interaction._player=player
	GameState.time_running=true
	await frames(2)
	var g:=resource("I5")
	var before:=Inventory.count("I5")
	interaction.interact_with_object(g)
	check("flora action starts without immediate reward",Inventory.count("I5")==before and not g.is_queued_for_deletion())
	check("direct gather cannot bypass reserved action",g.gather()=="")
	interaction.interact_with_object(g)
	check("same target repeat still no early reward",Inventory.count("I5")==before)
	await frames(35)
	check("contact grants exactly once after anticipation",Inventory.count("I5")==before+1)
	await cancellation_cases()
	await reentry_cases()
	await target_cases()
	await feedback_cases()
	await held_ground_cancellation()
	print("HARVEST_INTEGRATION_DONE failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func target_cases() -> void:
	var touch:=TouchController.new()
	add_child(touch)
	touch._loader=loader;touch._player=player;touch._interaction=interaction
	var g:=resource("I4")
	var before:=Inventory.count("I4")
	interaction.interact_with_object(g)
	touch.handle_tap(Vector2(-9999,-9999))
	await frames(20)
	check("new rejected ground tap cancels prior action",Inventory.count("I4")==before)
	if is_instance_valid(g):g.queue_free()
	await frames(2)
	g=resource("I5")
	var flowers:=Inventory.count("I5")
	interaction.interact_with_object(g)
	var stale_token:int=interaction._harvest.token
	g.queue_free()
	await frames(2)
	var replacement:=resource("I5")
	await frames(15)
	check("respawn replacement cannot inherit old reward",Inventory.count("I5")==flowers and replacement._harvest_owner==0)
	check("stale generation token rejected",not interaction._harvest.state.take_commit(stale_token).get("granted",false))
	interaction.interact_with_object(replacement)
	await frames(20)
	check("fresh respawn input earns exactly one",Inventory.count("I5")==flowers+1)
	for item in ["I1","I7","I6","I4","J1"]:
		var n:=resource(item)
		var count_before:=Inventory.count(item)
		interaction.interact_with_object(n)
		await frames(20)
		check("material or gentle fallback remains usable %s" % item,Inventory.count(item)==count_before+1)
	touch.queue_free()
	await frames(2)

func held_ground_cancellation() -> void:
	var touch:=BlockedTouch.new()
	add_child(touch)
	touch._loader=loader;touch._player=player;touch._interaction=interaction
	var cell:=Vector2i(5,3)
	loader.set_cell(cell,8,Vector2i.ZERO)
	Inventory.add("D14",1)
	interaction.set_held_item("D14")
	var g:=resource("I4")
	var before:=Inventory.count("I4")
	interaction.interact_with_object(g)
	check("blocked ground swap harvest armed",g._harvest_owner!=0)
	var point:=loader.cell_center_world(cell)
	check("blocked ground tap overlaps current object pick",touch._object_near(point)==g)
	check("blocked ground tap resolves to held ground",interaction.prefers_held_ground(cell) and not touch._is_adjacent_to_cell(cell))
	touch.handle_tap(point)
	await frames(20)
	check("held ground route rejection still cancels harvest",Inventory.count("I4")==before and is_instance_valid(g) and g._harvest_owner==0)
	interaction.set_held_item("")
	if is_instance_valid(g):g.queue_free()
	touch.queue_free()
	loader.set_cell(cell,2,Vector2i.ZERO)
	await frames(2)

func feedback_cases() -> void:
	var g:=resource("I5")
	g.amount=3
	var original_offset:=g.offset
	var original_position:=g.position
	var feedback:=Node2D.new()
	add_child(feedback)
	interaction._feedback_layer=feedback
	interaction.interact_with_object(g)
	await frames(3)
	check("anticipation moves sprite ink before contact",is_instance_valid(g) and g.offset!=original_offset)
	check("anticipation never moves collision root",is_instance_valid(g) and g.position==original_position)
	await frames(9)
	var quantity_visible:=false
	for child in feedback.get_children():
		if child is Label and child.text.begins_with("+3 "):quantity_visible=true
	check("reward feedback reports actual amount",quantity_visible)
	check("contact leaves material response after removal",not get_tree().get_nodes_in_group("harvest_response").is_empty())
	for material in ["flora","rock","wood"]:
		check("dedicated material sound loaded %s" % material,AudioManager._streams.has("harvest_"+material))
	interaction._feedback_layer=interaction
	feedback.queue_free()
	await frames(2)

func cancellation_cases() -> void:
	for reason in ["movement","escape","modal","time","cinematic","focus","scene_exit"]:
		var g:=resource("I4")
		var before:=Inventory.count("I4")
		interaction.interact_with_object(g)
		check("cancellation armed %s" % reason,g.get("_harvest_owner")!=0)
		match reason:
			"movement": Input.action_press("move_right")
			"escape":
				var e:=InputEventAction.new(); e.action="ui_cancel"; e.pressed=true
				Input.parse_input_event(e)
			"modal": GameState.push_modal("harvest_test"); GameState.pop_modal("harvest_test")
			"time": GameState.time_running=false; GameState.time_running=true
			"cinematic": GameState.begin_cinematic("harvest_test"); GameState.end_cinematic("harvest_test")
			"focus": interaction._harvest.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			"scene_exit":
				remove_child(interaction)
		await frames(20)
		Input.action_release("move_right")
		check("precontact %s gives zero" % reason,Inventory.count("I4")==before)
		check("precontact %s releases only reservation" % reason,is_instance_valid(g) and not g._spent and g.get("_harvest_owner")==0)
		if is_instance_valid(g): g.queue_free()
		if reason=="scene_exit": add_child(interaction)
		player.position=loader.cell_center_world(Vector2i(4,5))
		await frames(2)
	# Admission gates are tested separately from cancellation after begin.
	for reason in ["far","locked"]:
		var g:=resource("I6")
		var before:=Inventory.count("I6")
		if reason=="far": g.position=loader.cell_center_world(Vector2i(10,10))
		else: GameState.push_modal("harvest_test")
		interaction.interact_with_object(g)
		await frames(20)
		check("admission refuses %s" % reason,Inventory.count("I6")==before and not g._spent)
		GameState.pop_modal("harvest_test")
		if is_instance_valid(g): g.queue_free()
		await frames(2)

