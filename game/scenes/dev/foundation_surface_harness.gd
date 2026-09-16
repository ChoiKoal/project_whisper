extends Node
## Terrain-only regression for owner-rejected FDN11 ramp. Actual StartingGrove/root viewport.
## Injected camera/position/white light, hidden props, per-face ink; NOT normal play/art.
## Oracle projects the logical diamond through the declared continuous height plane;
## it never uses a prior screenshot or the production sprite alpha as its expected shape.
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
const CASES = [Vector2i(18,17), Vector2i(18,22), Vector2i(19,22)]
const DIRECTIONS = [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]
var scene: Node
var ground: MapLoader
var player: Player
var camera: Camera2D
var failures := 0
var checks := 0
var records: Array = []
var output: String
var hidden_nodes: Dictionary = {}
func check(label: String, ok: bool, detail := "") -> void:
	checks += 1
	if not ok: failures += 1
	print("[%s] %s %s" % ["PASS" if ok else "FAIL",label,detail])
func frames(n := 3) -> void:
	for i in range(n): await get_tree().process_frame
	var receipt:=[false]
	var done:=func():receipt[0]=true
	RenderingServer.frame_post_draw.connect(done,CONNECT_ONE_SHOT)
	var deadline:=Time.get_ticks_msec()+2000
	while not receipt[0] and Time.get_ticks_msec()<deadline:await get_tree().process_frame
	if not receipt[0]:
		RenderingServer.force_draw()
		deadline=Time.get_ticks_msec()+1000
		while not receipt[0] and Time.get_ticks_msec()<deadline:await get_tree().process_frame
	if RenderingServer.frame_post_draw.is_connected(done):RenderingServer.frame_post_draw.disconnect(done)
	if not receipt[0]:
		check("bounded render receipt",false)
		get_tree().quit(89)
func _ready() -> void:
	if not GUARD.require_isolated_user_data("foundation_surface"):
		get_tree().quit(86)
		return
	output=OS.get_environment("FDN_EVIDENCE")
	call_deferred("run")
func ramp_spec(cell: Vector2i) -> Dictionary:
	var low := 99
	var high := -1
	var high_delta := Vector2.ZERO
	for direction in DIRECTIONS:
		var nb := ground.terrain_neighbor(cell,direction)
		var level := ground.height_at(nb)
		low=mini(low,level)
		if level>high:
			high=level
			high_delta=ground.map_to_local(nb)-ground.map_to_local(cell)
	return {"low":low,"high":high,"sx":signf(high_delta.x),"sy":signf(high_delta.y)}
func projected(cell: Vector2i, point: Vector2, spec: Dictionary) -> Vector2:
	var t: float=0.5+0.5*(spec.sx*point.x/64.0+spec.sy*point.y/32.0)
	return ground.map_to_local(cell)+point+Vector2(0,-32.0*lerpf(spec.low,spec.high,t))
