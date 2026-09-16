extends "res://scenes/dev/l1_progression_capture.gd"
## Same normal quest loop as stable10. Only harness change: explicit bounded NEW
## movement request after observed OS focus loss. Player's cancellation stays intact.
var _focus_losses := 0
func _ready() -> void:
	get_tree().root.focus_exited.connect(func(): _focus_losses+=1)
	if OS.get_environment("FDN_LOCK_TRACE")=="1":
		GameState.control_lock_changed.connect(_trace_lock)
		GameState.ui_modal_changed.connect(func(value): print("FDN13_MODAL ",value," keys=",GameState._modal_keys," at=",Time.get_ticks_msec()))
	super._ready()
	get_tree().create_timer(480,true,false,true).timeout.connect(func():
		push_error("FDN13_HARNESS_WALLCLOCK_EXHAUSTED")
		get_tree().quit(89))
func _trace_lock(value: bool) -> void:
	print("FDN13_LOCK ",JSON.stringify({"locked":value,"legacy":GameState._control_locked,"cinematic":GameState._cinematic_keys,"modal":GameState._modal_keys,"at":Time.get_ticks_msec(),"stack":get_stack()}))
func _input(event: InputEvent) -> void:
	if OS.get_environment("FDN_LOCK_TRACE")!="1": return
	for action in ["interact","ui_accept","ui_cancel","move_up","move_down","move_left","move_right"]:
		if event.is_action(action): print("FDN13_INPUT at=",Time.get_ticks_msec()," action=",action," pressed=",event.is_pressed())
func walk(cell: Vector2i) -> bool:
	if not require(touch.move_to(cell),"path accepted "+str(cell)): return false
	var target:=touch._waypoint_world(cell)
	var deadline:=Time.get_ticks_msec()+24000
	var observed_focus:=_focus_losses
	var focus_retries:=0
	while player.global_position.distance_to(target)>8 and Time.get_ticks_msec()<deadline:
		await _physics_frames(1)
		if GameState.control_locked():
			while GameState.control_locked() and Time.get_ticks_msec()<deadline: await _physics_frames(1)
			if not GameState.control_locked():
				print("NORMAL_INPUT_REISSUE_AFTER_CUTSCENE ",cell)
				if not touch.move_to(cell): break
		elif not player.is_pathing() and _focus_losses>observed_focus and focus_retries<3:
			observed_focus=_focus_losses
			focus_retries+=1
			print("FDN_NEW_TAP_AFTER_OBSERVED_FOCUS_LOSS cell=",cell," count=",focus_retries," pos=",player.global_position)
			if not touch.move_to(cell): break
	player.release_move_and_path()
	return require(player.global_position.distance_to(target)<9,"actual walk arrives "+str(cell)+" actual="+str(player.global_position))
func _runtime_record(phase: String) -> Dictionary:
	var record:=super._runtime_record(phase)
	record["foundation_entry"]="production starting_grove -> representative_grove -> preserved legacy_grove"
	record["focus_automation"]="Observed OS focus losses only permit at most 3 explicit new public movement requests per walk; no private path restoration or disabled cancellation. Logged separately."
	return record
