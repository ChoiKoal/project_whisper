extends "res://scripts/world/map_loader.gd"
## FDN-01 isolated presentation candidate. Reuses the actual catalog, physics,
## recipes, saves and continuous logical-foot height sampler. Not approved art.
## Each vertical face has its own receiver and depth; surfaces never sort as walls.
var _foundation_walls: Array[Sprite2D] = []
const PLACED_SURFACE = preload("res://scripts/foundation/placed_surface.gd")
const LAYOUTS=preload("res://scripts/foundation/grove_layout.gd")
@export var required_layout_revision := ""

func _ready() -> void:
	layout_revision=SaveManager.grove_revision_for_build()
	var profile:=LAYOUTS.profile(layout_revision)
	if profile.is_empty() or (required_layout_revision!="" and required_layout_revision!=layout_revision):
		SaveManager._reject_layout("Grove profile unavailable or candidate/save mismatch")
		return
	layout_path_override=profile.layout
	height_path_override=profile.height
	legend_path_override=profile.legend
	topology_contract="grove_stacked"
	enable_scatter=layout_revision==LAYOUTS.LEGACY
	legacy_grove_bank=enable_scatter
	semantic_anchors=LAYOUTS.anchors(layout_revision)
	super._ready()
	if _ysort != null:
		_ysort.child_entered_tree.connect(_on_foundation_child)
		for child in _ysort.get_children(): _on_foundation_child(child)

func _on_foundation_child(child: Node) -> void:
	if child is PlacedObject:
		_attach_placed_surface.call_deferred(child)

func _classify_void_cells() -> void:
	if layout_revision==LAYOUTS.CANDIDATE:
		# V2 authored void is a gap, not an implicit 230px wall unrelated to height.
		ridge_cells.clear()
	else:super._classify_void_cells()

## Candidate broad ascent uses one continuous plane across connected ramp cells.
## Permit a crossing only when BOTH shared-edge endpoints coincide. Legacy stays frozen.
func surface_level_at(cell:Vector2i,point:Vector2)->float:
	if not is_ramp(cell):return float(height_at(cell))
	var low:=99;var high:=0
	for d in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
		var level:=height_at(terrain_neighbor(cell,d));low=mini(low,level);high=maxi(high,level)
	var dir:=_ramp_climb_dir(cell)
	var sx:=1.0 if dir in ["ne","se"] else -1.0
	var sy:=1.0 if dir in ["se","sw"] else -1.0
	var delta:=point-map_to_local(cell)
	return lerpf(low,high,clampf(0.5+0.5*(sx*delta.x/64.0+sy*delta.y/32.0),0,1))
func can_traverse(a:Vector2i,b:Vector2i)->bool:
	if layout_revision!=LAYOUTS.CANDIDATE or (not is_ramp(a) and not is_ramp(b)):return super.can_traverse(a,b)
	var delta:=map_to_local(b)-map_to_local(a)
	var midpoint:=map_to_local(a)+delta*0.5
	var tangent:=Vector2(delta.x,-delta.y)*0.5
	for point:Vector2 in [midpoint-tangent,midpoint+tangent]:
		if absf(surface_level_at(a,point)-surface_level_at(b,point))>0.001:return false
	return true
func visual_height_offset(world_position:Vector2)->float:
	if layout_revision!=LAYOUTS.CANDIDATE:return super.visual_height_offset(world_position)
	return -HILL_LIFT*surface_level_at(world_to_cell(world_position),to_local(world_position))

func _attach_placed_surface(child: Node) -> void:
	if not is_instance_valid(child) or child.is_queued_for_deletion() or child.has_node("FoundationSurface"): return
	var adapter := PLACED_SURFACE.new()
	adapter.name="FoundationSurface"
	adapter.map=self
	child.add_child(adapter)

func _build_elevation() -> void:
	clear_foundation_elevation()
	# One cell owns one top. Whole-height TileMaps cannot order a slope against
	# its neighbours and used to duplicate the flat top on the route-ramp cell.
	# Surface roots stay in the logical plane; height is ONLY texture displacement.
	# This common Y-sort domain orders all tops by world depth, not construction order.
	_cliff_face_overlay = Node2D.new()
	_cliff_face_overlay.name = "Elevation"
	add_child(_cliff_face_overlay)
	var surfaces := Node2D.new()
	surfaces.name = "Surfaces"
	surfaces.z_index = HILL_Z
	surfaces.z_as_relative = false
	surfaces.y_sort_enabled = true
	_cliff_face_overlay.add_child(surfaces)
	for cell in hill_cells:
		if is_ramp(cell): continue
		var source := get_cell_source_id(cell)
		if layout_revision!=LAYOUTS.CANDIDATE and (source < 2 or source > 5): source = _variant_source(cell.x,cell.y)
		if not tile_set.has_source(source):source=_variant_source(cell.x,cell.y)
		var atlas := tile_set.get_source(source) as TileSetAtlasSource
		var texture := AtlasTexture.new()
		texture.atlas = atlas.texture
		texture.region = atlas.get_tile_texture_region(ATLAS)
		var top := Sprite2D.new()
		top.name = "Top_%d_%d" % [cell.x,cell.y]
		top.texture = texture
		top.centered = false
		top.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		top.position = map_to_local(cell)
		top.offset = Vector2(-64,-32-HILL_LIFT*height_at(cell))
		top.modulate = Color.WHITE.lerp(Color(1.14,1.13,1.06),float(height_at(cell))/2.0)
		top.set_meta("surface_cell",cell)
		top.set_meta("render_role","walkable_surface")
		surfaces.add_child(top)
		hill_sprite_count += 1
	_build_ao_seats()
	_build_cliff_faces()
	_build_ramp_slopes()
	_build_ledge_collision()
	for child in _cliff_face_overlay.get_children():
		if child == surfaces: continue
		if child is CanvasItem: child.z_as_relative = false
		if child.has_meta("ramp_surface"):
			var cell: Vector2i = child.get_meta("ramp_surface")
			var texture_origin: Vector2 = child.position
			child.reparent(surfaces,false)
			child.position = map_to_local(cell)
			child.offset = texture_origin-child.position
			child.z_as_relative = true
			child.z_index = 0
			child.set_meta("surface_cell",cell)
			child.set_meta("render_role", "walkable_surface")
		if child.has_meta("raised_cell"):
			_split_vertical_faces(child as Sprite2D)
	if layout_revision==LAYOUTS.CANDIDATE:_build_ramp_end_faces()

