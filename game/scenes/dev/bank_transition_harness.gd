extends Node
## Continuous authored bank surface must follow actual TileMap topology/state.
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
var failures := 0
func check(label: String, ok: bool, detail := "") -> void:
	print("[%s] %s %s" % ["PASS" if ok else "FAIL",label,detail])
	if not ok: failures += 1
func _ready() -> void:
	if not GUARD.require_isolated_user_data("bank_transition"):
		get_tree().quit(86)
		return
	SaveManager.new_game()
	var scene: Node = load("res://scenes/world/starting_grove.tscn").instantiate()
	add_child(scene)
	for i in range(8): await get_tree().process_frame
	var ground: MapLoader = scene.get_node("Ground")
	var report: Array = []
	for y in range(32,40):
		for x in range(8,15):
			var cell := Vector2i(x,y)
			report.append({"cell":[x,y],"center":[ground.map_to_local(cell).x,ground.map_to_local(cell).y],"source":ground.get_cell_source_id(cell),"height":ground.height_at(cell)})
	var evidence := OS.get_environment("BANK_EVIDENCE")
	if evidence.begins_with(ProjectSettings.globalize_path("res://../evidence/07-bank-transition/").simplify_path()):
		var f := FileAccess.open(evidence.path_join("actual-topology.json"),FileAccess.WRITE)
		if f != null: f.store_string(JSON.stringify(report,"\t"));f.close()
	var art: Node2D = ground.get_node_or_null("BankTransition")
	check("representative continuous bank replaces tiled scallops",art!=null)
	if art != null:
		check("bank below objects and above edge tiles",art.z_index==2 and art.z_index<ground.YSORT_Z)
		var ink := 0
		var outside := 0
		var bank_cells: Dictionary = {}
		var grass_mismatch := 0
		var field: Image=load("res://assets/tiles/grove_bank_transition.png").get_image()
		for sprite in art.get_children():
			if not sprite is Sprite2D: continue
			var cell: Vector2i = sprite.get_meta("bank_cell")
			bank_cells[cell]=true
			var image: Image=sprite.texture.get_image()
			var source:=ground.get_cell_source_id(cell)
			var grass_source:=source if source in [2,3,4,5] else 2
			var base: Image=(ground.tile_set.get_source(grass_source) as TileSetAtlasSource).texture.get_image()
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					if image.get_pixel(x,y).a==0: continue
					ink+=1
					var local: Vector2=sprite.position+Vector2(x+0.5,y+0.5)
					var actual:=ground.local_to_map(local)
					if actual!=cell or ground.get_cell_source_id(actual) not in [1,2,3,4,5] or ground.height_at(actual)!=0: outside+=1
					var uv:=Vector2i(sprite.position)+Vector2i(x,y)-Vector2i(1216,1056)
					if field.get_pixelv(uv)==Color8(102,120,91) and base.get_pixel(x,y).a>0 and image.get_pixel(x,y)!=base.get_pixel(x,y): grass_mismatch+=1
		check("grass margin preserves live tile palette and exact pixel clusters",grass_mismatch==0,str(grass_mismatch))
		check("authored ink covers a whole representative landform",ink>20000,"pixels=%d"%ink)
		check("every visible pixel belongs to real low land, no fake water",outside==0,"outside=%d"%outside)
		check("both original bank endpoint cells represented",bank_cells.has(Vector2i(11,35)) and bank_cells.has(Vector2i(10,38)))
		var cell:=Vector2i(11,36)
		var source:=ground.get_cell_source_id(cell)
		ground.set_cell(cell,11,Vector2i.ZERO)
		for i in range(6): await get_tree().process_frame
		var hides_hollow:=true
		for sprite in art.get_children():
			if sprite.get_meta("bank_cell",Vector2i(-1,-1))==cell: hides_hollow=false
		check("bestowed hollow removes authored land art",hides_hollow)
		ground.set_cell(cell,source,Vector2i.ZERO)
		for i in range(6): await get_tree().process_frame
		var restored:=0
		for sprite in art.get_children():
			if sprite.get_meta("bank_cell",Vector2i(-1,-1))==cell: restored+=1
		check("restored ground draws exactly once",restored==1,str(restored))
		# Both STACKED row parities, two non-land source types, direct mutation.
		for target in [Vector2i(11,35),Vector2i(11,36)]:
			var original:=ground.get_cell_source_id(target)
			for replacement in [8,11]:
				ground.set_cell(target,replacement,Vector2i.ZERO)
				for i in range(6): await get_tree().process_frame
				var count:=0
				for sprite in art.get_children():
					if sprite.get_meta("bank_cell",Vector2i(-1,-1))==target: count+=1
				check("parity %d source%d has no cosmetic land"%[target.y%2,replacement],count==0)
				ground.set_cell(target,original,Vector2i.ZERO)
				for i in range(6): await get_tree().process_frame
				count=0
				for sprite in art.get_children():
					if sprite.get_meta("bank_cell",Vector2i(-1,-1))==target: count+=1
				check("parity %d restore after source%d is unique"%[target.y%2,replacement],count==1)
	SaveManager.unregister_world()
	scene.queue_free()
	await get_tree().process_frame
	print("BANK_RESULT failures=%d"%failures)
	get_tree().quit(1 if failures else 0)
