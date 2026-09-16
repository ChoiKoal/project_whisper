extends Node
## Candidate-only RED harness for the uphill/ramp actor-occlusion defect.
##
## PROVENANCE / INJECTION:
## - Boots the real StartingGrove scene, TileSet, MapLoader, Player and CharacterBody physics.
## - Uses authored odd-row ramp (18,17) and even-row route ramp (18,22).
## - Teleports only to each disclosed endpoint, then drives the real Player with a short
##   explicit waypoint path through the authored ramp. This isolates traversal from route choice.
## - Gameplay PNGs use the shipped actor and world. Diagnostic PNGs replace only the actor ink
##   with a unique magenta alpha mask and hide unrelated YSort props. Terrain remains live.
## - The diagnostic mask is an oracle for draw coverage, not gameplay art evidence.
## - Does not mutate source data, progression, save positions or collision geometry.
##
## Expected on the audited source: RED because a ramp Sprite2D is effective z=6 while the
## YSortLayer/Player is effective z=5. The candidate patch should make ramp-on-surface mask
## coverage green without lifting the CharacterBody.

const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
const GROVE := "res://scenes/world/starting_grove.tscn"
const EXPECTED_VIEWPORT := Vector2i(1600, 900)
const SIDES := [
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
]
const RAMP_CASES := [
	{"name": "odd-h0-h1", "cell": Vector2i(18, 17), "parity": 1},
	{"name": "even-h1-h2", "cell": Vector2i(18, 22), "parity": 0},
]

var failures := 0
var checks := 0
var observations: Array[Dictionary] = []
var _out_dir := ""
var _scene: Node
var _ground: MapLoader
var _player: Player
var _touch: TouchController
var _anim: AnimatedSprite2D
var _camera: Camera2D
var _mask: Sprite2D
var _full_mask_pixels := 0
var _hidden_clutter: Dictionary = {}


func check(label: String, condition: bool, detail := "") -> void:
	checks += 1
	print("[%s] %s %s" % ["PASS" if condition else "FAIL", label, detail])
	if not condition:
		failures += 1


func _ready() -> void:
	if not GUARD.require_isolated_user_data("ramp_occlusion_red"):
		get_tree().quit(86)
		return
	_out_dir = OS.get_environment("RAMP_OCCLUSION_DIR")
	if _out_dir.is_empty():
		_out_dir = ProjectSettings.globalize_path("user://ramp-occlusion-red")
	var err := DirAccess.make_dir_recursive_absolute(_out_dir)
	if err != OK:
		push_error("RAMP_OCCLUSION_RED output unavailable %s err=%d" % [_out_dir, err])
		get_tree().quit(87)
		return
	call_deferred("run")


func run() -> void:
	SaveManager.new_game()
	WorldContext.arrival_mode = ""
	var scene_path := OS.get_environment("FDN_SCENE")
	_scene = load(GROVE if scene_path.is_empty() else scene_path).instantiate()
	add_child(_scene)
	await process_frames(12)
	GameState.time_running = true
	_ground = _scene.get_node("Ground") as MapLoader
	_player = _scene.get_node("YSortLayer/Player") as Player
	_touch = _scene.get_node("TouchController") as TouchController
	_anim = _player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_camera.position_smoothing_enabled = false
	_camera.zoom = Vector2.ONE
	var day_night := _scene.get_node_or_null("DayNight") as CanvasModulate
	if day_night != null:
		day_night.color = Color.WHITE
	_open_g2_fixture()
	_touch.refresh_grid()
	_make_diagnostic_mask()
	check("diagnostic actor mask built", _mask != null)
	check("actor tier remains the gameplay YSort domain",
		_ground.YSORT_Z == (_scene.get_node("YSortLayer") as Node2D).z_index,
		"Elevation(parent)=%d ramp-child=%d actor=%d" % [
			_ground.get_node("Elevation").z_index,
			_ground.CLIFF_FACE_Z,
			_ground.YSORT_Z,
		])

	for spec in RAMP_CASES:
		await _run_ramp_case(spec)

	await _run_cliff_order_probe()
	if not scene_path.is_empty():
		check("candidate requires mixed-corner/lifecycle capability", _ground.has_method("clear_foundation_elevation"))
	if _ground.has_method("clear_foundation_elevation"):
		await _mixed_corner_probes()
	await _record_auxiliary_contracts()
	_write_manifest()
	SaveManager.unregister_world()
	_scene.queue_free()
	await process_frames(2)
	print("RAMP_OCCLUSION_RED checks=%d failures=%d manifest=%s" % [
		checks, failures, _out_dir.path_join("manifest.json")])
	get_tree().quit(1 if failures else 0)


