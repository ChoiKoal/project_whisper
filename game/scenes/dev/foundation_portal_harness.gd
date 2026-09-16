extends Node
## Home actual root fixture. State injections disclosed; not normal progression.
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var failures := 0
func check(label: String, ok: bool) -> void:
	print("[%s] %s"%["PASS" if ok else "FAIL",label])
	if not ok: failures+=1
func _ready() -> void:
	if not GUARD.require_isolated_user_data("foundation_portal"):
		get_tree().quit(86)
		return
	call_deferred("run")
func frames(n:=3) -> void:
	for i in range(n): await get_tree().physics_frame
func run() -> void:
	SaveManager.new_game()
	var home: Node=load("res://scenes/world/home_island.tscn").instantiate()
	add_child(home)
	await frames(15)
	var gate: Portal
	var others := 0
	for obj in home.get_node("YSortLayer").get_children():
		if obj is Portal:
			if obj.object_id=="portal_nature": gate=obj
			else:
				others+=1
				check("other layer art unchanged "+obj.object_id,not obj.has_node("FoundationPortalPresence"))
	check("five saved layer portals retained",gate!=null and others==4)
	if gate==null:
		get_tree().quit(1)
		return
	check("authored representative art installed on nature gate",gate.has_node("FoundationPortalPresence"))
	var origin:=gate.global_position
	var stand:=gate.entry_stand_point()
	var target:=gate.target_point()
	var ids:=[]
	for state in [GameState.PORTAL_DORMANT,GameState.PORTAL_FLICKERING,GameState.PORTAL_OPEN]:
		GameState.set_portal_state("nature",state)
		await frames(6)
		check("state policy preserved "+state,gate.state()==state and gate.is_enterable()==(state!=GameState.PORTAL_DORMANT))
		check("state glyph signaling preserved "+state,gate.is_sigil_lit()==(state!=GameState.PORTAL_DORMANT))
		check("logical anchor and entry apron unchanged "+state,gate.global_position==origin and gate.entry_stand_point()==stand and gate.target_point()==target)
		check("authored frame loaded "+state,gate._gate.texture.resource_path.ends_with("nature_gate.png"))
		check("native integer art, no rotated/rescaled veil "+state,gate._veil.rotation==0.0 and gate._veil.scale==Vector2.ONE)
		ids.append(gate._veil.texture.resource_path)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var image:=get_viewport().get_texture().get_image()
			check("state root capture saved "+state,image.save_png(OS.get_environment("FDN_EVIDENCE").path_join(state+".png"))==OK)
	check("shape frames distinguish flicker/open",ids[1]!=ids[2] and not ids[1].is_empty() and not ids[2].is_empty())
	var player:Player=home.get_node("YSortLayer/Player")
	player.global_position=stand
	await frames(6)
	check("real Player recognized in original entry apron",gate.is_player_in_entry_zone())
	check("gate remains an interactable, never gathered",not gate.can_gather() and gate.gather()=="")
	check("isolated Home save succeeds",SaveManager.save_game())
	SaveManager.unregister_world()
	home.queue_free()
	await frames()
	print("FOUNDATION_PORTAL_DONE failures=%d"%failures)
	get_tree().quit(1 if failures else 0)
