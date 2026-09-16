extends Node
## DialoguePanel runtime regression harness.
## Run only after candidate files are copied under res:// at the parent ownership checkpoint:
##   godot --headless --path game scenes/dev/dialogue_panel_harness.tscn
## Prints PASS/FAIL and exits with the failure count.

const DialogueScene := preload("res://scenes/ui/dialogue_panel.tscn")
const DialoguePanelScript := preload("res://scripts/ui/dialogue_panel.gd")

class RetryOnCancel extends RefCounted:
	var panel: DialoguePanel
	var calls:=0
	var rejected_synchronously:=false
	func retry(_completed: bool) -> void:
		calls+=1
		if calls>=20:return # bounded RED, never hang the engine
		var ticket:=panel.enqueue(["다시"],"cancel-retry:%d"%calls)
		rejected_synchronously=ticket.done and not ticket.result
		if not ticket.done:ticket.completed.connect(retry)

class DropthroughProbe extends Node:
	var unhandled_count := 0

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("interact"):
			unhandled_count += 1
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			unhandled_count += 1
		elif event is InputEventScreenTouch and event.pressed:
			unhandled_count += 1


var _fail := 0
var _dialogue: DialoguePanel
var _probe: DropthroughProbe


func _ready() -> void:
	print("=== DIALOGUE PANEL HARNESS ===")
	GameState.time_running = true
	GameState.set_control_lock(false)
	_probe = DropthroughProbe.new()
	add_child(_probe)
	call_deferred("_run")


func _run() -> void:
	await _frames(2)
	await _test_layout_and_hierarchy()
	await _test_pre_ready_queue()
	await _test_request_validation()
	await _test_typewriter_and_progression()
	await _test_repeat_key()
	await _test_queue_and_deduplication()
	await _test_input_dropthrough()
	await _test_owned_lease_cleanup()
	await _test_reentrant_cancel()
	await _test_scene_exit_cleanup()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


func _check(label: String, condition: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if condition else "FAIL", label, (" — " + detail) if detail != "" else ""])
	if not condition:
		_fail += 1


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _spawn_dialogue() -> DialoguePanel:
	var panel := DialogueScene.instantiate() as DialoguePanel
	add_child(panel)
	await _frames(2)
	return panel


func _free_dialogue() -> void:
	if is_instance_valid(_dialogue):
		_dialogue.queue_free()
	await _frames(2)
	_dialogue = null