func _open_g2_fixture() -> void:
	# The odd-row authored ramp's low endpoint is the real dry-bush gate cell. Exercise the
	# production bloom removal so the diagnostic can reach the ramp; this is disclosed setup.
	for node in get_tree().get_nodes_in_group("gatherable"):
		if node is BushDry and _scene.is_ancestor_of(node):
			(node as BushDry).bloom()


func _make_diagnostic_mask() -> void:
	var texture := _anim.sprite_frames.get_frame_texture(_anim.animation, _anim.frame)
	if texture == null:
		return
	var source := texture.get_image()
	if source == null:
		return
	if source.is_compressed():
		source.decompress()
	var image := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			var alpha := source.get_pixel(x, y).a
			if alpha > 0.01:
				image.set_pixel(x, y, Color(1.0, 0.0, 1.0, alpha))
	_mask = Sprite2D.new()
	_mask.name = "InjectedDiagnosticActorMask"
	_mask.texture = ImageTexture.create_from_image(image)
	_mask.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mask.scale = _anim.scale
	_mask.visible = false
	_player.add_child(_mask)
	process_priority = 100
	_sync_mask()


func _process(_delta: float) -> void:
	# Sample after Player._process, not at process_frame (before node processing).
	if is_instance_valid(_mask):
		_sync_mask()


func _sync_mask() -> void:
	if _mask == null:
		return
	_mask.position = _anim.position
	_mask.flip_h = _anim.flip_h


func _set_diagnostic(enabled: bool) -> void:
	_anim.visible = not enabled
	_mask.visible = enabled
	_sync_mask()
	if enabled:
		_hide_unrelated_ysort_props()
	else:
		_restore_unrelated_ysort_props()


func _hide_unrelated_ysort_props() -> void:
	if not _hidden_clutter.is_empty():
		return
	var ysort := _scene.get_node("YSortLayer")
	for child in ysort.get_children():
		if child == _player or child.has_meta("raised_cell"):
			continue
		if child is CanvasItem:
			_hidden_clutter[child] = (child as CanvasItem).visible
			(child as CanvasItem).visible = false


func _restore_unrelated_ysort_props() -> void:
	for child in _hidden_clutter:
		if is_instance_valid(child):
			(child as CanvasItem).visible = bool(_hidden_clutter[child])
	_hidden_clutter.clear()


