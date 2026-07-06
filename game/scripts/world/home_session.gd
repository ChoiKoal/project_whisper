extends Node
class_name HomeSession
## Glue node inside home_island.tscn (제0세계). Mirror of GroveSession but for the home
## world + the portal travel hub. On ready it:
##   - registers the live world (MapLoader, Player, ObjectRespawn) with SaveManager under
##     the "home" scene id
##   - if SaveManager.pending_load, restores the home world state
##   - wires every Portal's portal_interacted → travel (flickering/open) or a locked hint
##   - draws the central stone dais under the spawn
##   - places the player on the portal-arrival point when returning from a world
##   - runs the CS-05 「귀환과 점화」 return cutscene when WorldContext flags a return
##
## Travel: interacting with the flickering/open Layer-1 (nature) portal plays CS-02 (violet
## swell) and changes to the grove. Returning from the grove (post-clear) lands here and, if
## the clear just happened, fires CS-05.

@export var map_loader_path: NodePath
@export var player_path: NodePath
@export var respawn_path: NodePath
@export var portal_cutscene_path: NodePath   ## PortalCutscene CanvasLayer (travel swell / CS-05)

var _loader: MapLoader
var _player: Node2D
var _portal_cutscene: Node

const LOCKED_HINT := "이 문은 아직 잠들어 있다"

## (v0.5.1 BUG3) The portal whose entry apron the player is currently standing in (or null).
## Driven from _process; when non-null the E-prompt shows and `interact` enters that gate.
var _active_portal: Portal = null
## The floating "E 들어가기 / 다가가기 / …잠들어 있다" prompt above the active gate. Created lazily.
var _entry_prompt: Label = null
var _portals: Array = []

## (EG-1) The 빛의 문 (platinum Portal) spawned at the dais focus once five portals are lit, plus
## its own EntryZone tracking + the confirm-prompt modal it opens. The light gate is NOT wired
## into the normal travel path (`_on_portal_interacted`) — it opens the ending confirm prompt.
var _light_gate: Portal = null
var _light_gate_active: bool = false   ## player in the light gate's apron this frame
## (EG-1) The 3-choice confirm modal ([들어간다]/[돌아선다]/[아직 아니야]) + its control_lock guard.
var _ending_modal: Control = null
var _ending_layer: CanvasLayer = null
const ENDING_MODAL_KEY := "ending_prompt"
## (EG-1/EG-3) The EndingSequence CanvasLayer that plays E1/E2 (built lazily on first ending).
var _ending_seq: Node = null
const EndingSequenceScript := preload("res://scripts/world/ending_sequence.gd")


func _ready() -> void:
	WorldContext.current_scene = WorldContext.SCENE_HOME
	call_deferred("_setup")


func _setup() -> void:
	await get_tree().process_frame
	_loader = get_node_or_null(map_loader_path) as MapLoader
	_player = get_node_or_null(player_path) as Node2D
	var respawn := get_node_or_null(respawn_path) as ObjectRespawn
	_portal_cutscene = get_node_or_null(portal_cutscene_path)
	if _loader != null and _player != null and respawn != null:
		SaveManager.register_world(_loader, _player, respawn)

	_draw_ground_traces()
	_draw_dead_grass_patches()
	_draw_dais()
	_draw_cauldron_pad()
	_wire_portals()

	# A FRESH awakening = arrived from the CS-01 opening (not a portal return, not 이어하기).
	# On that beat we play the camera reveal (zoom on dais → ease out to the portal arc).
	var fresh_awakening := WorldContext.arrival_mode != "portal_arrival" and not SaveManager.pending_load

	# Apply a pending load into this live scene (이어하기 that saved in the home world).
	if SaveManager.pending_load:
		SaveManager.pending_load = false
		SaveManager.load_game()

	if fresh_awakening:
		_play_awakening_reveal()

	# If we arrived via a portal-return, land the player near the dais (arrival point) and
	# run the return cutscene when the world was just cleared (CS-05).
	if WorldContext.arrival_mode == "portal_arrival":
		WorldContext.arrival_mode = ""
		_place_at_arrival()
		if SaveManager.consume_pending_return_ignition():
			await _play_return_ignition()

	if AudioManager != null:
		AudioManager.start_world_audio()
		AudioManager.set_home_ambience(true)   # quieter/sparser home soundscape

	# (EG-1) 빛의 문: spawn it if the five portals are already lit (restored save / returned after
	# L5). Also listen for the live `five_portals_lit` so a run that lights them WHILE on the home
	# island (never happens today — L5 lights them in the cathedral — but future-proof + harness)
	# spawns the gate immediately. Both paths are idempotent (guarded by `_light_gate`).
	if GameState != null:
		if GameState.light_gate_previewed_flag:
			_spawn_light_gate()
		if not GameState.five_portals_lit.is_connected(_on_five_portals_lit):
			GameState.five_portals_lit.connect(_on_five_portals_lit)


