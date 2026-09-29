extends "res://scenes/dev/harvest_progression_capture.gd"
## Unmodified CURRENT16 normal input route, with passive MAP1 motion/render evidence.
## No teleports, ingredient/time/gate injections, new progression steps or direct clears.
var motion_records:Array=[]
var normal_void_hits:=0
var normal_projection_errors:=0
var normal_draw_samples:=0
var crossing_shots:Dictionary={}
var crossing_busy:=false
func _ready()->void:
	super._ready()
	RenderingServer.frame_post_draw.connect(observe_normal_draw)
func observe_normal_draw()->void:
	if _tree==null or _tree.current_scene==null or _tree.current_scene.name!="StartingGrove":return
	var map:=_tree.current_scene.get_node_or_null("Ground") as MapLoader
	var actor:=_tree.current_scene.get_node_or_null("YSortLayer/Player") as Player
	if map==null or actor==null or not map.layout_ready:return
	var cell:=map.world_to_cell(actor.global_position)
	if map._sym_at(cell)=="V":normal_void_hits+=1
	var expected:Vector2=actor._base_anim_position+Vector2(0,map.visual_height_offset(actor.global_position))
	if actor._anim.position.distance_to(expected)>0.1:normal_projection_errors+=1
	normal_draw_samples+=1
	if normal_draw_samples%4==0:
		motion_records.append({"cell":[cell.x,cell.y],"position":[actor.global_position.x,actor.global_position.y],"height":map.visual_height_offset(actor.global_position),"game_time":GameState.game_time,"quest":QuestManager.active_id,"symbol":map._sym_at(cell)})
	if map.layout_revision!="l1-v2" or crossing_busy:return
	var role:=""
	if cell.y in [7,8,9,13,14,15]:role="bank-row-%d"%cell.y
	elif map.is_ramp(cell) and cell.y in [16,22]:role="ramp-end-%d"%cell.y
	if role=="" or crossing_shots.has(role):return
	crossing_shots[role]=true
	crossing_busy=true
	save_crossing.call_deferred(role)
func save_crossing(role:String)->void:
	await _capture("normal-motion-"+role+".png","normal_input_motion_"+role)
	crossing_busy=false
func _finish()->void:
	var deadline:=Time.get_ticks_msec()+3000
	while crossing_busy and Time.get_ticks_msec()<deadline:await _frames(1)
	require(normal_draw_samples>100 and normal_void_hits==0,"normal movement never enters authored V")
	require(normal_projection_errors==0,"normal presented frames retain logical-foot projection")
	var data:={"kind":"passive observation of inherited harvest_progression_capture normal title/Home/L1/revisit route; no added state injection","samples":normal_draw_samples,"void_hits":normal_void_hits,"projection_errors":normal_projection_errors,"crossing_shots":crossing_shots.keys(),"motion":motion_records}
	var encoded:=JSON.stringify(data,"\t")
	var path:=_out_dir.path_join("normal-motion-receipt.json")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:_failed=true
	else:
		file.store_string(encoded);file.close()
		require(FileAccess.get_file_as_string(path)==encoded,"normal motion manifest persisted")
	super._finish()
