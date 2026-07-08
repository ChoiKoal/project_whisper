extends Control
class_name Opening
## Opening cutscene (v0.2.1) — shown only on 새로 시작 (title → opening → grove).
## 이어하기 / NG+ skip straight to the grove (they never load this scene).
##
## Black screen; 4 cream text cards fade in → hold → fade out in sequence
## (프롤로그, storyline §1 / §7). Each card auto-advances (~2.5s visible); a
## click / E / Space skips to the next card; "건너뛰기 (ESC)" bottom-right skips
## the whole sequence. When the last card finishes, fades to black and changes to
## starting_grove.tscn.
##
## Everything is code-built (no fragile .tscn) and driven by a single Tween chain
## per card, so the flow is deterministic and the m7 harness can drive it headlessly
## via advance() / skip_all().

## CS-01 (v0.5.0) fades into the HOME island (제0세계) — the player awakens on their own
## empty world, not the grove.
const HOME_SCENE := "res://scenes/world/home_island.tscn"

const CREAM := Color("#faf5e6")
const VIOLET := Color("#9e7ad9")
const MUTED := Color("#b8b4a8")

## Timing (seconds). (v0.4.0-B B4) fades lengthened a touch for a softer, higher-quality
## feel and to let the per-card background tint cross-fade breathe.
const FADE_IN := 1.0
const HOLD := 2.6
const FADE_OUT := 0.9
const FINAL_FADE := 1.1
## (B4) how long the backdrop takes to drift to the next card's tint.
const TINT_FADE := 1.4

## CS-01 「각성」 (v0.5 개정판 — 제0세계에서 시작). Per docs/project-whisper-cutscenes-v2.md.
const CARDS := [
	"어둠 속에서, 누군가 나를 불렀다.",
	"…아니. 부른 게 아니라, 속삭였다.",
	"여기가 나의 세계라고 했다. …아무것도 없는데.",
	"문 하나가, 숨을 쉬고 있었다.",
]

## (B4) One deep, near-black tint per card — the backdrop drifts between them so the
## mood shifts subtly as the prologue unfolds (waking dark → cool stillness → violet
## self → a warmer stir of intent). Kept very dark so text legibility never suffers.
const CARD_TINTS := [
	Color(0.020, 0.020, 0.030, 1.0),   # waking — near-black
	Color(0.022, 0.030, 0.044, 1.0),   # cool blue stillness
	Color(0.038, 0.028, 0.052, 1.0),   # violet — "나는 컨스트럭터"
	Color(0.044, 0.034, 0.036, 1.0),   # a faint warm stir of intent
]

var _label: Label
var _skip_hint: Label
var _fade: ColorRect
var _bg: ColorRect
## Running tint tween so an advance() mid-drift restarts cleanly.
var _tint_tween: Tween
var _index: int = -1
var _card_tween: Tween
var _finishing: bool = false
## Guards re-entrant advance() (a click landing mid-transition).
var _busy: bool = false
## (CQ-3 G1/G2) True during the pre-card CS-01 intro (purple-dot heartbeat → island
## silhouette). A click / ESC during the intro fast-forwards straight to the cards.
var _intro_playing: bool = false
var _intro_done: bool = false
## The faint island silhouette + starfield revealed under the second card (G2).
var _stars: Node2D
var _isle: Node2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_play_intro()


## (CQ-3 G1) CS-01 opening: 검은 화면. 아주 작은 보라 점 하나가 심장박동처럼 두 번 깜빡인다.
## (G2) 점이 커지며 흐릿한 부유섬 실루엣으로, 별하늘 배경. Then the cards proceed.
func _play_intro() -> void:
	_intro_playing = true
	if Codex != null and Codex.has_method("mark_cutscene_seen"):
		Codex.mark_cutscene_seen("CS-01")
	# 낮은 톤의 단음 (best-effort — reuses the portal hum as a low single tone).
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("portal_hum")
	# 보라 점 심장박동 2회 (shared Director rhythm — E2 「대답」이 이걸 회수한다).
	await CutsceneDirector.purple_dot_heartbeat(self, self, 2)
	if _finishing:
		return
	# 점이 커지며 → 흐릿한 부유섬 실루엣 + 별하늘 페이드인 (아주 낮은 대비).
	_reveal_starfield_and_isle()
	if not _intro_done:
		await get_tree().create_timer(1.4, true, false, true).timeout
	_intro_playing = false
	_intro_done = true
	if not _finishing:
		_show_card(0)


## Build a faint starfield + a floating-island silhouette behind the cards, fading them in.
## Drawn once with a small Node2D that scatters dim star dots + a dark isle diamond.
func _reveal_starfield_and_isle() -> void:
	if _stars != null:
		return
	_stars = _StarfieldIsle.new()
	_stars.modulate.a = 0.0
	# Sit just above the backdrop, below the text label.
	add_child(_stars)
	move_child(_stars, 1)
	var tw := create_tween()
	tw.tween_property(_stars, "modulate:a", 0.5, 1.6).set_trans(Tween.TRANS_SINE)


