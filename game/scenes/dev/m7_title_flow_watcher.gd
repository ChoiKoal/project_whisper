extends Node
## Drives the M7 title-flow state machine across scene changes. Lives on the tree
## root (PROCESS_MODE_ALWAYS) so it survives change_scene_to_file swaps.
##
## States:
##   BOOT      → switch to title.tscn
##   AT_TITLE1 → find title menu, press 새로 시작
##   IN_GROVE1 → survive GROVE1_FRAMES, then open pause + 저장, then 타이틀로
##   AT_TITLE2 → find title menu, press 이어하기
##   IN_GROVE2 → survive GROVE2_FRAMES, then report + quit
##
## Assertions are collected and printed PASS/FAIL; exit code = failure count.

const TITLE_SCENE := "res://scenes/ui/title.tscn"
const GROVE1_FRAMES := 90
const GROVE2_FRAMES := 60

enum State { BOOT, AT_TITLE1, IN_GROVE1, AT_TITLE2, IN_GROVE2, DONE }

var _state: int = State.BOOT
var _frames: int = 0
var _fail: int = 0
var _saved := false
var _pressed_title := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("=== M7 TITLE FLOW HARNESS ===")
	# Start from a clean slate: no stale save from a previous run.
	SaveManager.delete_save()
	await get_tree().process_frame
	get_tree().change_scene_to_file(TITLE_SCENE)
	_state = State.AT_TITLE1


func _check(label: String, cond: bool) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_fail += 1


func _process(_delta: float) -> void:
	match _state:
		State.AT_TITLE1:
			_tick_title1()
		State.IN_GROVE1:
			_tick_grove1()
		State.AT_TITLE2:
			_tick_title2()
		State.IN_GROVE2:
			_tick_grove2()
		_:
			pass


# ---- state handlers ------------------------------------------------------

func _tick_title1() -> void:
	var menu := _find_method(_current(), "_on_new_game")
	if menu == null:
		return
	_check("title screen built (새로 시작 present)", true)
	menu.call("_on_new_game")
	_frames = 0
	_state = State.IN_GROVE1


func _tick_grove1() -> void:
	_frames += 1
	if _frames == 1:
		_check("grove reached after 새로 시작", _grove_ok())
		_check("map tiles present (export data intact)", _tiles_ok())
		_check("ItemDB/RecipeDB loaded (export data intact)",
			ItemDB.all_ids().size() >= 30 and RecipeDB.all_recipes().size() >= 50)
	if _frames < GROVE1_FRAMES:
		return
	# Survived the crash window. Now open pause + save, then go to title.
	_check("survived %d frames in grove (new game)" % GROVE1_FRAMES, _grove_ok())
	var pause := _find_class_node(_current(), "PauseMenu")
	if pause != null and pause.has_method("toggle"):
		pause.call("toggle")   # open
		var ok: bool = bool(SaveManager.save_game())
		_check("save_game() succeeded from pause menu", ok)
		_saved = SaveManager.has_save()
		_check("save file exists on disk", _saved)
		pause.call("toggle")   # close
	else:
		_check("pause menu present", false)
	# Leave to title via the pause menu's real handler (autosave + unregister).
	var pause2 := _find_method(_current(), "_on_title")
	if pause2 != null:
		pause2.call("_on_title")
		_pressed_title = true
	_frames = 0
	_state = State.AT_TITLE2


func _tick_title2() -> void:
	var menu := _find_method(_current(), "_on_continue")
	if menu == null:
		# Title present but no save → 이어하기 button absent = failure.
		var at_title := _find_method(_current(), "_on_new_game") != null
		if at_title:
			_check("이어하기 present at title (save exists)", false)
			_state = State.DONE
			_finish()
		return
	_check("returned to title; 이어하기 present", true)
	menu.call("_on_continue")
	_frames = 0
	_state = State.IN_GROVE2


func _tick_grove2() -> void:
	_frames += 1
	if _frames == 1:
		_check("grove reached after 이어하기", _grove_ok())
	if _frames < GROVE2_FRAMES:
		return
	_check("survived %d frames in grove (continue)" % GROVE2_FRAMES, _grove_ok())
	_state = State.DONE
	_finish()


func _finish() -> void:
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- helpers -------------------------------------------------------------

func _current() -> Node:
	return get_tree().current_scene


## The grove is healthy if the current scene is StartingGrove and its MapLoader
## built the 40×40 map.
func _grove_ok() -> bool:
	var cs := _current()
	if cs == null or cs.name != "StartingGrove":
		return false
	var ground := cs.get_node_or_null("Ground")
	if ground == null:
		return false
	return int(ground.get("height")) == 40 and int(ground.get("width")) == 40


func _tiles_ok() -> bool:
	var cs := _current()
	if cs == null:
		return false
	var tm := _find_tilemap(cs)
	return tm != null and tm.get_used_cells().size() >= 1600


func _find_tilemap(n: Node) -> TileMapLayer:
	if n is TileMapLayer:
		return n
	for c in n.get_children():
		var r := _find_tilemap(c)
		if r != null:
			return r
	return null


func _find_method(n: Node, m: String) -> Node:
	if n == null:
		return null
	if n.has_method(m):
		return n
	for c in n.get_children():
		var r := _find_method(c, m)
		if r != null:
			return r
	return null


func _find_class_node(n: Node, cls_name: String) -> Node:
	if n == null:
		return null
	if n.get_class() == cls_name or (n.get_script() != null and _script_class(n) == cls_name):
		return n
	for c in n.get_children():
		var r := _find_class_node(c, cls_name)
		if r != null:
			return r
	return null


func _script_class(n: Node) -> String:
	var s: Script = n.get_script()
	if s is GDScript:
		return (s as GDScript).get_global_name()
	return ""
