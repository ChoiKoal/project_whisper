extends CanvasLayer
class_name ClearSequence
## CS-04 「정화」 (v0.5.0 phase C — replaces the old G4 clear cutscene). Listens for
## GameState.world_tree_planted (emitted when D22 어린 세계수 is placed on a T0 VOID/HOLLOW
## cell). Plays the purification per docs/project-whisper-cutscenes-v2.md CS-04:
##   1. one-frame WHITE flash
##   2. a light ripple RING expands from the planted cell; VOID/HOLLOW cells it passes tint
##      faintly green (the world remembers being emptied, now healing)
##   3. text cards: "세계가, 숨을 뱉었어." / "…들려? 방금, 세계가 대답했어." /
##      "돌아갈 시간이야. 나의 세계로."
##   4. emits `cleared` → GroveSession auto-returns to the home island (CS-05 queued)
##
## Layered above everything (layer 10). Pauses GameState time during the beat.

const BG := Color("#1a1420")
const CREAM := Color("#faf5e6")
const VIOLET := Color("#9e7ad9")
const HEAL_GREEN := Color(0.42, 0.72, 0.36, 1.0)
const HOLLOW_SOURCE := 11
const ATLAS := Vector2i(0, 0)

const CARDS := [
	"세계가, 숨을 뱉었다.",
	"…들려? 방금, 세계가 대답했어.",
	"돌아갈 시간이야. 나의 세계로.",
]

var _flash: ColorRect
var _ring: Sprite2D
var _dim: ColorRect
var _line: Label
var _active: bool = false
var _planted_cell: Vector2i = Vector2i(-999, -999)

## Optional map loader (set by the scene) so the ring can green-tint hollow cells.
@export var map_loader_path: NodePath
var _loader: MapLoader

signal cleared


func _ready() -> void:
	layer = 10
	_build()
	_loader = get_node_or_null(map_loader_path) as MapLoader
	GameState.world_tree_planted.connect(_on_planted)


func _build() -> void:
	# Full-screen white flash (1-frame bloom).
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	# A soft dim so the text reads over the world.
	_dim = ColorRect.new()
	_dim.color = Color(BG.r, BG.g, BG.b, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(center)
	_line = Label.new()
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.add_theme_color_override("font_color", CREAM)
	_line.add_theme_font_size_override("font_size", 30)
	_line.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08, 0.9))
	_line.add_theme_constant_override("outline_size", 5)
	_line.modulate.a = 0.0
	center.add_child(_line)


func is_active() -> bool:
	return _active


func _on_planted(cell: Vector2i) -> void:
	if _active:
		return
	_planted_cell = cell
	play()


## Public entry (also the harness hook). Plays the purification then emits `cleared`.
func play() -> void:
	_active = true
	GameState.time_running = false
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("clear_fanfare")
	_run()


func _run() -> void:
	# 1. white flash (CQ-2: shared Director flash).
	await CutsceneDirector.flash(self, _flash, 0.9, 0.08, 0.8)

	# 2. expanding ripple ring + green-tint the hollow cells (visual, best-effort).
	_spawn_ring()
	_heal_hollow_cells()

	# 3. text cards over a soft dim.
	var dtw := create_tween()
	dtw.tween_property(_dim, "color:a", 0.55, 1.0)
	await dtw.finished
	# Card 1 — "세계가, 숨을 뱉었다."
	await _card(CARDS[0])
	# (CQ-4 G8) 새소리 — 이번엔 다른 멜로디. 반복이 깨졌다 (CS-04 핵심 모티프): 두 번,
	# 두 번째는 살짝 다른 피치로 재생해 '같은 새·같은 노래'의 루프가 깨졌음을 소리로.
	await _broken_birdsong()
	# Card 2 — "…들려? 방금, 세계가 대답했어."
	await _card(CARDS[1])
	# (CQ-4 G9) 3초 정적 — 대사도 소리도 없이. 그리고 발밑에서 보라 빛이 차오른다.
	await _silence_then_rising_light()
	# Card 3 — "돌아갈 시간이야. 나의 세계로."
	await _card(CARDS[2])

	# 4. hand off to the auto-return.
	# (v0.6.1) Restore time BEFORE emitting cleared. GameState.time_running is an autoload
	# flag that persists across the change_scene into the home island; leaving it false here
	# left the home scene booting with time frozen (day/night stalled, HomeSession treating the
	# world as permanently locked). The L2 purification (l2_gate_controller) already pairs its
	# false→true — this L1 clear beat was the one path that never restored it.
	_active = false
	if GameState != null:
		GameState.time_running = true
	cleared.emit()