func _run_ramp_case(spec: Dictionary) -> void:
	var name := String(spec.name)
	var ramp: Vector2i = spec.cell
	var axis := _ramp_axis(ramp)
	check("%s authored ramp has opposite low/high sides" % name, not axis.is_empty(), str(axis))
	if axis.is_empty():
		return
	var low: Vector2i = axis.low
	var high: Vector2i = axis.high
	check("%s row parity fixture" % name, ramp.y % 2 == int(spec.parity), str(ramp))
	check("%s real TileSet sides bridge height" % name,
		_ground.height_at(low) < _ground.height_at(high),
		"low=%s h%d high=%s h%d" % [low, _ground.height_at(low), high, _ground.height_at(high)])
	check("%s AStar contains low/ramp/high" % name,
		_touch._astar.has_point(_touch._pid(low))
		and _touch._astar.has_point(_touch._pid(ramp))
		and _touch._astar.has_point(_touch._pid(high)))
	check("%s low-ramp graph edge exists" % name,
		_touch._astar.are_points_connected(_touch._pid(low), _touch._pid(ramp)))
	check("%s ramp-high graph edge exists" % name,
		_touch._astar.are_points_connected(_touch._pid(ramp), _touch._pid(high)))

	# Shipped-art context captures: no diagnostic mask and no prop hiding.
	_set_diagnostic(false)
	for probe in [
		{"label": "lower", "position": _ground.cell_center_world(low)},
		{"label": "ramp-mid", "position": _ground.cell_center_world(ramp)},
		{"label": "upper", "position": _ground.cell_center_world(high)},
	]:
		_player.release_move_and_path()
		_player.global_position = probe.position
		await process_frames(2)
		await _capture("gameplay-%s-%s.png" % [name, probe.label], {
			"kind": "gameplay_context",
			"case": name,
			"probe": probe.label,
			"injected_position": true,
			"diagnostic_actor": false,
		})

	# Establish the complete-mask pixel count with all elevation Sprite2D render roles hidden.
	_set_diagnostic(true)
	_player.global_position = _ground.cell_center_world(low)
	await process_frames(2)
	var terrain_roles := _terrain_role_sprites()
	var prior := _set_visible(terrain_roles, false)
	var baseline := await _capture("diagnostic-%s-mask-reference.png" % name, {
		"kind": "injected_actor_mask_reference",
		"case": name,
		"terrain_roles_hidden": true,
		"diagnostic_actor": true,
	})
	_restore_visible(prior)
	if _full_mask_pixels == 0:
		_full_mask_pixels = int(baseline.mask_pixels)
	check("%s diagnostic reference has actor pixels" % name,
		int(baseline.mask_pixels) > 0, str(baseline.mask_pixels))
	check("%s diagnostic reference stable" % name,
		int(baseline.mask_pixels) == _full_mask_pixels,
		"actual=%d expected=%d" % [int(baseline.mask_pixels), _full_mask_pixels])

	await _traverse(name, ramp, low, high, true)
	await _traverse(name, ramp, high, low, false)
	_set_diagnostic(false)


func _ramp_axis(ramp: Vector2i) -> Dictionary:
	for i in range(2):
		var a := _ground.get_neighbor_cell(ramp, SIDES[i])
		var b := _ground.get_neighbor_cell(ramp, SIDES[i + 2])
		var ah := _ground.height_at(a)
		var bh := _ground.height_at(b)
		if ah == bh:
			continue
		var low := a if ah < bh else b
		var high := b if ah < bh else a
		if _ground.is_cell_walkable(low) and _ground.is_cell_walkable(high):
			return {"low": low, "high": high}
	return {}


