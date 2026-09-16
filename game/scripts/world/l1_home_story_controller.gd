extends Node
## WH-L1H-01: optional placed discoveries, never a three-slot quest.
## Coordinates are metadata only: no map symbols, terrain, scatter or save positions rewritten.
const Anchor=preload("res://scripts/world/l1_home_story_anchor.gd")
const EXPERIMENT_CELLS := [Vector2i(23,34),Vector2i(23,35),Vector2i(24,35)]
const RESPONSE := {
	"nest":"집부터 만들었네. …주인은 길을 잃었나 봐.",
	"bouquet":"꽃잎 하나가 떨어졌다. 같은 장면에, 작은 틈이 생겼다.",
	"moss":"돌이 계절을 기억했다. 물은 아래인데, 이끼는 북쪽으로 자랐다.",
	"other":"바람이 한 번, 잘못된 방향으로 불었다. 놓은 것만 흔들렸다.",
}
const CAIRN := {
	"":"돌을 쌓은 흔적. 같은 자리를, 여러 번 고친 것 같다.",
	"nest":"돌 틈에 짚이 끼어 있다. 같은 실험을, 누군가 먼저 했을까.",
	"bouquet":"돌 아래 눌린 색. 꽃이 지는 법을 기록한 흔적 같다.",
	"moss":"북쪽 면만 젖어 있다. 물은 한참 아래인데.",
	"other":"돌 하나가 길이 아니라, 네가 놓은 물건을 가리킨다.",
}
var loader: MapLoader
var world: Node
var perch: Sprite2D
var cairn: Sprite2D
var response_count := 0
var caption_count := 0
var _caption: Label
var _caption_time := 0.0
var _response_time := 0.0
var _frozen_cells: Array[Vector2i]=[]
var experiment_cells:Array=[]
func setup(map: MapLoader) -> void:
	loader=map
	experiment_cells=loader.anchor_cells("experiment_cells",EXPERIMENT_CELLS)
	world=loader.get_parent()
	var respawn: ObjectRespawn=world.get_node("ObjectRespawn")
	for entry in respawn._tracked: _frozen_cells.append(entry.cell)
	var ys:=loader.get_node(loader.ysort_layer_path)
	perch=Anchor.new();perch.name="L1ListeningPerch";perch.kind="perch";ys.add_child(perch)
	cairn=Anchor.new();cairn.name="L1StoryCairn";cairn.kind="cairn";ys.add_child(cairn)
	perch.inspected.connect(_inspect)
	cairn.inspected.connect(_inspect)
	GameState.placed_object_placed.connect(_placed)
	SaveManager.game_loaded.connect(_restore)
	var clear:=world.get_node_or_null("ClearSequence")
	if clear!=null: clear.world_answer_beat.connect(_world_answer)
	_restore()
func _restore() -> void:
	_place_anchor(perch,loader.anchor_cells("story_perch",[Vector2i(24,34)])[0])
	_place_anchor(cairn,loader.anchor_cells("story_cairn",[Vector2i(19,20)])[0])
	var outcome: String=GameState.story_episode().active_outcome
	perch.set_outcome(outcome)
	cairn.set_outcome(outcome)
	if SaveManager.cleared: _world_answer()

func _world_answer() -> void:
	var outcome: String=GameState.story_episode().active_outcome
	if outcome.is_empty() or loader.world_tree_cells.is_empty(): return
	var ys:=loader.get_node(loader.ysort_layer_path)
	var trace:=ys.get_node_or_null("L1H01WorldAnswer") as Sprite2D
	if trace==null:
		trace=Sprite2D.new()
		trace.name="L1H01WorldAnswer"
		trace.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		ys.add_child(trace)
		trace.global_position=loader.cell_center_world(loader.world_tree_cells[0])+Vector2(0,-28+loader.height_offset(loader.world_tree_cells[0]))
	trace.texture=load("res://assets/objects/l1_response_%s.png" % outcome)
	if outcome=="nest":
		trace.texture=load("res://assets/objects/l1_bird_shadow_strip.png")
		trace.hframes=6
		trace.frame=3
		trace.flip_h=true
	else:
		trace.hframes=1
		trace.frame=0
