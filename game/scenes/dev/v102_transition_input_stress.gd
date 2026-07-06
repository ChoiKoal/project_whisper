extends Node
## v1.0.2 TRANSITION-INPUT STRESS harness — the null-viewport crash fix.
##
## Reproduces the release-only SIGSEGV KOAL hit in v1.0.1: crash in
## Viewport::set_input_as_handled() (+44, KERN_INVALID_ADDRESS) with call stack
## GDScriptFunction::call ← Node::_call_unhandled_input ← Viewport::push_input. Root cause: a
## GDScript input handler (`_unhandled_input`/`_input`) calls `get_viewport().set_input_as_handled()`
## while the node is mid-departure from the tree (scene transition in flight). Buffered input
## events dispatched by Input.flush_buffered_events reach the leaving node whose get_viewport()
## now returns null → null deref inside set_input_as_handled.
##
## This harness DRIVES REAL in-game scene transitions (get_tree().change_scene_to_file via the
## sessions' travel + portal-return hooks, and the ending prompt open/cancel) and — in the SAME
## FRAME as each transition trigger — INJECTS buffered InputEventKey/InputEventMouseButton via
## Input.parse_input_event, then forces Input.flush_buffered_events() across the teardown frames so
## the buffered events are delivered right as the old scene's input-handler nodes leave the tree.
## Before the fix this crashes the process (exit != 0, no RESULT line). After the fix (every handler
## guards is_inside_tree() + null viewport) it completes with zero crashes.
##
## Paths covered (each hammered with same-frame buffered input):
##   home → L1 (grove) → return home
##   home → L2 (terminal_station) → return home
##   home → L3 (clockwork_city) → return home
##   home → L4 (mage_tower) → return home
##   home → L5 (cathedral) → return home
##   ending prompt: open (E on 빛의 문 apron) then cancel (ESC) — repeated
## It reparents itself under the tree ROOT so change_scene_to_file (which frees the current scene)
## does not free the harness.
##
## Assertion: every transition lands in the expected scene with NO crash. Any crash aborts the
## process before the final RESULT line (the runner greps for it). Exit code = failure count.

const REPS := 3   ## repeat each path this many times so buffered input lands on varied frames

# Each layer id → destination scene name after change_scene_to_file(layer_scene).
const LAYERS := [
	["nature", "StartingGrove"],
	["science", "TerminalStation"],
	["machine", "ClockworkCity"],
	["magic", "MageTower"],
	["divinity", "Cathedral"],
]

var _tree: SceneTree
var _fail := 0

func _ready() -> void:
	_tree = get_tree()
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	# Move under the persistent Window root so change_scene_to_file won't free us.
	get_parent().remove_child(self)
	_tree.root.add_child(self)
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in range(n):
		await _tree.process_frame

func _wait(s: float) -> void:
	await _tree.create_timer(s).timeout

func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  — " + detail) if detail != "" else ""])
	if not cond:
		_fail += 1

# ---- buffered-input injection (the crash trigger) -------------------------

## Queue a spread of key + mouse events into the INPUT BUFFER (not directly dispatched), then flush
## them repeatedly over the given number of idle frames. Because change_scene_to_file frees the old
## scene deferred (end of frame), flushing the buffer across the teardown boundary delivers these
## events to input-handler nodes that are leaving the tree — the exact null-viewport crash window.
func _inject_buffered_input_across(frames: int) -> void:
	for i in range(frames):
		_queue_burst()
		Input.flush_buffered_events()
		await _tree.process_frame
	# One more flush after the last frame for good measure.
	_queue_burst()
	Input.flush_buffered_events()

func _queue_burst() -> void:
	# The actions the guarded handlers key off: interact (E), ui_cancel (ESC), plus a raw left-click.
	_key(KEY_E, true); _key(KEY_E, false)
	_key(KEY_ESCAPE, true); _key(KEY_ESCAPE, false)
	_key(KEY_I, true); _key(KEY_I, false)
	_click(true); _click(false)