func _traverse(name: String, ramp: Vector2i, start: Vector2i, end: Vector2i, uphill: bool) -> void:
	_player.release_move_and_path()
	_player.global_position = _ground.cell_center_world(start)
	await physics_frames(3)
	# Explicit two-waypoint route guarantees that this case crosses the named authored ramp.
	# Player._follow_path + CharacterBody2D.move_and_slide remain production runtime physics.
	_player.set_path([
		_ground.cell_center_world(ramp),
		_ground.cell_center_world(end),
	])
	var samples: Array[Dictionary] = []
	var captures := 0
	for frame in range(240):
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var cell := _ground.world_to_cell(_player.global_position)
		var visual_offset := _anim.position.y - _player._base_anim_position.y
		var expected_offset := _ground.visual_height_offset(_player.global_position)
		var sample := {
			"frame": frame,
			"body": [_player.global_position.x, _player.global_position.y],
			"cell": [cell.x, cell.y],
			"visual_offset": visual_offset,
			"expected_visual_offset": expected_offset,
			"foot_gap": _actor_foot_gap(),
		}
		samples.append(sample)
		if cell == ramp and captures < 8:
			var record := await _capture(
				"diagnostic-%s-%s-%02d.png" % [name, "up" if uphill else "down", captures],
				{
					"kind": "actual_player_physics_frame_with_injected_actor_mask",
					"case": name,
					"direction": "up" if uphill else "down",
					"frame": frame,
					"cell": [cell.x, cell.y],
					"body": [_player.global_position.x, _player.global_position.y],
					"visual_offset": visual_offset,
					"expected_visual_offset": expected_offset,
					"diagnostic_actor": true,
				})
			check("%s %s ramp frame mask fully visible %02d" % [name, "up" if uphill else "down", captures],
				int(record.mask_pixels) == _full_mask_pixels,
				"visible=%d reference=%d" % [int(record.mask_pixels), _full_mask_pixels])
			captures += 1
		if not _player.is_pathing():
			break
	_player.release_move_and_path()
	var target := _ground.cell_center_world(end)
	check("%s %s real Player reaches endpoint" % [name, "up" if uphill else "down"],
		_player.global_position.distance_to(target) < 9.0,
		"actual=%s target=%s" % [_player.global_position, target])
	check("%s %s body remains on flat logical endpoint (no double lift)" % [name, "up" if uphill else "down"],
		absf(_player.global_position.y - target.y) < 9.0,
		"body_y=%.3f target_y=%.3f" % [_player.global_position.y, target.y])
	var sampler_ok := true
	var ramp_offsets: Array[float] = []
	var foot_gaps: Array[float] = []
	for sample in samples:
		if absf(float(sample.visual_offset) - float(sample.expected_visual_offset)) > 0.01:
			sampler_ok = false
		if Vector2i(sample.cell[0], sample.cell[1]) == ramp:
			ramp_offsets.append(float(sample.visual_offset))
			foot_gaps.append(float(sample.foot_gap))
	check("%s %s AnimatedSprite follows visual_height_offset" % [name, "up" if uphill else "down"], sampler_ok)
	check("%s %s captured actual ramp frames" % [name, "up" if uphill else "down"], captures >= 2,
		"captures=%d" % captures)
	check("%s %s ramp height changes monotonically" % [name, "up" if uphill else "down"],
		_monotonic(ramp_offsets, not uphill), str(ramp_offsets))
	# A moving animation may intentionally move feet; this is a tight tolerance observation,
	# not evidence that a separate ground shadow exists.
	if not foot_gaps.is_empty():
		var spread: float = foot_gaps.max() - foot_gaps.min()
		check("%s %s foot-to-sampled-surface gap stays bounded" % [name, "up" if uphill else "down"],
			spread <= 4.0, "spread=%.3f gaps=%s" % [spread, foot_gaps])
		if not OS.get_environment("FDN_SCENE").is_empty():
			check("%s %s body-only sole reaches sampled surface" % [name,"up" if uphill else "down"],
				foot_gaps.all(func(gap): return absf(gap)<0.01),str(foot_gaps))
	observations.append({
		"kind": "physics_traversal",
		"case": name,
		"direction": "up" if uphill else "down",
		"ramp": [ramp.x, ramp.y],
		"start": [start.x, start.y],
		"end": [end.x, end.y],
		"samples": samples,
	})


func _monotonic(values: Array[float], nondecreasing: bool) -> bool:
	if values.size() < 2:
		return false
	for i in range(1, values.size()):
		if nondecreasing:
			if values[i] + 0.5 < values[i - 1]:
				return false
		else:
			if values[i] - 0.5 > values[i - 1]:
				return false
	return true


func _actor_foot_gap() -> float:
	var texture := _anim.sprite_frames.get_frame_texture(_anim.animation, _anim.frame)
	if texture == null:
		return INF
	var image := texture.get_image()
	if image == null:
		return INF
	if image.is_compressed():
		image.decompress()
	var bottom := -1
	for y in range(image.get_height() - 1, -1, -1):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.01:
				bottom = y
				break
		if bottom >= 0:
			break
	if bottom < 0:
		return INF
	var foot_global := _anim.to_global(Vector2(0, float(bottom) + 1.0 - image.get_height() * 0.5))
	var surface_y := _player.global_position.y + _ground.visual_height_offset(_player.global_position)
	return foot_global.y - surface_y