func _place_anchor(anchor: Node2D, preferred: Vector2i) -> void:
	var candidates: Array[Vector2i]=[preferred]
	for r in range(1,4):
		for y in range(-r,r+1):
			for x in range(-r,r+1):
				if maxi(absi(x),absi(y))==r: candidates.append(preferred+Vector2i(x,y))
	for cell in candidates:
		if cell in experiment_cells or cell in _frozen_cells or not loader.is_cell_walkable(cell): continue
		var occupied:=false
		for group in ["placed_object","gatherable"]:
			for obj in get_tree().get_nodes_in_group(group):
				if obj==anchor or not obj is Node2D or not world.is_ancestor_of(obj): continue
				if obj.is_queued_for_deletion(): continue
				if loader.world_to_cell(obj.global_position)==cell: occupied=true
		if occupied: continue
		anchor.global_position=loader.cell_center_world(cell)
		anchor.set_height_lift(loader.height_offset(cell))
		anchor.visible=true
		if not anchor.is_in_group("gatherable"): anchor.add_to_group("gatherable")
		return
	# Saturated saves always win. Hide the derived prop and its interaction, never migrate data.
	anchor.visible=false
	anchor.remove_from_group("gatherable")
func _placed(item_id: String, cell: Vector2i) -> void:
	if WorldContext.current_scene!="grove" or not is_instance_valid(loader): return
	# Signal must correspond to a real object in this world, not a functional gate or other scene.
	var actual:=false
	for obj in get_tree().get_nodes_in_group("placed_object"):
		if world.is_ancestor_of(obj) and obj.cell==cell and obj.item_id==item_id: actual=true
	if not actual: return
	if cell not in experiment_cells:
		_restore()
		return
	var first:=GameState.story_record_experiment(item_id)
	_restore()
	if first:
		response_count+=1
		_response_time=2.4
		caption(RESPONSE.get(GameState.story_episode().active_outcome,""),perch)
	# Save after the placement transaction has consumed inventory, never mid-signal.
	call_deferred("_save_after_placement")
func _save_after_placement() -> void:
	if is_inside_tree() and WorldContext.current_scene=="grove": SaveManager.save_game()
var _inspect_requests: Dictionary = {}
func _inspect(anchor: Node) -> void:
	var dialogue := world.get_node_or_null("DialoguePanel") as DialoguePanel
	if not is_instance_valid(dialogue):
		push_warning("L1 story: dialogue view missing; inspect remains unseen")
		return
	var kind: String=anchor.kind
	if _inspect_requests.has(kind): return
	var state:=GameState.story_episode()
	var observed_outcome: String=state.active_outcome
	var text: String
	if anchor==perch:
		if SaveManager.cleared: text="같은 자리에 있는데, 같은 모습은 아니다."
		elif not state.perch_inspected: text="가지는 바람이 없는 쪽으로만 닳아 있다.\n새는 없는데, 둥지 자국만 매일 새것 같다."
		else: text="낡은 둥지 자국. 무엇을 놓든, 여기는 듣고 있을 것 같다."
	else:
		text=CAIRN.get(observed_outcome,CAIRN[""])
	_inspect_requests[kind]=true
	var ticket:=dialogue.enqueue([{"source":"관찰","place":"듣는 횃대" if kind=="perch" else "돌무더기","body":text}],"l1h01:inspect:"+kind)
	if not ticket.done: caption_count+=1
	var completed: bool=ticket.result if ticket.done else await ticket.completed
	_inspect_requests.erase(kind)
	if not completed or not is_inside_tree(): return
	# Read current state after the await; never overwrite a newer experiment outcome.
	state=GameState.story_episode()
	if kind=="perch": state.perch_inspected=true
	elif observed_outcome!="": state.cairn_seen[observed_outcome]=true
	GameState.story_state[GameState.L1_HOME_EPISODE]=state
	SaveManager.save_game()
func caption(text: String, anchor: Node2D) -> void:
	if _caption!=null: _caption.queue_free()
	_caption=Label.new()
	_caption.text=text
	_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size",18)
	_caption.add_theme_color_override("font_color",Color("e9dfc1"))
	_caption.add_theme_color_override("font_outline_color",Color("302f35"))
	_caption.add_theme_constant_override("outline_size",4)
	_caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_caption.z_index=100
	world.add_child(_caption)
	_caption.global_position=anchor.global_position+Vector2(-340,-196)
	_caption.size=Vector2(680,60)
	_caption_time=4.5
	caption_count+=1
func _process(delta: float) -> void:
	if _caption!=null:
		_caption_time-=delta
		if _caption_time<=0:
			_caption.queue_free();_caption=null
	if _response_time>0 and perch!=null:
		_response_time=maxf(0,_response_time-delta)
		var offset:=Vector2.ZERO
		match perch.outcome:
			"nest": offset=Vector2(0,-int(_response_time*3)%2*2)
			"bouquet": offset=Vector2(int(_response_time*2)%2*2,-int(_response_time*12)*2)
			"moss": offset=Vector2(0,2 if _response_time>1.2 else 0)
			"other": offset=Vector2(2 if int(_response_time*3)%2 else -2,0)
		perch.response.position=perch.response_rest()+offset
		if _response_time==0: perch.response.position=perch.response_rest()
