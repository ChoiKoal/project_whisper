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
## (L4-3) 마력 Whisper 표기 색 (금색, 에너지 시안 대비).
const GOLD := Color("#f2c14e")
## (L5-3) 생명 Whisper 표기 색 (연둣빛, 3번째 자릿수 — 에너지 시안·마력 금색 대비).
const VERDANT := Color("#8fd968")

var _panel: PanelContainer
var _icon: Label
var _amount: Label
## (L4-3) 마력 재화 패널 (2번째 자릿수, 에너지 행 아래, 보유 시만 표시).
var _mana_panel: PanelContainer
var _mana_amount: Label
## (L5-3) 생명 재화 패널 (3번째 자릿수, 마력 행 아래, 보유 시만 표시).
var _vita_panel: PanelContainer
var _vita_amount: Label


func _ready() -> void:
	layer = 3
	_build()
	_build_mana()
	_build_vita()
	if typeof(WhisperCurrency) == TYPE_NIL:
		return
	WhisperCurrency.currency_changed.connect(_on_changed)
	WhisperCurrency.energy_gained.connect(_on_gained)
	if WhisperCurrency.has_signal("mana_gained"):
		WhisperCurrency.mana_gained.connect(_on_mana_gained)
	if WhisperCurrency.has_signal("vita_gained"):
		WhisperCurrency.vita_gained.connect(_on_vita_gained)
	_refresh(WhisperCurrency.energy)
	_refresh_mana(WhisperCurrency.mana)
	_refresh_vita(WhisperCurrency.vita)


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


## (L4-3) Build the mana panel — same layout as the energy panel, gold trim, one row lower
## (y = energy y + ~44). Hidden until ≥1 mana held (L4 G2 재정화 보상으로 첫 등장).
func _build_mana() -> void:
	_mana_panel = PanelContainer.new()
	_mana_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_mana_panel.position = Vector2(16, 118)   # below the energy panel (y=72, ~44 tall)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BG.r, BG.g, BG.b, 0.9)
	sb.set_content_margin_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = GOLD
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 2)
	_mana_panel.add_theme_stylebox_override("panel", sb)
	add_child(_mana_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_mana_panel.add_child(row)

	# 마력 아이콘 (a stylized gold rune glyph — no art dependency).
	var icon := Label.new()
	icon.text = "✦"
	icon.add_theme_font_size_override("font_size", 20)
	icon.add_theme_color_override("font_color", GOLD)
	row.add_child(icon)

	_mana_amount = Label.new()
	_mana_amount.add_theme_color_override("font_color", CREAM)
	_mana_amount.add_theme_font_size_override("font_size", 18)
	row.add_child(_mana_amount)


## (L5-3) Build the vita panel — same layout, verdant trim, one row below mana (y = mana y + ~44).
## Hidden until ≥1 vita held (L5 G2 생명의 샘 재정화 보상으로 첫 등장 — 3속성 완성).
func _build_vita() -> void:
	_vita_panel = PanelContainer.new()
	_vita_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_vita_panel.position = Vector2(16, 164)   # below the mana panel (y=118, ~44 tall)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BG.r, BG.g, BG.b, 0.9)
	sb.set_content_margin_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = VERDANT
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 2)
	_vita_panel.add_theme_stylebox_override("panel", sb)
	add_child(_vita_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_vita_panel.add_child(row)

	# 생명 아이콘 (a stylized verdant leaf/sprout glyph — no art dependency).
	var icon := Label.new()
	icon.text = "❀"
	icon.add_theme_font_size_override("font_size", 20)
	icon.add_theme_color_override("font_color", VERDANT)
	row.add_child(icon)

	_vita_amount = Label.new()
	_vita_amount.add_theme_color_override("font_color", CREAM)
	_vita_amount.add_theme_font_size_override("font_size", 18)
	row.add_child(_vita_amount)


## Show/hide + set the amount. Hidden entirely at 0 (보유 시에만 표시).
func _refresh(amount: int) -> void:
	if _panel == null:
		return
	_panel.visible = amount > 0
	_amount.text = "에너지 %d" % amount


## (L4-3) Show/hide + set the mana amount. Hidden at 0 (보유 시에만 표시).
func _refresh_mana(amount: int) -> void:
	if _mana_panel == null:
		return
	_mana_panel.visible = amount > 0
	_mana_amount.text = "마력 %d" % amount


## (L5-3) Show/hide + set the vita amount. Hidden at 0 (보유 시에만 표시, 3번째 자릿수).
func _refresh_vita(amount: int) -> void:
	if _vita_panel == null:
		return
	_vita_panel.visible = amount > 0
	_vita_amount.text = "생명 %d" % amount


func _on_changed(kind: String, amount: int) -> void:
	if kind == "energy":
		_refresh(amount)
	elif kind == "mana":
		_refresh_mana(amount)
	elif kind == "vita":
		_refresh_vita(amount)


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


## (L4-3) First mana acquisition: gold pop-in flash (L4 마력 Whisper 첫 등장 연출).
func _on_mana_gained(amount: int) -> void:
	_refresh_mana(amount)
	if _mana_panel == null or not _mana_panel.visible:
		return
	_mana_panel.modulate = Color(GOLD.r, GOLD.g, GOLD.b, 0.0)
	_mana_panel.scale = Vector2(0.6, 0.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_mana_panel, "modulate", Color(1, 1, 1, 1), 0.5)
	tw.tween_property(_mana_panel, "scale", Vector2(1, 1), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## (L5-3) First vita acquisition: verdant pop-in flash (L5 생명 Whisper 첫 등장 연출 — 3속성 완성).
func _on_vita_gained(amount: int) -> void:
	_refresh_vita(amount)
	if _vita_panel == null or not _vita_panel.visible:
		return
	_vita_panel.modulate = Color(VERDANT.r, VERDANT.g, VERDANT.b, 0.0)
	_vita_panel.scale = Vector2(0.6, 0.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_vita_panel, "modulate", Color(1, 1, 1, 1), 0.5)
	tw.tween_property(_vita_panel, "scale", Vector2(1, 1), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
