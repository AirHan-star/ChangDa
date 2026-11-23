class_name NightRaid
extends RefCounted

signal growled(point: Vector3)
signal gate_struck(point: Vector3)
signal enemy_struck(point: Vector3)

const INFECTED_SCENE := preload("res://scenes/infected.tscn")
const MAX_ACTIVE := 4
const MAX_TOTAL := 10
const SPAWN_INTERVAL := 3.8
const HIT_DAMAGE := 3
const PLAYER_HIT_DAMAGE := 14
const PLAYER_AGGRO_CHANCE := 0.38
const PLAYER_NOTICE_RANGE := 6.5
const PLAYER_CHASE_RANGE := 9.5
const PLAYER_CHASE_TIME := 10.0
const PLAYER_SIGHT_GRACE := 1.25
const MAX_PLAYER_CHASERS := 2
const LANES: Array[float] = [-0.82, 0.0, 0.82]
const SWORD_RANGE := 2.55
const SWORD_CONE := 0.30

var spawned := 0
var active: Array[RelayInfected] = []
var chasing_count := 0
var _spawn_in := 0.0
var _parent: Node3D
var _gate: StationGate
var _player: RelayPlayer
var _rng := RandomNumberGenerator.new()


func _init(parent: Node3D, gate: StationGate, player: RelayPlayer) -> void:
	_parent = parent
	_gate = gate
	_player = player
	_rng.randomize()


func tick(delta: float, survival: SurvivalRules) -> void:
	_spawn_in = maxf(0.0, _spawn_in - delta)
	if _spawn_in == 0.0 and spawned < MAX_TOTAL and active.size() < MAX_ACTIVE:
		_spawn_in = SPAWN_INTERVAL if _spawn() else 0.45

	var visible_pursuers := _update_chases(delta)
	var stop_z := _gate.global_position.z + 0.78
	var previous: Dictionary = {}
	var ordered := active.duplicate()
	# A returning pursuer may arrive behind the unit that was once behind it.
	ordered.sort_custom(func(a: RelayInfected, b: RelayInfected) -> bool:
		return a.global_position.z < b.global_position.z)
	for infected in ordered:
		if infected.tick_voice(delta, _player.global_position):
			growled.emit(infected.global_position + Vector3.UP * 1.4)
		if infected.chase_left > 0.0:
			if infected.pursue(delta, visible_pursuers[infected]):
				survival.damage_player(PLAYER_HIT_DAMAGE)
		else:
			var ahead: RelayInfected = previous.get(infected.lane)
			var goal := stop_z if ahead == null else ahead.global_position.z + 1.15
			if infected.advance(delta, _gate.global_position.x + LANES[infected.lane], goal, ahead == null):
				gate_struck.emit(_gate.global_position + Vector3.UP * 1.20)
				survival.damage_gate(HIT_DAMAGE)
			previous[infected.lane] = infected
		if survival.is_over():
			return


func _update_chases(delta: float) -> Dictionary:
	var visible_pursuers: Dictionary = {}
	var player_at := _player.global_position
	for infected in active:
		if infected.chase_left <= 0.0:
			continue
		infected.chase_left = maxf(0.0, infected.chase_left - delta)
		if infected.chase_left == 0.0 or infected.global_position.distance_squared_to(player_at) > PLAYER_CHASE_RANGE ** 2:
			infected.chase_left = 0.0
			continue
		var visible := _sees_player(infected)
		if visible:
			infected.last_seen_player = player_at
			infected.sight_lost_for = 0.0
		else:
			infected.sight_lost_for += delta
			if infected.sight_lost_for >= PLAYER_SIGHT_GRACE:
				infected.chase_left = 0.0
				continue
		visible_pursuers[infected] = visible
	for infected in active:
		if visible_pursuers.size() >= MAX_PLAYER_CHASERS:
			break
		if infected.player_target_checked or infected.global_position.distance_squared_to(player_at) > PLAYER_NOTICE_RANGE ** 2:
			continue
		if not _sees_player(infected):
			continue
		# One roll per infected, on first unobstructed encounter.
		infected.player_target_checked = true
		if _rng.randf() < PLAYER_AGGRO_CHANCE:
			infected.chase_left = PLAYER_CHASE_TIME
			infected.last_seen_player = player_at
			visible_pursuers[infected] = true
	chasing_count = visible_pursuers.size()
	return visible_pursuers


func _sees_player(infected: RelayInfected) -> bool:
	var eye := infected.global_position + Vector3.UP * 1.35
	var torso := _player.global_position + Vector3.UP * 0.95
	var query := PhysicsRayQueryParameters3D.create(eye, torso, 9)
	return _parent.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func strike(origin: Vector3, facing: Vector3, player_rid: RID) -> bool:
	var target: RelayInfected
	var best_distance := SWORD_RANGE * SWORD_RANGE
	var space := _parent.get_world_3d().direct_space_state
	for infected in active:
		var body := infected.global_position + Vector3.UP * 0.92
		var offset := body - origin
		var horizontal := Vector3(offset.x, 0.0, offset.z)
		var distance := offset.length_squared()
		if distance > best_distance or horizontal.normalized().dot(facing) < SWORD_CONE:
			continue
		var ray := PhysicsRayQueryParameters3D.create(origin, body, 13, [player_rid])
		var hit := space.intersect_ray(ray)
		if not hit.is_empty() and hit.get("collider") != infected:
			continue
		best_distance = distance
		target = infected
	if target == null:
		return false
	enemy_struck.emit(target.global_position + Vector3.UP * 1.02)
	if target.take_sword_hit():
		active.erase(target)
	return true


func _spawn() -> bool:
	var counts := [0, 0, 0]
	for infected in active:
		counts[infected.lane] += 1
	var infected := INFECTED_SCENE.instantiate() as RelayInfected
	var collision := infected.get_node("Collision") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.collision_mask = 15
	var space := _parent.get_world_3d().direct_space_state
	var lanes := [0, 1, 2]
	lanes.sort_custom(func(a: int, b: int) -> bool:
		return a < b if counts[a] == counts[b] else counts[a] < counts[b])
	for lane in lanes:
		var z := _gate.global_position.z + 18.0 + (spawned % 3) * 1.15
		for other in active:
			if other.lane == lane:
				z = maxf(z, other.global_position.z + 1.4)
		for step in range(4):
			var destination := Vector3(_gate.global_position.x + LANES[lane], 0.06, z + step * 1.25)
			query.transform.origin = destination + collision.position
			if not space.intersect_shape(query, 1).is_empty():
				continue
			infected.lane = lane
			infected.position = _parent.to_local(destination)
			infected.rotation.y = PI
			_parent.add_child(infected)
			active.append(infected)
			spawned += 1
			return true
	infected.free()
	return false
