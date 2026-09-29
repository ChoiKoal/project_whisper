extends Node2D
## Cosmetic-only contact response. Never grants inventory or owns input/time.
## Original source slices keep material_kind identity; quantized motion keeps pixels crisp.
var material_kind := "flora"
var age := 0.0
var parts: Array[Sprite2D] = []
var foot := Vector2.ZERO
var icon: Sprite2D
var destination := Vector2.ZERO

func setup(source: Gatherable, kind: String, player_point: Vector2) -> void:
	material_kind=kind
	transform=source.transform
	z_index=source.z_index
	y_sort_enabled=source.y_sort_enabled
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	foot=to_local(source.visual_target_point())
	destination=to_local(player_point)
	if source.texture!=null and not source.unique:
		var size:=source.texture.get_size()
		var rects:Array[Rect2]=[Rect2(Vector2.ZERO,size)]
		if kind=="wood":
			var split:=floorf(size.y*0.68)
			rects=[Rect2(0,0,size.x,split),Rect2(0,split,size.x,size.y-split)]
		elif kind=="rock":
			var split:=floorf(size.x/3.0)
			rects=[Rect2(0,0,split,size.y),Rect2(split,0,split,size.y),Rect2(split*2,0,size.x-split*2,size.y)]
		for region in rects:
			var sprite:=Sprite2D.new()
			sprite.texture=source.texture
			sprite.region_enabled=true;sprite.region_rect=region
			sprite.offset=source.get_rect().position+region.position+region.size*0.5
			add_child(sprite);parts.append(sprite)
	icon=Sprite2D.new();icon.texture=ItemDB.icon(source.item_id)
	if icon.texture!=null:
		icon.scale=Vector2.ONE*minf(1.0,20.0/icon.texture.get_width())
	icon.position=foot+Vector2(0,-22)
	add_child(icon)

func _ready() -> void:
	add_to_group("harvest_response")

func _process(delta: float) -> void:
	age+=delta
	if age>=0.30:queue_free();return
	for i in range(parts.size()):
		var shift:=Vector2.ZERO
		match material_kind:
			"wood":
				if i==0:shift=Vector2(sin(age*44.0)*3.0,0)
			"rock":shift=Vector2((i-1)*age*28.0,age*age*90.0)
			_:shift=Vector2(sin(age*32.0)*3.0,-sin(age*9.0)*4.0)
		parts[i].position=shift.round()
		parts[i].modulate.a=1.0 if age<0.10 else (0.65 if age<0.18 else 0.25)
	if is_instance_valid(icon):
		icon.position=(foot.lerp(destination,age/0.30)+Vector2(0,-22-sin(age/0.30*PI)*10.0)).round()
		icon.modulate.a=1.0 if age<0.24 else 0.5
	queue_redraw()

func _draw() -> void:
	var color:=Color("bca47f") if material_kind=="wood" else (Color("b1b9ba") if material_kind=="rock" else Color("c5c793"))
	for i in range(4):
		var direction:=Vector2(-1.0 if i%2==0 else 1.0,-1.0)
		var point:Vector2=(foot+Vector2((i-2)*5,-10)+direction*age*(28.0+i*11.0)+Vector2(0,age*age*110)).round()
		draw_rect(Rect2(point,Vector2(4,2)),color)
		if material_kind!="rock":draw_rect(Rect2(point+Vector2(2,-2),Vector2(4,2)),color.darkened(0.15))
