extends Gatherable
class_name WorldTree
## G4 — the World Tree (O0). A UNIQUE gatherable: gathering it once grants I9
## (세계수 정수) and the tree stays in the world (Gatherable's unique/_spent
## exception). A separate additive GlowSprite child makes it blaze at night.
##
## Placed once, centered over the O cluster (cols 19~20, rows 2~3). A StaticBody2D
## blocks the trunk so the player gathers from adjacent (OBJECT_REACH).

const TEX := "res://assets/objects/world_tree.png"
const GLOW_TEX := "res://assets/objects/world_tree_glow.png"

## (EG-2) L1 진상 조각 — 세계수의 잎. Investigating the tree (or gathering its 정수) records the
## shard. New text per 설계 §3 (L1/L2 needed new 조각 대사). TruthShard-style card via a lazy modal.
const SHARD_ID := "world_tree"
const SHARD_TITLE := "세계수의 잎"
const SHARD_LOG := "…잎 뒤에 새겨진 글: 나를 심은 이도 '완성하라'는 말을 들었다 한다. 완성하고 떠난 자리에서, 나는 홀로 시들었다. 그러니 너는 — 자꾸 말을 걸어 다오."

var _shard_card: CanvasLayer = null

## (CQ-3 G7) CS-03 「세계수 앞에서」 first-encounter beat: fires ONCE when the player first comes
## near the tree. Transient session guard (WorldContext) so it never repeats within a run.
const CS03_CARDS := ["이 세계에서 유일하게, 따뜻한 것.", "…방금, 나를 본 건가?"]
var _cs03_playing: bool = false


func _ready() -> void:
	super._ready()
	item_id = "I9"
	unique = true
	object_id = "world_tree"
	if texture == null:
		texture = load(TEX)
	# 512×512 sprite, ground origin at bottom-center: offset up by half height.
	offset = Vector2(0, -240)
	scale = Vector2(0.5, 0.5)  # fit the canopy over the O cluster footprint

	# Glow overlay (additive, night-reactive).
	var glow := GlowSprite.new()
	glow.texture = load(GLOW_TEX)
	glow.offset = offset
	glow.scale = scale
	add_child(glow)

	# (CQ-3 G7) CS-03 proximity trigger — an Area2D around the trunk; first entry plays the beat.
	_setup_cs03_trigger()


## An Area2D around the tree; the first time the player's body enters, play CS-03 (once/session).
func _setup_cs03_trigger() -> void:
	var area := Area2D.new()
	area.name = "CS03Trigger"
	area.monitoring = true
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 150.0
	col.shape = shape
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(_on_cs03_body_entered)


func _on_cs03_body_entered(body: Node) -> void:
	if _cs03_playing or not (body is Player):
		return
	if WorldContext == null or WorldContext.cs03_encounter_seen:
		return
	# Don't overlap the plant/clear or a modal; keep it to the quiet first approach.
	if GameState != null and (GameState.control_locked() or not GameState.time_running):
		return
	WorldContext.cs03_encounter_seen = true
	_play_cs03(body as Node2D)


## CS-03: 카메라 아래→위 틸트 + BGM 페이드아웃(저음) + 잎 기욺 + 2 cards. Low-cost, high-impact.
func _play_cs03(player: Node2D) -> void:
	_cs03_playing = true
	if GameState != null:
		GameState.set_control_lock(true)
	# BGM 페이드아웃 → 심장박동 같은 저음만 (best-effort: duck the BGM bus).
	if AudioManager != null and AudioManager.has_method("duck_bgm"):
		AudioManager.duck_bgm(true)
	# Card overlay layer (freed after).
	var cl := CanvasLayer.new()
	cl.layer = 11
	add_child(cl)
	var label := CutsceneDirector.make_card_label(30)
	cl.add_child(label)
	# 카메라 아래→위 틸트 (sweep the tree from base to canopy).
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		# fire-and-forget the tilt sweep in parallel with the cards.
		CutsceneDirector.camera_tilt_sweep(self, cam, 90.0, -140.0, 2.4, 0.9)
	await CutsceneDirector.play_card(self, label, CS03_CARDS[0], CutsceneDirector.CREAM)
	if not is_instance_valid(self):
		return
	# 세계수 잎이 플레이어 쪽으로 아주 살짝 기운다 (a small trunk-sprite tilt, once).
	_tilt_leaf()
	await CutsceneDirector.play_card(self, label, CS03_CARDS[1], CutsceneDirector.CREAM)
	if AudioManager != null and AudioManager.has_method("duck_bgm"):
		AudioManager.duck_bgm(false)
	if is_instance_valid(cl):
		cl.queue_free()
	if GameState != null:
		GameState.set_control_lock(false)
	_cs03_playing = false


## A hair of rotation on the tree sprite — "…방금, 나를 본 건가?"
func _tilt_leaf() -> void:
	var tw := create_tween()
	tw.tween_property(self, "rotation", 0.05, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "rotation", 0.0, 0.9).set_trans(Tween.TRANS_SINE)

	# Trunk collision.
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([
		Vector2(0, -32), Vector2(64, 0), Vector2(0, 32), Vector2(-64, 0)
	])
	col.shape = shape
	body.add_child(col)
	add_child(body)


func target_point() -> Vector2:
	return global_position


## (EG-2) Gathering the 세계수 정수 ALSO collects the L1 진상 조각 + records its log (the leaf's
## inscription). The player who takes the essence has read the leaf.
func gather() -> String:
	var granted := super.gather()
	if granted != "":
		_collect_shard()
	return granted


## (EG-2) After the tree is 정수-spent, E on it 조사s the leaf: collect the shard + show the card.
## (Before it's spent, E gathers — and gather() collects too — so the shard is reachable either way.)
func on_interact() -> void:
	_collect_shard()
	_show_shard_card()


func _collect_shard() -> void:
	if GameState != null:
		GameState.collect_truth_shard(SHARD_ID)
		# (v1.1.0 GP-4) every investigation announces itself for NPC 회고 quests (부록B #2).
		GameState.truth_shard_investigated.emit(SHARD_ID)
	if Codex != null:
		Codex.record_truth_log(SHARD_ID, SHARD_TITLE, SHARD_LOG)


func _show_shard_card() -> void:
	if _shard_card != null and is_instance_valid(_shard_card):
		return
	var append_final := GameState != null and GameState.truth_final_seen
	_shard_card = TruthShard.build_card(self, SHARD_TITLE, SHARD_LOG, append_final, _close_shard_card)


func _close_shard_card() -> void:
	if _shard_card != null and is_instance_valid(_shard_card):
		_shard_card.queue_free()
	_shard_card = null
	if GameState != null:
		GameState.pop_modal("truth_card")
		GameState.set_control_lock(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if _shard_card == null or not is_instance_valid(_shard_card):
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
		_close_shard_card()