func _run_cliff_order_probe() -> void:
	_set_diagnostic(true)
	var wall := _nearest_wall(Vector2i(18, 17))
	check("vertical cliff occluder fixture found", wall != null)
	if wall == null:
		return
	var high: Vector2i = wall.get_meta("raised_cell")
	print("[OBSERVE] wall-order wall=", wall.get_path(), " root=", wall.global_position, " offset=", wall.offset, " z=", wall.z_index, " relative=", wall.z_as_relative, " parent-sort=", wall.get_parent().y_sort_enabled, " player-sort=", _player.y_sort_enabled, " actor-z=", _player.z_index, " sprite-z=", _anim.z_index)
	var depths: Vector2i = wall.get_meta("face_depths", Vector2i.ZERO)
	var direction := Vector2i(1, 0) if depths.x > 0 else Vector2i(0, 1)
	var receiver := _ground.terrain_neighbor(high, direction)
	var high_world := _ground.cell_center_world(high)
	var receive_world := _ground.cell_center_world(receiver)
	var delta := receive_world - high_world
	var behind := high_world.lerp(receive_world, 0.72)
	var front := receive_world + delta.normalized() * 24.0
	var behind_pair := await _wall_visibility_pair(wall, behind, "behind")
	var front_pair := await _wall_visibility_pair(wall, front, "front")
	check("foreground wall occludes lower actor behind its contact line",
		int(behind_pair.observed) < int(behind_pair.reference), str(behind_pair))
	check("lower actor in front of wall is not covered",
		int(front_pair.observed) == int(front_pair.reference), str(front_pair))
	observations.append({
		"kind": "vertical_wall_order",
		"raised_cell": [high.x, high.y],
		"receiver_cell": [receiver.x, receiver.y],
		"behind": behind_pair,
		"front": front_pair,
		"diagnostic_actor": true,
	})


func _nearest_wall(cell: Vector2i) -> Sprite2D:
	var best: Sprite2D
	var best_distance := INF
	for node in _all_nodes(_scene):
		if not node is Sprite2D or not node.has_meta("raised_cell"):
			continue
		var raised: Vector2i = node.get_meta("raised_cell")
		var distance := _ground.cell_center_world(raised).distance_to(_ground.cell_center_world(cell))
		if distance < best_distance:
			best = node as Sprite2D
			best_distance = distance
	return best


func _wall_visibility_pair(wall: Sprite2D, body_position: Vector2, label: String) -> Dictionary:
	_player.release_move_and_path()
	# Static occlusion probes intersect the ledge; freeze physics for this A/B only.
	# Otherwise collision pushes the actor in front between the two screenshots.
	_player.set_physics_process(false)
	_player.global_position = body_position
	await process_frames(2)
	_sync_mask()
	wall.visible = false
	var reference := await _capture("diagnostic-cliff-%s-reference.png" % label, {
		"kind": "injected_actor_mask_wall_hidden_reference",
		"probe": label,
		"diagnostic_actor": true,
	})
	wall.visible = true
	var observed := await _capture("diagnostic-cliff-%s-observed.png" % label, {
		"kind": "injected_actor_mask_wall_visible",
		"probe": label,
		"diagnostic_actor": true,
	})
	check("static wall probe retains disclosed position", _player.global_position.is_equal_approx(body_position))
	_player.set_physics_process(true)
	return {
		"body": [body_position.x, body_position.y],
		"reference": int(reference.mask_pixels),
		"observed": int(observed.mask_pixels),
	}


