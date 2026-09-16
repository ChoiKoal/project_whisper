extends CanvasLayer
class_name PortalCutscene
## CS-02/05, cancellable single-owner timelines. Skip commits, scene exit cancels.
const VIOLET := Color("#9e7ad9")
const VIOLET_DEEP := Color(0.35,0.22,0.55,1.0)
const CREAM := Color("#faf5e6")
const CS05_CARDS := ["하나의 세계가, 내 안에서 자리를 잡았다.","…그리고 다음 문이, 나를 알아봤다."]
signal finished
var _swell: ColorRect
var _center: VBoxContainer
var _line: Label
var _active:=false
var _mode:=""
var _callback:=Callable()
var _sequence: Tween
var _key:=""
var _ignited:=false
func _ready() -> void:
	layer=11
	_key="portal:%s" % get_instance_id()
	_build()
func _build() -> void:
	_swell=ColorRect.new()
	_swell.color=Color(VIOLET_DEEP.r,VIOLET_DEEP.g,VIOLET_DEEP.b,0)
	_swell.set_anchors_preset(Control.PRESET_FULL_RECT)
	_swell.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_swell)
	_center=VBoxContainer.new()
	_center.set_anchors_preset(Control.PRESET_CENTER)
	_center.alignment=BoxContainer.ALIGNMENT_CENTER
	_center.grow_horizontal=Control.GROW_DIRECTION_BOTH
	_center.grow_vertical=Control.GROW_DIRECTION_BOTH
	add_child(_center)
	_line=Label.new()
	_line.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_line.add_theme_color_override("font_color",CREAM)
	_line.add_theme_font_size_override("font_size",30)
	_line.add_theme_color_override("font_outline_color",Color(0.06,0.04,0.09,0.9))
	_line.add_theme_constant_override("outline_size",5)
	_line.modulate.a=0
	_center.add_child(_line)
func _begin(mode: String) -> void:
	_active=true
	_mode=mode
	GameState.begin_cinematic(_key)
	_sequence=create_tween()
func play_travel(then: Callable) -> void:
	if _active: return
	_callback=then
	_begin("travel")
	AudioManager.play_sfx("travel_whoosh")
	_sequence.tween_property(_swell,"color:a",1.0,1.1).set_trans(Tween.TRANS_SINE)
	_sequence.tween_interval(0.3)
	_sequence.tween_callback(_finish)
func play_return_ignition() -> void:
	if _active:
		# A second Home/caller observes the existing ignition, not an early completion.
		if _mode == "ignition":
			await finished
		return
	if _ignited: return
	_begin("ignition")
	Codex.mark_cutscene_seen("CS-05")
	_swell.color.a=1
	_sequence.tween_property(_swell,"color:a",0.0,1.0)
	_append_card(CS05_CARDS[0])
	_sequence.tween_callback(func():
		GameState.set_portal_state("nature",GameState.PORTAL_OPEN)
		AudioManager.play_sfx("portal_ignite"))
	_sequence.tween_interval(0.7)
	_sequence.tween_property(_line,"modulate:a",0.0,0.6)
	_append_card(CS05_CARDS[1])
	_sequence.tween_callback(func():
		if GameState.portal_state("science")==GameState.PORTAL_DORMANT:
			GameState.set_portal_state("science",GameState.PORTAL_FLICKERING)
		AudioManager.play_sfx("portal_hum"))
	_sequence.tween_interval(0.8)
	_sequence.tween_property(_line,"modulate:a",0.0,0.6)
	_sequence.tween_callback(_finish)
	await finished
func _append_card(text: String) -> void:
	_sequence.tween_callback(func(): _line.text=text)
	_sequence.tween_property(_line,"modulate:a",1.0,0.9)
func _finish() -> void:
	if not _active: return
	_active=false
	if _sequence!=null: _sequence.kill()
	if _mode=="ignition" and not _ignited:
		_ignited=true
		GameState.set_portal_state("nature",GameState.PORTAL_OPEN)
		if GameState.portal_state("science")==GameState.PORTAL_DORMANT:
			GameState.set_portal_state("science",GameState.PORTAL_FLICKERING)
		QuestManager.advance_to("P2")
	_line.modulate.a=0
	_swell.color.a=0
	GameState.end_cinematic(_key)
	var callback:=_callback
	_callback=Callable()
	finished.emit()
	if callback.is_valid(): callback.call()
func skip() -> void: _finish()
func is_active() -> bool: return _active
func _input(event: InputEvent) -> void:
	if _active and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact")):
		get_viewport().set_input_as_handled()
		skip()
func _exit_tree() -> void:
	if _sequence!=null: _sequence.kill()
	_callback=Callable()
	_active=false
	GameState.end_cinematic(_key)
