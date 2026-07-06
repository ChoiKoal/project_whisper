extends Sprite2D
class_name TruthShard
## (EG-2) 진상 조각 조사 오브젝트 — a narrative investigation sprite (세계수 잎 / 마지막 로그 스크린 /
## 멈춘 로봇 / 마법사 잔영 / 석화된 피조물). Registers into the `gatherable` group so the existing
## InteractionController targets it (E 조사); it is NOT gatherable and NOT a use-target — E routes to
## on_interact(), which shows the log card + collects the shard (GameState.collect_truth_shard) +
## records the log to the 도감 「기록」 탭 (Codex.record_truth_log).
##
## Idempotent per shard: re-investigating an already-collected shard just re-shows the card (no
## double-count). Reuses the existing prompt "E 조합"? no — the InteractionController shows "E 조합"
## for any on_interact object; that reads fine here as "E 조사" is not a distinct verb in the HUD.
## Best-effort headless: the card modal is a CanvasLayer built on demand; collect works without it.

const GROUP := "gatherable"

## Stable id for InteractionController targeting.
@export var object_id: String = "truth_shard"
## The canonical shard id (one of GameState.TRUTH_SHARD_IDS).
@export var shard_id: String = ""
## Short label for the 도감 기록 row + card header (e.g. "세계수의 잎", "멈춘 로봇").
@export var title: String = "진상의 조각"
## The full log text shown on the card + stored in the 기록 탭.
@export var log_text: String = ""

var _card_layer: CanvasLayer = null


func _ready() -> void:
	add_to_group(GROUP)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true


## Configure from code (used by the layer sessions that scatter these).
func setup(p_shard_id: String, p_title: String, p_text: String, tex: Texture2D = null) -> void:
	shard_id = p_shard_id
	title = p_title
	log_text = p_text
	object_id = "truth_" + p_shard_id
	if tex != null:
		texture = tex


# ---- Gatherable-compatible targeting interface ----------------------------

func can_gather() -> bool:
	return false

func gather() -> String:
	return ""

func target_point() -> Vector2:
	return global_position + Vector2(0, offset.y * scale.y)

## Optional brighten hook (InteractionController calls set_targeted on gatherables). No-op glow
## kept minimal — a slight modulate so the object reads as investigable when adjacent.
func set_targeted(on: bool) -> void:
	self_modulate = Color(1.25, 1.2, 1.35) if on else Color.WHITE


## E 조사 — collect the shard (idempotent) + record the log + show the card.
func on_interact() -> void:
	var newly := false
	if GameState != null:
		newly = GameState.collect_truth_shard(shard_id)
	if Codex != null:
		Codex.record_truth_log(shard_id, title, log_text)
	_show_card(newly)


## Show the log card modal. When `newly` completed the set of five, the final 회수 카드 (§3.1) is
## appended inline so the [돌아선다] 해금 beat reads with the last shard.
func _show_card(newly: bool) -> void:
	if _card_layer != null and is_instance_valid(_card_layer):
		return
	var append_final := newly and GameState != null and GameState.truth_final_seen
	_card_layer = TruthShard.build_card(self, title, log_text, append_final, _close_card)


## Static: build + parent the shared truth-log card modal. Reused by WorldTree (L1) so the card
## look is authored once. `owner_node` provides the scene tree + push_modal/control_lock. `on_close`
## is the caller's close handler (bound to dim-click). Returns the CanvasLayer (caller frees it).
static func build_card(owner_node: Node, card_title: String, card_text: String, append_final: bool, on_close: Callable) -> CanvasLayer:
	if GameState != null:
		GameState.push_modal("truth_card")
		GameState.set_control_lock(true)
	var layer_node := CanvasLayer.new()
	layer_node.layer = 11
	var root: Node = owner_node.get_tree().current_scene if owner_node.get_tree() != null else null
	if root == null:
		root = owner_node
	root.add_child(layer_node)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			on_close.call())
	layer_node.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	dim.add_child(col)

	var head := Label.new()
	head.text = "「%s」" % card_title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_color", Color("#c8b0ec"))
	head.add_theme_font_size_override("font_size", 22)
	col.add_child(head)

	var body := Label.new()
	body.text = card_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(640, 0)
	body.add_theme_color_override("font_color", Color("#faf5e6"))
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_constant_override("line_spacing", 8)
	col.add_child(body)

	if append_final and Codex != null:
		col.add_child(HSeparator.new())
		var final_lbl := Label.new()
		final_lbl.text = Codex.TRUTH_FINAL_CARD
		final_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		final_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		final_lbl.custom_minimum_size = Vector2(640, 0)
		final_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78))
		final_lbl.add_theme_font_size_override("font_size", 19)
		final_lbl.add_theme_constant_override("line_spacing", 8)
		col.add_child(final_lbl)

	var hint := Label.new()
	hint.text = "닫기 (ESC / 클릭)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.72, 0.70, 0.66, 0.7))
	hint.add_theme_font_size_override("font_size", 15)
	col.add_child(hint)
	return layer_node


func _close_card() -> void:
	if _card_layer != null and is_instance_valid(_card_layer):
		_card_layer.queue_free()
	_card_layer = null
	if GameState != null:
		GameState.pop_modal("truth_card")
		GameState.set_control_lock(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if _card_layer == null or not is_instance_valid(_card_layer):
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
		_close_card()
