extends RefCounted
class_name WindowChrome
## (v0.4.0-B B3.2) Shared window chrome: a consistent 32px close (X) button, top-right
## on every window panel (fusion / inventory / codex / character / pause). "X 없어서
## 어떻게 닫는지 모르겠다" — a visible close affordance with a hover state.
##
## Static factory only; holds no state. Each window adds the returned Button to its
## header row (or anchors it top-right) and passes its own close() Callable.

const VIOLET := Color("#9e7ad9")
const VIOLET_SOFT := Color("#c8b0ec")
const CREAM := Color("#faf5e6")
const SIZE := 32

## Build a 32×32 "✕" close button wired to `on_close`. Focusless, with a normal +
## hover style (the hover brightens the border + fill so the affordance reads).
static func make_close_button(on_close: Callable) -> Button:
	var b := Button.new()
	b.name = "CloseButton"
	b.text = "✕"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(SIZE, SIZE)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", VIOLET_SOFT)
	b.add_theme_color_override("font_pressed_color", VIOLET_SOFT)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("normal", _style(false))
	b.add_theme_stylebox_override("hover", _style(true))
	b.add_theme_stylebox_override("pressed", _style(true))
	if on_close.is_valid():
		b.pressed.connect(on_close)
	return b


## (v0.4.0-B B3.2) A dim, centered "ESC 닫기" hint label for the bottom of a window
## panel. Pairs with the ✕ button so the close affordance reads two ways ("닫을 수 있어
## 보이지도 않는다"). Named "EscHint" so the harness can assert its presence per window.
static func make_esc_hint() -> Label:
	var l := Label.new()
	l.name = "EscHint"
	l.text = "ESC 닫기"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(CREAM.r, CREAM.g, CREAM.b, 0.45))
	l.add_theme_font_size_override("font_size", 13)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _style(hover: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#3a3a46") if hover else Color("#2f2f39")
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(2)
	sb.set_border_width_all(1)
	sb.border_color = VIOLET if hover else Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.4)
	return sb
