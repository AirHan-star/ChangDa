class_name SupplyRules
extends RefCounted
## Run-local state. Callers provide pickup identities and handle proximity separately.

signal changed

enum Kind { WOOD, CAN }

const WOOD_TARGET := 3
const CAN_TARGET := 1

var _available: Dictionary = {}
var _inventory: Dictionary = {Kind.WOOD: 0, Kind.CAN: 0}
var _stored: Dictionary = {Kind.WOOD: 0, Kind.CAN: 0}


func register_pickup(id: StringName, kind: Kind) -> bool:
	if id == &"" or _available.has(id) or not _inventory.has(kind):
		return false
	_available[id] = kind
	return true


func collect(id: StringName) -> bool:
	if not _available.has(id) or _available[id] == null:
		return false
	var kind: Kind = _available[id]
	_available[id] = null
	_inventory[kind] += 1
	changed.emit()
	return true


func deposit() -> bool:
	if carried(Kind.WOOD) + carried(Kind.CAN) == 0:
		return false
	for kind in [Kind.WOOD, Kind.CAN]:
		_stored[kind] += _inventory[kind]
		_inventory[kind] = 0
	changed.emit()
	return true


func carried(kind: Kind) -> int:
	return _inventory[kind]


func stored(kind: Kind) -> int:
	return _stored[kind]


func is_complete() -> bool:
	return stored(Kind.WOOD) >= WOOD_TARGET and stored(Kind.CAN) >= CAN_TARGET
