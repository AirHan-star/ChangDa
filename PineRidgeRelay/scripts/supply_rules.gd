class_name SupplyRules
extends RefCounted
## Run-local inventory and recipes. World nodes handle proximity and resource placement.

signal changed

enum Kind { WOOD, CAN, STONE }
enum Tool { WOOD_PICK, STONE_PICK, STONE_SWORD }

const WOOD_TARGET := 3
const CAN_TARGET := 1
const RECIPES := {
	Tool.WOOD_PICK: {Kind.WOOD: 2},
	Tool.STONE_PICK: {Kind.WOOD: 2, Kind.STONE: 2},
	Tool.STONE_SWORD: {Kind.WOOD: 1, Kind.STONE: 2},
}

var _available: Dictionary = {}
var _inventory: Dictionary = {Kind.WOOD: 0, Kind.CAN: 0, Kind.STONE: 0}
var _stored: Dictionary = {Kind.WOOD: 0, Kind.CAN: 0}
var _tools: Dictionary = {}


func register_pickup(id: StringName, kind: Kind) -> bool:
	if id == &"" or _available.has(id) or not _inventory.has(kind):
		return false
	_available[id] = kind
	return true


func collect(id: StringName) -> bool:
	if not _available.has(id):
		return false
	var kind: Kind = _available[id]
	_available.erase(id)
	_inventory[kind] += 1
	changed.emit()
	return true


func add_stone(amount: int) -> void:
	_inventory[Kind.STONE] += amount
	changed.emit()


func consume_ration() -> bool:
	if carried(Kind.CAN) == 0:
		return false
	_inventory[Kind.CAN] -= 1
	changed.emit()
	return true


func can_deposit() -> bool:
	return carried(Kind.WOOD) + carried(Kind.CAN) > 0


func deposit() -> bool:
	if not can_deposit():
		return false
	for kind in [Kind.WOOD, Kind.CAN]:
		_stored[kind] += _inventory[kind]
		_inventory[kind] = 0
	changed.emit()
	return true


func can_craft(tool: Tool) -> bool:
	if has_tool(tool) or not RECIPES.has(tool):
		return false
	for kind in RECIPES[tool]:
		if carried(kind) < RECIPES[tool][kind]:
			return false
	return true


func craft(tool: Tool) -> bool:
	if not can_craft(tool):
		return false
	var recipe: Dictionary = RECIPES[tool]
	for kind in recipe:
		_inventory[kind] -= recipe[kind]
	_tools[tool] = true
	changed.emit()
	return true


func spend_wood(amount: int) -> bool:
	if carried(Kind.WOOD) < amount:
		return false
	_inventory[Kind.WOOD] -= amount
	changed.emit()
	return true


func has_tool(tool: Tool) -> bool:
	return _tools.has(tool)


func mining_power(tool := -1) -> int:
	if tool < 0:
		tool = Tool.STONE_PICK if has_tool(Tool.STONE_PICK) else Tool.WOOD_PICK
	if not has_tool(tool):
		return 0
	match tool:
		Tool.STONE_PICK:
			return 3
		Tool.WOOD_PICK:
			return 1
	return 0


func carried(kind: Kind) -> int:
	return _inventory[kind]


func stored(kind: Kind) -> int:
	return _stored[kind]


func is_complete() -> bool:
	return stored(Kind.WOOD) >= WOOD_TARGET and stored(Kind.CAN) >= CAN_TARGET
