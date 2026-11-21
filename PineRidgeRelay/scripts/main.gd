extends Node3D

const PICKUP_RANGE := 2.15
const CHEST_RANGE := 2.55

@onready var player: CharacterBody3D = $Player
@onready var supplies: Node3D = $Clearing/Supplies
@onready var chest: Marker3D = $Clearing/ChestInteraction
@onready var hud: CanvasLayer = $HUD

var rules := SupplyRules.new()
var _interaction_requested := false


func _ready() -> void:
	for child in supplies.get_children():
		var pickup := child as SupplyPickup
		if not rules.register_pickup(pickup.supply_id, pickup.kind):
			push_error("Invalid supply ID: %s" % pickup.supply_id)
	rules.changed.connect(_refresh_inventory)
	_refresh_inventory()


func _physics_process(_delta: float) -> void:
	var interact := _interaction_requested
	_interaction_requested = false
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		hud.set_prompt("鼠标已释放 · 单击画面继续")
		return
	var target := _interaction_target()
	if interact:
		if target == chest:
			rules.deposit()
		elif target is SupplyPickup and rules.collect(target.supply_id):
			target.queue_free()
			target = null
	if target == chest:
		var has_supplies := rules.carried(SupplyRules.Kind.WOOD) + rules.carried(SupplyRules.Kind.CAN) > 0
		hud.set_prompt("按 E 存入补给箱" if has_supplies else "补给箱 · 背包为空")
	elif target is SupplyPickup:
		hud.set_prompt("按 E 拾取")
	else:
		hud.set_prompt("")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"interact") or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	_interaction_requested = true
	get_viewport().set_input_as_handled()


func _interaction_target() -> Node3D:
	var nearest: Node3D = null
	var best_distance := INF
	if _within_reach(chest.global_position, CHEST_RANGE):
		nearest = chest
		best_distance = player.global_position.distance_squared_to(chest.global_position)
	for child in supplies.get_children():
		var pickup := child as SupplyPickup
		if pickup.is_queued_for_deletion():
			continue
		var distance := player.global_position.distance_squared_to(pickup.global_position)
		if distance < best_distance and _within_reach(pickup.global_position + Vector3.UP * 0.45, PICKUP_RANGE):
			nearest = pickup
			best_distance = distance
	return nearest


func _within_reach(point: Vector3, reach: float) -> bool:
	var from := player.global_position + Vector3.UP * 0.85
	if from.distance_squared_to(point) > reach * reach:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, point, 1, [player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _refresh_inventory() -> void:
	hud.show_supplies(rules)
