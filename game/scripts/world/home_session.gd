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

	_draw_dais()
	_wire_portals()

	# Apply a pending load into this live scene (이어하기 that saved in the home world).
	if SaveManager.pending_load:
		SaveManager.pending_load = false
		SaveManager.load_game()

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


# ---- portals --------------------------------------------------------------

func _wire_portals() -> void:
	for node in get_tree().get_nodes_in_group("gatherable"):
		if node is Portal:
			(node as Portal).portal_interacted.connect(_on_portal_interacted)


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
	var dest := WorldContext.SCENE_GROVE  # v0.5: every enterable layer routes to the grove
	if _portal_cutscene != null and _portal_cutscene.has_method("play_travel"):
		_portal_cutscene.play_travel(func():
			WorldContext.current_scene = dest
			get_tree().change_scene_to_file(WorldContext.scene_path(dest)))
	else:
		WorldContext.current_scene = dest
		get_tree().change_scene_to_file(WorldContext.scene_path(dest))


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

## Draw a small round stone dais under the spawn cell so the centre reads as a plinth.
func _draw_dais() -> void:
	if _loader == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	var r := 42
	var img := Image.create(r * 2, r, false, Image.FORMAT_RGBA8)  # iso-squashed disc
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(r, r * 0.5)
	for y in range(r):
		for x in range(r * 2):
			var dx := (x - c.x) / float(r)
			var dy := (y - c.y) / float(r * 0.5)
			if dx * dx + dy * dy <= 1.0:
				var shade := 0.62 + 0.14 * (1.0 - (dx * dx + dy * dy))
				var col := Color(0.46, 0.44, 0.42) * shade
				col.a = 1.0
				img.set_pixel(x, y, col)
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.centered = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = _loader.cell_center_world(_loader.spawn_cell)
	s.z_index = 1   # above ground tiles, below the y-sorted player
	_loader.add_child(s)


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
