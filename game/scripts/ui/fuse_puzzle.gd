extends GatePuzzle
class_name FusePuzzle
## (v1.1.0 GP-5 §3 · L2) 퓨즈 순서 맞추기. 목표 색 순서(4)가 상단에 표시 → 플레이어가 그 순서로 퓨즈를
## 꽂는다. 틀리면 슬롯 빨강 점멸 + 초기화(무한 재시도, 감점 없음). 색맹 대응: 색 + 숫자 병기.

## 색 팔레트(색 + 숫자 라벨 병기 — 색맹 대응). index = "색 번호".
const COLORS := [Color("#3b5bdb"), Color("#22b8cf"), Color("#e8590c"), Color("#f59f00")]
const COLOR_NAMES := ["1 남", "2 청", "3 주", "4 금"]

## 이번 판 목표 순서(길이 4). 데모/하네스 재현성을 위해 고정.
var _target: Array[int] = [0, 1, 0, 1]
## 지금까지 꽂은 순서.
var _entered: Array[int] = []
var _slots: Array[Panel] = []


func _init() -> void:
	puzzle_title = "배전반 — 퓨즈 순서"
	puzzle_subtitle = "상단의 색 순서대로 퓨즈를 꽂으세요. 틀리면 초기화됩니다."


func _skip_label() -> String:
	return "그냥 전력 연결 (건너뛰기)"


func _build_body(col: VBoxContainer) -> void:
	# Target sequence row (색 + 숫자 라벨).
	var goal := HBoxContainer.new()
	goal.alignment = BoxContainer.ALIGNMENT_CENTER
	goal.add_theme_constant_override("separation", 8)
	col.add_child(goal)
	for idx in _target:
		goal.add_child(_swatch(idx, false))

	# Empty slot row (fills as the player enters).
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 8)
	col.add_child(slots)
	for i in range(_target.size()):
		var s := Panel.new()
		s.custom_minimum_size = Vector2(48, 48)
		_style_slot(s, Color(0.15, 0.15, 0.2))
		slots.add_child(s)
		_slots.append(s)

	# Fuse buttons (one per color).
	var picks := HBoxContainer.new()
	picks.alignment = BoxContainer.ALIGNMENT_CENTER
	picks.add_theme_constant_override("separation", 8)
	col.add_child(picks)
	for idx in range(COLORS.size()):
		var b := Button.new()
		b.text = COLOR_NAMES[idx]
		b.custom_minimum_size = Vector2(60, 44)
		b.add_theme_color_override("font_color", Color.WHITE)
		var box := StyleBoxFlat.new()
		box.bg_color = COLORS[idx]
		box.set_corner_radius_all(6)
		b.add_theme_stylebox_override("normal", box)
		b.pressed.connect(_place.bind(idx))
		picks.add_child(b)


func _swatch(idx: int, _big: bool) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(44, 44)
	_style_slot(p, COLORS[idx])
	var l := Label.new()
	l.text = COLOR_NAMES[idx].substr(0, 1)   # 숫자만
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_font_size_override("font_size", 16)
	p.add_child(l)
	return p


func _style_slot(p: Panel, c: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = c
	box.set_corner_radius_all(6)
	box.border_color = Color(1, 1, 1, 0.3)
	box.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", box)


func _place(idx: int) -> void:
	var pos := _entered.size()
	if pos >= _target.size():
		return
	# Correct so far?
	if idx != _target[pos]:
		# 틀림 — 슬롯 빨강 점멸 + 초기화.
		_flash_reset()
		return
	_entered.append(idx)
	if pos < _slots.size():
		_style_slot(_slots[pos], COLORS[idx])
	if _entered.size() == _target.size():
		_set_status("전력 연결됨.")
		_succeed()
	else:
		_set_status("좋아요… 다음.")


func _flash_reset() -> void:
	_set_status("순서가 틀렸습니다. 초기화.")
	for i in range(_slots.size()):
		if i < _entered.size():
			_style_slot(_slots[i], Color(0.8, 0.15, 0.15))
		else:
			_style_slot(_slots[i], Color(0.15, 0.15, 0.2))
	_entered.clear()
	# Reset the slot visuals back to empty after a beat (guarded — modal may close).
	get_tree().create_timer(0.35).timeout.connect(func():
		for s in _slots:
			if is_instance_valid(s):
				_style_slot(s, Color(0.15, 0.15, 0.2)))


## Enter the correct sequence programmatically (harness).
func solve_for_test() -> void:
	for idx in _target:
		_place(idx)