func _mixed_corner_probes() -> void:
	# Synthetic corner topology, not historical save/play. Original height dictionaries
	# are restored before auxiliary/progression probes; all other terrain ink is hidden
	# only while comparing a single split face's real canvas-pixel occlusion.
	var old_elevation := _ground.elevation.duplicate()
	var old_hills := _ground.hill_cells.duplicate()
	var old_ramps := _ground.ramp_cells.duplicate()
	_set_diagnostic(true)
	for row in [20, 21]:
		_ground.elevation = old_elevation.duplicate()
		_ground.hill_cells = old_hills.duplicate()
		_ground.ramp_cells = old_ramps.duplicate()
		var cell := Vector2i(14, row)
		var se := _ground.terrain_neighbor(cell, Vector2i(1,0))
		var sw := _ground.terrain_neighbor(cell, Vector2i(0,1))
		for c in [cell,se,sw]: _ground.ramp_cells.erase(c)
		_ground.elevation[cell] = 2
		_ground.hill_cells[cell] = 2
		_ground.elevation[se] = 1
		_ground.hill_cells[se] = 1
		_ground.elevation.erase(sw)
		_ground.hill_cells.erase(sw)
		_ground._build_elevation()
		await process_frames(2)
		var roles := _terrain_role_sprites()
		var visibility := _set_visible(roles, false)
		var faces: Array[Sprite2D] = []
		for role in roles:
			if role is Sprite2D and role.get_meta("raised_cell", Vector2i(-1,-1)) == cell:
				faces.append(role)
		check("mixed receiver corner has two separately sorted faces row%d" % row, faces.size()==2)
		for face in faces:
			var depths: Vector2i = face.get_meta("face_depths")
			var receiver: Vector2i = face.get_meta("receiver_cell")
			var high_pos := _ground.cell_center_world(cell)
			var receive_pos := _ground.cell_center_world(receiver)
			var delta := receive_pos-high_pos
			var name := "mixed-row%d-%s" % [row,"se" if depths.x>0 else "sw"]
			check(name+" exact independent depth", depths==Vector2i(32,0) if receiver==se else depths==Vector2i(0,64),str(depths))
			var behind := await _wall_visibility_pair(face,high_pos.lerp(receive_pos,0.72),name+"-behind")
			var front := await _wall_visibility_pair(face,receive_pos+delta.normalized()*24.0,name+"-front")
			var upper := await _wall_visibility_pair(face,high_pos,name+"-upper")
			check(name+" occludes lower actor behind contact",int(behind.observed)<int(behind.reference),str(behind))
			check(name+" reveals lower actor in front",int(front.observed)==int(front.reference),str(front))
			check(name+" never buries upper actor standing on surface",int(upper.observed)==int(upper.reference),str(upper))
			face.visible=false
		_restore_visible(visibility)
	_ground.elevation = old_elevation
	_ground.hill_cells = old_hills
	_ground.ramp_cells = old_ramps
	_ground._build_elevation()
	await process_frames(2)
	_set_diagnostic(false)


func _record_auxiliary_contracts() -> void:
	_set_diagnostic(false)
	var ramp := Vector2i(18, 17)
	_player.global_position = _ground.cell_center_world(ramp)
	await process_frames(2)
	var highlight := _scene.get_node("TileHighlight") as TileHighlight
	highlight.show_cell(_ground.cell_center_world(ramp))
	var expected_surface_y := _player.global_position.y + _ground.visual_height_offset(_player.global_position)
	check("highlight lies on sampled visible surface", absf(highlight.global_position.y-expected_surface_y)<0.01,
		"actual=%.2f expected=%.2f" % [highlight.global_position.y,expected_surface_y])
	var shadow_nodes := _player.find_children("*Shadow*", "", true, false)
	if not OS.get_environment("FDN_SCENE").is_empty():
		check("separate shadow is present for body-only atlas",shadow_nodes.size()==1)
		if shadow_nodes.size()==1:
			var shadow: Node2D=shadow_nodes[0]
			var polygon: PackedVector2Array=shadow.surface_polygon()
			var samples: Array[Vector2]=[Vector2(-20,0),Vector2(-10,-4),Vector2(10,-4),Vector2(20,0),Vector2(12,4),Vector2(-12,4)]
			var aligned:=polygon.size()==samples.size()
			for i in range(mini(polygon.size(),samples.size())):
				var logical:=_player.global_position+samples[i]
				aligned=aligned and shadow.to_global(polygon[i]).distance_to(logical+Vector2(0,_ground.visual_height_offset(logical)))<0.01
			check("shadow conforms to ramp surface at every contact vertex",aligned)
	var auxiliary := {
		"kind": "auxiliary_alignment",
		"ramp": [ramp.x, ramp.y],
		"body_y": _player.global_position.y,
		"actor_visual_offset": _ground.visual_height_offset(_player.global_position),
		"expected_surface_y": expected_surface_y,
		"production_highlight_y": highlight.global_position.y,
		"highlight_gap": highlight.global_position.y - expected_surface_y,
		"player_shadow_node_count": shadow_nodes.size(),
		"note": "Numerical projection gate, not art acceptance. Baseline uses baked shadow; candidate body-only atlas and separate surface shadow are disclosed.",
	}
	observations.append(auxiliary)
	print("[OBSERVE] auxiliary alignment ", JSON.stringify(auxiliary))
	await _capture("gameplay-ramp-highlight-unresolved.png", {
		"kind": "gameplay_auxiliary_alignment_observation",
		"diagnostic_actor": false,
		"note": auxiliary.note,
	})
	highlight.hide_highlight()


