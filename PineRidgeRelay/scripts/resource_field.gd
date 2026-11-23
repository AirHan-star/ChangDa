class_name ResourceField
extends RefCounted

const WOOD_SCENE := preload("res://scenes/wood_pickup.tscn")
const ORE_SCENE := preload("res://scenes/ore.tscn")
const TIN := preload("res://assets/world/ration_tin.glb")
const WOOD_DELAY := 48.0
const ORE_DELAY := 72.0

class Slot:
	var key: String
	var place: Vector3
	var kind: int
	var occupant: Node3D

var _slots: Array[Slot] = []
var _region: SurvivalRegion
var _depleted: Dictionary
var _clearance := SphereShape3D.new()


func _init(region: SurvivalRegion, depleted: Dictionary) -> void:
	_region = region
	_depleted = depleted
	_clearance.radius = 0.82
	var rows := region.deposits()
	for i in range(rows.size()):
		var row: Array = rows[i]
		var slot := Slot.new()
		slot.key = "%d:%d" % [region.id, i]
		slot.place = region.surface(Vector2(row[0], row[1]))
		slot.kind = row[2]
		_slots.append(slot)
		if not depleted.has(slot.key):
			_place(slot)


func tick(time: float, daylight: bool) -> void:
	if not daylight:
		return
	for slot in _slots:
		if is_instance_valid(slot.occupant) or float(_depleted.get(slot.key, 0.0)) > time:
			continue
		if slot.kind >= SupplyRules.Kind.STONE and not _clear_to_spawn(slot.place):
			continue
		_depleted.erase(slot.key)
		_place(slot)


func remove(resource: Node3D, time: float) -> void:
	for slot in _slots:
		if slot.occupant != resource:
			continue
		slot.occupant = null
		var delay := WOOD_DELAY if slot.kind == SupplyRules.Kind.WOOD else ORE_DELAY
		_depleted[slot.key] = time + delay if slot.kind != SupplyRules.Kind.CAN else INF
		resource.queue_free()
		return


func _clear_to_spawn(location: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _clearance
	query.transform.origin = location + Vector3.UP * 0.5
	query.collision_mask = 6
	return _region.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _place(slot: Slot) -> void:
	if slot.kind >= SupplyRules.Kind.STONE:
		var ore := ORE_SCENE.instantiate() as MineableOre
		ore.name = "Deposit_" + slot.key.replace(":", "_")
		ore.kind = slot.kind
		ore.position = slot.place
		_region.ores.add_child(ore)
		slot.occupant = ore
		return
	var supply: Node3D
	if slot.kind == SupplyRules.Kind.WOOD:
		supply = WOOD_SCENE.instantiate()
	else:
		supply = SupplyPickup.new()
		supply.kind = SupplyRules.Kind.CAN
		supply.add_child(TIN.instantiate())
		RelayGeometry.label(supply, "罐头", Vector3.UP * 1.2, Color("#8aefca"))
	supply.name = "Supply_" + slot.key.replace(":", "_")
	supply.position = slot.place
	_region.supplies.add_child(supply)
	slot.occupant = supply
