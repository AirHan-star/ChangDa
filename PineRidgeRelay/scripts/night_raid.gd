class_name NightRaid
extends RefCounted

signal enemy_struck(point: Vector3)
signal enemy_felled(enemy: RelayInfected)

const INFECTED_SCENE := preload("res://scenes/infected.tscn")
const DETECT_RANGE := 8.0
const HOME_LEASH := 17.0
const SIGHT_GRACE := 2.1
const HIT_DAMAGE := 14

var active: Array[RelayInfected] = []
var chasing_count := 0
var _spawn_in := 0.0
var _next_nest := 0
var _spawn_attempts := 0
var _region: SurvivalRegion
var _player: RelayPlayer
var _cleared: Dictionary
var _day := 0


func _init(region: SurvivalRegion, player: RelayPlayer, cleared: Dictionary) -> void:
	_region = region
	_player = player
	_cleared = cleared


func end_night() -> void:
	for enemy in active:
		enemy.queue_free()
	active.clear()
	_next_nest = 0
	_spawn_attempts = 0
	_spawn_in = 0
	chasing_count = 0


func tick(delta: float, survival: SurvivalRules) -> void:
	_day = survival.day
	_spawn_in = maxf(0.0, _spawn_in - delta)
	var nests := _region.nests()
	if _spawn_in <= 0.0 and _next_nest < nests.size():
		var home := _region.surface(nests[_next_nest])
		if _cleared.has(_key(_next_nest)) or _spawn(home, _next_nest):
			_next_nest += 1
			_spawn_attempts = 0
			_spawn_in = 1.1
		else:
			_spawn_attempts += 1
			if _spawn_attempts >= 4:
				_next_nest += 1
				_spawn_attempts = 0
			_spawn_in = 0.9

	chasing_count = 0
	for enemy in active:
		var seen := _update_target(enemy, delta)
		if enemy.chasing:
			chasing_count += 1
			if enemy.pursue(delta, seen):
				survival.damage_player(HIT_DAMAGE)
		else:
			enemy.roam(delta)
		if survival.player_health <= 0:
			return


func _update_target(enemy: RelayInfected, delta: float) -> bool:
	var player_at := _player.global_position
	var player_near_home := enemy.home.distance_squared_to(player_at) <= HOME_LEASH ** 2
	var enemy_near_home := enemy.home.distance_squared_to(enemy.global_position) <= HOME_LEASH ** 2
	if not player_near_home or not enemy_near_home:
		if enemy.chasing:
			enemy.return_home()
		return false
	if enemy.returning:
		return false
	var in_range := enemy.global_position.distance_squared_to(player_at) <= DETECT_RANGE ** 2
	if not in_range and not enemy.chasing:
		return false
	var visible := _sees_player(enemy)
	if visible:
		enemy.last_seen_player = player_at
		enemy.sight_lost_for = 0.0
		enemy.chasing = true
	elif enemy.chasing:
		enemy.sight_lost_for += delta
		if enemy.sight_lost_for > SIGHT_GRACE:
			enemy.return_home()
	return visible


func _sees_player(enemy: RelayInfected) -> bool:
	var start := enemy.global_position + Vector3.UP * 1.35
	var finish := _player.global_position + Vector3.UP * 0.92
	var ray := PhysicsRayQueryParameters3D.create(start, finish, 9)
	return _region.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func has_clear_strike(enemy: RelayInfected) -> bool:
	return enemy.global_position.distance_squared_to(_player.global_position) < 12.0 and _sees_player(enemy)


func strike(origin: Vector3, facing: Vector3, reach: float, damage: int) -> bool:
	var target: RelayInfected
	var best := reach * reach
	var space := _region.get_world_3d().direct_space_state
	for enemy in active:
		var point := enemy.global_position + Vector3.UP * 0.92
		var offset := point - origin
		var alignment := Vector3(offset.x, 0, offset.z).normalized().dot(facing)
		var distance := offset.length_squared()
		if distance > best or alignment < 0.30:
			continue
		var ray := PhysicsRayQueryParameters3D.create(origin, point, 13)
		var hit := space.intersect_ray(ray)
		if not hit.is_empty() and hit.get("collider") != enemy:
			continue
		target = enemy
		best = distance
	if target == null:
		return false
	_hit(target, damage)
	return true


func shoot(origin: Vector3, direction: Vector3, damage := 4, reach := 36.0) -> Vector3:
	var end := origin + direction * reach
	var query := PhysicsRayQueryParameters3D.create(origin, end, 13, [_player.get_rid()])
	var hit := _region.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return end
	var enemy := hit.get("collider") as RelayInfected
	if enemy != null and active.has(enemy):
		_hit(enemy, damage)
	return hit.position


func _hit(enemy: RelayInfected, damage: int) -> void:
	enemy_struck.emit(enemy.global_position + Vector3.UP)
	if enemy.take_hit(damage):
		if enemy.nest >= 0:
			_cleared[_key(enemy.nest)] = true
		active.erase(enemy)
		enemy_felled.emit(enemy)


func _spawn(home: Vector3, index: int) -> bool:
	var enemy := INFECTED_SCENE.instantiate() as RelayInfected
	var hull := enemy.get_node("Collision") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hull.shape
	query.collision_mask = 15
	for offset in [Vector3.ZERO, Vector3(1.5,0,0), Vector3(-1.5,0,0), Vector3(0,0,1.5), Vector3(0,0,-1.5)]:
		var flat := Vector2(home.x, home.z) + Vector2(offset.x, offset.z)
		var point := _region.surface(flat) + Vector3.UP * 0.16
		query.transform.origin = point + hull.position
		if not _region.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			continue
		enemy.position = point
		enemy.home = point
		enemy.nest = index
		_region.infected.add_child(enemy)
		active.append(enemy)
		return true
	enemy.free()
	return false


func _key(nest: int) -> String:
	return "%d:%d:%d" % [_day, _region.id, nest]