func _on_five_portals_lit() -> void:
	_spawn_light_gate()


# ---- portals --------------------------------------------------------------

func _wire_portals() -> void:
	_portals.clear()
	for node in get_tree().get_nodes_in_group("gatherable"):
		if node is Portal and is_instance_valid(node):
			var portal := node as Portal
			# (EG-1) The 빛의 문 is a Portal too, but it opens the ending prompt, not travel — it is
			# tracked/wired separately (see _spawn_light_gate). Never add it to the travel list.
			if portal.platinum or portal.object_id == "light_gate":
				continue
			_portals.append(node)
			if not portal.portal_interacted.is_connected(_on_portal_interacted):
				portal.portal_interacted.connect(_on_portal_interacted)


## (v0.5.1 BUG3) Per-frame: track which gate's entry apron the player is in and show the
## state-driven prompt. Keyboard E (and click-on-portal, via touch_controller) enter the gate.
func _process(_delta: float) -> void:
	# Don't offer entry while a modal window is open or a cutscene is running.
	var locked := GameState != null and (GameState.ui_modal_open() or not GameState.time_running)
	var here: Portal = null
	if not locked:
		for p in _portals:
			if is_instance_valid(p) and (p as Portal).is_player_in_entry_zone():
				here = p
				break
	_active_portal = here
	# (EG-1) Track the 빛의 문 apron separately (it opens the ending prompt, not travel).
	_light_gate_active = (not locked) and is_instance_valid(_light_gate) \
		and _light_gate.is_player_in_entry_zone()
	_update_entry_prompt()


## Keyboard entry: pressing `interact` while inside a gate's apron enters it (enterable) or
## surfaces the locked whisper (dormant). Uses `_input` (ahead of the InteractionController's
## `_unhandled_input`) and marks the event handled, so a gate in the apron is entered by E and
## the same press can't also be consumed as a gather/facing interaction.
func _input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	# (EG-1) While the ending confirm prompt is up, ESC = cancel (walk-away escape hatch, QA 필수).
	if _ending_modal != null and is_instance_valid(_ending_modal):
		if event.is_action_pressed("ui_cancel"):
			var vp0 := get_viewport()
			if vp0:
				vp0.set_input_as_handled()
			_cancel_ending_prompt()
		return
	if GameState != null and (GameState.ui_modal_open() or not GameState.time_running):
		return
	if not event.is_action_pressed("interact"):
		return
	# (EG-1) 빛의 문 apron takes priority: E opens the ending confirm prompt.
	if _light_gate_active and is_instance_valid(_light_gate):
		var vp1 := get_viewport()
		if vp1:
			vp1.set_input_as_handled()
		_open_ending_prompt()
		return
	if _active_portal == null:
		return
	var vp2 := get_viewport()
	if vp2:
		vp2.set_input_as_handled()
	_active_portal.on_interact()


