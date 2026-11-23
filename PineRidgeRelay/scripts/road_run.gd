class_name RoadRun
extends RefCounted

enum Outcome { ACTIVE, WON, LOST }
enum Upgrade { DAMAGE, RATE, EXP, MAGAZINE, RELOAD, FIELD_DRESSING, ARMOR }

const WAVE_LIMIT := 30
const ACTIVE_CAP := 13
const SHOT_RANGE := 68.0
const SPAWN_LINE := 54.0
const LANES := [-4.8, -2.5, 0.0, 2.5, 4.8]
const PERKS := [
	["加重弹芯", "每发伤害 +2"],
	["快速扳机", "射击间隔缩短 17%"],
	["战场观察", "击杀经验加成 +25%"],
	["扩展弹匣", "弹匣容量 +6，补满弹匣"],
	["熟练换弹", "换弹时间缩短 19%"],
	["应急绷带", "立即恢复 40 点生命"],
	["衬板护甲", "每次受击少扣 2 点生命"],
]

var gun := RelayMagazine.new(true)
var vitals := SurvivalRules.new()
var wave := 0
var level := 1
var experience := 0
var kills := 0
var boss: RelayInfected
var boss_max_health := 0
var choices: Array[int] = []
var outcome := Outcome.ACTIVE
var intermission := 3.0
var _spawn_in := 0.0
var _pending := 0
var _spawned_this_wave := 0
var _boss_pending := false
var _xp_bonus := 0
var _armor := 0
var _rng := RandomNumberGenerator.new()
var _raid: NightRaid
var _region: SurvivalRegion
var _player: RelayPlayer


func _init(region: SurvivalRegion, player: RelayPlayer, raid: NightRaid) -> void:
	_region = region
	_player = player
	_raid = raid
	_rng.randomize()
	vitals.phase = SurvivalRules.Phase.NIGHT
	_raid.enemy_felled.connect(_on_felled)


func dispose() -> void:
	_raid.enemy_felled.disconnect(_on_felled)


func experience_needed() -> int:
	var depth := level - 1
	return 28 + depth * 13 + depth * depth * 2


func remaining() -> int:
	return _pending + _raid.active.size() + int(_boss_pending)


func standard_health() -> int:
	return 3 + wave


func tick(delta: float) -> void:
	if outcome != Outcome.ACTIVE or not choices.is_empty():
		return
	vitals.advance_hit_grace(delta)
	if intermission > 0:
		intermission = maxf(0, intermission - delta)
		if intermission == 0:
			_begin_wave()
	if wave == 0:
		return
	_spawn_in = maxf(0, _spawn_in - delta)
	if _spawn_in == 0 and _raid.active.size() < ACTIVE_CAP and (_boss_pending or _pending > 0):
		_spawn_in = 0.43 if _spawn() else 0.18
	for enemy in _raid.active:
		enemy.last_seen_player = _player.global_position
		if enemy.pursue(delta, _raid.has_clear_strike(enemy)):
			vitals.damage_player(maxi(4, enemy.road_hit - _armor))
			if vitals.player_health == 0:
				outcome = Outcome.LOST
				return


func _begin_wave() -> void:
	wave += 1
	_pending = 3 + ceili(wave * 0.34)
	_boss_pending = wave % 10 == 0
	_spawned_this_wave = 0
	_spawn_in = 0


func _spawn() -> bool:
	var brute := _boss_pending
	var anchor := (_spawned_this_wave * 2 + wave) % LANES.size()
	var candidate := NightRaid.INFECTED_SCENE.instantiate() as RelayInfected
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.65 if brute else 0.31
	capsule.height = 3.61 if brute else 1.70
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 15
	var space := _region.get_world_3d().direct_space_state
	for row in range(3):
		for lane in range(LANES.size()):
			var x: float = LANES[(anchor + lane) % LANES.size()]
			var point := Vector3(x,0.07,SPAWN_LINE + row * 2.1)
			query.transform.origin = point + Vector3.UP * capsule.height * 0.5
			if not space.intersect_shape(query,1).is_empty():
				continue
			candidate.position = point
			candidate.nest = -1
			candidate.health = 70 + wave * 4 if brute else standard_health()
			candidate.road_hit = 25 + int(wave / 5.0) if brute else 11 + int(wave / 5.0)
			candidate.travel_speed = 2.75 + wave * 0.04 if brute else 3.2 + wave * 0.045
			candidate.elite_scale = 2.08 + wave * 0.005 if brute else 1.0
			candidate.chasing = true
			_region.infected.add_child(candidate)
			_raid.active.append(candidate)
			_spawned_this_wave += 1
			if brute:
				boss = candidate
				boss_max_health = candidate.health
				_boss_pending = false
			else:
				_pending -= 1
			return true
	candidate.free()
	return false


func _on_felled(enemy: RelayInfected) -> void:
	if outcome != Outcome.ACTIVE:
		return
	kills += 1
	if enemy == boss:
		boss = null
	var base := 55 + wave * 3 if enemy.elite_scale > 1.0 else 9 + int(wave / 3.0)
	experience += roundi(base * (1.0 + _xp_bonus * 0.25))
	if remaining() == 0:
		if wave == WAVE_LIMIT:
			outcome = Outcome.WON
			choices.clear()
			return
		intermission = 2.7
	_offer_promotion()


func _offer_promotion() -> void:
	if experience < experience_needed() or not choices.is_empty():
		return
	experience -= experience_needed()
	level += 1
	var pool: Array[int] = [Upgrade.DAMAGE]
	if gun.interval > 0.071:
		pool.append(Upgrade.RATE)
	if _xp_bonus < 4:
		pool.append(Upgrade.EXP)
	if gun.capacity < 56:
		pool.append(Upgrade.MAGAZINE)
	if gun.reload_time > 0.46:
		pool.append(Upgrade.RELOAD)
	if vitals.player_health < 93:
		pool.append(Upgrade.FIELD_DRESSING)
	if _armor < 10:
		pool.append(Upgrade.ARMOR)
	while not pool.is_empty() and choices.size() < 3:
		var index := _rng.randi_range(0,pool.size()-1)
		choices.append(pool.pop_at(index))


func choose(upgrade: int) -> bool:
	if outcome != Outcome.ACTIVE or not choices.has(upgrade):
		return false
	match upgrade:
		Upgrade.DAMAGE: gun.damage += 2
		Upgrade.RATE: gun.interval = maxf(0.071,gun.interval * 0.83)
		Upgrade.EXP: _xp_bonus += 1
		Upgrade.MAGAZINE:
			gun.capacity += 6
			gun.rounds = gun.capacity
			gun.reload_left = 0
		Upgrade.RELOAD: gun.reload_time = maxf(0.46,gun.reload_time * 0.81)
		Upgrade.FIELD_DRESSING: vitals.heal(40)
		Upgrade.ARMOR: _armor += 2
	choices.clear()
	_offer_promotion()
	return true
