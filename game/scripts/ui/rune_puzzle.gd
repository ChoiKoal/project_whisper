extends GatePuzzle
class_name RunePuzzle
## (v1.1.0 GP-5 §3 · L4) 룬 순서 점등. 목표 점등 순서가 잠깐 빛났다 사라짐(기억) → 그 순서로 룬을 터치.
## 틀리면 전체 소등 후 순서 재표시(패널티 없음). 색맹 대응: 룬마다 고유 문양(숫자) 병기.

const RUNE_GLYPHS := ["ᚠ", "ᚢ", "ᚦ", "ᚨ", "ᚱ", "ᚲ"]
## 이번 판 목표 순서(룬 인덱스). 재현성을 위해 고정.
var _target: Array[int] = [2, 0, 4, 1]
var _entered: Array[int] = []
var _buttons: Array[Button] = []


func _init() -> void:
	puzzle_title = "룬 다리 — 점등 순서"
	puzzle_subtitle = "빛나는 순서를 기억해 그대로 룬을 터치하세요. 틀리면 전체 소등."


func _skip_label() -> String:
	return "룬을 억지로 잇기 (건너뛰기)"


func _build_body(col: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for i in range(RUNE_GLYPHS.size()):
		var b := Button.new()
		b.text = "%s\n%d" % [RUNE_GLYPHS[i], i + 1]   # 문양 + 숫자 병기.
		b.custom_minimum_size = Vector2(56, 60)
		b.pressed.connect(_touch.bind(i))
		_buttons.append(b)
		row.add_child(b)
	# Show the target sequence briefly (memory), then dim (guarded — headless has no real timer wait).
	_set_status("순서: " + _seq_str(_target))
	if get_tree() != null:
		get_tree().create_timer(1.4).timeout.connect(func():
			_set_status("기억한 순서대로 터치하세요."))


func _seq_str(seq: Array) -> String:
	var parts: Array[String] = []
	for idx in seq:
		parts.append(str(int(idx) + 1))
	return " → ".join(parts)


func _touch(idx: int) -> void:
	var pos := _entered.size()
	if idx != _target[pos]:
		# 틀림 — 전체 소등 후 재표시(패널티 없음). 누적 시 스킵 제안.
		_note_fail()
		_entered.clear()
		_dim_all()
		_set_status("틀렸습니다. 다시: " + _seq_str(_target))
		return
	_entered.append(idx)
	_light(idx)
	if _entered.size() == _target.size():
		_set_status("룬 다리 점등 완료.")
		_succeed()


func _light(idx: int) -> void:
	if idx < _buttons.size() and is_instance_valid(_buttons[idx]):
		_buttons[idx].add_theme_color_override("font_color", Color("#ffd966"))


func _dim_all() -> void:
	for b in _buttons:
		if is_instance_valid(b):
			b.remove_theme_color_override("font_color")


## Touch the runes in the correct order (harness).
func solve_for_test() -> void:
	for idx in _target:
		_touch(idx)


## Touch a wrong rune first through the real _touch path (harness) — exercises the fail branch.
func fail_for_test() -> void:
	var wrong := (_target[0] + 1) % RUNE_GLYPHS.size()
	_touch(wrong)
