extends RefCounted
## Layout identity is independent of SAVE_VERSION. Never normalize revision tokens.
const LEGACY := "l1-v1"
const CANDIDATE := "l1-v2"
const SUPPORTED := [LEGACY,CANDIDATE]
static func inspect(data:Dictionary)->Dictionary:
	var choices:Variant=data.get("world_layouts",{})
	var worlds:Variant=data.get("worlds",{})
	if not choices is Dictionary or not worlds is Dictionary:return _bad("invalid world layout map")
	var snapshot:Variant=worlds.get("grove",{})
	if not snapshot is Dictionary:return _bad("invalid grove snapshot")
	var saved:Variant=snapshot.get("layout_revision",LEGACY)
	var revision:Variant=choices.get("grove",saved)
	if not revision is String or revision not in SUPPORTED:return _bad("unsupported grove layout revision")
	if not snapshot.is_empty() and saved!=revision:return _bad("grove snapshot/run layout mismatch")
	var bundle:=profile(revision)
	if bundle.is_empty():return _bad("Grove profile files missing or invalid")
	var error:=snapshot_error(snapshot,revision,bundle)
	if error!="":return _bad(error)
	return {"ok":true,"revision":revision,"reason":""}
static func _bad(reason:String)->Dictionary:
	return {"ok":false,"revision":"","reason":reason}
static func profile(revision:String)->Dictionary:
	if revision not in SUPPORTED:return {}
	var base:="res://data/l1/"+("v1" if revision==LEGACY else "v2")+"/"
	var result:={"layout":base+"map_layout.txt","height":base+"map_height.txt","legend":base+"map_legend.json"}
	for path in result.values():
		if not FileAccess.file_exists(path):return {}
	var rows:=FileAccess.get_file_as_string(result.layout).strip_edges().split("\n")
	var heights:=FileAccess.get_file_as_string(result.height).strip_edges().split("\n")
	var legend:Variant=JSON.parse_string(FileAccess.get_file_as_string(result.legend))
	if rows.size()!=40 or heights.size()!=40 or not legend is Dictionary or not legend.get("tiles") is Dictionary:return {}
	if legend.get("layout_revision",LEGACY)!=revision:return {}
	for y in range(40):
		if rows[y].length()!=40 or heights[y].length()!=40:return {}
		for x in range(40):
			if not legend.tiles.has(rows[y][x]) or heights[y][x] not in ["0","1","2","/"]:return {}
	result["rows"]=rows
	return result
static func valid_cell(value:Variant)->bool:
	if not value is Array or value.size()!=2:return false
	for n in value:
		if (not n is int and not n is float) or not is_finite(float(n)) or float(n)!=floorf(float(n)) or n<0 or n>=40:return false
	return true
static func snapshot_error(snapshot:Dictionary,revision:String,bundle:Dictionary)->String:
	for key in ["void_cells","stepping_stones","objects","placed_objects"]:
		var entries:Variant=snapshot.get(key,[])
		if not entries is Array:return "invalid Grove "+key
		for entry in entries:
			var cell:Variant=entry
			if key in ["objects","placed_objects"]:
				if not entry is Dictionary:return "invalid Grove object record"
				cell=entry.get("cell")
			if not valid_cell(cell):return "invalid Grove cell in "+key
			var symbol:String=bundle.rows[int(cell[1])][int(cell[0])]
			if revision==CANDIDATE and key=="void_cells" and symbol in ["X","K"]:return "protected stream cannot be restored as gathered ground"
			if revision==CANDIDATE and key=="stepping_stones" and symbol!="K":return "stepping stone outside candidate G1 slots"
	if snapshot.has("player"):
		var player:Variant=snapshot.player
		if not player is Dictionary:return "invalid Grove player"
		for key in ["x","y"]:
			var n:Variant=player.get(key)
			if (not n is int and not n is float) or not is_finite(float(n)):return "invalid Grove player position"
	if not snapshot.get("gates",{}) is Dictionary:return "invalid Grove gates"
	return ""
static func anchors(revision:String)->Dictionary:
	if revision!=CANDIDATE:return {}
	return {
		"story_perch":[Vector2i(24,34)],"story_cairn":[Vector2i(29,17)],
		"experiment_cells":[Vector2i(23,34),Vector2i(23,35),Vector2i(24,35)],
		"return_portal":[Vector2i(10,31)],"return_fallback":[Vector2i(10,31),Vector2i(11,31)],
		"cauldron_fallback":[Vector2i(17,35)],"oak_npc":[Vector2i(17,36)],
		"garden_portal":[Vector2i(10,32),Vector2i(11,33)],
		"heart_portal":[Vector2i(18,32),Vector2i(19,33)]}
