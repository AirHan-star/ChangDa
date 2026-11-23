class_name RelayMagazine
extends RefCounted

const STANDARD_CAPACITY := 20

var capacity := STANDARD_CAPACITY
var rounds := 0
var infinite_reserve: bool
var damage := 4
var interval := 0.17
var reload_time := 1.65
var reload_left := 0.0
var shot_left := 0.0


func _init(infinite := false) -> void:
	infinite_reserve = infinite
	if infinite:
		rounds = capacity


func tick(delta: float, inventory: SupplyRules) -> void:
	shot_left = maxf(0, shot_left - delta)
	if reload_left <= 0:
		return
	reload_left = maxf(0, reload_left - delta)
	if reload_left == 0:
		fill(inventory)


func start_reload(inventory: SupplyRules) -> bool:
	if rounds >= capacity or reload_left > 0 or (not infinite_reserve and inventory.carried(SupplyRules.Kind.AMMO) == 0):
		return false
	reload_left = reload_time
	return true


func fill(inventory: SupplyRules) -> void:
	var amount := capacity - rounds
	if infinite_reserve:
		rounds += amount
	else:
		amount = mini(amount, inventory.carried(SupplyRules.Kind.AMMO))
		if amount > 0:
			rounds += amount
			inventory.pay({SupplyRules.Kind.AMMO: amount})


func take_shot(cadence := 1.0) -> bool:
	if rounds == 0 or reload_left > 0 or shot_left > 0:
		return false
	rounds -= 1
	shot_left = interval * cadence
	return true
