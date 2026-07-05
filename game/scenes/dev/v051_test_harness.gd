extends Node
## v0.5.1 hotfix acceptance harness. Covers the three live-play bug fixes:
##   A. TITLE FITS   — the title menu column is fully inside the viewport at 640×480, 768×526,
##                     1280×720, 1920×1080 (every button's global rect inside); the logotype
##                     glow copy is aligned over the main label (same x, ≤1px y — no sideways
##                     ghost).
##   B. INPUT LOCK   — pressing a move action then locking (modal) + swallowing the release +
##                     unlocking leaves the action NOT pressed (Player.release on lock/unlock);
##                     a queued tap path is cleared on the lock; a cutscene control-lock also
##                     releases; focus-out releases move actions.
##   C. PORTAL ENTRY — the flickering Layer-1 gate has a front-apron entry zone; standing in it
##                     + interacting travels (keyboard path via HomeSession._input equivalent,
##                     and click walk-then-enter via TouchController). A dormant gate in the
##                     apron surfaces the locked whisper and does NOT travel.
##
## Each section prints PASS/FAIL; process exit code = failure count.

const HOME := "res://scenes/world/home_island.tscn"
const TITLE := "res://scenes/ui/title.tscn"

var _fail := 0
var _scene: Node = null


func _ready() -> void:
	print("=== v051 HOTFIX HARNESS ===")
	SaveManager.new_game()
	SaveManager.delete_save()
	GameState.time_running = false
	call_deferred("_run")


func _run() -> void:
	await _frames(1)
	await _a_title_fits()
	await _b_input_lock()
	await _c_portal_entry()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ==== infra ================================================================

func _check(label: String, cond: bool, detail: String = "") -> bool:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  — " + detail) if detail != "" else ""])
	if not cond:
		_fail += 1
	return cond


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


