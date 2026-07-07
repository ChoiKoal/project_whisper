extends GatePuzzle
class_name GearPuzzle
## (v1.1.0 GP-5 §3 · L3) 톱니 맞물림. 축 3개 중 가운데 축이 비어 있음 — 올바른 크기의 톱니를 가운데
## 축에 놓아 좌측 구동 톱니 → 우측 출력 톱니로 회전이 전달되게 한다. 크기가 안 맞으면 맞물리지 않음.
## 색맹 무관(크기/문양 기반). 스킵 = 수동으로 태엽 감기.

## 가용 톱니 크기(반지름 계수). 정답은 두 축 간격에 맞물리는 MID 하나.
const SIZES := [26, 38, 50]
const SIZE_NAMES := ["소", "중", "대"]
## 가운데 축에 필요한 정답 크기 인덱스.
const CORRECT := 1   # "중"

var _placed: int = -1
var _mid_slot: Panel = null


func _init() -> void:
	puzzle_title = "태엽 장치 — 톱니 맞물림"
	puzzle_subtitle = "가운데 축에 알맞은 톱니를 놓아 좌→우로 회전이 전달되게 하세요."


func _skip_label() -> String:
	return "수동으로 태엽 감기 (건너뛰기)"


func _build_body(col: VBoxContainer) -> void:
	# Axle row: fixed drive gear (left) — empty mid slot — fixed output gear (right).
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	row.add_child(_gear_disc(SIZES[2], Color("#b08d57"), "구동"))
	_mid_slot = Panel.new()
	_mid_slot.custom_minimum_size = Vector2(56, 56)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.12, 0.14)
	box.border_color = Color(0.5, 0.5, 0.55)
	box.set_border_width_all(2)
	box.set_corner_radius_all(28)
	_mid_slot.add_theme_stylebox_override("panel", box)
	row.add_child(_mid_slot)
	row.add_child(_gear_disc(SIZES[2], Color("#b08d57"), "출력"))

	# Gear picker.
	var picks := HBoxContainer.new()
	picks.alignment = BoxContainer.ALIGNMENT_CENTER
	picks.add_theme_constant_override("separation", 10)
	col.add_child(picks)
	for i in range(SIZES.size()):
		var b := Button.new()
		b.text = "톱니 %s" % SIZE_NAMES[i]
		b.custom_minimum_size = Vector2(72, 44)
		b.pressed.connect(_place.bind(i))
		picks.add_child(b)


func _gear_disc(sz: int, c: Color, label: String) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(sz + 8, sz + 8)
	var box := StyleBoxFlat.new()
	box.bg_color = c
	box.set_corner_radius_all(int((sz + 8) / 2.0))
	p.add_theme_stylebox_override("panel", box)
	var l := Label.new()
	l.text = label
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
	l.add_theme_font_size_override("font_size", 12)
	p.add_child(l)
	return p


func _place(size_idx: int) -> void:
	_placed = size_idx
	# Only the CORRECT-size gear meshes both axles → transmits rotation.
	if size_idx == CORRECT:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("#d4a94a")
		box.set_corner_radius_all(28)
		_mid_slot.add_theme_stylebox_override("panel", box)
		_set_status("맞물렸습니다 — 회전 전달.")
		_succeed()
	else:
		_set_status("크기가 맞지 않아 헛돕니다.")


## Place the correct gear programmatically (harness).
func solve_for_test() -> void:
	_place(CORRECT)
