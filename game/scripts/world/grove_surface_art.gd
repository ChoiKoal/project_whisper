extends RefCounted
## L1-only raster surfaces. No collision, map, progression or save writes.
## Material UVs are WORLD pixels, so overlapping neighbouring skirts agree.
const MATERIAL: Texture2D = preload("res://assets/tiles/grove_rock_field.png")
static var _field: Image

static func wall(origin: Vector2i, depth: int, expose_se: bool, expose_sw: bool) -> Image:
	if _field == null:
		_field = MATERIAL.get_image()
	var image := Image.create(128, 64 + depth, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for x in range(128):
		if not (expose_sw if x < 64 else expose_se):
			continue
		# Two-logical-pixel stairs, exact 2:1 edges. No antialias/airbrush.
		var rim := 32 + (mini(x, 127 - x) / 4) * 2
		for y in range(rim, rim + depth):
			var u := posmod(origin.x + x, _field.get_width())
			var v := posmod(origin.y + y, _field.get_height())
			image.set_pixel(x, y, _field.get_pixel(u, v))
	return image

## Merge exposed face intervals per world column. One shared surface profile
## prevents each overlapping diamond from painting its own soil stripe.
static func rim_profile(origins: Array, faces: Array, depth: int) -> Dictionary:
	var columns: Dictionary = {}
	for i in range(origins.size()):
		var origin: Vector2i = origins[i]
		var side: Vector2i = faces[i]
		for x in range(128):
			if (side.y if x<64 else side.x)==0: continue
			var world_x := origin.x+x
			var top := origin.y+32+(mini(x,127-x)/4)*2
			if not columns.has(world_x): columns[world_x]=[]
			columns[world_x].append(Vector2i(top,top+depth))
	for world_x in columns:
		var intervals: Array = columns[world_x]
		intervals.sort_custom(func(a: Vector2i,b: Vector2i): return a.x<b.x)
		var merged: Array = []
		for interval: Vector2i in intervals:
			if merged.is_empty() or interval.x>merged[-1].y:
				merged.append(interval)
			else:
				merged[-1]=Vector2i(merged[-1].x,maxi(merged[-1].y,interval.y))
		columns[world_x]=merged
	return columns

## A narrow irregular turf/soil cross-section, within the existing face mask.
## No geometry, physics or save-coordinate changes; the rock stays world-mapped.
static func skirt_wall(origin: Vector2i, depth: int, se: bool, sw: bool, profile: Dictionary) -> Image:
	var image := wall(origin,depth,se,sw)
	const SOIL_DEPTH = [6,6,8,8,12,10,6,4,4,6,8,6,6,10,8,6,4,6,6,8,10,12,8,6,6,4,4,6,8,6,10,8,6,6,8,10,6,4,6,8,8,6,4,6,6,10,8]
	for x in range(128):
		var world_x := origin.x+x
		var intervals: Array = profile.get(world_x,[])
		var soil: int = SOIL_DEPTH[posmod(world_x/4,SOIL_DEPTH.size())]
		for y in range(image.get_height()):
			if image.get_pixel(x,y).a==0: continue
			var world_y := origin.y+y
			for interval: Vector2i in intervals:
				if world_y<interval.x or world_y>=interval.y: continue
				var d := world_y-interval.x
				if d<2:
					image.set_pixel(x,y,Color8(94,112,74))
				elif d<4:
					image.set_pixel(x,y,Color8(64,73,52))
				elif d<soil+2:
					image.set_pixel(x,y,Color8(101,88,66))
				elif d<soil+4:
					image.set_pixel(x,y,Color8(76,72,56))
				break
	return image

## Raised walls use independent depths on each face; the old max-depth apron
## extended the shallower face into the receiving plateau.
static func raised_wall(origin: Vector2i, depths: Vector2i) -> Image:
	var image := wall(origin, maxi(depths.x, depths.y), depths.x>0, depths.y>0)
	for x in range(128):
		var depth := depths.y if x<64 else depths.x
		var rim := 32+(mini(x,127-x)/4)*2
		for y in range(image.get_height()):
			if depth==0 or y<rim or y>=rim+depth:
				image.set_pixel(x,y,Color.TRANSPARENT)
			elif y<rim+4:
				image.set_pixel(x,y,Color8(103,120,77) if y<rim+2 else Color8(72,85,63))
			elif y<rim+8:
				image.set_pixel(x,y,Color8(95,85,65))
	return image

## Pixel contact at the receiver, not a tile-centred radial AO stamp.
static func contact(depths: Vector2i) -> Image:
	var image := Image.create(128,64+maxi(depths.x,depths.y)+8,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for x in range(128):
		var depth := depths.y if x<64 else depths.x
		if depth<=0: continue
		var foot := 32+(mini(x,127-x)/4)*2+depth
		for dy in range(6):
			image.set_pixel(x,foot+dy,Color8(35,49,43,80 if dy<2 else 40))
	return image

## Inverse rasterization of the real sloping surface, no hanging solid wedge.
## The top spans low..high and is anchored at centre-(64,32+high*32).
static func ramp(dir: String, low: int, high: int) -> Image:
	var earth: Image = load("res://assets/tiles/t1_dirt.png").get_image()
	var span := high-low
	var image := Image.create(128,64+span*32,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var sx := 1.0 if dir in ["ne","se"] else -1.0
	var sy := 1.0 if dir in ["se","sw"] else -1.0
	var denominator := 1.0-float(span)*sy*0.5
	if absf(denominator)<0.01: return image
	for x in range(0,128,2):
		var c := 0.5+sx*(float(x)-64.0)/128.0-sy*0.5
		for y in range(0,image.get_height(),2):
			var source_y := (float(y)-span*32.0+span*32.0*c)/denominator
			if source_y<0.0 or source_y>=64.0: continue
			var color := earth.get_pixel(x,int(source_y))
			if color.a==0: continue
			for dx in range(2):
				for dy in range(2): image.set_pixel(x+dx,y+dy,color)
	return image
