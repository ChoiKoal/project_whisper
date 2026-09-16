extends CanvasLayer
class_name DialoguePanel
## Persistent, screen-space dialogue for important inspect/story beats.
##
## Callers enqueue authored beats. Each beat is a Dictionary:
##   {"source": "관찰", "place": "듣는 횃대", "body": "..."}
## `source` is a real speaker when one exists; otherwise use a presentation label such
## as 관찰/장소/기록. Portraits and choices are deliberately outside this component.
##
## Await contract:
##   var completed := await dialogue.present(beats, "stable:event:key")
## Concurrent calls with the same non-empty key join one DialogueTicket and therefore
## resume only when that actual request ends. "Already active" is never reported as done.

signal opened(request_key: String)
signal beat_changed(index: int, count: int)
signal closed(request_key: String, completed: bool)

const MAX_PENDING_REQUESTS := 8
const MAX_BEATS_PER_REQUEST := 6
const MAX_BODY_CHARACTERS := 360
const MIN_BOTTOM_CLEARANCE := 112.0 # command bar + held-item HUD remain unobscured
const MAX_PANEL_WIDTH := 1040.0

class DialogueTicket extends RefCounted:
	signal completed(was_completed: bool)
	var done := false
	var result := false
	var key := ""

	func resolve(value: bool) -> void:
		if done:
			return
		done = true
		result = value
		completed.emit(value)


@export_range(0.0, 120.0, 1.0) var characters_per_second := 34.0

@onready var _root: Control = $Root
@onready var _bottom_band: CenterContainer = $Root/BottomBand
@onready var _frame: PanelContainer = $Root/BottomBand/DialogFrame
@onready var _source: Label = $Root/BottomBand/DialogFrame/FrameInset/InnerPanel/ContentMargin/Content/Header/SourceLabel
@onready var _place: Label = $Root/BottomBand/DialogFrame/FrameInset/InnerPanel/ContentMargin/Content/Header/PlaceLabel
@onready var _body: Label = $Root/BottomBand/DialogFrame/FrameInset/InnerPanel/ContentMargin/Content/BodyLabel
@onready var _progress: Label = $Root/BottomBand/DialogFrame/FrameInset/InnerPanel/ContentMargin/Content/Footer/ProgressLabel
@onready var _continue: Button = $Root/BottomBand/DialogFrame/FrameInset/InnerPanel/ContentMargin/Content/Footer/ContinueButton

var _active_request: Dictionary = {}
var _pending: Array[Dictionary] = []
var _tickets_by_key: Dictionary = {}
var _entry_index := 0
var _request_serial := 0
var _reveal_progress := 0.0
var _leases_held := false
var _last_advance_frame := -1
var _shutting_down := false
var _finishing := false
var _between_requests := false
var _modal_key := ""
var _cinematic_key := ""
var _pointer_guard_until := 0
var _cancelling := false


func _ready() -> void:
	layer = 7 # above HUD/log (3/4), below fade/pause (8/9) and cutscenes (10+)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_modal_key = "dialogue:%s" % get_instance_id()
	_cinematic_key = "dialogue_time:%s" % get_instance_id()
	_root.visible = false
	_continue.pressed.connect(advance)
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	_pump()


func _process(delta: float) -> void:
	if not is_open() or characters_per_second <= 0.0 or not _is_revealing():
		return
	_reveal_progress += delta * characters_per_second
	_body.visible_characters = mini(_body.text.length(), int(floor(_reveal_progress)))


## Queue a request without awaiting it. Duplicate non-empty keys return the same ticket.
## Invalid/overflow requests return an already-resolved false ticket (safe to inspect).
func enqueue(entries: Array, request_key: String = "") -> DialogueTicket:
	if _shutting_down or _cancelling:
		var rejected:=DialogueTicket.new()
		rejected.key=request_key
		rejected.resolve(false)
		return rejected
	if request_key != "" and _tickets_by_key.has(request_key):
		return _tickets_by_key[request_key] as DialogueTicket

	var ticket := DialogueTicket.new()
	ticket.key = request_key
	var normalized := _normalize_entries(entries)
	if normalized.is_empty():
		ticket.resolve(false)
		return ticket
	if _shutting_down or _pending.size() >= MAX_PENDING_REQUESTS:
		push_warning("DialoguePanel: pending queue full; dropped '%s'" % request_key)
		ticket.resolve(false)
		return ticket

	_request_serial += 1
	var request := {
		"key": request_key,
		"serial": _request_serial,
		"entries": normalized,
		"ticket": ticket,
	}
	if request_key != "":
		_tickets_by_key[request_key] = ticket
	_pending.append(request)
	_pump()
	return ticket


## Reentrant await API. A duplicate key waits on the original request's ticket.
func present(entries: Array, request_key: String = "") -> bool:
	var ticket := enqueue(entries, request_key)
	if ticket.done:
		return ticket.result
	return await ticket.completed


