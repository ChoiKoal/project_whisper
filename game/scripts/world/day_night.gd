extends CanvasModulate
class_name DayNight
## Drives the global day/night tint via a CanvasModulate color curve keyed off
## GameState.day_fraction(). Per art guide §3 / level design C-3: don't bake time
## into sprites — tint the whole scene. A CanvasModulate only tints its OWN canvas
## layer; the additive glow sprites (GlowSprite) reparent themselves at runtime onto
## the sibling "GlowLayer" CanvasLayer (layer 1, follow_viewport_enabled), so they
## are NOT dimmed by this node and the night glow pops as designed.
##
## Keyframes (level design C-3):
##   day     0.00 .. 0.60  cream/warm  #faf5e6 -> #e8dfc8
##   evening 0.60 .. 0.7333 warm brown -> violet  #b59268 -> #6b4a9e
##   night   0.7333.. 0.9333 dark blue-violet     #3a2a5c
##   dawn    0.9333.. 1.00  night -> day (violet -> cream)

const DAY_A := Color("#faf5e6")
const DAY_B := Color("#e8dfc8")
const EVE_A := Color("#b59268")
const EVE_B := Color("#6b4a9e")
const NIGHT := Color("#3a2a5c")


func _ready() -> void:
	# Defensive: if the GameState autoload were ever missing/renamed, reading
	# .day_fraction() during the grove ready-flush would null-deref in a release
	# template (no debug error). Fall back to the day tint and skip.
	if GameState == null:
		color = DAY_A
		return
	color = _color_for(GameState.day_fraction())


func _process(_delta: float) -> void:
	if GameState == null:
		return
	color = _color_for(GameState.day_fraction())


func _color_for(f: float) -> Color:
	if f < GameState.DAY_END:
		# day: gentle drift cream -> warm cream
		var t := f / GameState.DAY_END
		return DAY_A.lerp(DAY_B, t)
	elif f < GameState.EVENING_END:
		# evening: warm brown -> violet ramp
		var t := (f - GameState.DAY_END) / (GameState.EVENING_END - GameState.DAY_END)
		return EVE_A.lerp(EVE_B, t)
	elif f < GameState.NIGHT_END:
		# night: settle from violet into deep blue-violet
		var t := (f - GameState.EVENING_END) / (GameState.NIGHT_END - GameState.EVENING_END)
		return EVE_B.lerp(NIGHT, clampf(t * 2.0, 0.0, 1.0))
	else:
		# dawn: night -> day
		var t := (f - GameState.NIGHT_END) / (1.0 - GameState.NIGHT_END)
		return NIGHT.lerp(DAY_A, t)
