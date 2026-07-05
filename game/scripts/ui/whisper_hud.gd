extends CanvasLayer
class_name WhisperHUD
## (L2-3) 에너지 Whisper 재화 표기. A small top-left readout (에너지 아이콘 + 수량) shown ONLY
## while the player holds ≥1 energy (§보완: "보유 시에만 표시, 좌상단 퀘스트 아래"). Sits below the
## QuestHUD panel. Reads WhisperCurrency and reacts to currency_changed; on the first acquisition
## (energy_gained) it pops in with a soft cyan flash.
##
## Owns no currency logic. Headless-safe (no-op draw under --headless).

const CYAN := Color("#4ad9c8")
const CREAM := Color("#faf5e6")
const BG := Color("#141c2b")

var _panel: PanelContainer
var _icon: Label
var _amount: Label


func _ready() -> void:
	layer = 3
	_build()
	if typeof(WhisperCurrency) == TYPE_NIL:
		return
	WhisperCurrency.currency_changed.connect(_on_changed)
	WhisperCurrency.energy_gained.connect(_on_gained)
	_refresh(WhisperCurrency.energy)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# Below the QuestHUD panel (which sits at y=16, ~44 tall). 좌상단 퀘스트 아래.
	_panel.position = Vector2(16, 72)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BG.r, BG.g, BG.b, 0.9)
	sb.set_content_margin_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = CYAN
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 2)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_panel.add_child(row)

	# 에너지 아이콘 (a stylized cyan spark glyph — no art dependency).
	_icon = Label.new()
	_icon.text = "⚡"
	_icon.add_theme_font_size_override("font_size", 20)
	_icon.add_theme_color_override("font_color", CYAN)
	row.add_child(_icon)

	_amount = Label.new()
	_amount.add_theme_color_override("font_color", CREAM)
	_amount.add_theme_font_size_override("font_size", 18)
	row.add_child(_amount)


## Show/hide + set the amount. Hidden entirely at 0 (보유 시에만 표시).
func _refresh(amount: int) -> void:
	if _panel == null:
		return
	_panel.visible = amount > 0
	_amount.text = "에너지 %d" % amount


func _on_changed(kind: String, amount: int) -> void:
	if kind != "energy":
		return
	_refresh(amount)


## First acquisition: pop-in flash so the new HUD element reads as a reward.
func _on_gained(amount: int) -> void:
	_refresh(amount)
	if _panel == null or not _panel.visible:
		return
	_panel.modulate = Color(CYAN.r, CYAN.g, CYAN.b, 0.0)
	_panel.scale = Vector2(0.6, 0.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate", Color(1, 1, 1, 1), 0.5)
	tw.tween_property(_panel, "scale", Vector2(1, 1), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