func _test_layout_and_hierarchy() -> void:
	_dialogue = await _spawn_dialogue()
	_dialogue.characters_per_second = 0.0
	_dialogue.enqueue([{
		"source": "관찰",
		"place": "듣는 횃대",
		"body": "가지는 바람이 없는 쪽으로만 닳아 있다. 새는 없는데, 둥지 자국만 매일 새것 같다.",
	}], "harness:layout")
	await _frames(2)

	var window := get_window()
	var old_mode := window.content_scale_mode
	var old_aspect := window.content_scale_aspect
	var old_scale_size := window.content_scale_size
	var old_size := window.size
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

	for size in [Vector2i(640,480),Vector2i(1600,900),Vector2i(390,844),Vector2i(844,390)]:
		window.content_scale_size = size
		window.size = size
		await _frames(3)
		var viewport_rect := _dialogue.get_viewport().get_visible_rect()
		_check("requested logical viewport is actual %s"%size,Vector2i(viewport_rect.size)==size,str(viewport_rect.size))
		var rect := _dialogue.dialogue_rect()
		var inside := rect.position.x >= viewport_rect.position.x - 0.5 \
			and rect.end.x <= viewport_rect.end.x + 0.5 \
			and rect.position.y >= 16.0 \
			and rect.end.y <= viewport_rect.end.y - (64.0 if size.y<450 else DialoguePanelScript.MIN_BOTTOM_CLEARANCE) + 0.5
		var layout_label := "%dx%d layout"%[size.x,size.y]
		_check(layout_label, inside, "panel=%s viewport=%s" % [rect, viewport_rect])
		_check("%dx%d body wraps with Korean-readable metrics" % [size.x, size.y],
			_dialogue.body_label().autowrap_mode == TextServer.AUTOWRAP_WORD_SMART \
			and _dialogue.body_label().get_theme_font_size("font_size") >= 18 \
			and _dialogue.body_label().get_theme_constant("line_spacing") >= 6)
		_check("continue touch target >=48px %s"%size,_dialogue.continue_button().size.y>=48)
		var body:=_dialogue.body_label()
		_check("all visible Korean lines fit body %s"%size,body.get_line_count()*body.get_line_height()+maxi(0,body.get_line_count()-1)*body.get_theme_constant("line_spacing")<=body.size.y+1)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var out:=OS.get_environment("FDN_EVIDENCE").path_join("dialogue-%dx%d.png"%[size.x,size.y])
			_check("layout capture saved %s"%size,window.get_texture().get_image().save_png(out)==OK)
		if size==Vector2i(844,390):
			_check("safe-area layout function present",_dialogue.has_method("_layout_in_safe_rect"))
			if _dialogue.has_method("_layout_in_safe_rect"):
				var safe:=Rect2(48,12,740,356)
				_dialogue._layout_in_safe_rect(safe)
				await _frames(3)
				_check("synthetic left right top bottom insets respected",safe.encloses(_dialogue.dialogue_rect()),str(_dialogue.dialogue_rect()))

	_check("continue control receives keyboard focus",
		_dialogue.get_viewport().gui_get_focus_owner() == _dialogue.continue_button())
	_check("hierarchy exposes source/place/body/progress/continue",
		_dialogue.get_node_or_null("Root/BottomBand/DialogFrame/FrameInset/InnerPanel/ContentMargin/Content/Header/SourceLabel") != null \
		and _dialogue.get_node_or_null("Root/BottomBand/DialogFrame/FrameInset/InnerPanel/ContentMargin/Content/Header/PlaceLabel") != null \
		and _dialogue.body_label() != null and _dialogue.continue_button() != null)

	window.content_scale_mode = old_mode
	window.content_scale_aspect = old_aspect
	window.content_scale_size = old_scale_size
	window.size = old_size
	_dialogue.cancel_all()
	await _free_dialogue()


func _test_pre_ready_queue() -> void:
	# A story signal may enqueue immediately after instantiate but before add_child/_ready.
	# The request must wait for readiness rather than touching null @onready controls.
	_dialogue = DialogueScene.instantiate() as DialoguePanel
	var ticket = _dialogue.enqueue([{"source": "관찰", "body": "준비 전 요청"}], "harness:pre-ready")
	add_child(_dialogue)
	await _frames(2)
	_check("pre-ready enqueue survives interrupted opening", _dialogue.is_open() \
		and _dialogue.has_own_leases() and not ticket.done)
	_dialogue.queue_free()
	await _frames(2)
	_dialogue = null
	_check("pre-ready request cleans up on scene exit", ticket.done and not ticket.result \
		and not GameState.ui_modal_open() and not GameState.control_locked())


func _test_request_validation() -> void:
	_dialogue=DialogueScene.instantiate() as DialoguePanel
	var tickets: Array=[]
	for i in range(DialoguePanelScript.MAX_PENDING_REQUESTS+3):
		tickets.append(_dialogue.enqueue(["준비 전 %d"%i],"preburst:%d"%i))
	_check("pre-ready burst bounded even without active request",_dialogue.pending_count()<=DialoguePanelScript.MAX_PENDING_REQUESTS and tickets[-1].done and not tickets[-1].result)
	add_child(_dialogue)
	await _frames(2)
	_dialogue.cancel_all()
	var mixed=_dialogue.enqueue(["유효한 줄","가".repeat(DialoguePanelScript.MAX_BODY_CHARACTERS+1)],"mixed")
	_check("invalid mixed request rejected atomically, no silent lost line",mixed.done and not mixed.result and not _dialogue.is_open())
	_dialogue.cancel_all()
	var beats: Array=[]
	for i in range(DialoguePanelScript.MAX_BEATS_PER_REQUEST+1): beats.append("줄%d"%i)
	var too_many=_dialogue.enqueue(beats,"too-many")
	_check("too many beats rejected atomically, never truncated",too_many.done and not too_many.result and not _dialogue.is_open())
	_dialogue.cancel_all()
	var maximum := "가나다라마바사 ".repeat(45)
	var full=_dialogue.enqueue([maximum],"maximum")
	var normalized: Array=_dialogue._active_request.get("entries",[])
	var joined := ""
	var bounded := true
	for beat in normalized:
		joined+=str(beat.body)
		bounded=bounded and str(beat.body).length()<=48
	_check("maximum text paginated without dropping characters",not full.done and joined==maximum.strip_edges() and bounded and normalized.size()>1)
	_dialogue.cancel_all()
	await _free_dialogue()

