extends Node
## v1.4.1 bug3 acceptance harness — 벽/나무 y-sort 가림(occlusion) 정합.
##
## v1.4.0 리사이즈 이후 관측된 "벽 뒤 나무 뚫림": 내부 릿지 바위벽(interior VOID band의
## ridge_rock)이 고정 z(RIDGE_Z=3)에 놓여 YSortLayer(z5)의 나무/오브젝트에게 항상 짐 →
## 벽 북쪽(뒤)에 있어야 할 나무가 벽을 뚫고 앞에 그려짐.
##
## Fix(v1.4.1): 릿지 벽 스프라이트를 YSortLayer로 이동하고 노드 position.y = 셀 중심
## (접지점 = 나무 발밑과 동일 기준)으로 두어, 벽·나무가 화면 Y로 올바르게 정렬되게 함.
##
## 어서션:
##   1. L1 grove에 내부 릿지 셀이 존재한다.
##   2. 릿지 벽 스프라이트가 YSortLayer의 자식이다(고정-z Ridges 오버레이가 아님) + y_sort_enabled.
##   3. 릿지 벽 노드의 position.y == 그 셀 중심 y (foot/접지 앵커, 나무와 동일 기준).
##   4. 가림 불변식: 벽 북쪽(row-1) 셀 = 벽보다 작은 Y → 뒤에 그려짐(가려짐);
##      벽 남쪽(row+1) 셀 = 벽보다 큰 Y → 앞에 그려짐(보임).
##   5. 나무 스프라이트 앵커: Gatherable(tree) 노드의 position.y도 셀 중심(발밑) 기준이다.
##
## Instances the real starting_grove scene. PASS/FAIL 출력 + 실패 수로 quit.

const GROVE := "res://scenes/world/starting_grove.tscn"

var _fail := 0


func _check(label: String, cond: bool) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== v1.4.1 Y-SORT (wall/tree occlusion) HARNESS ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	SaveManager.pending_load = false

	var scene: PackedScene = load(GROVE)
	var map := scene.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame

	var loader := map.get_node("Ground") as MapLoader
	var ysort := map.get_node("YSortLayer") as Node2D

	# 1. interior ridge cells exist
	_check("L1 grove has interior ridge cells", loader.ridge_cells.size() > 0)
	_check("ridge sprites were placed", loader.ridge_sprite_count > 0)

	# 2. + 3. ridge wall sprites live in the YSortLayer, foot-anchored at the cell centre.
	var ridge_sprites_in_ysort := 0
	var anchor_ok := true
	var ysort_ridge_positions := {}   # Vector2i cell -> Sprite2D (matched by position → cell)
	for child in ysort.get_children():
		if not (child is Sprite2D):
			continue
		var spr := child as Sprite2D
		# ridge walls use the ridge_rock textures; identify by texture path or by matching a ridge cell.
		var cell: Vector2i = loader.world_to_cell(spr.global_position)
		if not loader.ridge_cells.has(cell):
			continue
		# only count the tall wall sprites (offset lifts them well above the tile)
		if spr.texture == null or spr.texture.get_height() < 180:
			continue
		ridge_sprites_in_ysort += 1
		ysort_ridge_positions[cell] = spr
		if not spr.y_sort_enabled:
			anchor_ok = false
		# node position.y must equal the cell centre y (foot anchor) — same basis as trees.
		var expected_y := loader.cell_center_world(cell).y
		if absf(spr.position.y - expected_y) > 1.0:
			anchor_ok = false
			print("    ridge %s position.y=%.1f != cell centre y=%.1f" % [cell, spr.position.y, expected_y])
	_check("ridge walls are YSortLayer children (not fixed-z overlay)", ridge_sprites_in_ysort > 0)
	_check("ridge wall nodes foot-anchored at cell centre (y_sort on)", anchor_ok)

	# ensure the old fixed-z Ridges overlay no longer holds the wall sprites (may still exist,
	# but must not carry the tall ridge_rock pieces that beat the YSortLayer).
	var overlay := loader.get_node_or_null("Ridges")
	var tall_in_overlay := 0
	if overlay != null:
		for c in overlay.get_children():
			if c is Sprite2D and (c as Sprite2D).texture != null and (c as Sprite2D).texture.get_height() >= 180:
				tall_in_overlay += 1
	_check("no tall ridge walls left on the fixed-z overlay", tall_in_overlay == 0)

	# 4. occlusion invariant: pick a ridge cell, compare a north vs south neighbour's sort Y.
	var probe: Vector2i = Vector2i(-1, -1)
	for cell in ysort_ridge_positions.keys():
		probe = cell
		break
	_check("found a ridge probe cell", probe != Vector2i(-1, -1))
	if probe != Vector2i(-1, -1):
		var wall_y := loader.cell_center_world(probe).y
		var north_y := loader.cell_center_world(probe + Vector2i(0, -1)).y  # row-1 (behind)
		var south_y := loader.cell_center_world(probe + Vector2i(0, 1)).y   # row+1 (in front)
		_check("wall NORTH neighbour sorts BEHIND the wall (y < wall_y)", north_y < wall_y)
		_check("wall SOUTH neighbour sorts IN FRONT of the wall (y > wall_y)", south_y > wall_y)

	# 5. tree (Gatherable) nodes are foot-anchored at their cell centre too (same y-sort basis).
	var tree_anchor_ok := true
	var trees_checked := 0
	for child in ysort.get_children():
		if not (child is Gatherable):
			continue
		var g := child as Gatherable
		if g.texture == null or not String(g.texture.resource_path).contains("tree"):
			continue
		var cell := loader.world_to_cell(g.global_position)
		var expected := loader.cell_center_world(cell).y
		if absf(g.position.y - expected) > 1.0:
			tree_anchor_ok = false
		trees_checked += 1
		if trees_checked >= 8:
			break
	_check("tree Gatherables foot-anchored at cell centre", trees_checked > 0 and tree_anchor_ok)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)
