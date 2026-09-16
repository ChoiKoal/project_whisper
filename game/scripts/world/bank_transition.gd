extends Node2D
## One authored bank field clipped by live TileMap topology, never a fake land
## mask over water. Logical cells, collision, spawn IDs and save data are untouched.
const ART: Texture2D = preload("res://assets/tiles/grove_bank_transition.png")
const ORIGIN := Vector2i(1216,1056)
const FIRST := Vector2i(9,32)
const LAST := Vector2i(13,39)
var _ground: TileMapLayer
var _field: Image
var _signature: Array = []
var _queued := false

func _ready() -> void:
	_ground = get_parent() as TileMapLayer
	_field = ART.get_image()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground.changed.connect(_queue_refresh)
	_refresh()

func _process(_delta: float) -> void:
	# TileMapLayer.changed does not announce every set_cell mutation. Compare the
	# small representative cell window so load/bestow/direct tile changes cannot
	# leave a cosmetic land mask over a newly hollow or flooded tile.
	var index := 0
	for y in range(FIRST.y,LAST.y+1):
		for x in range(FIRST.x,LAST.x+1):
			var cell := Vector2i(x,y)
			if _signature[index][0]!=_ground.get_cell_source_id(cell) or _signature[index][1]!=_ground.height_at(cell):
				_refresh()
				return
			index+=1

func _queue_refresh() -> void:
	if _queued: return
	_queued = true
	call_deferred("_refresh")

func _refresh() -> void:
	_queued = false
	if not is_instance_valid(_ground): return
	var signature: Array = []
	for y in range(FIRST.y,LAST.y+1):
		for x in range(FIRST.x,LAST.x+1):
			var cell := Vector2i(x,y)
			signature.append([_ground.get_cell_source_id(cell),_ground.height_at(cell)])
	if signature==_signature: return
	_signature=signature
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for y in range(FIRST.y,LAST.y+1):
		for x in range(FIRST.x,LAST.x+1):
			var cell := Vector2i(x,y)
			var source := _ground.get_cell_source_id(cell)
			if source not in [1,2,3,4,5] or _ground.height_at(cell)!=0: continue
			var grass_source: int = source if source in [2,3,4,5] else 2
			var grass: Image = (_ground.tile_set.get_source(grass_source) as TileSetAtlasSource).texture.get_image()
			var top_left := Vector2i(_ground.map_to_local(cell))-Vector2i(64,32)
			var image := Image.create(128,64,false,Image.FORMAT_RGBA8)
			image.fill(Color.TRANSPARENT)
			var ink := false
			for py in range(64):
				for px in range(128):
					var local := top_left+Vector2i(px,py)
					var uv := local-ORIGIN
					if uv.x<0 or uv.y<0 or uv.x>=_field.get_width() or uv.y>=_field.get_height(): continue
					# Pixel centres use the engine's actual STACKED topology. Both row
					# parities, plus same-frame source/hollow changes, retain exact land.
					if _ground.local_to_map(Vector2(local)+Vector2(0.5,0.5))!=cell: continue
					var color := _field.get_pixelv(uv)
					if color.a==0: continue
					# Base-green is a semantic turf mask; keep existing grass clusters
					# at identical tile pixels instead of a differently coloured sticker.
					if color==Color8(102,120,91) and grass.get_pixel(px,py).a>0:
						color=grass.get_pixel(px,py)
					image.set_pixel(px,py,color)
					ink=true
			if not ink: continue
			var sprite := Sprite2D.new()
			sprite.texture=ImageTexture.create_from_image(image)
			sprite.centered=false
			sprite.position=top_left
			sprite.set_meta("bank_cell",cell)
			add_child(sprite)
