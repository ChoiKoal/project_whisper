extends Node
## v0.4.0-C acceptance harness — placement expansion + 속삭임 quest chain + procedural audio.
##
## Covers (validation §2):
##   PLACEMENT — items.json placement records (class/blocks per spec); ghost validity honours
##     the `on` tile rule; placing a structure/decor spawns a PlacedObject node that persists
##     through a save→load roundtrip; recall returns the item to the inventory; blocks:true
##     adds a StaticBody2D collider.
##   QUESTS   — drive Q1→Q9 purely via the EXISTING GameState signals the QuestManager listens
##     to; assert each quest advances in order and Q9 completes into the all-done / clear state.
##   AUDIO    — every expected WAV exists on disk; AudioManager loaded the streams and plays a
##     SFX + a BGM crossfade without erroring headless; loop streams carry a forward loop_mode.
##
## Runs headless. Audio is silent under --headless but must not error.

const GROVE := "res://scenes/world/starting_grove.tscn"
const AUDIO_DIR := "res://assets/audio/"

var _fail := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== v0.4.0-C TEST HARNESS ===")
	_test_placement_data()
	await _test_placement_world()
	_test_quest_chain()
	_test_audio()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ==== PLACEMENT: data-level =================================================

func _test_placement_data() -> void:
	print("--- placement data ---")
	# Spec: ~20+ dead-end craftables become placeable; functional stays D14/D22 only.
	# (v1.5.0 EX-L1) +4 신규 functional 배치물: D223 꽃돌다리(물 위 디딤돌 계열),
	#   D226/D227/D228 삼원색 물감(무지개 샘 퍼즐). 전부 blocks:false·on-rule 존재.
	# (v1.6.0 EX-L2 지하 데이터 성소) +4: D256 방수 디딤돌(T5A 위), D259/D260/D261
	#   정합 조각 α/β/γ(align_slot 위). 전부 blocks:false·on-rule 존재.
	var placeable_count := 0
	var functional := []
	for id in ItemDB.all_ids():
		if ItemDB.is_placeable(id):
			placeable_count += 1
			if ItemDB.placement_class(id) == "functional":
				functional.append(id)
	_check("20+ placeable items", placeable_count >= 20, "count=%d" % placeable_count)
	functional.sort()
	_check("functional class is exactly D14/D22 (+EX-L1 D223/D226/D227/D228 +EX-L2 D256/D259/D260/D261)",
		functional == ["D14", "D22", "D223", "D226", "D227", "D228", "D256", "D259", "D260", "D261"],
		str(functional))
	# Sample spec classes: structures block, decor doesn't.
	_check("D24 울타리 = structure, blocks", ItemDB.placement_class("D24") == "structure"
		and ItemDB.placement_blocks("D24"))
	_check("D46 벽 = structure, blocks", ItemDB.placement_class("D46") == "structure"
		and ItemDB.placement_blocks("D46"))
	_check("D29 화분 = decor, no block", ItemDB.placement_class("D29") == "decor"
		and not ItemDB.placement_blocks("D29"))
	_check("D48 등불꽃 = decor", ItemDB.placement_class("D48") == "decor")
	# spec items that were still missing before this sprint
	for id in ["D08", "D18", "D49", "D55", "D56", "D60"]:
		_check("%s now placeable" % id, ItemDB.is_placeable(id))
	# ghost validity honours the `on` rule
	_check("D24 valid on T1 ground", ItemDB.can_place_expanded("D24", "T1"))
	_check("D24 invalid on T5A water", not ItemDB.can_place_expanded("D24", "T5A"))


# ==== PLACEMENT: live world =================================================