func _update_entry_prompt() -> void:
	# (EG-1) The 빛의 문 apron takes priority over the layer portals for the floating prompt.
	var target: Portal = _light_gate if _light_gate_active and is_instance_valid(_light_gate) else _active_portal
	var text := ""
	if target == _light_gate and target != null:
		text = "E 빛의 문 앞에 서기"
	elif target != null:
		text = target.entry_prompt_text()
	if target == null or text == "":
		if _entry_prompt != null:
			_entry_prompt.visible = false
		return
	if _entry_prompt == null:
		_entry_prompt = _make_entry_prompt()
	_entry_prompt.text = text
	_entry_prompt.visible = true
	_entry_prompt.size = _entry_prompt.get_minimum_size()
	var anchor: Vector2 = target.target_point()
	_entry_prompt.global_position = anchor - Vector2(_entry_prompt.size.x * 0.5, 24)


func _make_entry_prompt() -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", Color("#faf5e6"))
	l.add_theme_font_size_override("font_size", 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.11, 0.84)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	sb.set_border_width_all(1)
	sb.border_color = Color(0.62, 0.48, 0.85, 0.75)
	l.add_theme_stylebox_override("normal", sb)
	l.z_index = 100
	var host: Node = _loader if _loader != null else self
	host.add_child(l)
	return l


func _on_portal_interacted(portal: Portal) -> void:
	if not portal.is_enterable():
		_float_hint(portal.target_point(), LOCKED_HINT)
		return
	# P1 ("들어가 봐") advances the moment the player commits to the flickering nature portal.
	GameState.portal_reached.emit(portal.layer)
	_travel_to_layer(portal.layer)


## Enter a world through a portal: play CS-02 (violet swell) then change scene. In v0.5 the
## only reachable world is Layer 1 (nature → grove); other layers stay dormant/locked.
func _travel_to_layer(layer: String) -> void:
	WorldContext.travel_layer = layer
	WorldContext.arrival_mode = "portal_arrival"
	# Snapshot the home world so returning restores placed objects etc.
	SaveManager.save_game()
	# (L2-5) Route by layer: nature→grove, science→terminal_station (꺼진 관문 기지). Others still
	# dormant/locked and never reach here.
	var dest := WorldContext.layer_scene(layer)
	if _portal_cutscene != null and _portal_cutscene.has_method("play_travel"):
		_portal_cutscene.play_travel(func():
			WorldContext.current_scene = dest
			get_tree().change_scene_to_file(WorldContext.scene_path(dest)))
	else:
		WorldContext.current_scene = dest
		get_tree().change_scene_to_file(WorldContext.scene_path(dest))


# ---- (EG-1) 빛의 문 (Door of Light) ---------------------------------------

## Spawn the platinum 빛의 문 at the home-island centre (the focus of the five-portal arc =
## the dais). Idempotent: a second call (live signal after the boot spawn) is a no-op. The gate
## is a Portal(platinum=true) rendered OPEN and rooted at the dais so its light pools over the
## whisper's heart. It is NOT registered in portal_states and never travels — E on its apron opens
## the ending confirm prompt (see _open_ending_prompt).
func _spawn_light_gate() -> void:
	if is_instance_valid(_light_gate):
		return
	if _loader == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	var gate := Portal.new()
	gate.platinum = true
	gate.object_id = "light_gate"
	gate.layer = "light"
	# Seat it a touch NORTH of the dais so the raised gate reads behind the awakening plinth and
	# the five portals' arc frames it (the reverse of a layer portal, which sits on the arc).
	var focus := _loader.cell_center_world(_loader.spawn_cell) + Vector2(0, -HH * 1.6)
	gate.global_position = focus
	gate.z_index = 3
	var host: Node = _loader if _loader != null else self
	host.add_child(gate)
	# Force it OPEN visually (it isn't in portal_states, so _apply_state won't be driven by the
	# portal signal — set it directly after _ready builds the parts).
	gate.call_deferred("_apply_state", GameState.PORTAL_OPEN)
	# A platinum floor pool under the gate (the sole new asset; light pooled at the door's foot).
	var pool_tex := load("res://assets/objects/light_pool_platinum.png") as Texture2D
	if pool_tex != null:
		var g := Sprite2D.new()
		g.texture = pool_tex
		g.centered = true
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		g.position = focus + Vector2(0, -4)
		g.scale = Vector2(1.6, 1.1)
		g.modulate = Color(1.0, 1.0, 1.0, 0.5)
		var gm := CanvasItemMaterial.new()
		gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		g.material = gm
		g.z_index = 2
		host.add_child(g)
	_light_gate = gate


