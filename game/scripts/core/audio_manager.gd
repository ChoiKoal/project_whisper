extends Node
## AudioManager — global autoload. Plays procedural SFX one-shots and crossfades the
## day/night BGM on GameState.day_phase_changed. Exposes master/sfx/bgm volumes
## (persisted to user://audio.cfg, surfaced as pause-menu sliders).
##
## v0.5b AUDIO FINALIZE: the day/night BGM is now real CC0 .ogg ambient music
## (bgm_day.ogg = "relaxing ambient" by isaiah658, bgm_night.ogg = "cathedral forest"
## by congusbongus — both CC0, see CREDITS.md). These loop via the .ogg import `loop=true`
## flag AND a defensive `stream.loop = true` set here. The old synth bgm_day/bgm_night.wav
## and the separate synth day_amb/night_amb ambience WAVs were DELETED — the CC0 music
## carries the whole day/night soundscape, so the redundant ambience layer is retired.
## SFX remain the .wav one-shots synthesized by tools_gen_audio.py; loop SFX (fuse_bubble)
## still get AudioStreamWAV.loop_mode = FORWARD set in code.
##
## Headless-safe: audio playback is silent under --headless but must not error. Every play
## call guards a missing stream and a missing player, so the harness can call play_sfx and
## crossfade_bgm without a device.

const AUDIO_DIR := "res://assets/audio/"
const CONFIG_PATH := "user://audio.cfg"

## SFX that ship as one-shots (name -> loaded stream). Loops handled separately.
const SFX_NAMES := [
	"gather_pop", "place_thud", "fuse_bubble", "fuse_success", "fuse_discovery",
	"fuse_fail", "ui_click", "ui_open", "ui_close", "quest_advance",
	"footstep_grass1", "footstep_grass2", "bush_bloom", "clear_fanfare",
	# v0.5.0 phase C: portal SFX (synth WAVs).
	"portal_hum", "travel_whoosh", "portal_ignite",
	# L2-3: power / gate SFX (전력 hum + 스파크).
	"power_hum", "power_spark",
]
## Streams that must loop (the CC0 BGM oggs + the fuse-bubble SFX).
const LOOP_NAMES := ["fuse_bubble", "bgm_day", "bgm_night"]

## Bus names (created at runtime so no .tres bus layout is required).
const BUS_MASTER := "Master"
const BUS_SFX := "SFX"
const BUS_BGM := "BGM"

var _streams: Dictionary = {}          # name -> AudioStream
var _sfx_players: Array = []           # pool of AudioStreamPlayer for SFX
var _sfx_next := 0
var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _bgm_cur: AudioStreamPlayer        # the currently-audible BGM player
var _amb: AudioStreamPlayer
var _cur_bgm_name := ""
var _cur_amb_name := ""

## Linear volumes 0..1 (persisted).
var volume_master := 0.9
var volume_sfx := 1.0
## v0.5b: BGM default kept modest so the CC0 music sits UNDER the SFX (~-8 dB).
var volume_bgm := 0.4

const SFX_POOL := 8


func _ready() -> void:
	_ensure_buses()
	_load_streams()
	_build_players()
	_load_config()
	_apply_volumes()
	if GameState != null:
		GameState.day_phase_changed.connect(_on_phase)
		_wire_gameplay_sfx()


## Centralized gameplay → SFX wiring (works regardless of per-caller code). Fusion plays a
## discovery sting on a first-time recipe and a success chime on a repeat craft; both never
## fire for the same event because recipe_discovered precedes item_crafted only on a new
## recipe, and we suppress the success chime when a discovery just fired this frame.
var _discovered_this_frame := false


func _wire_gameplay_sfx() -> void:
	GameState.item_gathered.connect(func(_id): play_sfx("gather_pop"))
	GameState.recipe_discovered.connect(func(_rid):
		_discovered_this_frame = true
		play_sfx("fuse_discovery")
		call_deferred("_clear_discovery_flag"))
	GameState.item_crafted.connect(func(_out, _rid):
		if not _discovered_this_frame:
			play_sfx("fuse_success"))
	GameState.stepping_stone_placed.connect(func(_cell): play_sfx("place_thud"))
	GameState.placed_object_placed.connect(func(_id, _cell): play_sfx("place_thud"))
	GameState.item_used_on_object.connect(func(_item, obj):
		if obj != null and String(obj.get("object_id")) == "bush_dry":
			play_sfx("bush_bloom"))
	GameState.world_tree_planted.connect(func(_cell): play_sfx("clear_fanfare"))
	# UI open/close chime, centralized on the modal transition (any window).
	if GameState.has_signal("ui_modal_changed"):
		GameState.ui_modal_changed.connect(func(open): play_sfx("ui_open" if open else "ui_close"))


func _clear_discovery_flag() -> void:
	_discovered_this_frame = false


# ==== setup ================================================================

func _ensure_buses() -> void:
	for bus in [BUS_SFX, BUS_BGM]:
		if AudioServer.get_bus_index(bus) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, BUS_MASTER)


func _load_streams() -> void:
	for name_v in SFX_NAMES + ["bgm_day", "bgm_night"]:
		var name := String(name_v)
		# v0.5: BGM is now real CC0 .ogg (see CREDITS.md); everything else stays .wav.
		# Prefer an .ogg if one exists for this name, else fall back to the .wav.
		var ogg_path := AUDIO_DIR + name + ".ogg"
		var wav_path := AUDIO_DIR + name + ".wav"
		var path := ogg_path if ResourceLoader.exists(ogg_path) else wav_path
		if not ResourceLoader.exists(path):
			push_warning("AudioManager: missing stream %s" % path)
			continue
		var s = load(path)
		if s is AudioStreamWAV and name in LOOP_NAMES:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = s.data.size() / 2   # 16-bit mono → 2 bytes/frame
		elif s is AudioStreamOggVorbis and name in LOOP_NAMES:
			# Ogg Vorbis loops via its own `loop` flag (seamless CC0 ambient loops).
			s.loop = true
		_streams[name] = s


