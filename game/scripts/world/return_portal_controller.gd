extends Node
class_name ReturnPortalController
## (v0.6.0) The shared 귀환(return) portal for the grove (Layer 1) and terminal_station (Layer 2).
##
## Owner report: the old grove return portal predated the v0.5.1 entry-zone pattern — it was
## spawned as a bare Portal with only `portal_interacted` connected, relying on the
## InteractionController's facing-cell adjacency to fire. That reads as a "weak" interaction: no
## front apron, no floating "E …" prompt, no click-walk-then-enter affordance. Home portals, by
## contrast, run HomeSession's per-frame entry-zone loop. This controller factors that loop out so
## BOTH return portals behave EXACTLY like the home gates:
##   • a real Portal (state = OPEN, monumental gate art, not a placeholder),
##   • a generous front Area2D entry zone (Portal._build_entry_zone),
##   • a floating "E 홈으로 돌아가기" prompt while standing in the apron,
##   • keyboard E enters (consumed ahead of the InteractionController),
##   • click / tap walks to the apron then enters (touch_controller's generic Portal handling),
##   • state glow (the OPEN violet vortex + rune/sigil light).
##
## The session that owns the world creates one of these, points it at its MapLoader + Player, and
## connects `entered` to its own "travel home" routine. Kept as a Node (added as a child of the
## session) so its _process/_input run inside the scene tree.
##
## Headless-safe: guards every autoload/node. Under --headless the prompt Label is still created
## (invisible) so is_player_in_entry_zone()/entry text can be asserted by the harness.

## Emitted when the player commits to the return portal (E in apron, or click-walk-then-enter).
signal entered()

## The spawned Portal (state OPEN, layer "return").
var portal: Portal = null

var _loader: MapLoader
var _player: Node2D
var _host: Node                 ## where the prompt Label is parented (the loader, ideally)
var _prompt_text: String = "E 홈으로 돌아가기"
var _entry_prompt: Label = null
var _active: bool = false       ## player currently in the apron
var _ready_done: bool = false


## Build + place the return portal. `cell_candidates` are tried in order for a walkable stand
## cell near the spawn; the first walkable one wins. Returns the Portal (or null on failure).
func setup(loader: MapLoader, player: Node2D, cell_candidates: Array, prompt_text: String = "E 홈으로 돌아가기") -> Portal:
	_loader = loader
	_player = player
	_prompt_text = prompt_text
	if _loader == null:
		return null
	var ysort := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ysort == null:
		return null
	_host = _loader
	# Pick the first walkable candidate cell.
	var cell := Vector2i(-1, -1)
	for c in cell_candidates:
		if c is Vector2i and _loader.is_cell_walkable(c):
			cell = c
			break
	if cell == Vector2i(-1, -1):
		# Fallback: the spawn cell itself.
		cell = _loader.spawn_cell
	if cell == Vector2i(-1, -1):
		return null
	# Force OPEN before add_child so Portal._ready adopts the OPEN visual on build.
	if GameState != null:
		GameState.set_portal_state("return", GameState.PORTAL_OPEN)
	var scr := load("res://scripts/world/portal.gd")
	if scr == null:
		return null
	var p: Portal = scr.new()
	if p == null:
		return null
	p.layer = "return"
	p.object_id = "portal_return"
	p.prompt_override = _prompt_text
	p.position = _loader.cell_center_world(cell)
	p.y_sort_enabled = true
	ysort.add_child(p)
	portal = p
	if p.has_signal("portal_interacted"):
		p.portal_interacted.connect(_on_portal_interacted)
	_ready_done = true
	set_process(true)
	return p


## Per-frame: mirror HomeSession — track whether the player is in the return gate's apron and
## show the state-driven prompt. Suppressed while a modal window is open or time is stopped
## (cutscene / travel swell), so the prompt never floats during a transition.
func _process(_delta: float) -> void:
	if not _ready_done or portal == null or not is_instance_valid(portal):
		return
	var locked := GameState != null and (GameState.ui_modal_open() or not GameState.time_running)
	var here := (not locked) and portal.is_player_in_entry_zone()
	_active = here
	_update_prompt()


## Keyboard entry: pressing `interact` while in the apron enters the portal. Uses _input (ahead of
## the InteractionController's _unhandled_input) and marks it handled so the same press isn't also
## consumed as a gather/facing interaction.
func _input(event: InputEvent) -> void:
	if not _active or portal == null or not is_instance_valid(portal):
		return
	if GameState != null and (GameState.ui_modal_open() or not GameState.time_running):
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		portal.on_interact()


func _update_prompt() -> void:
	if not _active:
		if _entry_prompt != null:
			_entry_prompt.visible = false
		return
	if _entry_prompt == null:
		_entry_prompt = _make_prompt()
	_entry_prompt.text = portal.entry_prompt_text()
	_entry_prompt.visible = true
	_entry_prompt.size = _entry_prompt.get_minimum_size()
	var anchor: Vector2 = portal.target_point()
	_entry_prompt.global_position = anchor - Vector2(_entry_prompt.size.x * 0.5, 24)


## The floating prompt pill (matches HomeSession's gate prompt styling, cyan-tinted border for the
## science/return read).
func _make_prompt() -> Label:
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
	sb.border_color = Color(0.62, 0.60, 0.85, 0.75)
	l.add_theme_stylebox_override("normal", sb)
	l.z_index = 100
	var host: Node = _host if _host != null else self
	host.add_child(l)
	return l


func _on_portal_interacted(_p) -> void:
	entered.emit()