## (EG-1) Open the 빛의 문 confirm prompt: 「들어가면, 세계가 완성된다. …정말?」 with three choices.
## [들어간다] = E1 (always available). [돌아선다] = E2 (locked until 진상 조각 5 → truth_final_seen).
## [아직 아니야] / ESC / walk-away = cancel: close + release control_lock, NO ending. QA 필수.
func _open_ending_prompt() -> void:
	if _ending_modal != null and is_instance_valid(_ending_modal):
		return
	if GameState != null:
		GameState.push_modal(ENDING_MODAL_KEY)
		GameState.set_control_lock(true)
	_ending_layer = CanvasLayer.new()
	_ending_layer.layer = 12
	add_child(_ending_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Clicking the dim = walk-away/cancel (ESC also cancels via _unhandled_key in the modal).
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_cancel_ending_prompt())
	_ending_layer.add_child(dim)
	_ending_modal = dim

	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 22)
	dim.add_child(panel)

	var line1 := Label.new()
	line1.text = "들어가면, 세계가 완성된다."
	line1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line1.add_theme_color_override("font_color", Color("#faf5e6"))
	line1.add_theme_font_size_override("font_size", 30)
	line1.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08, 0.9))
	line1.add_theme_constant_override("outline_size", 5)
	panel.add_child(line1)

	var line2 := Label.new()
	line2.text = "…정말?"
	line2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line2.add_theme_color_override("font_color", Color("#c8b0ec"))
	line2.add_theme_font_size_override("font_size", 24)
	panel.add_child(line2)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)

	row.add_child(_ending_button("들어간다", _choose_enter, false, ""))
	var shards_done := GameState != null and GameState.truth_final_seen
	var turn_tip := "" if shards_done else "아직… 이 세계를 두고 떠날 이유를 다 알지 못한다."
	row.add_child(_ending_button("돌아선다", _choose_turn_back, not shards_done, turn_tip))
	row.add_child(_ending_button("아직 아니야", _cancel_ending_prompt, false, ""))


## Build one ending-choice button. `locked` greys it + shows a tooltip and disables the action.
func _ending_button(label: String, cb: Callable, locked: bool, tip: String) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(140, 44)
	b.disabled = locked
	if tip != "":
		b.tooltip_text = tip
	var col := Color("#faf5e6") if not locked else Color(0.55, 0.53, 0.6)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.48, 0.55))
	if not locked:
		b.pressed.connect(cb)
	return b


## [들어간다] → E1「완성」.
func _choose_enter() -> void:
	_teardown_ending_modal()
	_play_ending("E1")


## [돌아선다] → E2「속삭임」 (only reachable when the button is enabled = truth_final_seen).
func _choose_turn_back() -> void:
	if GameState == null or not GameState.truth_final_seen:
		return
	_teardown_ending_modal()
	_play_ending("E2")


## [아직 아니야] / ESC / walk-away — cancel: close the prompt, restore control_lock, NO ending.
##횟수 무제한. This is the QA-mandated escape hatch (설계 §1.3) that keeps the E2 run alive.
func _cancel_ending_prompt() -> void:
	_teardown_ending_modal()


## Tear down the modal + release its modal key / control lock. Used by BOTH the cancel path and
## the commit path (before an ending plays). Idempotent.
func _teardown_ending_modal() -> void:
	if _ending_layer != null and is_instance_valid(_ending_layer):
		_ending_layer.queue_free()
	_ending_layer = null
	_ending_modal = null
	if GameState != null:
		GameState.pop_modal(ENDING_MODAL_KEY)
		GameState.set_control_lock(false)


