extends Node
## Scoped shoreline tree grounding: artwork children, never physics/save identity.
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
const SIDES = [TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE]
var failures := 0
func check(label: String, ok: bool, detail := "") -> void:
	print("[%s] %s %s" % ["PASS" if ok else "FAIL",label,detail])
	if not ok: failures+=1
func _ready() -> void:
	if not GUARD.require_isolated_user_data("shoreline_roots"):
		get_tree().quit(86)
		return
	call_deferred("run")
func run() -> void:
	SaveManager.new_game()
	WorldContext.arrival_mode=""
	var scene: Node=load("res://scenes/world/starting_grove.tscn").instantiate()
	add_child(scene)
	for i in range(12): await get_tree().process_frame
	GameState.time_running=false
	var ground: MapLoader=scene.get_node("Ground")
	var respawn: ObjectRespawn=scene.get_node("ObjectRespawn")
	var expected := 0
	var decorated := 0
	var decorated_cells: Array[Vector2i] = []
	var fixture := {}
	for entry in respawn._tracked:
		var node: Gatherable=entry.node
		if not is_instance_valid(node): continue
		var shore := false
		if entry.symbol=="T" and ground.height_at(entry.cell)==0:
			for side in SIDES:
				if ground.get_cell_source_id(ground.get_neighbor_cell(entry.cell,side)) in [8,9]: shore=true
		var root:=node.get_node_or_null("RootContact") as Sprite2D
		var tips:=node.get_node_or_null("RootOcclusion") as Sprite2D
		if shore:
			expected+=1
			check("shore tree has contact and selective occlusion %s" % entry.cell,root!=null and tips!=null)
			if root==null or tips==null: continue
			decorated+=1
			decorated_cells.append(entry.cell)
			check("contact layers cannot change collision or target %s" % entry.cell,node.position.is_equal_approx(ground.map_to_local(entry.cell)) and node.item_id=="I4" and root.get_child_count()==0 and tips.get_child_count()==0)
			check("root is behind tree, tips in front at same origin",root.show_behind_parent and not tips.show_behind_parent and root.position==Vector2.ZERO and tips.position==Vector2.ZERO and root.z_index==0 and tips.z_index==0)
			for sprite in [root,tips]:
				var image: Image=sprite.texture.get_image()
				var outside:=0
				for y in range(image.get_height()):
					for x in range(image.get_width()):
						if image.get_pixel(x,y).a==0: continue
						var local := Vector2(x+0.5-image.get_width()*0.5,y+0.5-image.get_height()*0.5)
						if absf(local.x)/64.0+absf(local.y)/32.0>=1.0: outside+=1
				check("contact alpha never redraws neighbour water",outside==0)
			if fixture.is_empty(): fixture=entry
		else:
			check("nonshore or raised object not decorated %s" % entry.cell,root==null and tips==null)
	check("representative shoreline trees actually covered",expected>0 and decorated==expected,"expected=%d decorated=%d" % [expected,decorated])
	decorated_cells.sort()
	check("frozen representative shore tree cells, not a duplicated predicate",decorated_cells==[Vector2i(6,39),Vector2i(9,39)])
	if not fixture.is_empty():
		var old: Gatherable=fixture.node
		var contact: Node=old.get_node("RootContact")
		var tips: Node=old.get_node("RootOcclusion")
		var before:=Inventory.count("I4")
		old.gather()
		for i in range(3): await get_tree().process_frame
		check("actual gather grants wood and removes contact children",Inventory.count("I4")==before+1 and not is_instance_valid(contact) and not is_instance_valid(tips))
		fixture.node=null
		fixture.respawn_at=GameState.game_time+1.0
		GameState.set_game_time(fixture.respawn_at+1.0)
		respawn.force_tick()
		check("same-cell respawn rebuilds contact once",is_instance_valid(fixture.node) and fixture.node.get_node_or_null("RootContact")!=null and fixture.node.position.is_equal_approx(ground.map_to_local(fixture.cell)))
		var copies := {"RootContact":0,"RootOcclusion":0}
		for child in fixture.node.get_children():
			if child.name in copies: copies[child.name]+=1
		check("both root layers respawn exactly once",copies=={"RootContact":1,"RootOcclusion":1})
		# Contact is a spawn-time local soil impression, not a live water boundary.
		# Draining neighbouring water does not erase an existing root bed. A new tree
		# is re-evaluated against current terrain, so it need not carry shoreline art.
		var water_count := 0
		for side in SIDES:
			var water := ground.get_neighbor_cell(fixture.cell,side)
			if ground.get_cell_source_id(water) in [8,9]:
				water_count+=1
				ground.set_cell(water,11,Vector2i.ZERO)
		for i in range(3): await get_tree().process_frame
		check("water mutation preserves existing root bed and stable tree cell",water_count>0 and fixture.node.get_node_or_null("RootContact")!=null and fixture.node.position.is_equal_approx(ground.map_to_local(fixture.cell)))
		fixture.node.gather()
		for i in range(3): await get_tree().process_frame
		fixture.node=null
		fixture.respawn_at=GameState.game_time+1.0
		GameState.set_game_time(fixture.respawn_at+1.0)
		respawn.force_tick()
		check("nonshore respawn drops both purely decorative layers",is_instance_valid(fixture.node) and fixture.node.get_node_or_null("RootContact")==null and fixture.node.get_node_or_null("RootOcclusion")==null and fixture.node.item_id=="I4")
	SaveManager.unregister_world()
	scene.queue_free()
	await get_tree().process_frame
	print("SHORELINE_ROOTS_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