func _test_typewriter_and_progression() -> void:
	_dialogue = await _spawn_dialogue()
	_dialogue.characters_per_second = 1.0
	var ticket = _dialogue.enqueue([
		{"source": "관찰", "place": "듣는 횃대", "body": "첫 문장은 천천히 나타난다."},
		{"source": "관찰", "place": "돌무더기", "body": "둘째 문장은 별도의 입력으로 넘어간다."},
	], "harness:typewriter")
	await _frames(1)
	_dialogue.advance()
	_check("first advance reveals", _dialogue.active_index() == 0 \
		and _dialogue.body_label().visible_characters == -1)
	await _frames(1)
	_dialogue.advance()
	_check("second advance changes beat", _dialogue.active_index() == 1 and not ticket.done)
	await _frames(1)
	_dialogue.advance() # reveal beat 2
	await _frames(1)
	_dialogue.advance() # close beat 2
	_check("final advance resolves completed ticket", ticket.done and ticket.result and not _dialogue.is_open())
	await _free_dialogue()


func _test_repeat_key() -> void:
	_dialogue = await _spawn_dialogue()
	_dialogue.characters_per_second = 0.0
	_dialogue.enqueue([
		{"source": "관찰", "body": "첫 줄"},
		{"source": "관찰", "body": "둘째 줄"},
	], "harness:repeat")
	await _frames(1)
	var repeat := InputEventKey.new()
	repeat.physical_keycode = KEY_E
	repeat.pressed = true
	repeat.echo = true
	_dialogue._input(repeat)
	_check("repeat key does not advance", _dialogue.active_index() == 0 and _dialogue.is_open())
	_dialogue.cancel_all()
	await _free_dialogue()


func _test_queue_and_deduplication() -> void:
	_dialogue = await _spawn_dialogue()
	_dialogue.characters_per_second = 0.0
	var original = _dialogue.enqueue([{"source": "관찰", "body": "활성"}], "harness:same")
	var duplicate = _dialogue.enqueue([{"source": "관찰", "body": "중복이면 보이면 안 됨"}], "harness:same")
	_check("duplicate key joins in-flight ticket", original == duplicate)
	var queued: Array = []
	for i in range(DialoguePanelScript.MAX_PENDING_REQUESTS):
		queued.append(_dialogue.enqueue([{"source": "기록", "body": "대기 %d" % i}], "harness:q:%d" % i))
	var overflow = _dialogue.enqueue([{"source": "기록", "body": "넘침"}], "harness:overflow")
	_check("bounded queue rejects overflow", overflow.done and not overflow.result \
		and _dialogue.pending_count() == DialoguePanelScript.MAX_PENDING_REQUESTS)
	_dialogue.cancel_all()
	var all_cancelled: bool = original.done and not original.result
	for ticket in queued:
		all_cancelled = all_cancelled and ticket.done and not ticket.result
	_check("cancel-all resolves active and queued waiters", all_cancelled)
	await _free_dialogue()