## (EG-1/EG-3) Launch the ending sequence (E1 or E2) via the EndingSequence CanvasLayer.
func _play_ending(ending_id: String) -> void:
	if _ending_seq != null and is_instance_valid(_ending_seq):
		return
	var seq: CanvasLayer = EndingSequenceScript.new()
	add_child(seq)
	_ending_seq = seq
	seq.call("play", ending_id, _light_gate)


# ---- CS-05 return & ignition ---------------------------------------------

func _play_return_ignition() -> void:
	if _portal_cutscene != null and _portal_cutscene.has_method("play_return_ignition"):
		await _portal_cutscene.play_return_ignition()
	# The state changes (nature→open, science→flickering) + grass tufts + quest advance are
	# applied by the cutscene's signal callbacks (see PortalCutscene / QuestManager). Sprout
	# a few Layer-1 grass tufts near the arrival point as the "가져온 세계의 흔적".
	_sprout_arrival_grass()
	SaveManager.save_game()


## A few grass tufts grow near the player's arrival point on the home island (the trace of
## the world just purified). Authored decoratively — not gatherable clutter.
func _sprout_arrival_grass() -> void:
	if _loader == null or _player == null:
		return
	var base := _loader.world_to_cell(_player.global_position)
	var tuft_tex := load("res://assets/objects/grass_tuft.png") as Texture2D
	if tuft_tex == null:
		return
	var ysort := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ysort == null:
		return
	for off in [Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, -1), Vector2i(2, 1), Vector2i(-1, -1)]:
		var cell: Vector2i = base + off
		if not _loader.is_cell_walkable(cell):
			continue
		var s := Sprite2D.new()
		s.texture = tuft_tex
		s.offset = Vector2(0, -12)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = _loader.cell_center_world(cell)
		s.y_sort_enabled = true
		ysort.add_child(s)


# ---- helpers --------------------------------------------------------------

## Stone palette for the dais / pads (matches the cliff rock family, a touch cooler).
const STONE_BASE := Color8(122, 116, 112)
const STONE_DK := Color8(78, 74, 72)
const STONE_LT := Color8(158, 152, 146)
const STONE_TOP := Color8(140, 134, 130)
const DIRT_DK := Color8(74, 58, 44)      # darker earth for path lines / cracks
const SIGIL_COL := Color(0.30, 0.24, 0.40, 0.55)  # faint violet-grey etch

## Iso half-tile (mirrors MapLoader.TILE_HALF_*).
const HW := 64.0
const HH := 32.0


