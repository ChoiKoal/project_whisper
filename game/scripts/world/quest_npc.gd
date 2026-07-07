extends Sprite2D
class_name QuestNPC
## (v1.1.0 GP-4 §1) QuestNPC — 「살아있지 않은 잔재」 world node. A layer resident frozen in its last
## motion (메아리/노목/안내 로봇/파수 로봇/마법사 잔영/석상) that speaks to the wanderer. Reuses the
## TruthShard pattern exactly: a Sprite2D in the `gatherable` group with an `object_id` and an
## on_interact() the InteractionController routes E to. It is NOT gatherable and NOT a use-target.
##
## on_interact():
##   1. Activates this NPC's sub-chain on first contact (QuestManager.activate_npc_line(npckey),
##      idempotent) — 진행/보상은 QuestManager가 소유, this node is pure presentation + trigger.
##   2. Shows the NpcDialogCard: 이름 + 현재 활성 의뢰문(whisper) — or a soft idle/farewell line when
##      the sub-chain is finished / not yet in this NPC's line.
##
## Headless-safe: the card modal is a CanvasLayer built on demand; activation + quest state advance
## work without any card (the harness drives on_interact() through the REAL InteractionController path
## and asserts QuestManager state, never touching the card UI).

const GROUP := "gatherable"

## Stable id for InteractionController targeting (e.g. "npc_oak").
@export var object_id: String = "npc_echo"
## Quest sub-chain key (`N-{npckey}-Q{n}` in quests.json), e.g. "echo", "oak", "robot".
@export var npckey: String = "echo"
## Display name for the dialog card header (e.g. "메아리", "시들지 않는 노목").
@export var npc_name: String = "메아리"
## Soft line shown when this NPC has no active 의뢰 (finished its chain / idle).
@export var idle_line: String = "…고마워. 이제, 조금 덜 외로워."

var _card_layer: CanvasLayer = null


func _ready() -> void:
	add_to_group(GROUP)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true


## Configure from code (used by the layer sessions that spawn these).
func setup(p_npckey: String, p_name: String, p_idle: String = "", tex: Texture2D = null) -> void:
	npckey = p_npckey
	npc_name = p_name
	object_id = "npc_" + p_npckey
	if p_idle != "":
		idle_line = p_idle
	if tex != null:
		texture = tex


## Static spawn helper reused by every layer session. Places a QuestNPC on `anchor_cell` (nudged to
## the nearest walkable neighbour if blocked, so the NPC is ALWAYS reachable — never on a wall/void),
## parents it under the loader's y-sort layer, and applies the height lift. Mirrors the TruthShard
## scatter idiom. `tex_path` optional. Returns the node ("" cell / no loader → null, no crash).
static func spawn(session: Node, loader: Node, anchor_cell: Vector2i, p_npckey: String, p_name: String, p_idle: String = "", tex_path: String = "") -> QuestNPC:
	if loader == null or not is_instance_valid(loader):
		return null
	var ys := loader.get_node_or_null(loader.ysort_layer_path) as Node2D
	var parent: Node = ys if ys != null else loader
	var use_cell: Vector2i = anchor_cell
	if loader.has_method("is_cell_walkable") and not loader.is_cell_walkable(use_cell):
		var found := false
		for off in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			if loader.is_cell_walkable(anchor_cell + off):
				use_cell = anchor_cell + off
				found = true
				break
		if not found:
			return null
	var npc := QuestNPC.new()
	var tex: Texture2D = null
	if tex_path != "" and ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	npc.setup(p_npckey, p_name, p_idle, tex)
	npc.offset = Vector2(0, -40)
	parent.add_child(npc)
	if loader.has_method("cell_center_world"):
		npc.global_position = loader.cell_center_world(use_cell)
	if loader.has_method("apply_height_lift"):
		loader.apply_height_lift(npc)
	return npc


# ---- Gatherable-compatible targeting interface (mirrors TruthShard) --------

func can_gather() -> bool:
	return false

func gather() -> String:
	return ""

func target_point() -> Vector2:
	return global_position + Vector2(0, offset.y * scale.y)

func set_targeted(on: bool) -> void:
	self_modulate = Color(1.25, 1.2, 1.35) if on else Color.WHITE


## E 상호작용 — activate this NPC's sub-chain (idempotent) + show the current 의뢰문.
func on_interact() -> void:
	if typeof(QuestManager) != TYPE_NIL and QuestManager.has_method("activate_npc_line"):
		QuestManager.activate_npc_line(npckey)
	_show_card()


## The line to speak this frame: the active 의뢰문(whisper), else the idle/farewell line.
func current_line() -> String:
	if typeof(QuestManager) != TYPE_NIL and QuestManager.has_method("npc_active_id"):
		var aid := String(QuestManager.npc_active_id(npckey))
		if aid != "":
			var w := String(QuestManager.whisper(aid))
			if w != "":
				return w
	return idle_line


func _show_card() -> void:
	if _card_layer != null and is_instance_valid(_card_layer):
		return
	_card_layer = QuestNPC.build_card(self, npc_name, current_line(), _close_card)


## Static: build + parent the NPC dialog card modal (초상 자리 없이 이름 + 대사, TruthShard 카드 톤을
## 계승). `owner_node` supplies the tree + push_modal/control_lock. Returns the CanvasLayer.
static func build_card(owner_node: Node, name_text: String, line_text: String, on_close: Callable) -> CanvasLayer:
	if GameState != null:
		GameState.push_modal("npc_card")
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
	col.add_theme_constant_override("separation", 14)
	dim.add_child(col)

	var head := Label.new()
	head.text = name_text
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_color", Color("#c8b0ec"))
	head.add_theme_font_size_override("font_size", 22)
	col.add_child(head)

	var body := Label.new()
	body.text = line_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(620, 0)
	body.add_theme_color_override("font_color", Color("#faf5e6"))
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_constant_override("line_spacing", 8)
	col.add_child(body)

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
		GameState.pop_modal("npc_card")
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
