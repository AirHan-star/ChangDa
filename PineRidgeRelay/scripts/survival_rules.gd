class_name SurvivalRules
extends RefCounted
## Owns the clock, gate and player health without depending on the scene or input.

signal phase_changed
signal player_health_changed

enum Phase { DAY, NIGHT, WON, LOST }
enum LossCause { NONE, GATE, PLAYER }

const DAY_SECONDS := 105.0
const NIGHT_SECONDS := 52.0
const BASE_HEALTH := 70
const PLAYER_MAX_HEALTH := 100
const RATION_HEAL := 30
const PLAYER_HIT_GRACE := 0.60
const WOOD_PER_UPGRADE := 2
const HEALTH_PER_UPGRADE := 32
const MAX_UPGRADES := 3

var phase := Phase.DAY
var remaining := DAY_SECONDS
var health := BASE_HEALTH
var upgrades := 0
var player_health := PLAYER_MAX_HEALTH
var loss_cause := LossCause.NONE
var _hurt_grace := 0.0


func tick(delta: float) -> void:
	if phase != Phase.DAY and phase != Phase.NIGHT:
		return
	_hurt_grace = maxf(0.0, _hurt_grace - delta)
	remaining = maxf(0.0, remaining - delta)
	if remaining > 0.0:
		return
	if phase == Phase.DAY:
		remaining = NIGHT_SECONDS
		_set_phase(Phase.NIGHT)
	else:
		_set_phase(Phase.WON)


func reinforce(inventory: SupplyRules) -> bool:
	if phase != Phase.DAY or upgrades >= MAX_UPGRADES:
		return false
	if not inventory.spend_wood(WOOD_PER_UPGRADE):
		return false
	upgrades += 1
	health += HEALTH_PER_UPGRADE
	return true


func damage_gate(amount: int) -> void:
	if phase != Phase.NIGHT:
		return
	health = maxi(0, health - amount)
	if health == 0:
		loss_cause = LossCause.GATE
		_set_phase(Phase.LOST)


func damage_player(amount: int) -> bool:
	if phase != Phase.NIGHT or _hurt_grace > 0.0:
		return false
	_hurt_grace = PLAYER_HIT_GRACE
	player_health = maxi(0, player_health - amount)
	player_health_changed.emit()
	if player_health == 0:
		loss_cause = LossCause.PLAYER
		_set_phase(Phase.LOST)
	return true


func eat_ration(inventory: SupplyRules) -> int:
	if is_over() or player_health >= PLAYER_MAX_HEALTH or not inventory.consume_ration():
		return 0
	var healed := mini(RATION_HEAL, PLAYER_MAX_HEALTH - player_health)
	player_health += healed
	player_health_changed.emit()
	return healed


func max_health() -> int:
	return BASE_HEALTH + upgrades * HEALTH_PER_UPGRADE


func is_over() -> bool:
	return phase == Phase.WON or phase == Phase.LOST


func _set_phase(next: Phase) -> void:
	phase = next
	phase_changed.emit()
