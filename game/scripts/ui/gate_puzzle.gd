extends CanvasLayer
class_name GatePuzzle
## (v1.1.0 GP-5 §3) GatePuzzle — 게이트 미니 퍼즐 베이스 모달. 각 레이어의 G1 장착 순간에 얹는 1화면
## 퍼즐. 성공/스킵 콜백 계약만 노출하고, 개방 로직은 게이트 컨트롤러의 기존 energize 함수를 그대로
## 호출한다(개방 로직 0줄 변경). 4종 퍼즐(퓨즈순서/톱니맞물림/룬점등/음순서)이 이 베이스를 상속.
##
## 계약:
##   GatePuzzle.open(scene_root, on_success, on_skip) — 정적 팩토리. 서브클래스가 오버라이드하는
##     _build_body(col)로 퍼즐 UI를 채우고, 성공 시 _succeed(), 스킵/닫기 시 _skip()을 호출한다.
##   스킵 버튼은 항상 노출(접근성 — 진행 차단 아님). 색맹 대응: 색 + 숫자/문양 병기(서브클래스).
##   헤드리스/하네스: solve_for_test()(정답 즉시 입력→성공), skip_for_test()(스킵 경로) 노출.
##
## 모달 규약: fusion_ui 패턴 재사용 — GameState.push_modal + set_control_lock, 뷰포트 클램프,
## ESC/클릭 = 스킵(닫기). 헤드리스 안전(카드 없이도 콜백 발화 가능).

const MODAL_KEY := "gate_puzzle"

## 성공 시 호출(게이트 개방). null이면 no-op.
var _on_success: Callable = Callable()
## 스킵/닫기 시 호출(그냥 장착 = 기존 개방과 동일 결과). null이면 _on_success로 폴백.
var _on_skip: Callable = Callable()
## 콜백 중복 발화 방지(성공/스킵은 정확히 한 번).
var _resolved: bool = false

## 퍼즐 제목/부제(서브클래스가 지정).
var puzzle_title: String = "게이트"
var puzzle_subtitle: String = ""

var _root: Control = null
var _status: Label = null


## 정적 팩토리 — 씬 루트 아래에 퍼즐 모달을 붙이고 반환. `puzzle_type` ∈
## {"fuse","gear","rune","chime"}. on_success/on_skip은 성공/스킵 시 정확히 한 번 호출.
static func open(scene_root: Node, puzzle_type: String, on_success: Callable, on_skip: Callable = Callable()) -> GatePuzzle:
	if scene_root == null or not is_instance_valid(scene_root):
		return null
	var p: GatePuzzle = _make(puzzle_type)
	p._on_success = on_success
	p._on_skip = on_skip
	scene_root.add_child(p)
	return p


## Construct the right subclass instance for a puzzle type.
static func _make(puzzle_type: String) -> GatePuzzle:
	match puzzle_type:
		"fuse":
			return FusePuzzle.new()
		"gear":
			return GearPuzzle.new()
		"rune":
			return RunePuzzle.new()
		"chime":
			return ChimePuzzle.new()
		_:
			return GatePuzzle.new()


func _ready() -> void:
	layer = 12
	if typeof(GameState) != TYPE_NIL:
		GameState.push_modal(MODAL_KEY)
		GameState.set_control_lock(true)
	_build_shell()
	if has_viewport():
		get_viewport().size_changed.connect(_clamp)
	_clamp()


func has_viewport() -> bool:
	return get_viewport() != null


## Build the common shell (dim, panel, title, body slot, status, skip button). Subclasses fill the
## body via _build_body(col).
func _build_shell() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			_skip())
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.12, 0.98)
	sb.border_color = Color("#7a5fb0")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	dim.add_child(panel)
	_root = panel

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(560, 0)
	panel.add_child(col)

	var head := Label.new()
	head.text = puzzle_title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_color", Color("#c8b0ec"))
	head.add_theme_font_size_override("font_size", 22)
	col.add_child(head)

	if puzzle_subtitle != "":
		var sub := Label.new()
		sub.text = puzzle_subtitle
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.add_theme_color_override("font_color", Color(0.80, 0.78, 0.72))
		sub.add_theme_font_size_override("font_size", 15)
		col.add_child(sub)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(body)
	_build_body(body)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(0.72, 0.70, 0.66))
	_status.add_theme_font_size_override("font_size", 14)
	col.add_child(_status)

	var skip := Button.new()
	skip.text = _skip_label()
	skip.add_theme_font_size_override("font_size", 15)
	skip.custom_minimum_size = Vector2(0, 44)   # ≥44px touch target (mobile).
	skip.pressed.connect(_skip)
	col.add_child(skip)


## Subclasses override to fill the puzzle body. Base = empty (a bare skip modal).
func _build_body(_col: VBoxContainer) -> void:
	pass


## Subclasses override the skip button label with an in-fiction phrasing.
func _skip_label() -> String:
	return "건너뛰기 — 그냥 장착"


func _set_status(t: String) -> void:
	if _status != null and is_instance_valid(_status):
		_status.text = t


## Puzzle solved — fire success exactly once, then close.
func _succeed() -> void:
	if _resolved:
		return
	_resolved = true
	if _on_success.is_valid():
		_on_success.call()
	_teardown()


## Skip/close — fire skip (fallback to success: 스킵 = 그냥 장착 = 동일 개방) exactly once, then close.
func _skip() -> void:
	if _resolved:
		return
	_resolved = true
	if _on_skip.is_valid():
		_on_skip.call()
	elif _on_success.is_valid():
		_on_success.call()
	_teardown()


func _teardown() -> void:
	if typeof(GameState) != TYPE_NIL:
		GameState.pop_modal(MODAL_KEY)
		GameState.set_control_lock(false)
	queue_free()


func _clamp(_override: Variant = null) -> void:
	if _root == null or not is_instance_valid(_root):
		return
	if get_viewport() == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_root.set("size", Vector2(min(_root.size.x, vp.x * 0.92), min(_root.size.y, vp.y * 0.9)))


func _unhandled_input(event: InputEvent) -> void:
	if _resolved:
		return
	if event.is_action_pressed("ui_cancel"):
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
		_skip()


# ==== test hooks (headless / harness) ======================================

## Solve the puzzle immediately (correct input) → success callback. Base: no puzzle logic, treat as
## solved. Subclasses override with their real solve path.
func solve_for_test() -> void:
	_succeed()


## Take the skip path (그냥 장착). Same as pressing the skip button.
func skip_for_test() -> void:
	_skip()


## True once success/skip has fired (harness convenience).
func is_resolved() -> bool:
	return _resolved
