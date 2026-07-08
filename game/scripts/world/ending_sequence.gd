extends CanvasLayer
class_name EndingSequence
## (EG-1/EG-3) 엔딩 시퀀스 — E1「완성」 / E2「속삭임」(트루). Built + owned by HomeSession, layered
## above everything (layer 13). Reuses the opening/clear card systems' TIMING + the CS-01 purple-dot
## rhythm + the CS-04 white flash, per docs/project-whisper-endgame-design-v1.md §2 / §3.3.
##
## E1 (진입 → [들어간다]):
##   1. 백금 화이트 플래시 → 화면이 백금빛으로 가득
##   2. 완성 몽타주 5카드 (각 세계 정화 회상) 순차 크로스페이드
##   3. 마지막 컷: 내 섬 새소리 2회 반복 (무음·무대사), 미세 채도 저하
##   4. 크레딧 롤 (스킵 가능, 멱등)
##   5. endings_seen.E1 → NG+ 제안
##
## E2 (진상 조각 5 + [돌아선다]):
##   1. 문이 조용히 닫힘 (빛의 문 veil 역재생)
##   2. 홈 배치물 일제 반짝임 (glow_layer 그룹 펄스)
##   3. 어린 세계수 잎 기욺 (world_tree 스프라이트 회전 Tween)
##   4. 카드 「완성하지 않을 거야. 계속 말을 걸 거야.」
##   5. 크레딧 롤
##   6. 크레딧 후 검은 화면에 보라 점 2회 깜빡 (오프닝 CS-01 리듬 — 대답)
##   7. endings_seen.E2 → 타이틀 (NG+ 제안)
##
## control_lock / time_running 페어링 엄수: play() pauses+locks at entry, EVERY exit path
## (credits skip included) restores time_running=true + control_lock(false) before leaving.
##
## Headless: skip_all()/is_done()/advance() drive it deterministically for the harness. No node
## is hard-required (world_tree / placed objects are best-effort visual beats).

const CREAM := Color("#faf5e6")
const PLATINUM := Color(1.0, 0.96, 0.82)
const VIOLET := Color("#9e7ad9")
const TITLE_SCENE := "res://scenes/ui/title.tscn"
const HOME_SCENE := "res://scenes/world/home_island.tscn"

## E1 완성 몽타주 카드 (설계 §2 — 정화 순간 회상, 대사 최소).
const E1_CARDS := [
	"자연 — 어린 세계수를 되심는 순간.",
	"과학 — 관제탑에 불이 들어오는 순간.",
	"기계 — 대시계가 다시 도는 순간.",
	"마법 — 최심부 봉인이 다시 짜이는 순간.",
	"신성 — 대제단이 처음 '대답'을 받는 순간.",
]
const E2_CARD := "완성하지 않을 거야. 계속 말을 걸 거야."

## (CQ-5 G12) Per-world preview tone behind each montage card — 자연 초록 / 과학 시안 / 기계 황동 /
## 마법 자수정 / 신성 백금. Deep + desaturated so the cream text stays legible over each.
const E1_MONTAGE_TINTS := [
	Color(0.10, 0.16, 0.11, 1.0),   # 자연 — deep grove green
	Color(0.09, 0.15, 0.18, 1.0),   # 과학 — cool cyan station
	Color(0.16, 0.12, 0.07, 1.0),   # 기계 — warm brass city
	Color(0.13, 0.09, 0.18, 1.0),   # 마법 — amethyst sanctum
	Color(0.17, 0.16, 0.12, 1.0),   # 신성 — warm platinum cathedral
]

## 크레딧 롤 (§6.5(d): 제작진). Kept short + skippable.
const CREDITS := [
	"— PROJECT WHISPER —",
	"기획 · 디렉션   카나",
	"오너   KOAL",
	"세계를 완성하지 않기로 한 당신에게.",
]

var _ending: String = ""
var _gate: Portal = null
var _bg: ColorRect
var _flash: ColorRect
var _label: Label
var _skip_hint: Label
var _done: bool = false
var _phase: String = "idle"
## Set true once endings_seen recorded + the post-credits prompt shown (so it fires once).
var _recorded: bool = false


func _ready() -> void:
	layer = 13
	_build()