func _card(text: String) -> void:
	_line.text = text
	var tw := create_tween()
	tw.tween_property(_line, "modulate:a", 1.0, 0.7)
	tw.tween_interval(1.1)
	tw.tween_property(_line, "modulate:a", 0.0, 0.5)
	await tw.finished


## (CQ-4 G8) The world's answer: birdsong that is no longer the same loop. Two calls, the
## second faintly pitch-shifted (playback via a temp player) so the "반복이 깨졌다" reads by ear.
func _broken_birdsong() -> void:
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("bird")
	await get_tree().create_timer(0.9, true, false, true).timeout
	_play_bird_shifted(1.18)
	await get_tree().create_timer(0.9, true, false, true).timeout


## Play the bird stream at a shifted pitch (a different melody) via a one-shot temp player.
## Best-effort: falls back to the plain sfx if the stream isn't loaded.
func _play_bird_shifted(pitch: float) -> void:
	if AudioManager == null or not AudioManager.has_method("has_stream"):
		return
	if not AudioManager.has_stream("bird"):
		return
	var p := AudioStreamPlayer.new()
	p.stream = AudioManager._streams.get("bird")
	p.pitch_scale = pitch
	p.bus = "SFX"
	add_child(p)
	p.finished.connect(func():
		if is_instance_valid(p):
			p.queue_free())
	p.play()


## (CQ-4 G9) 3초 정적 → 발밑에서 보라 빛이 상승 (플레이어가 빛에 감싸이며 떠오르는 예고).
## A full-screen violet ColorRect rising from the bottom, deepening as the beat holds.
func _silence_then_rising_light() -> void:
	await get_tree().create_timer(3.0, true, false, true).timeout
	var rise := ColorRect.new()
	rise.color = Color(0.42, 0.28, 0.62, 0.0)
	rise.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	rise.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rise.custom_minimum_size = Vector2(0, 0)
	rise.size.y = 0
	rise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rise)
	var vp := get_viewport()
	var full_h: float = vp.get_visible_rect().size.y if vp != null else 900.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(rise, "size:y", full_h, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(rise, "color:a", 0.55, 1.4)
	await tw.finished


## A light ripple ring expanding from the planted cell (CQ-2: shared Director ring).
func _spawn_ring() -> void:
	if _loader == null:
		return
	var ysort := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ysort == null:
		return
	_ring = CutsceneDirector.spawn_ripple_ring(
		self, ysort, _loader.cell_center_world(_planted_cell),
		Color(0.8, 1.0, 0.85), 16.0, 1.6, 50)


## Faintly green-tint every HOLLOW (빈 자국) cell — the world healing as the ripple passes.
func _heal_hollow_cells() -> void:
	if _loader == null:
		return
	for r in range(_loader.height):
		var row: String = _loader._layout[r] if r < _loader._layout.size() else ""
		for c in range(min(_loader.width, row.length())):
			var cell := Vector2i(c, r)
			if _loader.get_cell_source_id(cell) == HOLLOW_SOURCE:
				# A green modulate overlay diamond on the healed spot (visual only).
				var s := Sprite2D.new()
				var img := CliffGen.make_ao_diamond(0.0)  # placeholder shape reuse
				# Recolour: a soft green diamond.
				var gi := Image.create(128, 64, false, Image.FORMAT_RGBA8)
				gi.fill(Color(0, 0, 0, 0))
				for yy in range(64):
					for xx in range(128):
						var dx := absf(float(xx - 64)) / 64.0
						var dy := absf(float(yy - 32)) / 32.0
						if dx + dy <= 1.0:
							var a := clampf((1.0 - (dx + dy)) / 0.8, 0.0, 1.0)
							gi.set_pixel(xx, yy, Color(HEAL_GREEN.r, HEAL_GREEN.g, HEAL_GREEN.b, a * 0.35))
				s.texture = ImageTexture.create_from_image(gi)
				s.centered = false
				s.position = _loader.cell_center_world(cell) + Vector2(-64, -32)
				s.z_index = 2
				var mat := CanvasItemMaterial.new()
				mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				s.material = mat
				_loader.add_child(s)