func _build_ramp_end_faces()->void:
	# Two exposed short ends of the contiguous candidate slope. These pixel faces
	# occupy the same non-traversable shared edges as the real ledge colliders.
	for cell:Vector2i in ramp_cells:
		for d in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
			var nb:=terrain_neighbor(cell,d)
			if can_traverse(cell,nb) or not is_cell_walkable(nb):continue
			var delta:=map_to_local(nb)-map_to_local(cell)
			var midpoint:=map_to_local(cell)+delta*0.5
			var tangent:=Vector2(delta.x,-delta.y)*0.5
			var a:=midpoint-tangent;var b:=midpoint+tangent
			var shape:=PackedVector2Array([a+Vector2(0,-32*surface_level_at(cell,a)),b+Vector2(0,-32*surface_level_at(cell,b)),b+Vector2(0,-32*surface_level_at(nb,b)),a+Vector2(0,-32*surface_level_at(nb,a))])
			var origin:=map_to_local(cell)+Vector2(-64,-64)
			var image:=Image.create(128,96,false,Image.FORMAT_RGBA8)
			image.fill(Color.TRANSPARENT)
			for y in range(0,96,2):
				for x in range(0,128,2):
					if not Geometry2D.is_point_in_polygon(origin+Vector2(x+1,y+1),shape):continue
					var color:=Color8(86,75,57) if d.x!=0 else Color8(104,89,64)
					image.fill_rect(Rect2i(x,y,2,2),color)
			var face:=Sprite2D.new();face.texture=ImageTexture.create_from_image(image)
			face.centered=false;face.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			face.set_meta("_height_lifted",true);face.set_meta("ramp_end_edge",[cell,nb])
			_ysort.add_child(face);face.global_position=to_global(midpoint);face.offset=origin-midpoint
			_foundation_walls.append(face)

func _split_vertical_faces(original: Sprite2D) -> void:
	var cell: Vector2i = original.get_meta("raised_cell")
	var depths: Vector2i = original.get_meta("face_depths")
	var art_origin := original.global_position
	for face in range(2):
		if depths[face] <= 0:
			continue
		var image := original.texture.get_image().duplicate() as Image
		# SE is right half, SW is left half. No shared max-depth corner root.
		for x in range(image.get_width()):
			if (x < 64) == (face == 0):
				for y in range(image.get_height()):
					image.set_pixel(x, y, Color.TRANSPARENT)
		var sprite := Sprite2D.new()
		sprite.name = "FDNFace_%d_%d_%d" % [cell.x, cell.y, face]
		sprite.texture = ImageTexture.create_from_image(image)
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.set_meta("raised_cell", cell)
		sprite.set_meta("face_depths", Vector2i(depths.x, 0) if face == 0 else Vector2i(0, depths.y))
		sprite.set_meta("render_role", "vertical_occluder")
		# Already projected terrain is not a newly spawned prop. The inherited
		# post-build object lift must not shift its sort root/art a second time.
		sprite.set_meta("_height_lifted", true)
		var direction := Vector2i(1, 0) if face == 0 else Vector2i(0, 1)
		var receiver := terrain_neighbor(cell, direction)
		sprite.set_meta("receiver_cell", receiver)
		sprite.set_meta("receiver_level", height_at(receiver))
		_ysort.add_child(sprite)
		# Actor bodies and the sort contact stay in the same unlifted logical plane.
		# Texture displacement alone contains the height; no collider/body is lifted.
		sprite.global_position = to_global(map_to_local(cell) + Vector2(0, TILE_HALF_H))
		sprite.offset = sprite.to_local(art_origin)
		_foundation_walls.append(sprite)
	original.get_parent().remove_child(original)
	original.queue_free()

func clear_foundation_elevation() -> void:
	# Reparented walls are owned here, not by Elevation; clear both ownership domains.
	for wall in _foundation_walls:
		if is_instance_valid(wall):
			if wall.get_parent() != null:
				wall.get_parent().remove_child(wall)
			wall.queue_free()
	_foundation_walls.clear()
	for layer in _elev_layers:
		if is_instance_valid(layer):
			remove_child(layer)
			layer.queue_free()
	_elev_layers.clear()
	if is_instance_valid(_cliff_face_overlay):
		remove_child(_cliff_face_overlay)
		_cliff_face_overlay.queue_free()
	if is_instance_valid(_ledge_body):
		remove_child(_ledge_body)
		_ledge_body.queue_free()
	hill_sprite_count = 0
	cliff_face_count = 0
	ramp_slope_count = 0
	ao_seat_count = 0
	ledge_collider_count = 0

func _exit_tree() -> void:
	# Sibling YSortLayer may already have left the tree during a full scene exit.
	for wall in _foundation_walls:
		if is_instance_valid(wall) and not wall.is_queued_for_deletion():
			wall.queue_free()
	_foundation_walls.clear()