func _terrain_role_sprites() -> Array[CanvasItem]:
	var result: Array[CanvasItem] = []
	for node in _all_nodes(_scene):
		if node is CanvasItem and (node.has_meta("ramp_surface") or node.has_meta("raised_cell")):
			result.append(node as CanvasItem)
	return result


func _all_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	for child in root.get_children():
		result.append_array(_all_nodes(child))
	return result


func _set_visible(nodes: Array[CanvasItem], value: bool) -> Dictionary:
	var prior := {}
	for node in nodes:
		prior[node] = node.visible
		node.visible = value
	return prior


func _restore_visible(prior: Dictionary) -> void:
	for node in prior:
		if is_instance_valid(node):
			(node as CanvasItem).visible = bool(prior[node])


func _capture(filename: String, metadata: Dictionary) -> Dictionary:
	# Already-rendered physics samples must not advance another frame before capture.
	if not metadata.has("frame"):
		await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var size := image.get_size() if image != null else Vector2i.ZERO
	check("capture viewport is 1600x900", size == EXPECTED_VIEWPORT, str(size))
	var path := _out_dir.path_join(filename)
	var error := ERR_CANT_CREATE if image == null else image.save_png(path)
	check("capture saved %s" % filename, error == OK, "err=%d" % error)
	var record := metadata.duplicate(true)
	record["path"] = path
	record["image_size"] = [size.x, size.y]
	record["mask_pixels"] = _count_mask_pixels(image)
	record["player_body"] = [_player.global_position.x, _player.global_position.y]
	record["player_cell"] = [
		_ground.world_to_cell(_player.global_position).x,
		_ground.world_to_cell(_player.global_position).y,
	]
	observations.append(record)
	print("RAMP_OCCLUSION_CAPTURE ", JSON.stringify(record))
	return record


func _count_mask_pixels(image: Image) -> int:
	if image == null:
		return 0
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.r > 0.80 and color.b > 0.80 and color.g < 0.20 and color.a > 0.50:
				count += 1
	return count


func _write_manifest() -> void:
	var manifest := {
		"harness": "ramp_occlusion_red",
		"resolved_scene_path": _scene.scene_file_path,
		"FDN_SCENE": OS.get_environment("FDN_SCENE"),
		"capture_kind": "real StartingGrove root plus explicitly injected diagnostic actor-mask frames",
		"expected_viewport": [EXPECTED_VIEWPORT.x, EXPECTED_VIEWPORT.y],
		"source_contract": {
			"logical_player_body_remains_flat_in_L1": true,
			"only_AnimatedSprite2D_receives_visual_height_offset": true,
			"no_double_lift_allowed": true,
		},
		"injections": [
			"new isolated save",
			"G2 BushDry.bloom() setup for odd-row ramp access",
			"endpoint teleports before each traversal",
			"explicit low->ramp->high / high->ramp->low Player waypoints",
			"magenta actor alpha mask and unrelated-prop hiding in diagnostic captures only",
			"DayNight CanvasModulate forced white for stable pixel classification",
			"wall-only static probes disable Player physics to prevent depenetration between A/B images",
		],
		"checks": checks,
		"failures": failures,
		"observations": observations,
	}
	var path := _out_dir.path_join("manifest.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		check("manifest opened", false, path)
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	var error := file.get_error()
	file.close()
	check("manifest written", error == OK, "err=%d" % error)


func process_frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func physics_frames(count: int) -> void:
	for _i in range(count):
		await get_tree().physics_frame
