class_name ResourceField
extends RefCounted

const WOOD_SCENE := preload("res://scenes/wood_pickup.tscn")
const ORE_SCENE := preload("res://scenes/ore.tscn")
const MAX_DAILY_WOOD := 22
const MAX_DAILY_ORE := 8
const WOOD_DELAY := 15.0
const ORE_DELAY := 21.0

class Slot:
	var occupant: Node3D
	var location: Vector3
	var cooldown := 0.0

	func _init(resource: Node3D) -> void:
		occupant = resource
		location = resource.position

var _wood: Array[Slot] = []
var _ore: Array[Slot] = []
var _wood_total := 0
var _ore_total := 0
var _supplies: Node3D
var _ores: Node3D
var _rules: SupplyRules


func _init(supplies: Node3D, ores: Node3D, rules: SupplyRules) -> void:
	_supplies = supplies
	_ores = ores
	_rules = rules
	for child in supplies.get_children():
		var pickup := child as SupplyPickup
		assert(pickup != null)
		var registered := _rules.register_pickup(pickup.supply_id, pickup.kind)
		assert(registered)
		if pickup.kind == SupplyRules.Kind.WOOD:
			_wood.append(Slot.new(pickup))
	for child in ores.get_children():
		_ore.append(Slot.new(child))
	_wood_total = _wood.size()
	_ore_total = _ore.size()


func tick(delta: float) -> void:
	# The authored slots also bound the number present simultaneously.
	for slot in _wood:
		if _wood_total >= MAX_DAILY_WOOD:
			break
		if _ready_to_refill(slot, delta):
			_wood_total += 1
			var pickup := WOOD_SCENE.instantiate() as SupplyPickup
			pickup.supply_id = StringName("refresh_%d" % _wood_total)
			var registered := _rules.register_pickup(pickup.supply_id, pickup.kind)
			assert(registered)
			_place(pickup, slot, _supplies)
	for slot in _ore:
		if _ore_total >= MAX_DAILY_ORE:
			break
		if _ready_to_refill(slot, delta):
			_ore_total += 1
			_place(ORE_SCENE.instantiate() as Node3D, slot, _ores)


func remove(resource: Node3D) -> void:
	var slots := _ore if resource is MineableOre else _wood
	for slot in slots:
		if slot.occupant == resource:
			slot.occupant = null
			slot.cooldown = ORE_DELAY if resource is MineableOre else WOOD_DELAY
			break
	resource.queue_free()


func _ready_to_refill(slot: Slot, delta: float) -> bool:
	if is_instance_valid(slot.occupant):
		return false
	slot.cooldown -= delta
	return slot.cooldown <= 0.0


func _place(resource: Node3D, slot: Slot, parent: Node3D) -> void:
	resource.position = slot.location
	parent.add_child(resource)
	slot.occupant = resource
