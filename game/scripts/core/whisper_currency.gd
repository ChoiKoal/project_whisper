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
## (L4-3) Emitted specifically when mana is first acquired (0 → >0), so the acquisition연출
## (금색 빛줄기 + 플로팅 텍스트) can fire once. `amount` = the new total.
signal mana_gained(amount: int)

## Energy 재화 보유량 (에너지 Whisper). 0 = none held (HUD hidden).
var energy: int = 0
## (L4-3) Mana 재화 보유량 (마력 Whisper). 2번째 속성, L4 마법 계열 — L4에서 첫 등장(정사).
## 0 = none held (HUD row hidden). G2 결계 분수 재정화가 획득처, G4 봉인구 조합이 소비처.
var mana: int = 0


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


## (L4-3) Grant `amount` mana (G2 보상 = +1). Mirrors add_energy exactly (2번째 자릿수). Emits
## currency_changed; emits mana_gained on the 0→positive edge so the first-acquisition연출 fires once.
func add_mana(amount: int = 1) -> void:
	if amount <= 0:
		return
	var was := mana
	mana += amount
	currency_changed.emit("mana", mana)
	if was == 0 and mana > 0:
		mana_gained.emit(mana)


## (L4-3) True if at least `amount` mana is held.
func has_mana(amount: int) -> bool:
	return mana >= amount


## (L4-3) Spend `amount` mana. Returns true if affordable (and spent), false otherwise (no partial
## spend). Emits currency_changed on success. G4 최심부 봉인구(whisper_cost.mana:1)가 유일 소비처.
func spend_mana(amount: int) -> bool:
	if amount <= 0:
		return true
	if mana < amount:
		return false
	mana -= amount
	currency_changed.emit("mana", mana)
	return true


## Reset to the new-game baseline (no Whisper held). Called by new game / NG+.
func reset() -> void:
	var was_e := energy
	var was_m := mana
	energy = 0
	mana = 0
	if was_e != 0:
		currency_changed.emit("energy", 0)
	if was_m != 0:
		currency_changed.emit("mana", 0)


# ==== persistence ==========================================================

func to_dict() -> Dictionary:
	return {"energy": energy, "mana": mana}


func from_dict(data: Dictionary) -> void:
	energy = int(data.get("energy", 0))
	mana = int(data.get("mana", 0))
	currency_changed.emit("energy", energy)
	currency_changed.emit("mana", mana)