## Draw a proper RAISED round stone dais under the spawn: THREE concentric weathered stone
## slabs (each a stepped iso-diamond ring, lightest on top), a low front wall so it reads as a
## plinth the player stands ON, a faint carved whisper-sigil ring engraved into the top slab,
## and a soft violet glow pooled at its centre. Spawn sits at its centre.
func _draw_dais() -> void:
	if _loader == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	var center: Vector2 = _loader.cell_center_world(_loader.spawn_cell)
	var rise := 16.0                 # how tall the plinth stands
	var half_w := HW * 2.0           # outer diamond half width (≈ 2 tiles)
	var half_h := HH * 2.0
	var w := int(half_w * 2.0) + 4
	var h := int(half_h * 2.0 + rise) + 4
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := w * 0.5
	var cy := half_h + 2.0        # diamond centre (top surface); wall hangs below
	# Three concentric slab rings: outer (largest), mid, inner. Each steps up ~a hair and is a
	# touch lighter, so the dais reads as stacked weathered slabs, not a flat disc.
	var rings := [
		{"r": 1.00, "tone": 0.80, "lift": 0.0},
		{"r": 0.74, "tone": 0.92, "lift": 3.0},
		{"r": 0.46, "tone": 1.04, "lift": 6.0},
	]
	# top diamond surface (paint outer→inner so inner rings sit on top)
	for y in range(int(half_h * 2.0 + 2.0)):
		for x in range(w):
			var dx := absf(x - cx) / half_w
			var dy := absf(y - cy) / half_h
			var d := dx + dy
			if d > 1.0:
				continue
			# pick the innermost ring this pixel falls inside.
			var tone := 0.80
			var lift := 0.0
			var edge := false
			for ring in rings:
				if d <= float(ring["r"]):
					tone = float(ring["tone"])
					lift = float(ring["lift"])
				# carved groove just inside each ring boundary
				if absf(d - float(ring["r"])) < 0.03:
					edge = true
			var col := STONE_TOP * (tone * (0.94 + 0.10 * (1.0 - d)))
			if edge:
				col = STONE_DK
			# faint carved whisper-sigil ring engraved mid-slab
			if absf(d - 0.60) < 0.02 and not edge:
				col = col.lerp(Color(0.36, 0.28, 0.46), 0.5)
			col.a = 1.0
			img.set_pixel(x, int(y - lift), col)
	# front wall (the two lower diamond edges of the OUTER slab extruded down by `rise`)
	for x in range(w):
		var dxn := absf(x - cx) / half_w
		if dxn > 1.0:
			continue
		var rim := cy + (1.0 - dxn) * half_h
		for yy in range(int(rim), int(rim + rise)):
			if yy < 0 or yy >= h:
				continue
			var t := float(yy - rim) / rise
			var lit := 0.66 if x < cx else 0.84   # left face darker
			# stepped bands so the wall reads as stacked slab courses
			var band := 1.0 - 0.12 * float(int(t * 3.0))
			var col := STONE_DK.lerp(STONE_BASE, lit * band)
			col.a = 1.0
			img.set_pixel(x, yy, col)
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = center + Vector2(-cx, -cy)
	s.z_index = 1   # above ground tiles + traces, below the y-sorted player
	_loader.add_child(s)

	# Soft violet glow pooled at the dais centre (the whisper's heart). Additive light-pool decal.
	var glow_tex := load("res://assets/objects/light_pool_violet.png") as Texture2D
	if glow_tex != null:
		var g := Sprite2D.new()
		g.texture = glow_tex
		g.centered = true
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		g.position = center + Vector2(0, -6)
		g.scale = Vector2(1.4, 1.0)
		g.modulate = Color(1.0, 1.0, 1.0, 0.55)
		var gm := CanvasItemMaterial.new()
		gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		g.material = gm
		g.z_index = 2
		_loader.add_child(g)


## Draw the DEAD/WORN grass patches on each `g` cell: a low desaturated olive-tan mat of short
## dry blades on the barren dirt — the last傷 of a dying world, NOT a bright green square.
## Authored per cell (deterministic), drawn as a decal below the y-sorted player.
const DEAD_MAT := Color8(96, 92, 58)     # dry-grass mat base (olive-tan)
const DEAD_MAT_DK := Color8(70, 66, 40)
const DEAD_BLADE := Color8(122, 116, 72) # pale dry blade
const DEAD_BLADE_DK := Color8(84, 78, 46)

func _draw_dead_grass_patches() -> void:
	if _loader == null:
		return
	var cells: Array = _loader.cells_with_symbol("g")
	if cells.is_empty():
		return
	var node := Node2D.new()
	node.name = "DeadGrassPatches"
	node.z_index = 0
	var pts: Array = []
	for cell in cells:
		pts.append(_loader.cell_center_world(cell))
	var drawer := _DeadGrassDrawer.new()
	drawer.pts = pts
	node.add_child(drawer)
	_loader.add_child(node)


