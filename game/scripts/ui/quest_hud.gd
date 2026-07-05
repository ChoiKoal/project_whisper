extends CanvasLayer
class_name QuestHUD
## v0.4.0-C — minimal top-left "속삭임" quest line. Shows the active quest's whisper in
## italic-feel styling (「…뭐든, 주워봐.」) plus a (cur/need) progress counter when the quest
## is countable (count > 1). On quest advance it fades the old line out, swaps text, fades the
## new line in, and plays a soft chime through AudioManager. A completed check (✓) flashes
## briefly. When the whole line finishes, the panel fades away.
##
## Reads QuestManager (autoload) and reacts to its signals; owns no quest logic.

const CREAM := Color("#faf5e6")
const BG := Color("#22222b")
const VIOLET := Color("#c8b0ec")
const DIM := Color("#b8b4a8")

var _panel: PanelContainer
var _whisper: Label
var _progress: Label
var _check: Label


func _ready() -> void:
	layer = 3
	_build()
	if QuestManager == null:
		push_warning("QuestHUD: QuestManager missing; HUD static")
		return
	QuestManager.quest_started.connect(_on_started)
	QuestManager.quest_progress.connect(_on_progress)
	QuestManager.quest_completed.connect(_on_completed)
	QuestManager.quest_advanced.connect(_on_advanced)
	QuestManager.all_quests_completed.connect(_on_all_done)
	# Reflect whatever quest is already active (autoloads run before this HUD).
	if QuestManager.active_id != "":
		_show_quest(QuestManager.active_id)
	elif QuestManager.all_completed():
		_panel.visible = false


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(16, 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BG.r, BG.g, BG.b, 0.9)
	sb.set_content_margin_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = VIOLET
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 2)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_panel.add_child(row)

	# Small quill/whisper glyph.
	var glyph := Label.new()
	glyph.text = "❝"
	glyph.add_theme_font_size_override("font_size", 20)
	glyph.add_theme_color_override("font_color", VIOLET)
	row.add_child(glyph)

	_whisper = Label.new()
	_whisper.add_theme_color_override("font_color", CREAM)
	_whisper.add_theme_font_size_override("font_size", 18)
	# Italic-feel: soft violet, slightly letter-spaced via a leading space in text.
	row.add_child(_whisper)

	_progress = Label.new()
	_progress.add_theme_color_override("font_color", DIM)
	_progress.add_theme_font_size_override("font_size", 16)
	row.add_child(_progress)

	_check = Label.new()
	_check.text = "✓"
	_check.add_theme_font_size_override("font_size", 20)
	_check.add_theme_color_override("font_color", Color("#8ce0a0"))
	_check.visible = false
	row.add_child(_check)


## Render a quest's whisper + progress immediately (no fade).
func _show_quest(id: String) -> void:
	_panel.visible = true
	_whisper.text = "「%s」" % QuestManager.whisper(id)
	_check.visible = false
	_refresh_progress(id, 0, QuestManager.quest_count(id))


func _refresh_progress(id: String, cur: int, need: int) -> void:
	if need > 1:
		_progress.text = "(%d/%d)" % [cur, need]
		_progress.visible = true
	else:
		_progress.visible = false


func _on_started(id: String) -> void:
	_show_quest(id)


func _on_progress(id: String, cur: int, need: int) -> void:
	if id == QuestManager.active_id:
		_refresh_progress(id, cur, need)


func _on_completed(_id: String) -> void:
	# Flash the completion check.
	_check.visible = true
	var tw := create_tween()
	_check.modulate = Color(1, 1, 1, 1)
	tw.tween_property(_check, "modulate:a", 0.0, 0.6).set_delay(0.3)


func _on_advanced(_old_id: String, new_id: String) -> void:
	if new_id == "":
		return
	# Soft chime + fade transition to the new whisper.
	if AudioManager != null:
		AudioManager.play_sfx("quest_advance")
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func(): _show_quest(new_id))
	tw.tween_property(_panel, "modulate:a", 1.0, 0.35)


func _on_all_done() -> void:
	if AudioManager != null:
		AudioManager.play_sfx("quest_advance")
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 0.0, 0.8).set_delay(0.6)
	tw.tween_callback(func(): _panel.visible = false)