func _test_input_dropthrough() -> void:
	_dialogue = await _spawn_dialogue()
	_dialogue.characters_per_second = 0.0
	_probe.unhandled_count = 0
	var ticket = _dialogue.enqueue([{"source": "장소", "place": "제0세계", "body": "한 줄"}], "harness:drop")
	await _frames(1)
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	_check("input does not drop through", ticket.done and ticket.result and _probe.unhandled_count == 0,
		"probe=%d" % _probe.unhandled_count)
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(1)

	# Touch press uses the same consumed path and must not reach the world probe either.
	_probe.unhandled_count = 0
	var touch_ticket = _dialogue.enqueue([{"source": "관찰", "body": "터치"}], "harness:touch")
	await _frames(1)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(320, 300)
	touch.pressed = true
	Input.parse_input_event(touch)
	await _frames(2)
	_check("touch input does not drop through", touch_ticket.done and touch_ticket.result \
		and _probe.unhandled_count == 0,"done=%s result=%s probe=%d"%[touch_ticket.done,touch_ticket.result,_probe.unhandled_count])
	var companion:=InputEventMouseButton.new()
	companion.device=-1;companion.button_index=MOUSE_BUTTON_LEFT;companion.pressed=true;companion.position=touch.position
	get_viewport().push_input(companion,true)
	await _frames(1)
	_check("explicit emulated close companion does not drop through",_probe.unhandled_count==0)
	touch.pressed = false
	Input.parse_input_event(touch)
	await _frames(1)
	await _free_dialogue()


func _test_owned_lease_cleanup() -> void:
	GameState.push_modal("harness:external_modal")
	GameState.begin_cinematic("harness:external_cinematic")
	_dialogue = await _spawn_dialogue()
	_dialogue.characters_per_second = 0.0
	_dialogue.enqueue([{"source": "관찰", "body": "외부 잠금 보존"}], "harness:leases")
	await _frames(1)
	_check("dialogue owns leases while open", _dialogue.has_own_leases())
	_dialogue.cancel_all()
	_dialogue.cancel_all()
	_check("double close is idempotent", not _dialogue.has_own_leases() and not _dialogue.is_open())
	_check("external modal survives", GameState.ui_modal_open())
	_check("external cinematic survives", GameState.control_locked() and not GameState.time_running)
	GameState.pop_modal("harness:external_modal")
	GameState.end_cinematic("harness:external_cinematic")
	_check("world restores after final external leases end", not GameState.ui_modal_open() \
		and not GameState.control_locked() and GameState.time_running)
	await _free_dialogue()


func _test_reentrant_cancel() -> void:
	_dialogue=await _spawn_dialogue()
	var callback:=RetryOnCancel.new()
	callback.panel=_dialogue
	var ticket:=_dialogue.enqueue(["취소"],"cancel-initial")
	ticket.completed.connect(callback.retry)
	_dialogue.cancel_all()
	_check("cancel barrier rejects callback re-enqueue synchronously",callback.calls==1 and callback.rejected_synchronously,"callbacks=%d"%callback.calls)
	_check("reentrant cancel releases owned locks",not _dialogue.has_own_leases() and not GameState.ui_modal_open())
	await _free_dialogue()

func _test_scene_exit_cleanup() -> void:
	GameState.push_modal("harness:exit_external_modal")
	GameState.begin_cinematic("harness:exit_external_cinematic")
	_dialogue = await _spawn_dialogue()
	var active = _dialogue.enqueue([{"source": "관찰", "body": "중단"}], "harness:exit:active")
	var queued = _dialogue.enqueue([{"source": "관찰", "body": "대기"}], "harness:exit:queued")
	await _frames(1)
	_dialogue.queue_free()
	await _frames(2)
	_dialogue = null
	_check("scene exit releases own leases", active.done and not active.result \
		and queued.done and not queued.result)
	_check("scene exit preserves external owners", GameState.ui_modal_open() \
		and GameState.control_locked() and not GameState.time_running)
	GameState.pop_modal("harness:exit_external_modal")
	GameState.end_cinematic("harness:exit_external_cinematic")
	_check("scene-exit fixture restores after external cleanup", not GameState.ui_modal_open() \
		and not GameState.control_locked() and GameState.time_running)