## Inner custom-draw helper for the dead-grass patches (deterministic sparse dry blades on a
## worn olive mat). Kept inline so no extra file is needed.
class _DeadGrassDrawer extends Node2D:
	var pts: Array = []
	const HW := 64.0
	const HH := 32.0

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		for p in pts:
			var c: Vector2 = p
			var seed := int(absf(c.x) * 3.0 + absf(c.y) * 7.0)
			# a worn olive mat (an iso ellipse of scattered soft dabs, ragged edge).
			for i in range(70):
				var h := (seed * 1103515245 + i * 12345 + 7) & 0x7fffffff
				var a := float(h % 628) / 100.0
				var rr := 0.30 + float((h >> 8) % 100) / 100.0 * 0.70
				var px := cos(a) * rr * (HW * 0.78)
				var py := sin(a) * rr * (HH * 0.78)
				var col := HomeSession.DEAD_MAT if ((h >> 3) % 3 != 0) else HomeSession.DEAD_MAT_DK
				draw_circle(c + Vector2(px, py), 3.0, Color(col.r, col.g, col.b, 0.42))
			# sparse short dry blades poking up.
			for j in range(14):
				var h2 := (seed * 22695477 + j * 6971 + 13) & 0x7fffffff
				var a2 := float(h2 % 628) / 100.0
				var rr2 := float((h2 >> 6) % 100) / 100.0 * 0.72
				var bx := c.x + cos(a2) * rr2 * (HW * 0.66)
				var by := c.y + sin(a2) * rr2 * (HH * 0.66)
				var blade := HomeSession.DEAD_BLADE if (j % 2 == 0) else HomeSession.DEAD_BLADE_DK
				var lean := (-2.0 if (h2 & 1) else 2.0)
				var hgt := 5.0 + float((h2 >> 4) % 5)
				draw_line(Vector2(bx, by), Vector2(bx + lean, by - hgt),
					Color(blade.r, blade.g, blade.b, 0.85), 1.5)


## Draw a small square stone PAD under the cauldron so it doesn't sit on bare dirt.
func _draw_cauldron_pad() -> void:
	if _loader == null or _loader.cauldron_cell == Vector2i(-1, -1):
		return
	var center: Vector2 = _loader.cell_center_world(_loader.cauldron_cell)
	var half_w := HW * 0.78
	var half_h := HH * 0.78
	var w := int(half_w * 2.0)
	var h := int(half_h * 2.0)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := w * 0.5
	var cy := h * 0.5
	for y in range(h):
		for x in range(w):
			var dx := absf(x - cx) / half_w
			var dy := absf(y - cy) / half_h
			if dx + dy <= 1.0:
				var shade := 0.82 + 0.16 * (1.0 - (dx + dy))
				var col := STONE_BASE * shade
				if absf((dx + dy) - 0.86) < 0.05:
					col = STONE_DK
				col.a = 1.0
				img.set_pixel(x, y, col)
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.centered = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = center
	s.z_index = 1
	_loader.add_child(s)


## Draw the barren-world "누군가 걸었던 자국": a faint darker path line from the dais to each
## portal, a subtle spiral whisper-sigil etched around the dais, and a few cracked-earth
## patches — so the barren ground reads as walked-upon and marked, not an empty pancake.
## All drawn as one custom-draw Node2D under the ground (below the dais/objects).
func _draw_ground_traces() -> void:
	if _loader == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	var node := Node2D.new()
	node.name = "GroundTraces"
	node.z_index = 0   # sits with the ground tiles, below the dais (z1) and objects
	# Precompute the world points the drawer needs.
	var dais: Vector2 = _loader.cell_center_world(_loader.spawn_cell)
	var portal_pts: Array = []
	for layer_id in _loader.portal_cells:
		portal_pts.append(_loader.cell_center_world(_loader.portal_cells[layer_id]))
	# cracked-earth patches on a handful of deterministic dirt cells.
	var crack_cells: Array = []
	for entry in [Vector2i(3, 2), Vector2i(-4, 1), Vector2i(2, -3), Vector2i(-2, 4),
			Vector2i(5, -1), Vector2i(-5, -2), Vector2i(1, 5), Vector2i(4, 3)]:
		var cell: Vector2i = _loader.spawn_cell + entry
		if _loader.is_cell_walkable(cell):
			crack_cells.append(_loader.cell_center_world(cell))
	var drawer := _TraceDrawer.new()
	drawer.dais = dais
	drawer.portal_pts = portal_pts
	drawer.crack_pts = crack_cells
	node.add_child(drawer)
	_loader.add_child(node)


