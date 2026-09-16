extends Node
## Synthetic isolated day/night/collision fixtures; normal progression captured separately.
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var failures:=0
func check(label:String,ok:bool)->void:
	print(("[PASS] " if ok else "[FAIL] ")+label)
	if not ok:failures+=1
func frames(n:int)->void:
	for i in range(n):await get_tree().physics_frame
func _ready()->void:call_deferred("run")
func run()->void:
	if not GUARD.require_isolated_user_data("night_flower_art"):
		get_tree().quit(86);return
	for revision in ["l1-v1","l1-v2"]:
		SaveManager.new_game_for_layout(revision)
		var scene:Node=load("res://scenes/world/starting_grove.tscn").instantiate();add_child(scene)
		await frames(12)
		var ground:MapLoader=scene.get_node("Ground")
		var player:Player=scene.get_node("YSortLayer/Player")
		var gates:Array=[]
		for node in get_tree().get_nodes_in_group("night_gate"):
			if scene.is_ancestor_of(node):gates.append(node)
		check(revision+" exact two N consumers",gates.size()==2 and ground.night_gate_cells.size()==2)
		var roots:Array=[]
		for gate:NightGate in gates:
			roots.append(gate.global_position)
			check(revision+" emission is separately authored, not whole plant",gate._glow.texture.resource_path=="res://assets/objects/night_bud_emission.png")
			check(revision+" original native canvas/contact offset retained",gate._sprite.texture.get_size()==Vector2(128,128) and gate._sprite.offset==Vector2(0,-60) and gate._sprite.scale==Vector2.ONE)
		for phase in [[0.3,false],[0.65,true],[0.8,true],[0.97,true],[0.3,false]]:
			GameState.set_game_time(GameState.DAY_LENGTH*phase[0]);await frames(3)
			for i in range(gates.size()):
				var gate:NightGate=gates[i]
				check(revision+" phase "+str(phase[0])+" state/body/glow",gate.is_open()==phase[1] and gate._body.get_child(0).disabled==phase[1] and gate._glow.visible==phase[1])
				check(revision+" phase root/contact unchanged",gate.global_position==roots[i] and gate._sprite.offset==gate._glow.offset)
				check(revision+" exact open/closed binding",gate._sprite.texture.resource_path==(NightGate.OPEN_TEX if phase[1] else NightGate.CLOSED_TEX))
		# Actual CharacterBody + keyboard trajectory, not just collider existence.
		var gate:NightGate=gates[0]
		for open in [false,true]:
			GameState.set_game_time(GameState.DAY_LENGTH*(0.8 if open else 0.3))
			player.global_position=gate.global_position+Vector2(0,100)
			await frames(4)
			Input.action_press("move_up")
			await get_tree().create_timer(0.7).timeout
			Input.action_release("move_up");await frames(3)
			if open and GameState.control_locked():
				var encounter_deadline:=Time.get_ticks_msec()+15000
				while GameState.control_locked() and Time.get_ticks_msec()<encounter_deadline:await frames(1)
				check(revision+" first encounter releases its own lock",not GameState.control_locked())
				# A fresh physical key press, never revival of the canceled path.
				Input.action_press("move_up");await get_tree().create_timer(0.25).timeout
				Input.action_release("move_up");await frames(3)
			print("NIGHT_WALK ",JSON.stringify({"revision":revision,"open":open,"start":str(gate.global_position+Vector2(0,100)),"end":str(player.global_position),"gate":str(gate.global_position),"locked":GameState.control_locked()}))
			check(revision+" real keyboard "+("passes open gate" if open else "stops at closed gate"),player.global_position.y<gate.global_position.y-12 if open else player.global_position.y>gate.global_position.y+20)
		# First tree approach legitimately owns CS-03; let it finish before freeing
		# the fixture. Never carry a deliberately interrupted legacy lock to v2.
		var deadline:=Time.get_ticks_msec()+15000
		while GameState.control_locked() and Time.get_ticks_msec()<deadline:await frames(1)
		check(revision+" legitimate encounter finishes before teardown",not GameState.control_locked())
		SaveManager.unregister_world();scene.queue_free();await frames(4)
	print("NIGHT_FLOWER_ART_DONE failures=",failures)
	get_tree().quit(1 if failures else 0)