## Convenience for one beat without inventing a speaker.
func present_line(body: String, source: String = "관찰", place: String = "", request_key: String = "") -> bool:
	return await present([{"source": source, "place": place, "body": body}], request_key)


func _normalize_entries(entries: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if entries.is_empty() or entries.size()>MAX_BEATS_PER_REQUEST: return out
	for raw in entries:
		var beat: Dictionary
		if raw is String:
			beat = {"source": "관찰", "place": "", "body": String(raw).strip_edges()}
		elif raw is Dictionary:
			beat = {
				"source": String(raw.get("source", "관찰")).strip_edges(),
				"place": String(raw.get("place", "")).strip_edges(),
				"body": String(raw.get("body", "")).strip_edges(),
			}
		else:
			return []
		if beat.body.is_empty():
			return []
		if beat.body.length() > MAX_BODY_CHARACTERS:
			push_warning("DialoguePanel: rejected wall-of-text beat (%d > %d characters)" % [beat.body.length(), MAX_BODY_CHARACTERS])
			return []
		if beat.source.is_empty():
			beat.source = "관찰"
		# Preserve every authored character while fitting narrow screens. The six
		# input-beat limit is validation, not a truncation limit on generated pages.
		var body: String=beat.body
		var start := 0
		while start<body.length():
			var finish:=mini(start+48,body.length())
			var newlines:=0
			for i in range(start,finish):
				if body[i]=="\n":
					newlines+=1
					if newlines==3:
						finish=i+1
						break
			var page:=beat.duplicate()
			page.body=body.substr(start,finish-start)
			out.append(page)
			start=finish
	return out


func _pump() -> void:
	if _shutting_down or _finishing or not is_node_ready() or not _active_request.is_empty() or _pending.is_empty():
		return
	_between_requests = false
	_active_request = _pending.pop_front()
	_entry_index = 0
	_acquire_own_leases()
	_root.visible = true
	_show_entry()
	_continue.grab_focus()
	opened.emit(String(_active_request.key))


func _show_entry() -> void:
	if _active_request.is_empty():
		return
	var entries: Array = _active_request.entries
	var beat: Dictionary = entries[_entry_index]
	_source.text = String(beat.source)
	_place.text = String(beat.place)
	_place.visible = not _place.text.is_empty()
	_body.text = String(beat.body)
	_progress.text = "%d / %d" % [_entry_index + 1, entries.size()]
	_continue.text = "계속  ▶" if _entry_index + 1 < entries.size() else "닫기  ■"
	_reveal_progress = 0.0
	_body.visible_characters = 0 if characters_per_second > 0.0 else -1
	beat_changed.emit(_entry_index, entries.size())


## One physical press performs exactly one transition. During typewriter reveal the first
## press only reveals the current beat; a later press advances/closes it.
func advance() -> bool:
	if not is_open() or _between_requests or _active_request.is_empty():
		return false
	var frame := Engine.get_process_frames()
	if _last_advance_frame == frame:
		return false
	_last_advance_frame = frame
	if _is_revealing():
		_body.visible_characters = -1
		_reveal_progress = float(_body.text.length())
		return true
	var entries: Array = _active_request.entries
	if _entry_index + 1 < entries.size():
		_entry_index += 1
		_show_entry()
		_continue.grab_focus()
		return true
	_finish_active(true, true)
	return true


## Cancel the active request. By default queued requests remain and open on the next frame.
func cancel_current(continue_queue: bool = true) -> void:
	if not continue_queue:
		cancel_all()
		return
	if _active_request.is_empty():
		if continue_queue and (_between_requests or not _pending.is_empty()):
			return
		_between_requests = false
		if not continue_queue:
			_cancel_pending()
		_release_own_leases()
		if is_instance_valid(_root):
			_root.visible = false
		return
	_finish_active(false, continue_queue)


## Escape/scene interruption closes the panel and resolves every waiter false.
func cancel_all() -> void:
	if _cancelling: return
	_cancelling=true
	if not _active_request.is_empty():
		_finish_active(false, false)
	else:
		_between_requests = false
		_cancel_pending()
		if is_instance_valid(_root):
			_root.visible = false
		_release_own_leases()
	_cancelling=false


func _finish_active(was_completed: bool, continue_queue: bool) -> void:
	if _active_request.is_empty():
		return
	_finishing = true
	var finished: Dictionary = _active_request
	_active_request = {}
	var key := String(finished.key)
	if key != "":
		_tickets_by_key.erase(key)
	(finished.ticket as DialogueTicket).resolve(was_completed)
	closed.emit(key, was_completed)
	if not continue_queue:
		_cancel_pending()
	if continue_queue and not _pending.is_empty() and not _shutting_down:
		# Defer so the key/click that closed this request cannot also skip the next one.
		_between_requests = true
		_finishing = false
		call_deferred("_pump")
		return
	_between_requests = false
	if is_instance_valid(_root):
		_root.visible = false
	_release_own_leases()
	_finishing = false


func _cancel_pending() -> void:
	# Pop before resolving: completion callbacks may enqueue reentrantly, and a cancel-all
	# must also reject those newly appended requests rather than leave a hidden orphan.
	while not _pending.is_empty():
		var request: Dictionary = _pending.pop_front()
		var key := String(request.key)
		if key != "":
			_tickets_by_key.erase(key)
		(request.ticket as DialogueTicket).resolve(false)


func _acquire_own_leases() -> void:
	if _leases_held:
		return
	_leases_held = true
	if GameState != null:
		GameState.push_modal(_modal_key)
		GameState.begin_cinematic(_cinematic_key)


func _release_own_leases() -> void:
	if not _leases_held:
		return
	_leases_held = false
	if GameState != null:
		GameState.pop_modal(_modal_key)
		GameState.end_cinematic(_cinematic_key)


func _input(event: InputEvent) -> void:
	# Godot can dispatch a companion mouse event AFTER a closing touch. Consume
	# only emulated companions; a fresh native click/tap remains responsive.
	var pointer := event is InputEventMouseButton or event is InputEventScreenTouch
	if pointer and event.device == -1 and (is_open() or Time.get_ticks_msec()<_pointer_guard_until):
		get_viewport().set_input_as_handled()
		return
	if not is_open():
		return
	# Consume every event while modal so unrelated UI/world handlers cannot act behind it.
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("ui_cancel"):
		cancel_all()
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		advance()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pointer_guard_until=Time.get_ticks_msec()+120
		advance()
		return
	if event is InputEventScreenTouch and event.pressed:
		_pointer_guard_until=Time.get_ticks_msec()+120
		advance()


func _is_revealing() -> bool:
	return _body.visible_characters >= 0 and _body.visible_characters < _body.text.length()


func _update_layout() -> void:
	if not is_instance_valid(_frame): return
	var viewport_size:=get_viewport().get_visible_rect().size
	var safe:=Rect2(Vector2.ZERO,viewport_size)
	if OS.has_feature("mobile"):
		var window:=get_window()
		var physical:=Rect2(DisplayServer.get_display_safe_area())
		physical.position-=Vector2(window.position)
		physical=physical.intersection(Rect2(Vector2.ZERO,Vector2(window.size)))
		if physical.has_area():
			var ratio:=viewport_size/Vector2(window.size)
			safe=Rect2(physical.position*ratio,physical.size*ratio)
	_layout_in_safe_rect(safe)

func _layout_in_safe_rect(safe: Rect2) -> void:
	var viewport_size:=get_viewport().get_visible_rect().size
	var width:=minf(MAX_PANEL_WIDTH,maxf(0.0,safe.size.x-32.0))
	var clearance:=64.0 if viewport_size.y<450.0 else MIN_BOTTOM_CLEARANCE
	var height:=minf(288.0 if safe.size.x<500.0 else 244.0,safe.size.y-clearance-16.0)
	_frame.custom_minimum_size=Vector2(width,height)
	_bottom_band.offset_left=safe.position.x
	_bottom_band.offset_right=safe.end.x-viewport_size.x
	_bottom_band.offset_top=safe.end.y-viewport_size.y-clearance-height
	_bottom_band.offset_bottom=safe.end.y-viewport_size.y-clearance
	var compact:=safe.size.x<900.0 or safe.size.y<600.0
	_body.add_theme_font_size_override("font_size",18 if compact else 20)
	_source.add_theme_font_size_override("font_size",16 if compact else 18)
	_place.add_theme_font_size_override("font_size",14 if compact else 16)
	get_node("Root/BottomBand/DialogFrame/FrameInset/InnerPanel/ContentMargin/Content/Footer/InputHint").visible=safe.size.x>=700.0


func _exit_tree() -> void:
	_shutting_down = true
	_between_requests = false
	if not _active_request.is_empty():
		var request: Dictionary = _active_request
		_active_request = {}
		var key := String(request.key)
		if key != "":
			_tickets_by_key.erase(key)
		(request.ticket as DialogueTicket).resolve(false)
	_cancel_pending()
	_release_own_leases()


# ---- Read-only harness/debug surface --------------------------------------
func is_open() -> bool:
	return not _active_request.is_empty() or _between_requests

func active_index() -> int:
	return _entry_index

func pending_count() -> int:
	return _pending.size()

func has_own_leases() -> bool:
	return _leases_held

func dialogue_rect() -> Rect2:
	return _frame.get_global_rect() if is_instance_valid(_frame) else Rect2()

func body_label() -> Label:
	return _body

func continue_button() -> Button:
	return _continue