## A tiny procedural starfield + floating-island silhouette (CS-01 별하늘 + 부유섬). Node2D so
## it draws over the ColorRect backdrop; deterministic seed so the sky is stable per boot.
class _StarfieldIsle extends Node2D:
	func _draw() -> void:
		var vp := get_viewport()
		var sz: Vector2 = vp.get_visible_rect().size if vp != null else Vector2(1600, 900)
		var rng := RandomNumberGenerator.new()
		rng.seed = 0x5748  # "WH" — stable sky
		for i in range(90):
			var p := Vector2(rng.randf() * sz.x, rng.randf() * sz.y * 0.9)
			var a := rng.randf_range(0.25, 0.9)
			draw_circle(p, rng.randf_range(0.6, 1.6), Color(0.85, 0.86, 0.95, a))
		# Floating-island silhouette: a dark iso diamond low-centre with a tapered underside.
		var c := Vector2(sz.x * 0.5, sz.y * 0.62)
		var hw := sz.x * 0.13
		var hh := sz.y * 0.045
		var top := c + Vector2(0, -hh)
		var isle := PackedVector2Array([
			c + Vector2(-hw, 0), top, c + Vector2(hw, 0),
			c + Vector2(hw * 0.6, hh * 1.4), c + Vector2(0, hh * 3.2), c + Vector2(-hw * 0.6, hh * 1.4)])
		draw_colored_polygon(isle, Color(0.05, 0.05, 0.09, 0.85))


func _build() -> void:
	# Backdrop — starts on the first card's deep tint and drifts per card (B4).
	_bg = ColorRect.new()
	_bg.color = CARD_TINTS[0]
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# Centered card text.
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", CREAM)
	_label.add_theme_font_size_override("font_size", 34)
	# Subtle letter-spacing via a large-ish shadow-free tracking; Godot Label has no
	# native letter-spacing, so approximate with a small extra character spacing font
	# constant where available, else rely on the size + centering for legibility.
	_label.add_theme_constant_override("line_spacing", 10)
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08, 0.9))
	_label.add_theme_constant_override("outline_size", 4)
	# Keep text off the extreme edges.
	_label.offset_left = 140
	_label.offset_right = -140
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.modulate.a = 0.0
	add_child(_label)

	# "건너뛰기 (ESC)" bottom-right.
	_skip_hint = Label.new()
	_skip_hint.text = "건너뛰기 (ESC)"
	_skip_hint.add_theme_color_override("font_color", Color(MUTED.r, MUTED.g, MUTED.b, 0.75))
	_skip_hint.add_theme_font_size_override("font_size", 18)
	_skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip_hint.position = Vector2(-190, -46)
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skip_hint)

	# Full-screen fade overlay for the final transition into the grove.
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.02, 0.03, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


## Show card `i` with a fade-in → hold → fade-out chain. When the chain finishes,
## it auto-advances to the next card (or ends the sequence).
func _show_card(i: int) -> void:
	if _finishing:
		return
	if i >= CARDS.size():
		_finish()
		return
	_index = i
	_busy = true
	_label.text = CARDS[i]
	_label.modulate.a = 0.0
	_drift_tint(i)
	if _card_tween != null and _card_tween.is_valid():
		_card_tween.kill()
	_card_tween = create_tween()
	_card_tween.tween_property(_label, "modulate:a", 1.0, FADE_IN)
	_card_tween.tween_interval(HOLD)
	_card_tween.tween_property(_label, "modulate:a", 0.0, FADE_OUT)
	_card_tween.tween_callback(func():
		_busy = false
		_show_card(_index + 1))


## (B4) Cross-fade the backdrop to card `i`'s tint over TINT_FADE. Restarts cleanly if
## a card advances mid-drift. Harmless if _bg is missing (defensive).
func _drift_tint(i: int) -> void:
	if _bg == null or i < 0 or i >= CARD_TINTS.size():
		return
	if _tint_tween != null and _tint_tween.is_valid():
		_tint_tween.kill()
	_tint_tween = create_tween()
	_tint_tween.tween_property(_bg, "color", CARD_TINTS[i], TINT_FADE) \
		.set_trans(Tween.TRANS_SINE)


## Public (also the m7 harness entrypoint): skip to the NEXT card immediately. If
## already on the last card, ends the sequence (→ grove).
func advance() -> void:
	if _finishing:
		return
	# During the CS-01 intro (heartbeat/silhouette), a click fast-forwards to the first card.
	if _intro_playing and not _intro_done:
		_intro_done = true
		_intro_playing = false
		if _stars != null and is_instance_valid(_stars):
			_stars.modulate.a = 0.5
		_show_card(0)
		return
	if _card_tween != null and _card_tween.is_valid():
		_card_tween.kill()
	_busy = false
	_show_card(_index + 1)


## Public (also the m7 harness entrypoint): skip the whole cutscene → grove now.
func skip_all() -> void:
	_finish()


func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	if _card_tween != null and _card_tween.is_valid():
		_card_tween.kill()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FINAL_FADE)
	tw.tween_callback(func():
		WorldContext.current_scene = WorldContext.SCENE_HOME
		get_tree().change_scene_to_file(HOME_SCENE))


func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if _finishing:
		return
	if event.is_action_pressed("ui_cancel"):
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
		skip_all()
		return
	# Click / E / Space advance to the next card.
	if event.is_action_pressed("interact") \
			or (event is InputEventMouseButton and event.pressed
				and event.button_index == MOUSE_BUTTON_LEFT):
		var vp2 := get_viewport()
		if vp2:
			vp2.set_input_as_handled()
		advance()