func _test_placement_world() -> void:
	print("--- placement world (spawn / recall / collision / save) ---")
	Inventory.clear()
	Codex.reset()
	GameState.set_game_time(0.0)
	SaveManager.pending_load = false

	var scene: PackedScene = load(GROVE)
	var map := scene.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var ysort := map.find_child("YSortLayer", true, false)
	_check("YSortLayer exists", ysort != null)

	# Spawn a blocking structure (D46 벽) directly via a PlacedObject, mirroring the
	# InteractionController's _spawn_placed_object path.
	var wall := PlacedObject.new()
	wall.setup("D46", Vector2i(5, 5))
	ysort.add_child(wall)
	await get_tree().process_frame
	_check("placed object node exists in tree", is_instance_valid(wall)
		and wall.is_inside_tree())
	_check("placed object registered in group",
		wall.is_in_group(PlacedObject.GROUP))
	# blocks:true → a StaticBody2D collider child.
	var has_body := false
	for c in wall.get_children():
		if c is StaticBody2D:
			has_body = true
	_check("blocks:true adds StaticBody2D collision", has_body)

	# A decor (D29 화분) must NOT add collision.
	var pot := PlacedObject.new()
	pot.setup("D29", Vector2i(6, 6))
	ysort.add_child(pot)
	await get_tree().process_frame
	var pot_body := false
	for c in pot.get_children():
		if c is StaticBody2D:
			pot_body = true
	_check("decor adds no collision", not pot_body)

	# Recall returns the item to the inventory and frees the node (non-destructive).
	var before := Inventory.count("D46")
	wall.recall()
	await get_tree().process_frame
	_check("recall returns item to inventory", Inventory.count("D46") == before + 1)
	_check("recall frees the node", not is_instance_valid(wall))

	# Save→load roundtrip: the remaining placed object (pot) survives.
	var loader := map.get_node("Ground") as MapLoader
	var player := map.get_node("YSortLayer/Player") as Node2D
	var respawn := map.get_node("ObjectRespawn")
	SaveManager.register_world(loader, player, respawn)
	SaveManager.save_game()
	var saved := SaveManager.build_save_dict()
	# (v0.5.0 phase C) world state is now keyed per scene under `worlds[current_scene]`.
	var world_dict: Dictionary = saved.get("worlds", {}).get(WorldContext.current_scene, {})
	var placed_arr: Array = world_dict.get("placed_objects", [])
	var pot_saved := false
	for e in placed_arr:
		if String(e.get("item_id", "")) == "D29":
			pot_saved = true
	_check("placed object serialized in save", pot_saved, "n=%d" % placed_arr.size())

	# Remove the live pot, then apply_world_state should rebuild it from the save.
	pot.free()
	await get_tree().process_frame
	SaveManager.apply_world_state(saved)
	await get_tree().process_frame
	var rebuilt := 0
	for node in get_tree().get_nodes_in_group(PlacedObject.GROUP):
		if node is PlacedObject and node.item_id == "D29":
			rebuilt += 1
	_check("placed object restored on load", rebuilt == 1, "found=%d" % rebuilt)

	SaveManager.unregister_world()
	map.queue_free()
	await get_tree().process_frame


# ==== QUEST CHAIN ==========================================================

func _test_quest_chain() -> void:
	print("--- quest chain Q1→Q9 (signal-driven) ---")
	QuestManager.reset()
	# (v0.5.0 phase C) the line now begins with the HOME quests P0→P1; advance past them to
	# test the Layer-1 grove chain Q1→Q9 as before.
	_check("line starts at P0 (home)", QuestManager.active_id == "P0",
		"active=%s" % QuestManager.active_id)
	QuestManager.advance_to("Q1")
	_check("advanced to Q1 (grove chain head)", QuestManager.active_id == "Q1",
		"active=%s" % QuestManager.active_id)

	# Q1 gather any×1
	GameState.item_gathered.emit("I1")
	_check("Q1→Q2 on gather", QuestManager.active_id == "Q2")

	# Q2 craft any×1
	GameState.item_crafted.emit("D01", "R01")
	_check("Q2→Q3 on craft", QuestManager.active_id == "Q3")

	# Q3 place 디딤돌×3 (stepping_stone_placed ×3)
	GameState.stepping_stone_placed.emit(Vector2i(1, 1))
	_check("Q3 still active after 1/3", QuestManager.active_id == "Q3")
	GameState.stepping_stone_placed.emit(Vector2i(1, 2))
	GameState.stepping_stone_placed.emit(Vector2i(1, 3))
	_check("Q3→Q4 after 3 stepping stones", QuestManager.active_id == "Q4")

	# Q4 use water on bush — target bush_dry
	var fake_bush := Node2D.new()
	fake_bush.set_meta("object_id", "bush_dry")
	# QuestManager reads obj.get("object_id"); use a tiny stub with that property.
	var bush := _StubObj.new()
	bush.object_id = "bush_dry"
	GameState.item_used_on_object.emit("I7", bush)
	_check("Q4→Q5 on water-on-bush", QuestManager.active_id == "Q5")
	fake_bush.free()
	bush.free()

	# Q5 event: night reached
	GameState.day_phase_changed.emit("night")
	_check("Q5→Q6 on night", QuestManager.active_id == "Q6")

	# Q6 reach world tree area
	GameState.player_entered_area.emit("world_tree")
	_check("Q6→Q7 on area enter", QuestManager.active_id == "Q7")

	# Q7 gather I9 specifically — a non-I9 gather must NOT advance
	GameState.item_gathered.emit("I2")
	_check("Q7 ignores non-I9 gather", QuestManager.active_id == "Q7")
	GameState.item_gathered.emit("I9")
	_check("Q7→Q8 on I9 gather", QuestManager.active_id == "Q8")

	# Q8 craft D22 — a non-D22 craft must NOT advance
	GameState.item_crafted.emit("D01", "R01")
	_check("Q8 ignores non-D22 craft", QuestManager.active_id == "Q8")
	GameState.item_crafted.emit("D22", "R40")
	_check("Q8→Q9 on D22 craft", QuestManager.active_id == "Q9")

	# Q9 place D22 on VOID → world_tree_planted → completes the line
	var all_done := [false]
	QuestManager.all_quests_completed.connect(func(): all_done[0] = true, CONNECT_ONE_SHOT)
	GameState.world_tree_planted.emit(Vector2i(10, 10))
	_check("Q9 completes the line", QuestManager.active_id == "")
	_check("all_quests_completed fired (→ clear)", all_done[0])
	_check("all quests recorded done", QuestManager.is_done("Q9")
		and QuestManager.is_done("Q1"))