func _key(keycode: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _click(pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = Vector2(320, 240)
	Input.parse_input_event(ev)

# ---- run ------------------------------------------------------------------

func _run() -> void:
	print("=== v102 TRANSITION-INPUT STRESS HARNESS ===")
	SaveManager.new_game()
	SaveManager.delete_save()
	SaveManager.new_game()

	# Boot the home island as the live scene.
	WorldContext.current_scene = WorldContext.SCENE_HOME
	_tree.change_scene_to_file(WorldContext.HOME_SCENE_PATH)
	await _frames(12)
	_check("boot home", _scene_name() == "HomeIsland", _scene_name())

	# --- home → each layer → return home, hammered with buffered input ---
	for entry in LAYERS:
		var layer: String = entry[0]
		var expect: String = entry[1]
		for rep in range(REPS):
			await _hop_to_layer_and_back(layer, expect, rep)

	# --- ending prompt open + cancel, hammered with buffered input ---
	for rep in range(REPS):
		await _ending_prompt_open_cancel(rep)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	_tree.quit(_fail)

## Direct-drive the layer transition (change_scene_to_file, like the real travel target) and inject
## buffered input across the teardown frames on BOTH legs (out and back).
func _hop_to_layer_and_back(layer: String, expect: String, rep: int) -> void:
	# OUT: trigger the scene change, then flush buffered input across the teardown boundary.
	WorldContext.travel_layer = layer
	WorldContext.arrival_mode = "portal_arrival"
	WorldContext.current_scene = WorldContext.layer_scene(layer)
	_tree.change_scene_to_file(WorldContext.scene_path(WorldContext.layer_scene(layer)))
	await _inject_buffered_input_across(6)
	await _frames(10)
	_check("[%s r%d] arrived (no crash)" % [layer, rep], _scene_name() == expect, _scene_name())

	# BACK: return home, again flushing buffered input across the teardown.
	WorldContext.travel_layer = ""
	WorldContext.arrival_mode = "portal_arrival"
	WorldContext.current_scene = WorldContext.SCENE_HOME
	_tree.change_scene_to_file(WorldContext.HOME_SCENE_PATH)
	await _inject_buffered_input_across(6)
	await _frames(10)
	_check("[%s r%d] returned home (no crash)" % [layer, rep], _scene_name() == "HomeIsland", _scene_name())

## Open the ending confirm prompt (spawn the light gate + fire HomeSession._open_ending_prompt),
## then cancel it (ESC) — all while buffered key events are flushed. Exercises the ending_sequence /
## home_session ending-modal input handlers across their modal open/teardown.
func _ending_prompt_open_cancel(rep: int) -> void:
	# Make sure we are home.
	if _scene_name() != "HomeIsland":
		WorldContext.current_scene = WorldContext.SCENE_HOME
		_tree.change_scene_to_file(WorldContext.HOME_SCENE_PATH)
		await _frames(12)
	var session := _find_by_class("HomeSession")
	if session == null:
		_check("[ending r%d] home session present" % rep, false)
		return
	# Force the ending prompt open (the E-on-빛의-문-apron path). Then hammer buffered ESC/E while the
	# modal + its input handlers are live, and finally cancel — closing the modal under input load.
	if session.has_method("_open_ending_prompt"):
		session._open_ending_prompt()
	await _frames(2)
	await _inject_buffered_input_across(4)
	if session.has_method("_cancel_ending_prompt"):
		session._cancel_ending_prompt()
	await _inject_buffered_input_across(4)
	await _frames(4)
	_check("[ending r%d] prompt open+cancel under input (no crash)" % rep,
		_scene_name() == "HomeIsland", _scene_name())

# ---- lookups --------------------------------------------------------------

func _scene_name() -> String:
	return _tree.current_scene.name if _tree.current_scene != null else "<null>"

func _find_by_class(cls: String) -> Node:
	return _search(_tree.current_scene, cls)

func _search(node: Node, cls: String) -> Node:
	if node == null:
		return null
	if node.get_script() != null and str(node.get_script().get_global_name()) == cls:
		return node
	for c in node.get_children():
		var r := _search(c, cls)
		if r != null:
			return r
	return null