func _build_players() -> void:
	for i in range(SFX_POOL):
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_sfx_players.append(p)
	_bgm_a = AudioStreamPlayer.new(); _bgm_a.bus = BUS_BGM; add_child(_bgm_a)
	_bgm_b = AudioStreamPlayer.new(); _bgm_b.bus = BUS_BGM; add_child(_bgm_b)
	_bgm_cur = _bgm_a
	_amb = AudioStreamPlayer.new(); _amb.bus = BUS_BGM; add_child(_amb)


# ==== SFX ==================================================================

## Play a one-shot SFX by name. No-op (with a warning) for an unknown name; safe headless.
func play_sfx(name: String) -> void:
	var s = _streams.get(name)
	if s == null:
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = s
	p.play()


## Whether a stream is loaded (used by tests / callers gating optional SFX).
func has_stream(name: String) -> bool:
	return _streams.has(name)


# ==== BGM crossfade ========================================================

## Crossfade to the BGM for a day/night phase. day/dawn → bgm_day, evening/night → bgm_night.
func crossfade_bgm_for_phase(phase: String) -> void:
	var target := "bgm_night" if phase in ["evening", "night"] else "bgm_day"
	crossfade_bgm(target)


## Crossfade the BGM to `name` over `secs`. Idempotent if already playing `name`.
func crossfade_bgm(name: String, secs: float = 1.5) -> void:
	if name == _cur_bgm_name:
		return
	var s = _streams.get(name)
	if s == null:
		return
	_cur_bgm_name = name
	var from_player := _bgm_cur
	var to_player := _bgm_b if _bgm_cur == _bgm_a else _bgm_a
	to_player.stream = s
	to_player.volume_db = -40.0
	to_player.play()
	_bgm_cur = to_player
	# Guard tweens for headless: create_tween needs the tree (present as autoload child).
	var full := linear_to_db(max(0.0001, volume_bgm))
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(to_player, "volume_db", full, secs)
	tw.tween_property(from_player, "volume_db", -40.0, secs)
	tw.chain().tween_callback(func():
		if from_player != _bgm_cur:
			from_player.stop())


func _on_phase(phase: String) -> void:
	crossfade_bgm_for_phase(phase)
	_update_ambience(phase)


# ==== ambience =============================================================

func _update_ambience(phase: String) -> void:
	# v0.5b: the dedicated synth ambience layer (day_amb/night_amb) was retired — the CC0
	# BGM oggs carry the day/night soundscape. This stays as a graceful no-op (no stream
	# loaded), so callers (start_world_audio / _on_phase) need no changes.
	var target := "night_amb" if phase in ["evening", "night"] else "day_amb"
	if target == _cur_amb_name:
		return
	var s = _streams.get(target)
	if s == null:
		return
	_cur_amb_name = target
	_amb.stream = s
	_amb.volume_db = linear_to_db(max(0.0001, volume_bgm * 0.5))
	_amb.play()


## Start the soundscape for the current phase (call when a world scene loads).
func start_world_audio() -> void:
	var phase := GameState.phase() if GameState != null else "day"
	crossfade_bgm_for_phase(phase)
	_update_ambience(phase)


## (v0.5.0 phase C) Home island = quieter, sparser ambience. On the home world we drop the
## BGM bus an extra ~6 dB so the 제0세계 reads as a hushed, near-empty place; the grove
## restores full BGM. Implemented as an extra multiplier on the BGM bus (leaves the user's
## saved volume_bgm untouched).
var _home_ambience := false
const HOME_BGM_SCALE := 0.5   # ≈ −6 dB under the normal BGM level

func set_home_ambience(on: bool) -> void:
	if on == _home_ambience:
		return
	_home_ambience = on
	var idx := AudioServer.get_bus_index(BUS_BGM)
	if idx == -1:
		return
	var lin := volume_bgm * (HOME_BGM_SCALE if on else 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(0.0001, lin)))


func stop_all() -> void:
	for p in _sfx_players:
		p.stop()
	_bgm_a.stop(); _bgm_b.stop(); _amb.stop()
	_cur_bgm_name = ""
	_cur_amb_name = ""


# ==== volumes + persistence ================================================

func set_volume(kind: String, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	match kind:
		"master": volume_master = value
		"sfx": volume_sfx = value
		"bgm": volume_bgm = value
	_apply_volumes()
	_save_config()


func _apply_volumes() -> void:
	_set_bus_db(BUS_MASTER, volume_master)
	_set_bus_db(BUS_SFX, volume_sfx)
	_set_bus_db(BUS_BGM, volume_bgm)


func _set_bus_db(bus: String, lin: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(0.0001, lin)))
	AudioServer.set_bus_mute(idx, lin <= 0.0001)


func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	volume_master = float(cfg.get_value("audio", "master", volume_master))
	volume_sfx = float(cfg.get_value("audio", "sfx", volume_sfx))
	volume_bgm = float(cfg.get_value("audio", "bgm", volume_bgm))


func _save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", volume_master)
	cfg.set_value("audio", "sfx", volume_sfx)
	cfg.set_value("audio", "bgm", volume_bgm)
	cfg.save(CONFIG_PATH)
