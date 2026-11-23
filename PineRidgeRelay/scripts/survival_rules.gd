class_name SurvivalRules
extends RefCounted

signal phase_changed
signal player_health_changed

enum Phase { DAY, NIGHT }

const DAY_SECONDS := 210.0
const NIGHT_SECONDS := 95.0
const PLAYER_MAX_HEALTH := 100
const RATION_HEAL := 30
const PLAYER_HIT_GRACE := 0.60

var phase := Phase.DAY
var day := 1
var remaining := DAY_SECONDS
var elapsed := 0.0
var player_health := PLAYER_MAX_HEALTH
var _hurt_grace := 0.0


func tick(delta: float) -> void:
	elapsed += delta
	advance_hit_grace(delta)
	remaining -= delta
	if remaining > 0.0:
		return
	if phase == Phase.DAY:
		phase = Phase.NIGHT
		remaining += NIGHT_SECONDS
	else:
		phase = Phase.DAY
		day += 1
		remaining += DAY_SECONDS
	phase_changed.emit()


func advance_hit_grace(delta: float) -> void:
	_hurt_grace = maxf(0.0,_hurt_grace-delta)


func heal(amount: int) -> int:
	var restored := mini(amount,PLAYER_MAX_HEALTH-player_health)
	if restored > 0:
		player_health += restored
		player_health_changed.emit()
	return restored


func damage_player(amount: int) -> bool:
	if player_health == 0 or _hurt_grace > 0.0:
		return false
	_hurt_grace = PLAYER_HIT_GRACE
	player_health = maxi(0, player_health - amount)
	player_health_changed.emit()
	return true


func eat_ration(inventory: SupplyRules) -> int:
	if player_health == 0 or player_health >= PLAYER_MAX_HEALTH or not inventory.consume_ration():
		return 0
	return heal(RATION_HEAL)


func recover() -> void:
	elapsed += remaining
	if phase == Phase.DAY:
		elapsed += NIGHT_SECONDS
	day += 1
	phase = Phase.DAY
	remaining = DAY_SECONDS
	player_health = PLAYER_MAX_HEALTH
	_hurt_grace = 2.0
	player_health_changed.emit()
	phase_changed.emit()