func polygon(cell: Vector2i, spec: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in [Vector2(0,-32),Vector2(64,0),Vector2(0,32),Vector2(-64,0)]:
		out.append(projected(cell,point,spec))
	return out
func ramp_node(cell: Vector2i) -> Sprite2D:
	for node in ground.find_children("*","Sprite2D",true,false):
		if node.get_meta("ramp_surface",Vector2i(-1,-1))==cell: return node
	return null
func shot(name: String) -> Image:
	await frames()
	var image := get_viewport().get_texture().get_image()
	check("capture written "+name,image.save_png(output.path_join(name+".png"))==OK)
	return image
func hide_clutter() -> void:
	for node in scene.get_node("YSortLayer").get_children():
		if node is CanvasItem and not node.has_meta("raised_cell"):
			hidden_nodes[node]=node.visible
			node.hide()
	for path in ["HUD","GlowLayer","TileHighlight","TileGlow"]:
		var node=scene.get_node_or_null(path)
		if node is CanvasItem or node is CanvasLayer:
			hidden_nodes[node]=node.visible
			node.hide()
func restore_clutter() -> void:
	for node in hidden_nodes:
		if is_instance_valid(node): node.visible=hidden_nodes[node]
	hidden_nodes.clear()
func scan(image: Image, cell: Vector2i, spec: Dictionary) -> Dictionary:
	var shape := polygon(cell,spec)
	var center := ground.map_to_local(cell)
	var rect := Rect2(shape[0],Vector2.ZERO)
	for point in shape: rect=rect.expand(point)
	var transform := ground.get_global_transform_with_canvas()
	var expected := 0
	var visible := 0
	var near_low := 0
	var near_high := 0
	var missed_low := 0
	var missed_high := 0
	var legitimate_cover := 0
	var erroneous_foreground := 0
	var edge_uncertain := 0
	for y in range(int(rect.position.y),int(rect.end.y)+1):
		for x in range(int(rect.position.x),int(rect.end.x)+1):
			var q := Vector2(x+0.5,y+0.5)
			var inside := true
			# Ignore only the 3px rasterization fringe, not the ramp ends/interior.
			for off in [Vector2.ZERO,Vector2(3,0),Vector2(-3,0),Vector2(0,3),Vector2(0,-3)]:
				inside=inside and Geometry2D.is_point_in_polygon(q+off,shape)
			if not inside: continue
			var span: float=spec.high-spec.low
			var dx := q.x-center.x
			var logical_dy: float=(q.y-center.y+32.0*spec.low+16.0*span*(1.0+spec.sx*dx/64.0))/(1.0-0.5*span*spec.sy)
			var t: float=0.5+0.5*(spec.sx*dx/64.0+spec.sy*logical_dy/32.0)
			var logical_y := center.y+logical_dy
			# Independent ray-depth oracle: legitimate foreground tops may occlude,
			# but a ramp cell has ONE surface and must not own a duplicate flat top.
			var covered := false
			var boundary := false
			for other in ground.hill_cells:
				if ground.is_ramp(other): continue
				var flat_center := ground.map_to_local(other)
				var flat_delta := q-flat_center+Vector2(0,32*ground.height_at(other))
				var diamond := absf(flat_delta.x)/64.0+absf(flat_delta.y)/32.0
				if flat_center.y+flat_delta.y>logical_y+0.1:
					# Tile art is a 2px staircase. The geometric boundary has a
					# 3px uncertainty band, not an occlusion exemption for its interior.
					if absf(diamond-1.0)<0.094: boundary=true
					if diamond<1.0: covered=true
			if boundary:
				edge_uncertain+=1
				continue
			var pixel := Vector2i(transform*q)
			if not Rect2i(Vector2i.ZERO,image.get_size()).has_point(pixel): continue
			var color := image.get_pixelv(pixel)
			var magenta := color.r>0.8 and color.b>0.8 and color.g<0.15
			if covered:
				legitimate_cover+=1
				if magenta: erroneous_foreground+=1
				continue
			expected+=1
			if magenta: visible+=1
			if t<0.25:
				near_low+=1
				if not magenta: missed_low+=1
			if t>0.75:
				near_high+=1
				if not magenta: missed_high+=1
	return {"expected":expected,"visible":visible,"low_samples":near_low,"high_samples":near_high,"missed_low":missed_low,"missed_high":missed_high,"legitimate_cover":legitimate_cover,"erroneous_foreground":erroneous_foreground,"edge_uncertain":edge_uncertain}
func run() -> void:
	SaveManager.new_game()
	if OS.get_environment("FDN_LAYOUT_REVISION")=="l1-v2":SaveManager.new_game_for_layout("l1-v2")
	WorldContext.arrival_mode=""
	scene=load("res://scenes/world/starting_grove.tscn").instantiate()
	add_child(scene)
	await frames(12)
	ground=scene.get_node("Ground")
	player=scene.get_node("YSortLayer/Player")
	camera=player.get_node("Camera2D")
	camera.position_smoothing_enabled=false
	camera.zoom=Vector2.ONE
	GameState.time_running=false
	scene.get_node("DayNight").color=Color.WHITE
	var owner_cells: Dictionary={}
	for node in ground.find_children("*","Sprite2D",true,false):
		if node.has_meta("surface_cell"):
			var owned: Vector2i=node.get_meta("surface_cell")
			owner_cells[owned]=int(owner_cells.get(owned,0))+1
	var owners_exact := true
	var expected_cells := ground.hill_cells.duplicate()
	expected_cells.merge(ground.ramp_cells,true)
	for owned in expected_cells: owners_exact=owners_exact and int(owner_cells.get(owned,0))==1
	check("complete surface ownership bijection",owners_exact and owner_cells.size()==expected_cells.size())
	var required:Array=CASES
	if ground.layout_revision=="l1-v2":
		required=[]
		for row in range(16,23):required.append(Vector2i(11+row/2,row))
	for cell in required: check("required ramp exists %s"%cell,ground.is_ramp(cell))
	var cases := ground.ramp_cells.keys()
	cases.sort()
	for cell in cases:
		var sprite := ramp_node(cell)
		check("ramp sprite exists %s"%cell,sprite!=null)
		if sprite==null: continue
		player.global_position=ground.cell_center_world(cell)
		camera.reset_smoothing()
		await shot("%d-%d-actor"%[cell.x,cell.y])
		player.hide()
		await shot("%d-%d-actor-hidden"%[cell.x,cell.y])
		player.show()
		hide_clutter()
		await shot("%d-%d-terrain"%[cell.x,cell.y])
		var duplicate := false
		var owners := 0
		for node in ground.find_children("*","Sprite2D",true,false):
			if node.get_meta("surface_cell",Vector2i(-1,-1))==cell: owners+=1
		check("exactly one top owner %s"%cell,owners==1,str(owners))
		for layer in ground._elev_layers:
			if is_instance_valid(layer) and layer.get_cell_source_id(cell)>=0: duplicate=true
		check("one ramp surface no same-cell flat top %s"%cell,not duplicate)
		var texture := sprite.texture
		var ink := texture.get_image().duplicate() as Image
		for y in range(ink.get_height()):
			for x in range(ink.get_width()):
				if ink.get_pixel(x,y).a>0.5: ink.set_pixel(x,y,Color.MAGENTA)
		sprite.texture=ImageTexture.create_from_image(ink)
		var spec := ramp_spec(cell)
		check_ramp_edges(cell,spec,sprite)
		var image := await shot("%d-%d-face-id"%[cell.x,cell.y])
		var result := scan(image,cell,spec)
		check("topological ramp full interior visible %s"%cell,result.expected>100 and result.visible>=result.expected-8,str(result))
		check("no ramp paints over physically foreground tops %s"%cell,result.erroneous_foreground<=8,str(result))
		check("both visible ramp end bands agree with geometry %s"%cell,result.missed_low<=4 and result.missed_high<=4,str(result))
		var overlay := ground.get_node("Elevation")
		var old_index := overlay.get_index()
		ground.move_child(overlay,ground.get_child_count()-1)
		var reordered_image := await shot("%d-%d-reordered"%[cell.x,cell.y])
		var reordered := scan(reordered_image,cell,spec)
		check("surface result independent of subtree insertion %s"%cell,result==reordered,str(reordered))
		check("exact face mask unchanged by reorder %s"%cell,mask_bytes(image)==mask_bytes(reordered_image))
		ground.move_child(overlay,old_index)
		var surfaces := sprite.get_parent()
		var children := surfaces.get_children()
		for child in children: surfaces.move_child(child,0)
		var reversed_image := await shot("%d-%d-reverse-children"%[cell.x,cell.y])
		check("exact mask independent of surface child insertion %s"%cell,mask_bytes(image)==mask_bytes(reversed_image))
		for child in children: surfaces.move_child(child,surfaces.get_child_count()-1)
		camera.offset=Vector2(64,32)
		var moved_image := await shot("%d-%d-camera-shift"%[cell.x,cell.y])
		check("oracle coverage invariant under camera shift %s"%cell,scan(moved_image,cell,spec)==result)
		camera.offset=Vector2.ZERO
		records.append({"cell":str(cell),"spec":spec,"normal_order":result,"reordered":reordered,"duplicate":duplicate,"ramp_z":sprite.z_index,"relative":sprite.z_as_relative,"parent":str(sprite.get_parent().get_path()),"origin":str(sprite.position),"projected_corners":str(polygon(cell,spec))})
		sprite.texture=texture
		restore_clutter()
	await synthetic_raster_contracts()
	check("all live ramps enumerated",records.size()==ground.ramp_cells.size())
	var report := {"checks":checks,"failures":failures,"provenance":"injected engineering root; white light, fixture position, hidden props; terrain walls RETAINED for face-ID", "records":records}
	var file := FileAccess.open(output.path_join("surface-manifest.json"),FileAccess.WRITE)
	if file==null:
		get_tree().quit(87)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	check("manifest readback",FileAccess.get_file_as_string(output.path_join("surface-manifest.json"))==JSON.stringify(report,"	"))
	SaveManager.unregister_world()
	scene.queue_free()
	await frames()
	print("SURFACE_DONE failures=%d checks=%d"%[failures,checks])
	get_tree().quit(1 if failures else 0)

func mask_bytes(image: Image) -> PackedByteArray:
	var bytes := PackedByteArray()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x,y)
			bytes.append(1 if color.r>0.8 and color.b>0.8 and color.g<0.15 else 0)
	return bytes

