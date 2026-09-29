extends RefCounted
## MAP1-v2 only. A recessed, rock-lined cut below the unchanged V collision plane.
## Four banks share actual TileSet edge endpoints. No grass cap or tile replacement.
const ROCK = preload("res://assets/tiles/grove_rock_field.png")
const SIDES = [TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE]

static func classify(map: MapLoader) -> Dictionary:
	var cells := {}
	# Authored v2 NightGate/bush bands only, not the perimeter nor runtime hollows.
	for row in [8,14]:
		for col in range(map.width):
			var cell := Vector2i(col,row)
			if map._sym_at(cell)!="V":continue
			var back := false;var front := false
			for side in SIDES.slice(0,2): back = back or map._is_island_cell(map.get_neighbor_cell(cell,side))
			for side in SIDES.slice(2,4): front = front or map._is_island_cell(map.get_neighbor_cell(cell,side))
			if back and front: cells[cell]=true
	return cells

static func build(map: MapLoader, cells: Dictionary) -> Node2D:
	var root := Node2D.new()
	root.name="InternalTrenches"
	root.z_index=2
	root.z_as_relative=false
	map.add_child(root)
	var field: Image=ROCK.get_image()
	for cell: Vector2i in cells:
		var center:=map.map_to_local(cell)
		var origin:=Vector2i(center+Vector2(-64,-72))
		var image:=Image.create(128,136,false,Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		# Narrower floor + four sloping banks: never a flat, walkable-looking top.
		var corners: Array[Vector2] = [Vector2(-64,0),Vector2(0,-32),Vector2(64,0),Vector2(0,32)]
		var floor_points:=PackedVector2Array()
		for corner: Vector2 in corners:floor_points.append(center+corner*0.66+Vector2(0,4))
		paint(image,origin,floor_points,field,0.62,false)
		var edges:Array=[]
		for index in range(4):
			var neighbor:=map.get_neighbor_cell(cell,SIDES[index])
			var a:=center+corners[index]
			var b:=center+corners[(index+1)%4]
			# Opposite/back faces and exposed end returns use the same actual
			# endpoint heights as the adjoining bank, including the lower-left end.
			var land:=map._is_island_cell(neighbor)
			var level_a:float=map.surface_level_at(neighbor,a) if land else 0.0
			var level_b:float=map.surface_level_at(neighbor,b) if land else 0.0
			var top_a:=a+Vector2(0,-MapLoader.HILL_LIFT*level_a)
			var top_b:=b+Vector2(0,-MapLoader.HILL_LIFT*level_b)
			var polygon:=PackedVector2Array([top_a,top_b,floor_points[(index+1)%4],floor_points[index]])
			paint(image,origin,polygon,field,0.84 if index<2 else 0.70,true)
			edges.append({"neighbor":neighbor,"a":top_a,"b":top_b,"bank":land,"end_return":not land})
		# At a low/high bank junction, the two owners project the SAME logical
		# corner to different heights. Close that vertical return explicitly;
		# joining both to the inset floor alone leaves a triangular opening.
		for index in range(4):
			var previous:Dictionary=edges[posmod(index-1,4)]
			var current:Dictionary=edges[index]
			if previous.b.distance_to(current.a)>0.01:
				paint(image,origin,PackedVector2Array([previous.b,current.a,floor_points[index]]),field,0.76,false)
		var sprite:=Sprite2D.new()
		sprite.name="Cut_%d_%d"%[cell.x,cell.y]
		sprite.centered=false
		sprite.position=Vector2(origin)
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture=ImageTexture.create_from_image(image)
		sprite.set_meta("trench_cell",cell)
		sprite.set_meta("bank_edges",edges)
		sprite.set_meta("render_role","recessed_nonwalkable_trench")
		root.add_child(sprite)
	return root

static func paint(image: Image, origin: Vector2i, polygon: PackedVector2Array, field: Image, shade: float, bank: bool) -> void:
	for y in range(0,image.get_height(),2):
		for x in range(0,image.get_width(),2):
			var point:=Vector2(origin)+Vector2(x+1,y+1)
			if not Geometry2D.is_point_in_polygon(point,polygon):continue
			var color:=field.get_pixel(posmod(origin.x+x,field.get_width()),posmod(origin.y+y,field.get_height()))
			color=Color(color.r*shade,color.g*shade,color.b*shade,1)
			if bank:
				var edge_distance:=Geometry2D.get_closest_point_to_segment(point,polygon[0],polygon[1]).distance_to(point)
				if edge_distance<2:color=Color8(91,96,64)
				elif edge_distance<5:color=Color8(98,83,60)
				elif edge_distance<8:color=Color8(72,63,47)
			image.fill_rect(Rect2i(x,y,2,2),color)