func _build() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", CREAM)
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_constant_override("line_spacing", 10)
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08, 0.9))
	_label.add_theme_constant_override("outline_size", 4)
	_label.offset_left = 140
	_label.offset_right = -140
	_label.modulate.a = 0.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	_flash = ColorRect.new()
	_flash.color = Color(PLATINUM.r, PLATINUM.g, PLATINUM.b, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_skip_hint = Label.new()
	_skip_hint.text = "건너뛰기 (ESC)"
	_skip_hint.add_theme_color_override("font_color", Color(0.72, 0.70, 0.66, 0.7))
	_skip_hint.add_theme_font_size_override("font_size", 16)
	_skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip_hint.position = Vector2(-190, -46)
	_skip_hint.visible = false
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skip_hint)


## Public entry (also the harness hook). Plays E1 or E2 and records the ending.
func play(ending_id: String, gate: Portal = null) -> void:
	_ending = ending_id
	_gate = gate
	if Codex != null and Codex.has_method("mark_cutscene_seen"):
		Codex.mark_cutscene_seen(ending_id)
	if GameState != null:
		GameState.time_running = false
		GameState.set_control_lock(true)
	if ending_id == "E2":
		_run_e2()
	else:
		_run_e1()


func is_done() -> bool:
	return _done


# ---- E1「완성」 ------------------------------------------------------------

func _run_e1() -> void:
	_phase = "e1"
	_skip_hint.visible = true
	# 1. 백금 화이트 플래시 (CS-04 flash 재사용 패턴).
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.95, 0.12)
	tw.tween_property(_flash, "color:a", 0.35, 0.7)
	await tw.finished
	if _done: return
	# 화면이 백금빛으로 가득 → 배경을 백금 틴트로.
	_bg.color = Color(PLATINUM.r * 0.9, PLATINUM.g * 0.86, PLATINUM.b * 0.7, 1.0)
	var ftw := create_tween()
	ftw.tween_property(_flash, "color:a", 0.0, 0.6)
	# 2. 완성 몽타주 5카드 — (CQ-5 G12) 각 세계의 프리뷰 톤 배경으로 크로스페이드하며 회상.
	for i in range(E1_CARDS.size()):
		if _done: return
		_drift_bg(E1_MONTAGE_TINTS[i] if i < E1_MONTAGE_TINTS.size() else _bg.color)
		await _card(E1_CARDS[i], CREAM)
	if _done: return
	# 3. 마지막 컷 — 내 섬 새소리 2회 (무음·무대사). 미세 채도 저하 = 배경을 회색으로 살짝.
	_label.text = ""
	await _birdsong_twice()
	if _done: return
	var dtw := create_tween()
	dtw.tween_property(_bg, "color", Color(0.10, 0.10, 0.12, 1.0), 1.2)
	await dtw.finished
	if _done: return
	# 4. 크레딧 → 5. 기록 + NG+ 제안.
	await _roll_credits()
	_finish_ending()


## 내 섬 새소리 2회 반복 (무음 배경 위, 대사 없음). Audio best-effort; the beat is the pause itself.
func _birdsong_twice() -> void:
	for i in range(2):
		if _done: return
		if AudioManager != null and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("bird")
		await _wait(1.3)


# ---- E2「속삭임」(트루) ----------------------------------------------------

func _run_e2() -> void:
	_phase = "e2"
	_skip_hint.visible = true
	# 1. 문이 조용히 닫힘 — 빛의 문 veil/pool 역재생 (OPEN→DORMANT 전이 재사용).
	if is_instance_valid(_gate) and _gate.has_method("_apply_state"):
		_gate._apply_state(GameState.PORTAL_DORMANT)
	await _wait(0.8)
	if _done: return
	# 2. 섬의 모든 배치물이 한 번씩 반짝인다 (glow_layer 그룹 펄스).
	_pulse_home_glow()
	await _wait(0.8)
	if _done: return
	# 3. 어린 세계수가 잎을 기울인다 (world_tree 스프라이트 회전 Tween).
	_tilt_world_tree_leaf()
	await _wait(0.8)
	if _done: return
	# 4. 대사.
	_bg.color = Color(0.03, 0.03, 0.05, 0.72)
	await _card(E2_CARD, CREAM)
	if _done: return
	# 5. 크레딧.
	await _roll_credits()
	if _done: return
	# 6. 크레딧 후 — 검은 화면에 보라 점 2회 깜빡 (오프닝 CS-01 리듬 — 대답). (CQ-5) 오프닝과
	#    IDENTICAL 리듬을 위해 CutsceneDirector.purple_dot_heartbeat 공유.
	_bg.color = Color(0.01, 0.01, 0.02, 1.0)
	await CutsceneDirector.purple_dot_heartbeat(self, self, 2)
	# 7. 기록 + 타이틀 (NG+ 제안).
	_finish_ending()


