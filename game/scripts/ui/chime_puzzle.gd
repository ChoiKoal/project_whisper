extends GatePuzzle
class_name ChimePuzzle
## (v1.1.0 GP-5 §3 · L5) 성가 음 순서 기억. 성가 한 소절이 순차 연주(음+발광) → 플레이어가 재현. 틀리면
## 소절 재생 후 재시도. 색맹 대응: 종마다 색 + 숫자(음계) 병기. 스킵 = 침묵으로 기도.

## 종 색(색 + 숫자 병기). 5종.
const BELL_COLORS := [Color("#e64980"), Color("#7048e8"), Color("#1c7ed6"), Color("#37b24d"), Color("#f59f00")]
## 이번 판 성가 소절(종 인덱스). 재현성을 위해 고정.
var _target: Array[int] = [0, 2, 4, 2, 3]
var _entered: Array[int] = []
var _bells: Array[Button] = []


func _init() -> void:
	puzzle_title = "성가 — 음 순서"
	puzzle_subtitle = "울린 성가의 순서를 그대로 재현하세요. 틀리면 소절이 다시 울립니다."


func _skip_label() -> String:
	return "침묵으로 기도 (건너뛰기)"


func _build_body(col: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for i in range(BELL_COLORS.size()):
		var b := Button.new()
		b.text = str(i + 1)   # 음계 숫자.
		b.custom_minimum_size = Vector2(56, 56)
		b.add_theme_color_override("font_color", Color.WHITE)
		var box := StyleBoxFlat.new()
		box.bg_color = BELL_COLORS[i]
		box.set_corner_radius_all(28)
		b.add_theme_stylebox_override("normal", box)
		b.pressed.connect(_ring.bind(i))
		_bells.append(b)
		row.add_child(b)
	_set_status("소절: " + _seq_str(_target))
	if get_tree() != null:
		get_tree().create_timer(1.6).timeout.connect(func():
			_set_status("들은 순서대로 종을 울리세요."))


func _seq_str(seq: Array) -> String:
	var parts: Array[String] = []
	for idx in seq:
		parts.append(str(int(idx) + 1))
	return " ".join(parts)


func _ring(idx: int) -> void:
	# 발광 피드백(간단): 잠깐 밝게.
	if idx < _bells.size() and is_instance_valid(_bells[idx]):
		_bells[idx].modulate = Color(1.4, 1.4, 1.4)
		if get_tree() != null:
			var b := _bells[idx]
			get_tree().create_timer(0.15).timeout.connect(func():
				if is_instance_valid(b):
					b.modulate = Color.WHITE)
	var pos := _entered.size()
	if idx != _target[pos]:
		_entered.clear()
		_set_status("어긋났습니다. 소절: " + _seq_str(_target))
		return
	_entered.append(idx)
	if _entered.size() == _target.size():
		_set_status("성가 완주 — 문이 응답합니다.")
		_succeed()


## Ring the bells in the correct order (harness).
func solve_for_test() -> void:
	for idx in _target:
		_ring(idx)