func check_ramp_edges(cell: Vector2i, spec: Dictionary, sprite: Sprite2D) -> void:
	var corners := [Vector2(0,-32),Vector2(64,0),Vector2(0,32),Vector2(-64,0)]
	var edges := [[1,2],[3,0],[2,3],[0,1]]
	var connected := 0
	for i in range(DIRECTIONS.size()):
		var d: Vector2i=DIRECTIONS[i]
		var nb:=ground.terrain_neighbor(cell,d)
		var delta:=ground.map_to_local(nb)-ground.map_to_local(cell)
		if signf(delta.x)!=spec.sx or signf(delta.y)!=spec.sy:
			if signf(delta.x)!=-spec.sx or signf(delta.y)!=-spec.sy: continue
		var aligned := true
		var raster_connected := true
		for index in edges[i]:
			var p: Vector2=corners[index]
			var shared:=ground.map_to_local(cell)+p
			var neighbour_edge:=shared+Vector2(0,-32*ground.height_at(nb))
			var ramp_edge:=projected(cell,p,spec)
			aligned=aligned and neighbour_edge.distance_to(ramp_edge)<0.01
		for step in range(1,16):
			var p: Vector2=corners[edges[i][0]].lerp(corners[edges[i][1]],float(step)/16.0)
			var q:=sprite.to_local(ground.to_global(projected(cell,p,spec)))-sprite.offset
			raster_connected=raster_connected and ink_near(sprite.texture.get_image(),q,2)
		check("shared high/low edge endpoints coincide %s -> %s"%[cell,nb],aligned)
		check("full shared edge has raster ink within 2px %s -> %s"%[cell,nb],raster_connected)
		connected+=1
	check("two authoritative end edges tested %s"%cell,connected==2)