## 홈 섬 배치물(glow_layer 그룹) 일제 반짝임 — 한 번의 밝기 펄스. Best-effort (no glow = no-op).
func _pulse_home_glow() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("glow_layer"):
		for child in node.get_children():
			if child is CanvasItem:
				var ci := child as CanvasItem
				var base := ci.modulate
				var tw := create_tween()
				tw.tween_property(ci, "modulate", Color(base.r * 1.8 + 0.4, base.g * 1.8 + 0.4, base.b * 1.8 + 0.4, base.a), 0.4)
				tw.tween_property(ci, "modulate", base, 0.6)


## 어린 세계수 잎 기욺 — the home-island world_tree (if grown here) rotates a hair, once.
func _tilt_world_tree_leaf() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("gatherable"):
		if node is WorldTree and is_instance_valid(node):
			var wt := node as Node2D
			var tw := create_tween()
			tw.tween_property(wt, "rotation", 0.06, 0.6).set_trans(Tween.TRANS_SINE)
			tw.tween_property(wt, "rotation", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
			return


# ---- credits + finish -----------------------------------------------------

func _roll_credits() -> void:
	_phase = "credits"
	_bg.color = Color(0.02, 0.02, 0.03, 1.0)
	for line in CREDITS:
		if _done: return
		await _card(line, CREAM, 0.6, 1.4, 0.5)


## Record endings_seen + show the NG+/타이틀 suggestion prompt. Idempotent (skip re-entry).
func _finish_ending() -> void:
	if _recorded:
		return
	_recorded = true
	_done = true
	_skip_hint.visible = false
	if GameState != null:
		GameState.record_ending(_ending)
	# control_lock / time_running 복원 — the ending is over; the suggestion prompt owns its own
	# lock via a modal key so releasing here is correct (the buttons drive a scene change).
	if GameState != null:
		GameState.time_running = true
		GameState.set_control_lock(false)
	_show_ngplus_prompt()


## NG+ 제안 (§5) — [NG+ 시작] / [타이틀로]. E1 defaults to NG+ (회차 동기), E2 to 타이틀.
func _show_ngplus_prompt() -> void:
	_label.text = ""
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 20)
	add_child(panel)

	var msg := Label.new()
	msg.text = "다시, 처음부터 말을 걸어볼까?" if _ending == "E1" else "세계는 계속 자란다."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_color_override("font_color", CREAM)
	msg.add_theme_font_size_override("font_size", 24)
	panel.add_child(msg)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	row.add_child(_prompt_button("NG+ 시작", _on_ngplus))
	row.add_child(_prompt_button("타이틀로", _on_title))


func _prompt_button(label: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 44)
	b.add_theme_color_override("font_color", CREAM)
	b.pressed.connect(cb)
	return b


func _on_ngplus() -> void:
	SaveManager.start_ng_plus()
	SaveManager.pending_load = false
	get_tree().change_scene_to_file(HOME_SCENE)


func _on_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)


# ---- helpers --------------------------------------------------------------

## Fade a card in → hold → out. `fin`/`hold`/`fout` override the default card timing.
func _card(text: String, col: Color, fin: float = 1.0, hold: float = 2.4, fout: float = 0.9) -> void:
	_label.add_theme_color_override("font_color", col)
	_label.text = text
	_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_label, "modulate:a", 1.0, fin)
	tw.tween_interval(hold)
	tw.tween_property(_label, "modulate:a", 0.0, fout)
	await tw.finished


## (CQ-5 G12) Crossfade the montage backdrop to a world's preview tone (1.2s SINE). Best-effort.
func _drift_bg(to: Color) -> void:
	if _bg == null or not is_instance_valid(_bg):
		return
	var tw := create_tween()
	tw.tween_property(_bg, "color", to, 1.2).set_trans(Tween.TRANS_SINE)


## A plain wait that respects skip (returns immediately once _done). Uses a scene-tree timer so
## it runs even though GameState.time_running is false (the ending owns the pause).
func _wait(secs: float) -> void:
	if _done:
		return
	await get_tree().create_timer(secs, true, false, true).timeout


func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if _done:
		return
	if event.is_action_pressed("ui_cancel"):
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
		skip_all()


## Public (harness): skip the montage/credits straight to the finish (기록 + NG+ 제안). Idempotent.
## The record + control/time restore still happen (they live in _finish_ending), so a skip can
## never leave endings_seen unrecorded or the world frozen (설계 §6.3 리스크 2).
func skip_all() -> void:
	if _done:
		return
	_done = true
	_finish_ending()