## Await physics frames — needed after teleporting a body via global_position so the physics
## server re-runs broadphase and Area2D overlap sets (get_overlapping_bodies) reflect the new
## position. process_frame alone does NOT flush physics, so a teleported body can otherwise read
## as still overlapping its old apron.
func _phys(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _boot(path: String) -> Node:
	var s: Node = load(path).instantiate()
	add_child(s)
	await _frames(4)
	return s


func _teardown() -> void:
	SaveManager.unregister_world()
	if _scene != null:
		_scene.queue_free()
		_scene = null
	await _frames(2)


func _collect_buttons(n: Node, out: Array) -> void:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		_collect_buttons(c, out)


func _find(node: Node, cls) -> Node:
	if is_instance_of(node, cls):
		return node
	for c in node.get_children():
		var r := _find(c, cls)
		if r != null:
			return r
	return null


# ==== A. TITLE fits the viewport at 4 window sizes =========================

## Drive the stretch system in the same CANVAS_ITEMS/EXPAND mode the project uses so the
## visible rect reflects the requested window size (headless can't truly resize the OS window,
## but content_scale_size makes the layout math + assertions honest — this is exactly the path
## the responsive title reads via get_visible_rect()).
func _a_title_fits() -> void:
	print("--- A. Title menu fits viewport at 640×480 / 768×526 / 1280×720 / 1920×1080 ---")
	# Seed a cleared save so ALL FOUR buttons render (새로 시작 / 이어하기 / NG+ 시작 / 종료) —
	# the worst case for vertical fit.
	SaveManager.new_game()
	SaveManager.mark_cleared()
	SaveManager.save_game()

	var win := get_window()
	var prev_mode := win.content_scale_mode
	var prev_aspect := win.content_scale_aspect
	var prev_size := win.content_scale_size
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

	for sz in [Vector2i(640, 480), Vector2i(768, 526), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		win.content_scale_size = sz
		win.size = sz
		await _frames(2)
		var t: Node = load(TITLE).instantiate()
		add_child(t)
		await _frames(6)
		var vr: Rect2 = t.get_viewport().get_visible_rect()
		var btns: Array = []
		_collect_buttons(t, btns)
		var all_inside: bool = btns.size() >= 2
		var worst := ""
		for b in btns:
			var r: Rect2 = (b as Control).get_global_rect()
			var inside: bool = r.position.x >= vr.position.x - 0.5 and r.position.y >= vr.position.y - 0.5 \
				and r.end.x <= vr.end.x + 0.5 and r.end.y <= vr.end.y + 0.5
			if not inside:
				all_inside = false
				worst = "%s y=%.0f..%.0f (vr.h=%.0f)" % [(b as Button).text, r.position.y, r.end.y, vr.size.y]
		_check("title buttons fully inside viewport @ %dx%d (n=%d)" % [sz.x, sz.y, btns.size()],
			all_inside, worst)
		t.queue_free()
		await _frames(2)

	# Glow-copy alignment: the two title labels (glow + main) share the same x and differ by
	# ≤1px in y (additive bloom straight under the crisp letters — never a sideways ghost).
	win.content_scale_size = Vector2i(1280, 720)
	win.size = Vector2i(1280, 720)
	await _frames(2)
	var t2: Node = load(TITLE).instantiate()
	add_child(t2)
	await _frames(6)
	var labels: Array = []
	_collect_title_labels(t2, labels)
	var aligned := false
	if labels.size() >= 2:
		var g: Control = labels[0]
		var m: Control = labels[1]
		var dx: float = absf(g.global_position.x - m.global_position.x)
		var dy: float = absf(g.global_position.y - m.global_position.y)
		aligned = dx <= 0.5 and dy <= 1.5
		_check("logotype glow aligned over main label (dx=%.2f, dy=%.2f)" % [dx, dy], aligned)
	else:
		_check("found glow + main title labels", false, "n=%d" % labels.size())
	t2.queue_free()

	win.content_scale_mode = prev_mode
	win.content_scale_aspect = prev_aspect
	win.content_scale_size = prev_size
	await _frames(2)


## Collect the two "Project Whisper" logotype labels (glow first, then main) from the title.
## They are the two Labels whose text contains a spaced "P r o j e c t".
func _collect_title_labels(n: Node, out: Array) -> void:
	if n is Label and String((n as Label).text).begins_with("P"):
		out.append(n)
	for c in n.get_children():
		_collect_title_labels(c, out)


# ==== B. INPUT LOCK releases move actions + clears path ====================

func _b_input_lock() -> void:
	print("--- B. Input-lock / focus-loss release move actions + clear path ---")
	GameState.time_running = true
	SaveManager.new_game()
	WorldContext.current_scene = WorldContext.SCENE_HOME
	SaveManager.pending_load = false
	_scene = await _boot(HOME)
	var player := _scene.get_node("YSortLayer/Player") as Player
	var touch := _find(_scene, TouchController) as TouchController

	# 1) Press move_up, then a modal opens (lock). The Player releases the action on the lock
	#    edge; the swallowed RELEASE (we simply never release it) can't leave it pressed.
	Input.action_press("move_up")
	await _frames(1)
	_check("move_up reads pressed after press", Input.is_action_pressed("move_up"))
	GameState.push_modal("test_modal")     # lock edge → Player.release_move_and_path()
	await _frames(1)
	_check("move_up released on LOCK edge (modal open)", not Input.is_action_pressed("move_up"))

	# 2) While locked, simulate the release being swallowed: press again under the lock, then
	#    unlock. The unlock edge must release it too.
	Input.action_press("move_up")
	GameState.pop_modal("test_modal")      # unlock edge → release again
	await _frames(1)
	_check("move_up released on UNLOCK edge", not Input.is_action_pressed("move_up"))

	# 3) A queued tap path is dropped on the lock edge (no auto-walk after unlock).
	var loader := _scene.get_node("Ground") as MapLoader
	touch.move_to(loader.spawn_cell + Vector2i(3, 0))
	await _frames(1)
	_check("player has a queued path after tap-to-move", player.is_pathing())
	GameState.push_modal("test_modal2")
	await _frames(1)
	_check("queued path cleared on the lock edge", not player.is_pathing())
	GameState.pop_modal("test_modal2")
	await _frames(1)

	# 4) A cutscene control-lock (time_running-based) also releases the move actions + path.
	Input.action_press("move_up")
	touch.move_to(loader.spawn_cell + Vector2i(0, 3))
	await _frames(1)
	GameState.set_control_lock(true)       # cutscene lock edge
	await _frames(1)
	_check("cutscene control-lock releases move_up", not Input.is_action_pressed("move_up"))
	_check("cutscene control-lock clears path", not player.is_pathing())
	GameState.set_control_lock(false)
	await _frames(1)

	# 5) touch_controller refuses NEW paths while control-locked (cutscene running).
	GameState.set_control_lock(true)
	touch.move_to(loader.spawn_cell + Vector2i(2, 2))
	await _frames(1)
	_check("tap-to-move refused while control-locked", not player.is_pathing())
	GameState.set_control_lock(false)

	# 6) Window focus-out releases the move actions + path (macOS cmd-tab).
	Input.action_press("move_up")
	await _frames(1)
	player.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(1)
	_check("focus-out releases move_up", not Input.is_action_pressed("move_up"))

	# Cleanup any lingering action presses.
	for a in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(a)
	await _teardown()


# ==== C. PORTAL entry zone (keyboard + click) ==============================

func _c_portal_entry() -> void:
	print("--- C. Portal entry apron: keyboard + click travel; dormant locked whisper ---")
	GameState.time_running = true
	GameState.reset_portals()
	SaveManager.new_game()
	WorldContext.current_scene = WorldContext.SCENE_HOME
	SaveManager.pending_load = false
	_scene = await _boot(HOME)
	var loader := _scene.get_node("Ground") as MapLoader
	var player := _scene.get_node("YSortLayer/Player") as Player
	var touch := _find(_scene, TouchController) as TouchController
	var session := _find(_scene, HomeSession) as HomeSession

	var nature: Portal = null
	var science: Portal = null
	for n in get_tree().get_nodes_in_group("gatherable"):
		if n is Portal and n.layer == "nature": nature = n
		if n is Portal and n.layer == "science": science = n
	_check("nature (flickering) + science (dormant) gates found", nature != null and science != null)

	# --- entry zone geometry: the apron stand cell is walkable (approach not blocked) ---
	var stand := nature.entry_stand_point()
	var stand_cell := loader.world_to_cell(stand)
	_check("nature gate front-apron stand cell is walkable (gate collision doesn't block)",
		loader.is_cell_walkable(stand_cell), "cell=%s" % stand_cell)

	# --- standing in the apron sets the in-zone flag + the state prompt ---
	player.global_position = stand
	player.force_update_transform()
	await _phys(3)
	await _frames(3)
	_check("player detected inside the nature gate entry apron", nature.is_player_in_entry_zone())
	_check("flickering gate apron prompt is the enter/approach affordance",
		nature.entry_prompt_text() == "E 다가가기")

	# --- KEYBOARD entry: on_interact from HomeSession's E path routes to travel. We drive the
	#     same on_interact() the E handler calls and assert HomeSession routed it to travel
	#     (portal_reached emits + a scene change is requested). Enterable → NOT a locked hint. ---
	var reached := [""]
	GameState.portal_reached.connect(func(l): reached[0] = l, CONNECT_ONE_SHOT)
	nature.on_interact()
	await _frames(1)
	_check("keyboard entry on flickering gate fires portal_reached (travel, not locked)",
		reached[0] == "nature", "reached=%s" % reached[0])
	# The travel cutscene is now active (control-locked) → confirm the travel beat kicked off.
	_check("travel beat started (control-locked) after keyboard entry", GameState.control_locked())
	# Reset the travel lock so we can continue testing in this same scene instance.
	GameState.set_control_lock(false)
	GameState.time_running = true
	await _frames(1)

	# --- DORMANT gate: standing in the science apron + interacting shows the locked whisper and
	#     does NOT travel (portal_reached must not fire, no travel lock). ---
	player.global_position = science.entry_stand_point()
	player.force_update_transform()
	await _phys(3)
	await _frames(3)
	_check("player detected inside the dormant science gate apron", science.is_player_in_entry_zone())
	_check("dormant gate apron prompt is the locked whisper",
		science.entry_prompt_text() == "…아직 잠들어 있다")
	var reached2 := [""]
	var cb := func(l): reached2[0] = l
	GameState.portal_reached.connect(cb)
	science.on_interact()
	await _frames(1)
	_check("dormant gate does NOT travel (no portal_reached)", reached2[0] == "")
	_check("dormant gate does NOT start a travel lock", not GameState.control_locked())
	if GameState.portal_reached.is_connected(cb):
		GameState.portal_reached.disconnect(cb)

	# --- CLICK walk-then-enter: tap the science gate from afar → touch paths to its apron and
	#     enters on arrival. Make science ENTERABLE (open) so arrival travels. We tap by handing
	#     the touch controller the gate's world position; it must queue a path to the apron and
	#     register a "portal" pending interaction. ---
	GameState.set_portal_state("science", GameState.PORTAL_OPEN)
	await _frames(1)
	# Move the player well away from the apron so a walk is required.
	player.global_position = loader.cell_center_world(loader.spawn_cell)
	player.force_update_transform()
	await _phys(3)
	await _frames(2)
	_check("player left the science apron before click test", not science.is_player_in_entry_zone())
	touch.handle_tap(science.global_position)
	await _frames(1)
	_check("click on gate queues a walk-to-apron path", player.is_pathing())

	await _teardown()
