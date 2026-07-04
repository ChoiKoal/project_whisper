extends Node
## Inventory — global autoload, stack-based item store.
##
## Keyed by canonical item id (ItemDB.resolve_id), value = integer count. No
## per-slot cap; a single entry holds the whole stack. Unique items (ItemDB
## `unique=true`) are capped at 1.
##
## Emits `changed` after any mutation so UI / HUD refresh via signal, not polling.
## `item_added` / `item_removed` carry deltas for feedback (floating labels).

signal changed
signal item_added(item_id: String, amount: int)
signal item_removed(item_id: String, amount: int)

## canonical id -> count (> 0). Absent key == zero.
var _stacks: Dictionary = {}


## Add `amount` of an item. Returns the amount actually added (may be less than
## requested for unique items already at cap). Aliased ids fold into canonical.
func add(item_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var id := ItemDB.resolve_id(item_id)
	if not ItemDB.has_item(id):
		push_warning("Inventory.add: unknown item '%s'" % item_id)
		return 0
	var current: int = _stacks.get(id, 0)
	var to_add := amount
	if ItemDB.is_unique(id):
		to_add = clampi(1 - current, 0, amount)
	if to_add <= 0:
		return 0
	_stacks[id] = current + to_add
	item_added.emit(id, to_add)
	changed.emit()
	return to_add


## Remove up to `amount`. Returns amount actually removed.
func remove(item_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var id := ItemDB.resolve_id(item_id)
	var current: int = _stacks.get(id, 0)
	if current <= 0:
		return 0
	var to_remove := mini(amount, current)
	var remaining := current - to_remove
	if remaining > 0:
		_stacks[id] = remaining
	else:
		_stacks.erase(id)
	item_removed.emit(id, to_remove)
	changed.emit()
	return to_remove


func count(item_id: String) -> int:
	return _stacks.get(ItemDB.resolve_id(item_id), 0)


func has(item_id: String, amount: int = 1) -> bool:
	return count(item_id) >= amount


## Canonical ids currently held (count > 0), in insertion order.
func ids() -> Array:
	return _stacks.keys()


func is_empty() -> bool:
	return _stacks.is_empty()


func clear() -> void:
	_stacks.clear()
	changed.emit()