func ink_near(image: Image, point: Vector2, radius: int) -> bool:
	for y in range(int(point.y)-radius,int(point.y)+radius+1):
		for x in range(int(point.x)-radius,int(point.x)+radius+1):
			if x>=0 and y>=0 and x<image.get_width() and y<image.get_height() and image.get_pixel(x,y).a>0.5: return true
	return false

func synthetic_raster_contracts() -> void:
	# Explicit isolated geometry fixtures: all directions/height steps; no save/map edits.
	for dir in ["ne","nw","se","sw"]:
		for low in [0,1]:
			var spec: Dictionary={"low":low,"high":low+1,"sx":1.0 if dir in ["ne","se"] else -1.0,"sy":1.0 if dir in ["se","sw"] else -1.0}
			var image: Image=ground.GROVE_SURFACE_ART.ramp(dir,low,low+1)
			var cell:=Vector2i(18,17+low)
			var shape:=polygon(cell,spec)
			var origin:=ground.map_to_local(cell)+Vector2(-64,-32-32*(low+1))
			var missing := 0
			var excess := 0
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					var q:=origin+Vector2(x+0.5,y+0.5)
					var inside:=Geometry2D.is_point_in_polygon(q,shape)
					var boundary:=false
					for i in range(4):
						boundary=boundary or Geometry2D.get_closest_point_to_segment(q,shape[i],shape[(i+1)%4]).distance_to(q)<=2.5
					if boundary: continue
					if inside and image.get_pixel(x,y).a<0.5: missing+=1
					if not inside and image.get_pixel(x,y).a>0.5: excess+=1
			check("all-direction/parity raster covers only authoritative plane %s h%d"%[dir,low],missing==0 and excess==0,"missing=%d excess=%d"%[missing,excess])