# Minimal stub exposing an `object_id` property (used-on target for Q4).
class _StubObj extends Node:
	var object_id: String = ""


# ==== AUDIO ================================================================

func _test_audio() -> void:
	print("--- audio ---")
	# v0.5b AUDIO FINALIZE: BGM is now real CC0 .ogg (bgm_day/bgm_night); the old synth
	# bgm_*.wav and the day_amb/night_amb ambience WAVs were DELETED (the CC0 music carries
	# the day/night soundscape). SFX remain .wav one-shots.
	var sfx_wavs := [
		"gather_pop", "place_thud", "fuse_bubble", "fuse_success", "fuse_discovery",
		"fuse_fail", "ui_click", "ui_open", "ui_close", "quest_advance",
		"footstep_grass1", "footstep_grass2", "bush_bloom", "clear_fanfare",
	]
	var missing := []
	for name in sfx_wavs:
		if not ResourceLoader.exists(AUDIO_DIR + name + ".wav"):
			missing.append(name)
	_check("all %d SFX WAV files exist" % sfx_wavs.size(), missing.is_empty(), str(missing))

	# BGM ships as CC0 .ogg (not .wav); the synth WAVs are gone.
	_check("bgm_day.ogg exists (CC0)", ResourceLoader.exists(AUDIO_DIR + "bgm_day.ogg"))
	_check("bgm_night.ogg exists (CC0)", ResourceLoader.exists(AUDIO_DIR + "bgm_night.ogg"))
	_check("old synth bgm_day.wav deleted", not ResourceLoader.exists(AUDIO_DIR + "bgm_day.wav"))
	_check("old synth day_amb.wav deleted", not ResourceLoader.exists(AUDIO_DIR + "day_amb.wav"))

	# AudioManager loaded the streams (SFX + both BGM oggs).
	_check("AudioManager loaded gather_pop", AudioManager.has_stream("gather_pop"))
	_check("AudioManager loaded bgm_day", AudioManager.has_stream("bgm_day"))
	_check("AudioManager loaded bgm_night", AudioManager.has_stream("bgm_night"))

	# bgm_day loops forward — the CC0 ogg loops via its import flag; AudioManager also sets
	# stream.loop = true defensively. Assert the loaded ogg is an OggVorbis stream flagged to loop.
	var bgm = load(AUDIO_DIR + "bgm_day.ogg")
	_check("bgm_day loops forward", bgm is AudioStreamOggVorbis and bgm.loop == true)

	# Play a SFX + a BGM crossfade without error (silent headless).
	AudioManager.play_sfx("gather_pop")
	AudioManager.play_sfx("does_not_exist")   # must no-op, not crash
	AudioManager.crossfade_bgm("bgm_day", 0.1)
	AudioManager.crossfade_bgm_for_phase("night")
	_check("AudioManager play/crossfade did not error", true)
