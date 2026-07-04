extends Label
class_name FloatingLabel
## Transient "+1 <이름>" feedback that rises and fades, then frees itself.
## Created in code via `FloatingLabel.spawn(parent, world_pos, text)`; no scene
## file needed. Uses a Tween (signals/callbacks, no _process polling).

const RISE_PX := 48.0
const DURATION := 0.9
const COLOR := Color("#faf5e6")  # cream, matches UI text


static func spawn(parent: Node, world_pos: Vector2, msg: String) -> FloatingLabel:
	var lbl := FloatingLabel.new()
	lbl.text = msg
	lbl.global_position = world_pos
	parent.add_child(lbl)
	lbl._start()
	return lbl


func _start() -> void:
	add_theme_color_override("font_color", COLOR)
	add_theme_color_override("font_outline_color", Color("#2a2a33"))
	add_theme_constant_override("outline_size", 4)
	z_index = 100
	modulate.a = 1.0
	var start_pos := global_position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position",
		start_pos - Vector2(0, RISE_PX), DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, DURATION).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
