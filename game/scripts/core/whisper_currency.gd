extends Node
## (L2-3) WhisperCurrency — global autoload for the Whisper 재화. Layer 2's currency is
## ENERGY (에너지): the first digit of the Whisper system, earned as the G2 발전기 수리 보상
## and spent by the G4 파워 코어 recipe (RecipeDB `whisper_cost.energy`). Design §보완.
##
## SCOPE (per L2-3 spec): a single named digit (`energy`). More Whisper kinds (later layers)
## can add fields the same way; the HUD + recipe cost system read this by key so adding a new
## digit is data + one HUD row, no new autoload. Saved by SaveManager (build_save_dict), reset
## on new game / NG+.
##
## Headless-safe: pure autoload, no scene dependency. The harness drives add/spend directly.

## Emitted whenever a currency amount changes (kind = "energy", new_amount). The HUD listens
## and shows/hides the energy readout (좌상단, 퀘스트 아래) — visible only while amount > 0.
signal currency_changed(kind: String, amount: int)
## Emitted specifically when energy is first acquired (0 → >0), so the acquisition연출
## (시안 빛줄기 + 플로팅 텍스트) can fire once. `amount` = the new total.
signal energy_gained(amount: int)

## Energy 재화 보유량 (에너지 Whisper). 0 = none held (HUD hidden).
var energy: int = 0


## Grant `amount` energy (G2 보상 = +1). Emits currency_changed; emits energy_gained on the
## 0→positive edge so the first-acquisition연출 fires exactly once.
func add_energy(amount: int = 1) -> void:
	if amount <= 0:
		return
	var was := energy
	energy += amount
	currency_changed.emit("energy", energy)
	if was == 0 and energy > 0:
		energy_gained.emit(energy)


## True if at least `amount` energy is held.
func has_energy(amount: int) -> bool:
	return energy >= amount


## Spend `amount` energy. Returns true if it was affordable (and spent), false otherwise
## (no partial spend). Emits currency_changed on success.
func spend_energy(amount: int) -> bool:
	if amount <= 0:
		return true
	if energy < amount:
		return false
	energy -= amount
	currency_changed.emit("energy", energy)
	return true


## Reset to the new-game baseline (no Whisper held). Called by new game / NG+.
func reset() -> void:
	var was := energy
	energy = 0
	if was != 0:
		currency_changed.emit("energy", 0)


# ==== persistence ==========================================================

func to_dict() -> Dictionary:
	return {"energy": energy}


func from_dict(data: Dictionary) -> void:
	energy = int(data.get("energy", 0))
	currency_changed.emit("energy", energy)
