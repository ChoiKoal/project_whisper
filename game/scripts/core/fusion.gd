extends Node
## Fusion — global autoload, the fuse transaction (logic split out from UI so it
## is testable headless).
##
## `fuse(a, b)` attempts to combine two ingredient ids:
##   - Match  → consume both inputs from Inventory, add the output, record the
##     recipe + output item in the Codex. Returns a result Dictionary.
##   - No match → inputs are NOT consumed, the Codex hint gauge ticks. Returns a
##     result with `matched=false`.
##
## Requires the ingredients to actually be in the Inventory (the UI only fills
## slots from held stacks, but we guard anyway). Aliases fold via Inventory.

## Result shape (always these keys):
##   matched: bool
##   recipe_id: String   ("" if no match)
##   output: String      (canonical output id, "" if no match)
##   hint_revealed: bool (true if a failed fuse tripped a gauge reveal)
##   failure_reason: String ((L2-3) set when a MATCHED recipe couldn't fuse —
##                           "에너지가 부족하다" when whisper_cost.energy exceeds WhisperCurrency;
##                           (L4-4) "마력이 부족하다" when whisper_cost.mana exceeds WhisperCurrency)
func fuse(a_id: String, b_id: String) -> Dictionary:
	var result := {
		"matched": false,
		"recipe_id": "",
		"output": "",
		"hint_revealed": false,
		"failure_reason": "",
	}
	if a_id == "" or b_id == "":
		return result

	var recipe := RecipeDB.find_recipe([a_id, b_id])
	if recipe.is_empty():
		# Failed pair: gauge only credits a not-previously-attempted pair.
		result["hint_revealed"] = Codex.register_failed_fusion(a_id, b_id)
		return result

	# (L2-3) Whisper 재화 gate: a recipe may cost 에너지 (L2-R08 파워 코어 = 코어 조각 +
	# 에너지). (L4-4) or 마력 (L4-R09 최심부 봉인구 = 봉인구 뼈대² + 마력). Check affordability
	# BEFORE consuming any material input so a shortfall is a clean no-op with a reason.
	var cost := RecipeDB.whisper_cost(recipe)
	var energy_cost := int(cost.get("energy", 0))
	var mana_cost := int(cost.get("mana", 0))
	if energy_cost > 0 and not WhisperCurrency.has_energy(energy_cost):
		result["failure_reason"] = "에너지가 부족하다"
		return result
	if mana_cost > 0 and not WhisperCurrency.has_mana(mana_cost):
		result["failure_reason"] = "마력이 부족하다"
		return result

	# Consume the two inputs. For a same-ingredient recipe (e.g. R10 풀+풀) we
	# need two of that stack; otherwise one of each canonical stack.
	if not _consume_inputs(a_id, b_id):
		# Not enough materials — treat as a no-op, not a failed attempt.
		return result

	# Materials consumed → now spend the Whisper cost (affordability re-checked defensively;
	# has_energy/has_mana passed above and nothing between could have drained it).
	if energy_cost > 0:
		WhisperCurrency.spend_energy(energy_cost)
	if mana_cost > 0:
		WhisperCurrency.spend_mana(mana_cost)

	var output: String = recipe["output"]
	Inventory.add(output, 1)
	Codex.discover_recipe(recipe["id"])
	Codex.discover_item(output)
	# (v0.4.0-C) Per-craft signal for quests/audio (fires every fuse, not just first).
	GameState.item_crafted.emit(ItemDB.resolve_id(output), recipe["id"])

	result["matched"] = true
	result["recipe_id"] = recipe["id"]
	result["output"] = ItemDB.resolve_id(output)
	return result


## Consume the recipe inputs from the Inventory.
##
## UNIQUE-AS-CATALYST rule (M3 refinement): an input item marked `unique` in
## items.json (e.g. I9 세계수 정수) must be PRESENT but is NOT consumed — it acts
## as a catalyst. This prevents the G4 softlock where spending the one-and-only I9
## would strand the clear chain. Non-unique inputs consume normally.
##
## Returns false without mutating if the inventory can't cover the inputs. For a
## same-ingredient recipe (e.g. R10 풀+풀) we need two of that stack; a unique
## same-ingredient recipe would only need one present (none exist today, but the
## catalyst check still applies per-input).
func _consume_inputs(a_id: String, b_id: String) -> bool:
	var ca := ItemDB.resolve_id(a_id)
	var cb := ItemDB.resolve_id(b_id)
	if ca == cb:
		# Same canonical stack. Unique items cap at 1, so a unique self-pair could
		# never have two anyway; require only 1 present and consume 0 (catalyst).
		if ItemDB.is_unique(ca):
			return Inventory.count(ca) >= 1
		if Inventory.count(ca) < 2:
			return false
		Inventory.remove(ca, 2)
		return true

	# Distinct inputs: each must be present; consume only the non-unique ones.
	if Inventory.count(ca) < 1 or Inventory.count(cb) < 1:
		return false
	if not ItemDB.is_unique(ca):
		Inventory.remove(ca, 1)
	if not ItemDB.is_unique(cb):
		Inventory.remove(cb, 1)
	return true