## Inner custom-draw helper for the ground traces (path lines + sigil + cracks). Kept as an
## inner class so no extra file is needed; deterministic, purely decorative.
class _TraceDrawer extends Node2D:
	var dais: Vector2
	var portal_pts: Array = []
	var crack_pts: Array = []
	const PATH_COL := Color(0.30, 0.24, 0.19, 0.42)
	const SIGIL := Color(0.32, 0.26, 0.42, 0.5)
	const CRACK := Color(0.20, 0.15, 0.12, 0.5)

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		# Path lines dais → each portal (a soft double stroke so it reads as a worn trail).
		for p in portal_pts:
			var v: Vector2 = (p as Vector2) - dais
			var n := v.length()
			if n < 1.0:
				continue
			# don't run the trail all the way into the gate base; stop ~46px short.
			var end: Vector2 = dais + v * ((n - 46.0) / n)
			draw_line(dais, end, PATH_COL, 9.0, true)
			draw_line(dais, end, Color(PATH_COL.r, PATH_COL.g, PATH_COL.b, PATH_COL.a * 0.5), 16.0, true)
		# Spiral whisper-sigil etched around the dais (an Archimedean spiral, iso-squashed).
		var pts := PackedVector2Array()
		var turns := 2.4
		var steps := 90
		for i in range(steps + 1):
			var t := float(i) / float(steps)
			var ang := t * turns * TAU
			var rad := 60.0 + t * 92.0
			pts.append(dais + Vector2(cos(ang) * rad, sin(ang) * rad * 0.5))
		for i in range(pts.size() - 1):
			draw_line(pts[i], pts[i + 1], SIGIL, 2.0, true)
		# A faint sigil ring just outside the dais.
		_draw_iso_ring(dais, 150.0, SIGIL)
		# Cracked-earth patches: little branching dark cracks at each patch centre.
		for cp in crack_pts:
			var c: Vector2 = cp
			for k in range(5):
				var a := float(k) / 5.0 * TAU + (c.x + c.y) * 0.01
				var len := 10.0 + fmod((c.x * 7.0 + c.y * 3.0 + k * 13.0), 12.0)
				var tip := c + Vector2(cos(a), sin(a) * 0.5) * len
				draw_line(c, tip, CRACK, 1.5, true)

	func _draw_iso_ring(center: Vector2, rad: float, col: Color) -> void:
		var pts := PackedVector2Array()
		var steps := 48
		for i in range(steps + 1):
			var ang := float(i) / float(steps) * TAU
			pts.append(center + Vector2(cos(ang) * rad, sin(ang) * rad * 0.5))
		for i in range(pts.size() - 1):
			draw_line(pts[i], pts[i + 1], col, 2.0, true)


## Play the new-game awakening camera reveal (start zoomed on the dais, ease out to the arc).
## Finds the Player's Camera2D and calls its reveal beat. Safe no-op if not present (headless).
func _play_awakening_reveal() -> void:
	if _player == null:
		return
	var cam := _player.get_node_or_null("Camera2D")
	if cam != null and cam.has_method("play_awakening_reveal"):
		cam.play_awakening_reveal()


## Land the player near the dais on return (a walkable cell just south of the spawn).
func _place_at_arrival() -> void:
	if _loader == null or _player == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	var arrival: Vector2i = _loader.spawn_cell + Vector2i(0, 1)
	if not _loader.is_cell_walkable(arrival):
		arrival = _loader.spawn_cell
	_player.global_position = _loader.cell_center_world(arrival)
	if _player.has_method("clear_path"):
		_player.clear_path()


func _float_hint(world: Vector2, msg: String) -> void:
	FloatingLabel.spawn(_loader if _loader != null else self, world - Vector2(0, 20), msg)
