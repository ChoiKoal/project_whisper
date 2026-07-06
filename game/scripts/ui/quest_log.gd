extends CanvasLayer
class_name QuestLog
## v0.4.0-C — 속삭임 일지 (quest log), toggled with J. A small centered window listing every
## quest in the line with its whisper text: completed ones checked (✓, dimmed), the active one
## highlighted with its (cur/need) progress, and not-yet-reached ones hidden as "…" so the log
## doesn't spoil the chain. ESC or J closes it. Pushes a modal lock while open so the world
## doesn't respond underneath (matches the other windows).

const CREAM := Color("#faf5e6")
const BG := Color("#22222b")
const PANEL_BG := Color("#2a2a33")
const VIOLET := Color("#c8b0ec")
const DIM := Color("#8a8678")
const DONE := Color("#8ce0a0")

const MODAL_KEY := "quest_log"

var _root: Control
var _list: VBoxContainer
var _open := false


func _ready() -> void:
	layer = 4   # above the command bar (3), below fade/pause
	_build()
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Dim scrim.
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.45)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(scrim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 420)
	panel.position = Vector2(-260, -210)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_content_margin_all(22)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = VIOLET
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title := Label.new()
	title.text = "속삭임"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", VIOLET)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var sep := HSeparator.new()
	col.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(476, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.custom_minimum_size = Vector2(460, 0)
	scroll.add_child(_list)

	var hint := Label.new()
	hint.text = "J · ESC 닫기"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)


func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	if QuestManager == null:
		return
	for id in QuestManager.all_ids():
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(450, 0)
		row.add_theme_font_size_override("font_size", 17)
		if QuestManager.is_done(id):
			row.text = "✓  「%s」" % QuestManager.whisper(id)
			row.add_theme_color_override("font_color", DONE)
			row.modulate = Color(1, 1, 1, 0.7)
		elif id == QuestManager.active_id or id == QuestManager.l2_active_id:
			# (L2-5) two coexisting lines — the active row of either line reads as ▸.
			var need := QuestManager.quest_count(id)
			var prog := QuestManager.l2_progress if id == QuestManager.l2_active_id else QuestManager.progress
			var suffix := "  (%d/%d)" % [min(prog, need), need] if need > 1 else ""
			row.text = "▸  「%s」%s" % [QuestManager.whisper(id), suffix]
			row.add_theme_color_override("font_color", CREAM)
		else:
			# Not yet reached — don't spoil.
			row.text = "…"
			row.add_theme_color_override("font_color", DIM)
		_list.add_child(row)


func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	var handled := false
	if event.is_action_pressed("quest_log"):
		toggle()
		handled = true
	elif _open and event.is_action_pressed("ui_cancel"):
		close()
		handled = true
	if handled:
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	if _open:
		return
	# Don't open over another modal (fusion/inventory/etc.) to avoid stacking.
	if GameState != null and GameState.ui_modal_open():
		return
	_open = true
	_rebuild_list()
	_root.visible = true
	if GameState != null:
		GameState.push_modal(MODAL_KEY)
	if AudioManager != null:
		AudioManager.play_sfx("ui_open")


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	if GameState != null:
		GameState.pop_modal(MODAL_KEY)
	if AudioManager != null:
		AudioManager.play_sfx("ui_close")


func is_open() -> bool:
	return _open
